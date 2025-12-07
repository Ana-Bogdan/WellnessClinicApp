import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var user: User
    @Published var practitioners: [Practitioner]
    @Published var services: [Service]
    @Published var appointments: [Appointment] = []
    @Published var selectedTab: Tab = .home
    @Published var appointmentsBannerMessage: String?
    @Published var appointmentsErrorMessage: String?
    @Published var isLoadingAppointments: Bool = false

    enum Tab: String {
        case home
        case appointments
        case practitioners
        case profile
    }
    
    private let appointmentRepository: AppointmentRepository
    private var cancellables = Set<AnyCancellable>()

    init(appointmentRepository: AppointmentRepository? = nil) {
        if let repository = appointmentRepository {
            self.appointmentRepository = repository
        } else {
            self.appointmentRepository = AppointmentRepository()
        }
        
        self.user = User(
            id: "user-1",
            name: "Ana Bogdan",
            email: "ana.bogdan@email.com",
            phone: "+40 752 119 963"
        )

        // Practitioners and services remain in memory for now (can be moved to DB later)
        self.practitioners = [
            Practitioner(
                id: "prac-1",
                name: "Dr. Emily Chen",
                specialty: "Acupuncture",
                bio: "Dr. Emily Chen is a licensed acupuncturist with over 15 years of experience in Traditional Chinese Medicine. She specializes in pain management, stress reduction, and holistic wellness approaches.",
                photoURL: URL(string: "https://images.unsplash.com/photo-1512290746430-3ffb4fab31bc?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                rating: 4.9
            ),
            Practitioner(
                id: "prac-2",
                name: "Marcus Thompson",
                specialty: "Massage Therapy",
                bio: "Marcus is a certified massage therapist specializing in deep tissue, sports massage, and therapeutic bodywork. With a background in physical therapy, he brings a clinical approach to relaxation and healing.",
                photoURL: URL(string: "https://images.unsplash.com/photo-1700882304335-34d47c682a4c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                rating: 4.8
            ),
            Practitioner(
                id: "prac-3",
                name: "Rachel Green",
                specialty: "Nutritional Counseling",
                bio: "Rachel is a registered dietitian and nutritional counselor passionate about helping clients achieve optimal health through personalized nutrition plans and sustainable lifestyle changes.",
                photoURL: URL(string: "https://images.unsplash.com/photo-1601341348280-550b5e87281b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                rating: 4.7
            ),
            Practitioner(
                id: "prac-4",
                name: "Dr. James Martinez",
                specialty: "Mental Health",
                bio: "Dr. Martinez is a licensed clinical psychologist with expertise in cognitive behavioral therapy, mindfulness-based approaches, and trauma-informed care. He creates a safe space for healing and growth.",
                photoURL: URL(string: "https://images.unsplash.com/photo-1620302044885-63a750e08a71?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                rating: 5.0
            ),
            Practitioner(
                id: "prac-5",
                name: "Lisa Anderson",
                specialty: "Massage Therapy",
                bio: "Lisa specializes in Swedish massage, prenatal massage, and aromatherapy. Her gentle yet effective techniques promote deep relaxation and stress relief.",
                photoURL: URL(string: "https://images.unsplash.com/photo-1657028310103-f53dd49a856a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                rating: 4.8
            ),
            Practitioner(
                id: "prac-6",
                name: "Dr. Sophia Kim",
                specialty: "Acupuncture",
                bio: "Dr. Kim integrates traditional acupuncture with modern wellness practices. She focuses on women's health, fertility support, and chronic pain management.",
                photoURL: URL(string: "https://images.unsplash.com/photo-1758797316117-8d133af25f8c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                rating: 4.9
            )
        ]

        self.services = [
            Service(
                id: "acupuncture",
                title: "Acupuncture",
                description: "Traditional Chinese medicine for balance and healing.",
                imageURL: URL(string: "https://images.unsplash.com/photo-1740689580128-9173edce303f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                iconName: "sparkles"
            ),
            Service(
                id: "massage",
                title: "Massage Therapy",
                description: "Therapeutic touch for relaxation and pain relief.",
                imageURL: URL(string: "https://images.unsplash.com/photo-1737352777897-e22953991a32?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                iconName: "heart.fill"
            ),
            Service(
                id: "nutrition",
                title: "Nutritional Counseling",
                description: "Personalized guidance for optimal health.",
                imageURL: URL(string: "https://images.unsplash.com/photo-1740560052706-fd75ee856b44?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                iconName: "calendar"
            ),
            Service(
                id: "mental-health",
                title: "Mental Health",
                description: "Professional support for emotional well-being.",
                imageURL: URL(string: "https://images.unsplash.com/photo-1758273240360-76b908e7582a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080"),
                iconName: "brain.head.profile"
            )
        ]
        
        // Observe repository changes
        self.appointmentRepository.$appointments
            .assign(to: &$appointments)
        
        self.appointmentRepository.$errorMessage
            .assign(to: &$appointmentsErrorMessage)
        
        self.appointmentRepository.$isLoading
            .assign(to: &$isLoadingAppointments)
        
        // Load appointments from database on initialization (runs in background thread)
        Task {
            await self.appointmentRepository.loadAppointments()
        }
    }

    /// Creates a new appointment in the database
    /// The ID is managed by the database/app, user is not aware of internal ID
    func createAppointment(
        practitionerID: Practitioner.ID,
        service: String,
        date: Date,
        status: AppointmentStatus = .booked
    ) async {
        if await appointmentRepository.createAppointment(
            userID: user.id,
            practitionerID: practitionerID,
            service: service,
            date: date,
            status: status
        ) != nil {
            showAppointmentsBanner("Appointment created successfully!")
        } else {
            // Error message is already set in repository and will be displayed
            if let errorMsg = appointmentRepository.errorMessage {
                showAppointmentsBanner("Failed to create appointment: \(errorMsg)")
            }
        }
    }

    /// Updates an existing appointment in the database
    /// The same entity is reused (not deleted and recreated), ID remains the same
    func updateAppointment(_ updatedAppointment: Appointment) async {
        if await appointmentRepository.updateAppointment(updatedAppointment) != nil {
            showAppointmentsBanner("Appointment updated successfully!")
        } else {
            // Error message is already set in repository and will be displayed
            if let errorMsg = appointmentRepository.errorMessage {
                showAppointmentsBanner("Failed to update appointment: \(errorMsg)")
            }
        }
    }

    /// Deletes an appointment from the database using only its ID
    func deleteAppointment(id: Appointment.ID) async {
        let success = await appointmentRepository.deleteAppointment(id: id)
        if success {
            showAppointmentsBanner("Appointment deleted successfully!")
        } else {
            // Error message is already set in repository and will be displayed
            if let errorMsg = appointmentRepository.errorMessage {
                showAppointmentsBanner("Failed to delete appointment: \(errorMsg)")
            }
        }
    }

    /// Cancels an appointment by updating its status
    func cancelAppointment(id: Appointment.ID) async {
        guard let appointment = appointments.first(where: { $0.id == id }) else {
            appointmentsErrorMessage = "Appointment not found"
            return
        }
        
        let canceledAppointment = Appointment(
            id: appointment.id,
            userID: appointment.userID,
            practitionerID: appointment.practitionerID,
            service: appointment.service,
            date: appointment.date,
            status: .canceled
        )
        
        await updateAppointment(canceledAppointment)
    }

    /// Completes an appointment by updating its status
    func completeAppointment(id: Appointment.ID) async {
        guard let appointment = appointments.first(where: { $0.id == id }) else {
            appointmentsErrorMessage = "Appointment not found"
            return
        }
        
        let completedAppointment = Appointment(
            id: appointment.id,
            userID: appointment.userID,
            practitionerID: appointment.practitionerID,
            service: appointment.service,
            date: appointment.date,
            status: .completed
        )
        
        await updateAppointment(completedAppointment)
    }

    func showAppointmentsBanner(_ message: String) {
        appointmentsBannerMessage = message
    }
}
