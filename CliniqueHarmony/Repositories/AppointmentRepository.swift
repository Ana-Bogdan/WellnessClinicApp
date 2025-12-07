import CoreData
import Combine
import Foundation
import OSLog

/// Repository for managing Appointment CRUD operations with Core Data
@MainActor
final class AppointmentRepository: ObservableObject {
    private let persistenceController: PersistenceController
    private let logger = Logger(subsystem: "com.cliniqueharmony", category: "AppointmentRepository")
    
    /// Published property that emits appointment changes
    @Published private(set) var appointments: [Appointment] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var fetchRequest: NSFetchRequest<AppointmentEntity> {
        let request = NSFetchRequest<AppointmentEntity>(entityName: "AppointmentEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AppointmentEntity.date, ascending: true)]
        return request
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        setupObserver()
    }
    
    /// Sets up Core Data observer to automatically update when data changes
    private func setupObserver() {
        let context = persistenceController.viewContext
        let notificationCenter = NotificationCenter.default
        
        // Observe Core Data save notifications
        notificationCenter.publisher(for: .NSManagedObjectContextDidSave, object: context)
            .merge(with: notificationCenter.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context))
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadAppointments()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Loads all appointments from the database on a background thread
    /// This is called once when the app starts and automatically when data changes
    func loadAppointments() async {
        isLoading = true
        errorMessage = nil
        
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
                        self.appointments = appointments
                        self.isLoading = false
                        self.logger.info("Loaded \(appointments.count) appointments from database")
                        continuation.resume()
                    }
                } catch {
                    let errorMsg = "Failed to load appointments: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")
                    
                    Task { @MainActor in
                        self.errorMessage = errorMsg
                        self.isLoading = false
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    /// Creates a new appointment in the database
    /// - Parameters:
    ///   - userID: The user ID
    ///   - practitionerID: The practitioner ID
    ///   - service: The service name
    ///   - date: The appointment date
    ///   - status: The appointment status (defaults to .booked)
    /// - Returns: The created Appointment, or nil if creation failed
    func createAppointment(
        userID: String,
        practitionerID: String,
        service: String,
        date: Date,
        status: AppointmentStatus = .booked
    ) async -> Appointment? {
        errorMessage = nil
        
        let controller = persistenceController
        
        return await withCheckedContinuation { continuation in
            let backgroundContext = controller.newBackgroundContext()
            
            backgroundContext.perform {
                do {
                    let entity = AppointmentEntity(context: backgroundContext)
                    // Let Core Data manage the ID - we'll use UUID
                    entity.id = UUID().uuidString
                    entity.userID = userID
                    entity.practitionerID = practitionerID
                    entity.service = service
                    entity.date = date
                    entity.status = status.rawValue
                    
                    try controller.save(context: backgroundContext)
                    
                    // Fetch the created entity to get the ID
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
                    
                    self.logger.info("Created appointment with ID: \(createdID)")
                    
                    Task { @MainActor in
                        // Reload to get the latest data
                        Task {
                            await self.loadAppointments()
                        }
                        continuation.resume(returning: appointment)
                    }
                } catch {
                    let errorMsg = "Failed to create appointment: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")
                    
                    Task { @MainActor in
                        self.errorMessage = errorMsg
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    /// Updates an existing appointment in the database
    /// The same entity is updated (not deleted and recreated), preserving the ID
    /// - Parameter appointment: The updated appointment
    /// - Returns: The updated Appointment, or nil if update failed
    func updateAppointment(_ appointment: Appointment) async -> Appointment? {
        errorMessage = nil
        
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
                    // ID remains the same - we're reusing the entity
                    
                    try controller.save(context: backgroundContext)
                    
                    self.logger.info("Updated appointment with ID: \(appointment.id)")
                    
                    Task { @MainActor in
                        // Reload to get the latest data
                        Task {
                            await self.loadAppointments()
                        }
                        continuation.resume(returning: appointment)
                    }
                } catch {
                    let errorMsg = "Failed to update appointment: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")
                    
                    Task { @MainActor in
                        self.errorMessage = errorMsg
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    /// Deletes an appointment from the database using only its ID
    /// - Parameter id: The appointment ID to delete
    /// - Returns: true if deletion was successful, false otherwise
    func deleteAppointment(id: String) async -> Bool {
        errorMessage = nil
        
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
                            self.errorMessage = errorMsg
                            continuation.resume(returning: false)
                        }
                        return
                    }
                    
                    // Delete using the entity's ID (properly identified)
                    backgroundContext.delete(entity)
                    try controller.save(context: backgroundContext)
                    
                    self.logger.info("Deleted appointment with ID: \(id)")
                    
                    Task { @MainActor in
                        // Reload to get the latest data
                        Task {
                            await self.loadAppointments()
                        }
                        continuation.resume(returning: true)
                    }
                } catch {
                    let errorMsg = "Failed to delete appointment: \(error.localizedDescription)"
                    self.logger.error("\(errorMsg)")
                    
                    Task { @MainActor in
                        self.errorMessage = errorMsg
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
}
