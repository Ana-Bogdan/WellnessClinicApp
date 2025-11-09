import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var user: User
    @Published var practitioners: [Practitioner]
    @Published var services: [Service]
    @Published var appointments: [Appointment]
    @Published var selectedTab: Tab = .home
    @Published var appointmentsBannerMessage: String?

    enum Tab: String {
        case home
        case appointments
        case practitioners
        case profile
    }

    init() {
        self.user = User(
            id: "user-1",
            name: "Ana Bogdan",
            email: "ana.bogdan@email.com",
            phone: "+40 752 119 963"
        )

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

        let calendar = Calendar.current
        let now = Date()
        let upcoming = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 6, to: now) ?? now) ?? now
        let completed1 = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now) ?? now) ?? now
        let completed2 = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -30, to: now) ?? now) ?? now

        self.appointments = [
            Appointment(
                id: "apt-1",
                userID: "user-1",
                practitionerID: "prac-2",
                service: "Deep Tissue Massage",
                date: upcoming,
                status: .booked
            ),
            Appointment(
                id: "apt-2",
                userID: "user-1",
                practitionerID: "prac-1",
                service: "Initial Consultation",
                date: completed1,
                status: .completed
            ),
            Appointment(
                id: "apt-3",
                userID: "user-1",
                practitionerID: "prac-3",
                service: "Initial Assessment",
                date: completed2,
                status: .completed
            )
        ]
    }

    @discardableResult
    func createAppointment(
        practitionerID: Practitioner.ID,
        service: String,
        date: Date,
        status: AppointmentStatus = .booked
    ) -> Appointment {
        let newAppointment = Appointment(
            id: "apt-\(UUID().uuidString.prefix(8))",
            userID: user.id,
            practitionerID: practitionerID,
            service: service,
            date: date,
            status: status
        )
        appointments.append(newAppointment)
        return newAppointment
    }

    func updateAppointment(_ updatedAppointment: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == updatedAppointment.id }) else { return }
        appointments[index] = updatedAppointment
    }

    func deleteAppointment(id: Appointment.ID) {
        appointments.removeAll { $0.id == id }
    }

    func cancelAppointment(id: Appointment.ID) {
        guard let index = appointments.firstIndex(where: { $0.id == id }) else { return }
        appointments[index].status = .canceled
    }

    func completeAppointment(id: Appointment.ID) {
        guard let index = appointments.firstIndex(where: { $0.id == id }) else { return }
        appointments[index].status = .completed
    }

    func showAppointmentsBanner(_ message: String) {
        appointmentsBannerMessage = message
    }
}
