import Foundation
import OSLog

/// Client for communicating with the REST API server
actor ServerClient {
    private let baseURL: URL
    private let logger = Logger(subsystem: "com.cliniqueharmony", category: "ServerClient")
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:3000")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    /// Checks if the server is reachable
    func isServerAvailable() async -> Bool {
        let healthURL = baseURL.appendingPathComponent("health")

        do {
            let (_, response) = try await session.data(from: healthURL)
            if let httpResponse = response as? HTTPURLResponse {
                let isAvailable = httpResponse.statusCode == 200
                logger.debug("Server availability check: \(isAvailable ? "available" : "unavailable")")
                return isAvailable
            }
        } catch {
            logger.debug("Server availability check failed: \(error.localizedDescription)")
        }

        return false
    }

    /// Fetches all appointments from the server
    func fetchAppointments() async throws -> [Appointment] {
        let url = baseURL.appendingPathComponent("appointments")
        logger.debug("Fetching appointments from server: \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Failed to fetch appointments: HTTP \(httpResponse.statusCode)")
            throw ServerError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let appointments = try decoder.decode([ServerAppointment].self, from: data)
            logger.info("Successfully fetched \(appointments.count) appointments from server")
            return appointments.map { $0.toAppointment() }
        } catch {
            logger.error("Failed to decode appointments: \(error.localizedDescription)")
            throw ServerError.decodingError(error)
        }
    }

    /// Creates a new appointment on the server
    /// Returns the created appointment with server-managed ID
    func createAppointment(
        userID: String,
        practitionerID: String,
        service: String,
        date: Date,
        status: AppointmentStatus
    ) async throws -> Appointment {
        let url = baseURL.appendingPathComponent("appointments")
        logger.debug("Creating appointment on server: \(url.absoluteString)")

        let serverAppointment = ServerAppointment(
            id: nil, // Server will manage the ID
            userID: userID,
            practitionerID: practitionerID,
            service: service,
            date: date,
            status: status.rawValue
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(serverAppointment)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.invalidResponse
        }

        guard httpResponse.statusCode == 201 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to create appointment: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            throw ServerError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let serverAppointment = try decoder.decode(ServerAppointment.self, from: data)
            let appointment = serverAppointment.toAppointment()
            logger.info("Successfully created appointment with ID: \(appointment.id)")
            return appointment
        } catch {
            logger.error("Failed to decode created appointment: \(error.localizedDescription)")
            throw ServerError.decodingError(error)
        }
    }

    /// Updates an existing appointment on the server
    /// The server reuses the element (not delete+create), ID remains the same
    func updateAppointment(_ appointment: Appointment) async throws -> Appointment {
        let url = baseURL.appendingPathComponent("appointments").appendingPathComponent(appointment.id)
        logger.debug("Updating appointment on server: \(url.absoluteString)")

        let serverAppointment = ServerAppointment.from(appointment)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(serverAppointment)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to update appointment: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            throw ServerError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let serverAppointment = try decoder.decode(ServerAppointment.self, from: data)
            let appointment = serverAppointment.toAppointment()
            logger.info("Successfully updated appointment with ID: \(appointment.id)")
            return appointment
        } catch {
            logger.error("Failed to decode updated appointment: \(error.localizedDescription)")
            throw ServerError.decodingError(error)
        }
    }

    /// Deletes an appointment from the server using only its ID
    func deleteAppointment(id: String) async throws {
        let url = baseURL.appendingPathComponent("appointments").appendingPathComponent(id)
        logger.debug("Deleting appointment on server: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.invalidResponse
        }

        guard httpResponse.statusCode == 204 else {
            logger.error("Failed to delete appointment: HTTP \(httpResponse.statusCode)")
            throw ServerError.httpError(httpResponse.statusCode)
        }

        logger.info("Successfully deleted appointment with ID: \(id)")
    }
}

/// Server-side appointment representation (for encoding/decoding)
struct ServerAppointment: Codable, Sendable {
    let id: String?
    let userID: String
    let practitionerID: String
    let service: String
    let date: Date
    let status: String

    nonisolated func toAppointment() -> Appointment {
        Appointment(
            id: id ?? UUID().uuidString,
            userID: userID,
            practitionerID: practitionerID,
            service: service,
            date: date,
            status: AppointmentStatus(rawValue: status) ?? .booked
        )
    }

    nonisolated static func from(_ appointment: Appointment) -> ServerAppointment {
        ServerAppointment(
            id: appointment.id,
            userID: appointment.userID,
            practitionerID: appointment.practitionerID,
            service: appointment.service,
            date: appointment.date,
            status: appointment.status.rawValue
        )
    }
}

/// Server communication errors
enum ServerError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            switch code {
            case 400:
                return "Invalid request. Please check your input."
            case 404:
                return "Appointment not found on server"
            case 500:
                return "Server error. Please try again later."
            default:
                return "Server error (HTTP \(code))"
            }
        case .decodingError(let error):
            return "Failed to process server response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }

    /// Returns a user-friendly error message
    var userFriendlyMessage: String {
        switch self {
        case .invalidResponse:
            return "Unable to connect to server. Please check your connection."
        case .httpError(let code):
            switch code {
            case 400:
                return "Invalid request. Please check your input and try again."
            case 404:
                return "The appointment was not found on the server."
            case 500:
                return "Server error occurred. Please try again later."
            default:
                return "Unable to complete the request. Please try again."
            }
        case .decodingError:
            return "Received unexpected data from server. Please try again."
        case .networkError:
            return "Network connection failed. Please check your internet connection."
        }
    }
}
