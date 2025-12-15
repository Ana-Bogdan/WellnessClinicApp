import Foundation
import OSLog

/// WebSocket client for listening to server changes
@MainActor
final class WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let logger = Logger(subsystem: "com.cliniqueharmony", category: "WebSocketClient")
    private let baseURL: URL
    private var reconnectTimer: Task<Void, Never>?
    @MainActor private var isConnected = false
    @MainActor private var shouldAttemptReconnect = true
    @MainActor private var isConnecting = false // Track if we're in the process of connecting

    /// Callback for when an appointment is created on the server
    var onAppointmentCreated: ((Appointment) -> Void)?
    
    /// Callback for when an appointment is updated on the server
    var onAppointmentUpdated: ((Appointment) -> Void)?
    
    /// Callback for when an appointment is deleted on the server
    var onAppointmentDeleted: ((String) -> Void)?
    
    /// Callback for when WebSocket successfully connects
    var onConnected: (() -> Void)?

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL
    }

    /// Connects to the WebSocket server
    func connect() {
        guard !isConnected && !isConnecting else {
            logger.debug("WebSocket already connected or connecting")
            return
        }
        
        // Enable reconnection attempts
        shouldAttemptReconnect = true
        isConnecting = true

        // Convert http:// to ws://
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            logger.error("Invalid base URL for WebSocket")
            isConnecting = false
            return
        }

        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard let wsURL = components.url else {
            logger.error("Failed to create WebSocket URL")
            isConnecting = false
            return
        }

        logger.debug("Connecting to WebSocket: \(wsURL.absoluteString)")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        // Don't set isConnected yet - wait for first successful message
        receiveMessage()
    }

    /// Disconnects from the WebSocket server
    func disconnect() {
        logger.debug("Disconnecting WebSocket")
        shouldAttemptReconnect = false
        reconnectTimer?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isConnecting = false
    }

    /// Receives messages from the WebSocket
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    // If this is the first successful message, we're connected
                    if !self.isConnected {
                        self.isConnected = true
                        self.isConnecting = false
                        self.logger.info("WebSocket successfully connected")
                        self.onConnected?()
                    }
                    
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        self.logger.warning("Unknown WebSocket message type")
                    }

                    // Continue receiving messages
                    if self.isConnected {
                        self.receiveMessage()
                    }

                case .failure(let error):
                    // Only log as debug if we're not attempting reconnection (server intentionally offline)
                    if self.shouldAttemptReconnect {
                        self.logger.debug("WebSocket connection failed (will retry): \(error.localizedDescription)")
                    } else {
                        self.logger.debug("WebSocket disconnected (server offline)")
                    }
                    self.isConnected = false
                    self.isConnecting = false
                    // Attempt to reconnect after a delay only if reconnection is enabled
                    if self.shouldAttemptReconnect {
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    /// Handles incoming WebSocket messages
    private func handleMessage(_ text: String) {
        logger.debug("Received WebSocket message: \(text)")

        guard let data = text.data(using: .utf8) else {
            logger.error("Failed to convert WebSocket message to data")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let message = try? decoder.decode(WebSocketMessage.self, from: data) {
            switch message.type {
            case "appointment_created":
                if let appointment = message.appointment {
                    let appt = appointment.toAppointment()
                    logger.info("Appointment created on server: \(appt.id)")
                    onAppointmentCreated?(appt)
                }

            case "appointment_updated":
                if let appointment = message.appointment {
                    let appt = appointment.toAppointment()
                    logger.info("Appointment updated on server: \(appt.id)")
                    onAppointmentUpdated?(appt)
                }

            case "appointment_deleted":
                if let appointmentId = message.appointmentId {
                    logger.info("Appointment deleted on server: \(appointmentId)")
                    onAppointmentDeleted?(appointmentId)
                }

            default:
                logger.warning("Unknown WebSocket message type: \(message.type)")
            }
        } else {
            logger.error("Failed to decode WebSocket message")
        }
    }

    /// Schedules a reconnection attempt
    private func scheduleReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !isConnected && shouldAttemptReconnect {
                logger.debug("Attempting WebSocket reconnection")
                connect()
            }
        }
    }
}

/// WebSocket message structure
struct WebSocketMessage: Codable, Sendable {
    let type: String
    let appointment: ServerAppointment?
    let appointmentId: String?
}
