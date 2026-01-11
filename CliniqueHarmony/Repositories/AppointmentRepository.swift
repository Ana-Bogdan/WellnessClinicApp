import CoreData
import Combine
import Foundation
import OSLog
import Network

/// Repository for managing Appointment CRUD operations with server integration and local DB fallback
/// All server operations run on a separate background thread/coroutine
@MainActor
final class AppointmentRepository: ObservableObject {
    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: "com.cliniqueharmony", category: "AppointmentRepository")

    // Server client (runs on separate actor/thread)
    private let serverClient: ServerClient
    private let webSocketClient: WebSocketClient

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var isServerAvailable = false

    /// Published property that emits appointment changes
    /// Values are retrieved only once and reused while the application is alive
    @Published private(set) var appointments: [Appointment] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedFromServer = false // Track if we've loaded from server once
    private var hasSyncedLocalToServer = false // Track if we've synced local data to server in this session
    private var isSyncingToServer = false // Track if a sync to server is in progress
    private var isCreatingAppointment = false // Track if an appointment creation is in progress
    private var recentlyCreatedAppointmentIds = Set<String>() // Track recently created IDs to ignore WebSocket duplicates
    private var isSavingToLocalDB = false // Track if we're actively saving to local DB (to prevent observer reload)
    private var pendingCreateAppointments = Set<String>() // Track appointments we're currently creating (by content hash) to ignore WebSocket
    private var serverWasUnavailable = false // Track if server was unavailable (to trigger sync when it comes back)

    private var fetchRequest: NSFetchRequest<AppointmentEntity> {
        let request = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AppointmentEntity.date, ascending: true)]
        return request
    }

    init(
        persistenceController: PersistenceController = .shared,
        serverBaseURL: URL = URL(string: "http://localhost:3000")!
    ) {
        self.persistenceController = persistenceController
        self.serverClient = ServerClient(baseURL: serverBaseURL)
        self.webSocketClient = WebSocketClient(baseURL: serverBaseURL)

        setupNetworkMonitoring()
        setupWebSocketCallbacks()
        setupObserver()
    }

    /// Sets up network monitoring to detect server availability
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let wasAvailable = self.isServerAvailable
                self.isServerAvailable = path.status == .satisfied

                if self.isServerAvailable != wasAvailable {
                    self.logger.debug("Network status changed: \(self.isServerAvailable ? "available" : "unavailable")")

                    if self.isServerAvailable {
                        // Check if server is actually reachable
                        let serverReachable = await self.serverClient.isServerAvailable()
                        if serverReachable {
                            self.logger.info("Server is reachable, connecting WebSocket")
                            
                            // If server was unavailable and now it's back, trigger sync
                            let wasUnavailable = self.serverWasUnavailable
                            if wasUnavailable {
                                self.serverWasUnavailable = false
                            }
                            
                            self.webSocketClient.connect()

                            // If we haven't loaded from server yet, do it now
                            if !self.hasLoadedFromServer {
                                await self.loadAppointments()
                            } else if wasUnavailable {
                                // Server came back online - sync local changes and reload
                                self.logger.info("Server came back online, syncing local changes and reloading")
                                await self.syncAndReloadWhenServerComesOnline()
                            }
                        } else {
                            self.serverWasUnavailable = true
                        }
                    } else {
                        self.logger.info("Network unavailable, disconnecting WebSocket")
                        self.webSocketClient.disconnect()
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    /// Sets up WebSocket callbacks for real-time server updates
    private func setupWebSocketCallbacks() {
        webSocketClient.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // If server was unavailable and now WebSocket connected, trigger sync
                if self.serverWasUnavailable && self.hasLoadedFromServer {
                    self.logger.info("WebSocket connected after server was unavailable, triggering sync")
                    self.serverWasUnavailable = false
                    await self.syncAndReloadWhenServerComesOnline()
                }
            }
        }
        
        webSocketClient.onAppointmentCreated = { [weak self] appointment in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Ignore WebSocket messages for appointments we just created (to prevent duplicates)
                if self.recentlyCreatedAppointmentIds.contains(appointment.id) {
                    self.logger.debug("WebSocket: Ignoring duplicate - appointment \(appointment.id) was recently created by this client")
                    return
                }

                // Check if we're currently creating an appointment with matching content
                let contentHash = "\(appointment.userID)-\(appointment.practitionerID)-\(appointment.service)-\(appointment.date.timeIntervalSince1970)-\(appointment.status.rawValue)"
                if self.pendingCreateAppointments.contains(contentHash) {
                    self.logger.debug("WebSocket: Ignoring duplicate - appointment matches pending creation")
                    return
                }

                // Also check if it's already in cache
                if self.appointments.contains(where: { $0.id == appointment.id }) {
                    self.logger.debug("WebSocket: Ignoring duplicate - appointment \(appointment.id) already exists in cache")
                    return
                }

                self.logger.info("WebSocket: Appointment created on server by another client: \(appointment.id)")
                await self.syncAppointmentFromServer(appointment)
            }
        }

        webSocketClient.onAppointmentUpdated = { [weak self] appointment in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.debug("WebSocket: Appointment updated on server, updating local cache")
                await self.syncAppointmentFromServer(appointment)
            }
        }

        webSocketClient.onAppointmentDeleted = { [weak self] appointmentId in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.debug("WebSocket: Appointment deleted on server, removing from local cache")
                await self.removeAppointmentFromCache(appointmentId)
            }
        }
    }

    /// Sets up Core Data observer to automatically update when local data changes
    private func setupObserver() {
        let context = persistenceController.viewContext
        let notificationCenter = NotificationCenter.default

        // Observe Core Data save notifications
        notificationCenter.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .merge(with: notificationCenter.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context))
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Don't reload if we're actively saving (to prevent duplicates from our own saves)
                    if !self.isSavingToLocalDB {
                        await self.loadAppointmentsFromLocalDB()
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Loads appointments - tries server first, falls back to local DB
    /// Values are retrieved only once and reused while the application is alive
    func loadAppointments() async {
        // Prevent concurrent loads
        guard !isLoading else {
            logger.debug("Load already in progress, skipping")
            return
        }

        isLoading = true
        errorMessage = nil

        logger.debug("Loading appointments - checking server availability")

        // Try server first if available
        if isServerAvailable {
            let serverReachable = await serverClient.isServerAvailable()
            if serverReachable {
                logger.debug("Server is available, loading from server")
                serverWasUnavailable = false // Reset flag when server is reachable
                await loadAppointmentsFromServer()
                hasLoadedFromServer = true

                // Connect WebSocket for real-time updates
                webSocketClient.connect()

                isLoading = false
                return
            } else {
                serverWasUnavailable = true // Mark server as unavailable
            }
        }

        // Fall back to local DB
        logger.debug("Server unavailable, loading from local database")
        serverWasUnavailable = true // Mark server as unavailable
        await loadAppointmentsFromLocalDB()
        isLoading = false
    }

    /// Loads appointments from the server (runs on background thread)
    private func loadAppointmentsFromServer() async {
        logger.debug("Fetching appointments from server")

        do {
            // Server operations run on separate thread (ServerClient is an actor)
            let serverAppointments = try await serverClient.fetchAppointments()

            logger.info("Successfully loaded \(serverAppointments.count) appointments from server")

            // If server is empty but local DB has data, sync local data to server (only once per session)
            // Check and set flags atomically to prevent concurrent syncs
            if serverAppointments.isEmpty {
                // Use a lock-like pattern: check and set in one go
                if !hasSyncedLocalToServer && !isSyncingToServer {
                    // Set flags immediately to prevent other calls from syncing
                    hasSyncedLocalToServer = true
                    isSyncingToServer = true

                    let localAppointments = await getLocalAppointments()
                    if !localAppointments.isEmpty {
                        logger.info("Server is empty but local DB has \(localAppointments.count) appointments. Syncing to server...")

                        // Store old local IDs to delete them after sync
                        let oldLocalIds = Set(localAppointments.map { $0.id })

                        await syncLocalAppointmentsToServer(localAppointments)
                        // Reload from server after sync
                        let syncedAppointments = try await serverClient.fetchAppointments()
                        self.appointments = syncedAppointments.sorted { $0.date < $1.date }

                        // Delete old local entries and sync new server data
                        await deleteLocalAppointmentsWithIds(oldLocalIds)
                        await syncAppointmentsToLocalDB(syncedAppointments)

                        isSyncingToServer = false // Mark sync as complete
                        return
                    } else {
                        // No local appointments, reset flags
                        hasSyncedLocalToServer = false
                        isSyncingToServer = false
                    }
                } else {
                    logger.debug("Sync already in progress or completed, skipping")
                }
            }

            // Update local cache
            self.appointments = serverAppointments.sorted { $0.date < $1.date }

            // Sync to local DB for offline access
            await syncAppointmentsToLocalDB(serverAppointments)

        } catch let error as ServerError {
            logger.error("Failed to load appointments from server: \(error.localizedDescription)")
            errorMessage = error.userFriendlyMessage
            serverWasUnavailable = true // Mark server as unavailable

            // Fall back to local DB
            await loadAppointmentsFromLocalDB()
        } catch {
            logger.error("Unexpected error loading appointments: \(error.localizedDescription)")
            errorMessage = "Unable to load appointments. Please try again."
            serverWasUnavailable = true // Mark server as unavailable

            // Fall back to local DB
            await loadAppointmentsFromLocalDB()
        }
    }

    /// Loads appointments from local database (runs on background thread)
    private func loadAppointmentsFromLocalDB() async {
        logger.debug("Loading appointments from local database")

        let controller = persistenceController

        await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    let entities = try backgroundContext.fetch(self.fetchRequest)
                    let appointments = entities.compactMap { entity -> Appointment? in
                        guard let id = entity.id,
                              let userID = entity.userID,
                              let practitionerID = entity.practitionerID,
                              let service = entity.service,
                              let date = entity.date,
                              let statusString = entity.status,
                              let status = AppointmentStatus(rawValue: statusString) else {
                            return nil
                        }

                        return Appointment(
                            id: id,
                            userID: userID,
                            practitionerID: practitionerID,
                            service: service,
                            date: date,
                            status: status
                        )
                    }

                    Task { @MainActor in
                        self.appointments = appointments.sorted { $0.date < $1.date }
                        self.logger.info("Loaded \(appointments.count) appointments from local database")
                        continuation.resume()
                    }
                } catch {
                    let errorMsg = "Failed to load appointments from database: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")

                    Task { @MainActor in
                        self.errorMessage = "Unable to load appointments. Please try again."
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Creates a new appointment - sends to server, falls back to local DB
    /// Only the created element is sent to the server. The ID is managed by the server.
    func createAppointment(
        userID: String,
        practitionerID: String,
        service: String,
        date: Date,
        status: AppointmentStatus = .booked
    ) async -> Appointment? {
        // Prevent concurrent creates (e.g., double-tap)
        guard !isCreatingAppointment else {
            logger.debug("Appointment creation already in progress, skipping duplicate request")
            return nil
        }

        isCreatingAppointment = true
        defer { isCreatingAppointment = false }

        errorMessage = nil
        logger.debug("Creating appointment - userID: \(userID), practitionerID: \(practitionerID), service: \(service)")

        // Check if server came back online and sync if needed (before attempting to create)
        await checkServerAndSyncIfNeeded()

        // Try server first if available
        if isServerAvailable {
            let serverReachable = await serverClient.isServerAvailable()
            if serverReachable {
                serverWasUnavailable = false // Reset flag when server is reachable
                do {
                    // Create a content hash to track this creation BEFORE the server call
                    // This way we can ignore the WebSocket message even if it arrives before we get the server response
                    let contentHash = "\(userID)-\(practitionerID)-\(service)-\(date.timeIntervalSince1970)-\(status.rawValue)"
                    pendingCreateAppointments.insert(contentHash)

                    // Server operations run on separate thread (ServerClient is an actor)
                    let appointment = try await serverClient.createAppointment(
                        userID: userID,
                        practitionerID: practitionerID,
                        service: service,
                        date: date,
                        status: status
                    )

                    logger.info("Successfully created appointment on server with ID: \(appointment.id)")

                    // Remove from pending and add to recently created
                    pendingCreateAppointments.remove(contentHash)
                    recentlyCreatedAppointmentIds.insert(appointment.id)

                    // Remove from tracking after a delay (WebSocket message should arrive within 2 seconds)
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        recentlyCreatedAppointmentIds.remove(appointment.id)
                    }

                    // Update local cache (this also saves to DB)
                    // Set isSavingToLocalDB BEFORE syncing to prevent observer from reloading
                    isSavingToLocalDB = true
                    await syncAppointmentFromServer(appointment)
                    // Small delay to ensure save completes before clearing flag
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    isSavingToLocalDB = false

                    return appointment
                } catch let error as ServerError {
                    logger.error("Failed to create appointment on server: \(error.localizedDescription)")
                    errorMessage = error.userFriendlyMessage
                    serverWasUnavailable = true // Mark server as unavailable

                    // Fall back to local DB
                    return await createAppointmentInLocalDB(
                        userID: userID,
                        practitionerID: practitionerID,
                        service: service,
                        date: date,
                        status: status
                    )
                } catch {
                    logger.error("Unexpected error creating appointment: \(error.localizedDescription)")
                    errorMessage = "Unable to create appointment. Please try again."
                    serverWasUnavailable = true // Mark server as unavailable

                    // Fall back to local DB
                    return await createAppointmentInLocalDB(
                        userID: userID,
                        practitionerID: practitionerID,
                        service: service,
                        date: date,
                        status: status
                    )
                }
            }
        }

        // Fall back to local DB
        logger.debug("Server unavailable, creating appointment in local database")
        serverWasUnavailable = true // Mark server as unavailable
        return await createAppointmentInLocalDB(
            userID: userID,
            practitionerID: practitionerID,
            service: service,
            date: date,
            status: status
        )
    }

    /// Updates an existing appointment - sends to server, falls back to local DB
    /// The server element is reused (not deleted and recreated). The ID remains the same.
    func updateAppointment(_ appointment: Appointment) async -> Appointment? {
        errorMessage = nil
        logger.debug("Updating appointment with ID: \(appointment.id)")

        // Check if server came back online and sync if needed (before attempting to update)
        await checkServerAndSyncIfNeeded()

        // Try server first if available
        if isServerAvailable {
            let serverReachable = await serverClient.isServerAvailable()
            if serverReachable {
                serverWasUnavailable = false // Reset flag when server is reachable
                do {
                    // Server operations run on separate thread (ServerClient is an actor)
                    let updatedAppointment = try await serverClient.updateAppointment(appointment)

                    logger.info("Successfully updated appointment on server with ID: \(updatedAppointment.id)")

                    // Update local cache
                    await syncAppointmentFromServer(updatedAppointment)

                    // Also update local DB (result is used to ensure update succeeded)
                    _ = await updateAppointmentInLocalDB(updatedAppointment)

                    return updatedAppointment
                } catch let error as ServerError {
                    logger.error("Failed to update appointment on server: \(error.localizedDescription)")
                    errorMessage = error.userFriendlyMessage

                    // Fall back to local DB
                    return await updateAppointmentInLocalDB(appointment)
                } catch {
                    logger.error("Unexpected error updating appointment: \(error.localizedDescription)")
                    errorMessage = "Unable to update appointment. Please try again."

                    // Fall back to local DB
                    return await updateAppointmentInLocalDB(appointment)
                }
            }
        }

        // Fall back to local DB
        logger.debug("Server unavailable, updating appointment in local database")
        return await updateAppointmentInLocalDB(appointment)
    }

    /// Deletes an appointment - sends only the ID to server, falls back to local DB
    /// The element is properly identified by its ID
    func deleteAppointment(id: String) async -> Bool {
        errorMessage = nil
        logger.debug("Deleting appointment with ID: \(id)")

        // Check if server came back online and sync if needed (before attempting to delete)
        await checkServerAndSyncIfNeeded()

        // Try server first if available
        if isServerAvailable {
            let serverReachable = await serverClient.isServerAvailable()
            if serverReachable {
                serverWasUnavailable = false // Reset flag when server is reachable
                do {
                    // Server operations run on separate thread (ServerClient is an actor)
                    // Only the ID is sent to the server
                    try await serverClient.deleteAppointment(id: id)

                    logger.info("Successfully deleted appointment on server with ID: \(id)")

                    // Update local cache
                    await removeAppointmentFromCache(id)

                    // Also delete from local DB (result is used to ensure deletion succeeded)
                    _ = await deleteAppointmentFromLocalDB(id: id)

                    return true
                } catch let error as ServerError {
                    logger.error("Failed to delete appointment on server: \(error.localizedDescription)")
                    errorMessage = error.userFriendlyMessage

                    // Fall back to local DB
                    return await deleteAppointmentFromLocalDB(id: id)
                } catch {
                    logger.error("Unexpected error deleting appointment: \(error.localizedDescription)")
                    errorMessage = "Unable to delete appointment. Please try again."

                    // Fall back to local DB
                    return await deleteAppointmentFromLocalDB(id: id)
                }
            }
        }

        // Fall back to local DB
        logger.debug("Server unavailable, deleting appointment from local database")
        return await deleteAppointmentFromLocalDB(id: id)
    }

    // MARK: - Local Database Operations (run on background thread)

    private func createAppointmentInLocalDB(
        userID: String,
        practitionerID: String,
        service: String,
        date: Date,
        status: AppointmentStatus
    ) async -> Appointment? {
        let controller = persistenceController

        return await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    let entity = AppointmentEntity(context: backgroundContext)
                    entity.id = UUID().uuidString
                    entity.userID = userID
                    entity.practitionerID = practitionerID
                    entity.service = service
                    entity.date = date
                    entity.status = status.rawValue

                    try controller.save(context: backgroundContext)

                    guard let createdID = entity.id else {
                        throw NSError(domain: "AppointmentRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get created appointment ID"])
                    }

                    let appointment = Appointment(
                        id: createdID,
                        userID: userID,
                        practitionerID: practitionerID,
                        service: service,
                        date: date,
                        status: status
                    )

                    self.logger.info("Created appointment in local DB with ID: \(createdID)")

                    Task { @MainActor in
                        await self.loadAppointmentsFromLocalDB()
                        continuation.resume(returning: appointment)
                    }
                } catch {
                    let errorMsg = "Failed to create appointment in local database: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")

                    Task { @MainActor in
                        self.errorMessage = "Unable to create appointment. Please try again."
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func updateAppointmentInLocalDB(_ appointment: Appointment) async -> Appointment? {
        let controller = persistenceController

        return await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", appointment.id)
                    fetchRequest.fetchLimit = 1

                    let results = try backgroundContext.fetch(fetchRequest)

                    guard let entity = results.first else {
                        throw NSError(
                            domain: "AppointmentRepository",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Appointment with ID \(appointment.id) not found"]
                        )
                    }

                    // Update the existing entity (reuse, don't delete and recreate)
                    entity.userID = appointment.userID
                    entity.practitionerID = appointment.practitionerID
                    entity.service = appointment.service
                    entity.date = appointment.date
                    entity.status = appointment.status.rawValue
                    // ID remains the same

                    try controller.save(context: backgroundContext)

                    self.logger.info("Updated appointment in local DB with ID: \(appointment.id), status: \(appointment.status.rawValue)")

                    Task { @MainActor in
                        // Update cache directly instead of reloading from DB to avoid race conditions
                        await self.syncAppointmentFromServer(appointment)
                        continuation.resume(returning: appointment)
                    }
                } catch {
                    let errorMsg = "Failed to update appointment in local database: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")

                    Task { @MainActor in
                        self.errorMessage = "Unable to update appointment. Please try again."
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func deleteAppointmentFromLocalDB(id: String) async -> Bool {
        let controller = persistenceController

        return await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id)
                    fetchRequest.fetchLimit = 1

                    let results = try backgroundContext.fetch(fetchRequest)

                    guard let entity = results.first else {
                        let errorMsg = "Appointment with ID \(id) not found for deletion"
                        self.logger.warning("\(errorMsg)")

                        Task { @MainActor in
                            self.errorMessage = "Appointment not found"
                            continuation.resume(returning: false)
                        }
                        return
                    }

                    backgroundContext.delete(entity)
                    try controller.save(context: backgroundContext)

                    self.logger.info("Deleted appointment from local DB with ID: \(id)")

                    Task { @MainActor in
                        await self.loadAppointmentsFromLocalDB()
                        continuation.resume(returning: true)
                    }
                } catch {
                    let errorMsg = "Failed to delete appointment from local database: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")

                    Task { @MainActor in
                        self.errorMessage = "Unable to delete appointment. Please try again."
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    // MARK: - Cache Management

    private func syncAppointmentFromServer(_ appointment: Appointment) async {
        // Update in-memory cache - ensure no duplicates
        let existingIndex = self.appointments.firstIndex(where: { $0.id == appointment.id })

        if let index = existingIndex {
            // Update existing
            self.appointments[index] = appointment
        } else {
            // Add new - but double-check for duplicates first
            if !self.appointments.contains(where: { $0.id == appointment.id }) {
                self.appointments.append(appointment)
                self.appointments.sort { $0.date < $1.date }
            } else {
                logger.warning("Duplicate appointment detected in cache: \(appointment.id)")
                // Don't add duplicate
                return
            }
        }

        // Also sync to local DB
        await saveAppointmentToLocalDB(appointment)
    }

    private func removeAppointmentFromCache(_ appointmentId: String) async {
        appointments.removeAll { $0.id == appointmentId }
    }

    private func saveAppointmentToLocalDB(_ appointment: Appointment) async {
        let controller = persistenceController

        // Mark that we're saving to prevent observer from reloading
        isSavingToLocalDB = true
        defer { isSavingToLocalDB = false }

        await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    // Check if already exists
                    let fetchRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", appointment.id)
                    fetchRequest.fetchLimit = 1

                    let results = try backgroundContext.fetch(fetchRequest)

                    let entity: AppointmentEntity
                    if let existing = results.first {
                        // Update existing - don't create duplicate
                        entity = existing
                        self.logger.debug("Updating existing appointment in local DB: \(appointment.id)")
                    } else {
                        // Create new
                        entity = AppointmentEntity(context: backgroundContext)
                        entity.id = appointment.id
                        self.logger.debug("Creating new appointment in local DB: \(appointment.id)")
                    }

                    entity.userID = appointment.userID
                    entity.practitionerID = appointment.practitionerID
                    entity.service = appointment.service
                    entity.date = appointment.date
                    entity.status = appointment.status.rawValue

                    try controller.save(context: backgroundContext)

                    Task { @MainActor in
                        continuation.resume()
                    }
                } catch {
                    self.logger.error("Failed to save appointment to local DB: \(error.localizedDescription)")
                    Task { @MainActor in
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func syncAppointmentsToLocalDB(_ appointments: [Appointment]) async {
        let controller = persistenceController

        await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    // Fetch all existing
                    let fetchRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
                    let existingEntities = try backgroundContext.fetch(fetchRequest)
                    let existingIds = Set(existingEntities.map { $0.id ?? "" })

                    // Create or update appointments
                    for appointment in appointments {
                        if let entity = existingEntities.first(where: { $0.id == appointment.id }) {
                            // Update existing
                            entity.userID = appointment.userID
                            entity.practitionerID = appointment.practitionerID
                            entity.service = appointment.service
                            entity.date = appointment.date
                            entity.status = appointment.status.rawValue
                        } else {
                            // Create new
                            let entity = AppointmentEntity(context: backgroundContext)
                            entity.id = appointment.id
                            entity.userID = appointment.userID
                            entity.practitionerID = appointment.practitionerID
                            entity.service = appointment.service
                            entity.date = appointment.date
                            entity.status = appointment.status.rawValue
                        }
                    }

                    // Delete local-only appointments (optional - you might want to keep them)
                    // For now, we'll keep local-only appointments

                    try controller.save(context: backgroundContext)

                    Task { @MainActor in
                        continuation.resume()
                    }
                } catch {
                    self.logger.error("Failed to sync appointments to local DB: \(error.localizedDescription)")
                    Task { @MainActor in
                        continuation.resume()
                    }
                }
            }
        }
    }

    /// Gets appointments from local database without updating the cache
    private func getLocalAppointments() async -> [Appointment] {
        let controller = persistenceController

        return await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    let entities = try backgroundContext.fetch(self.fetchRequest)
                    let appointments = entities.compactMap { entity -> Appointment? in
                        guard let id = entity.id,
                              let userID = entity.userID,
                              let practitionerID = entity.practitionerID,
                              let service = entity.service,
                              let date = entity.date,
                              let statusString = entity.status,
                              let status = AppointmentStatus(rawValue: statusString) else {
                            return nil
                        }

                        return Appointment(
                            id: id,
                            userID: userID,
                            practitionerID: practitionerID,
                            service: service,
                            date: date,
                            status: status
                        )
                    }

                    Task { @MainActor in
                        continuation.resume(returning: appointments)
                    }
                } catch {
                    self.logger.error("Failed to get local appointments: \(error.localizedDescription)")
                    Task { @MainActor in
                        continuation.resume(returning: [])
                    }
                }
            }
        }
    }

    /// Syncs local appointments to the server (used when server is empty)
    private func syncLocalAppointmentsToServer(_ localAppointments: [Appointment]) async {
        logger.info("Syncing \(localAppointments.count) local appointments to server")

        for appointment in localAppointments {
            do {
                // Try to create on server (server will assign new ID if needed)
                // Since server manages IDs, we'll create new appointments
                // The server will assign its own IDs
                _ = try await serverClient.createAppointment(
                    userID: appointment.userID,
                    practitionerID: appointment.practitionerID,
                    service: appointment.service,
                    date: appointment.date,
                    status: appointment.status
                )
                logger.debug("Synced appointment to server: \(appointment.id)")
            } catch {
                logger.error("Failed to sync appointment \(appointment.id) to server: \(error.localizedDescription)")
                // Continue with other appointments even if one fails
            }
        }

        logger.info("Finished syncing local appointments to server")
    }

    /// Deletes local appointments with the specified IDs (used after syncing to server)
    private func deleteLocalAppointmentsWithIds(_ ids: Set<String>) async {
        let controller = persistenceController

        await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()

            backgroundContext.perform {
                do {
                    let fetchRequest = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
                    fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
                    let entitiesToDelete = try backgroundContext.fetch(fetchRequest)

                    for entity in entitiesToDelete {
                        backgroundContext.delete(entity)
                    }

                    try controller.save(context: backgroundContext)

                    Task { @MainActor in
                        self.logger.info("Deleted \(entitiesToDelete.count) old local appointments after server sync")
                        continuation.resume()
                    }
                } catch {
                    self.logger.error("Failed to delete old local appointments: \(error.localizedDescription)")
                    Task { @MainActor in
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    /// Checks if server is available and syncs local changes if server came back online
    /// This is called before CRUD operations to sync any pending local changes
    private func checkServerAndSyncIfNeeded() async {
        // Only sync if we were offline and server is now available
        guard serverWasUnavailable && hasLoadedFromServer else {
            return
        }
        
        // Check if server is actually reachable
        let serverReachable = await serverClient.isServerAvailable()
        if serverReachable {
            logger.info("Server came back online (detected during operation), syncing local changes")
            serverWasUnavailable = false
            
            // Connect WebSocket if not already connected
            webSocketClient.connect()
            
            await syncAndReloadWhenServerComesOnline()
        }
    }
    
    /// Public method to manually trigger sync if server is available
    /// Useful when server comes back online but network monitor didn't detect it
    func syncIfServerAvailable() async {
        logger.info("Manual sync requested")
        await checkServerAndSyncIfNeeded()
    }
    
    /// Syncs local changes to server when server comes back online
    private func syncAndReloadWhenServerComesOnline() async {
        logger.info("Syncing local changes to server after reconnection")
        
        // Get local appointments
        let localAppointments = await getLocalAppointments()
        
        if localAppointments.isEmpty {
            logger.debug("No local appointments to sync, just reloading from server")
            await loadAppointmentsFromServer()
            return
        }
        
        // Get server appointments
        do {
            let serverAppointments = try await serverClient.fetchAppointments()
            let serverIds = Set(serverAppointments.map { $0.id })
            
            // Find local-only appointments (exist locally but not on server)
            // These are appointments created/updated while offline
            let localOnlyAppointments = localAppointments.filter { !serverIds.contains($0.id) }
            
            if localOnlyAppointments.isEmpty {
                logger.debug("No local-only appointments to sync, reloading from server")
                await loadAppointmentsFromServer()
                return
            }
            
            logger.info("Found \(localOnlyAppointments.count) local-only appointment(s) to sync to server")
            
            // Store old local IDs to delete them after sync (since server will assign new IDs)
            let oldLocalIds = Set(localOnlyAppointments.map { $0.id })
            
            // Sync local-only appointments to server
            for appointment in localOnlyAppointments {
                do {
                    _ = try await serverClient.createAppointment(
                        userID: appointment.userID,
                        practitionerID: appointment.practitionerID,
                        service: appointment.service,
                        date: appointment.date,
                        status: appointment.status
                    )
                    logger.debug("Synced local appointment to server (old ID: \(appointment.id))")
                } catch {
                    logger.error("Failed to sync local appointment \(appointment.id) to server: \(error.localizedDescription)")
                }
            }
            
            // Reload from server to get the merged state (with new server-assigned IDs)
            logger.info("Reloading appointments from server after sync")
            let syncedAppointments = try await serverClient.fetchAppointments()
            self.appointments = syncedAppointments.sorted { $0.date < $1.date }
            
            // Delete old local entries (with local IDs) and sync new server data (with server IDs)
            await deleteLocalAppointmentsWithIds(oldLocalIds)
            await syncAppointmentsToLocalDB(syncedAppointments)
            
            logger.info("Successfully synced local changes and reloaded from server")
            
        } catch {
            logger.error("Failed to sync with server after reconnection: \(error.localizedDescription)")
            // Fall back to local data
            await loadAppointmentsFromLocalDB()
        }
    }
}
