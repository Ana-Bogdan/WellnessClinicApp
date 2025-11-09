import SwiftUI

struct AppointmentCardView: View {
    let appointment: Appointment
    let practitioner: Practitioner?

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    private var badgeColors: (background: Color, border: Color, foreground: Color) {
        switch appointment.status {
        case .booked:
            return (Color(red: 0.90, green: 0.96, blue: 0.90), Color(red: 0.74, green: 0.87, blue: 0.73), Theme.primary)
        case .completed:
            return (Color(red: 0.95, green: 0.95, blue: 0.95), Color(red: 0.88, green: 0.88, blue: 0.88), Color.gray)
        case .canceled:
            return (Color(red: 1.00, green: 0.90, blue: 0.90), Color(red: 0.96, green: 0.76, blue: 0.74), Color(red: 0.76, green: 0.27, blue: 0.21))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                AsyncRemoteImage(url: practitioner?.photoURL) {
                    Circle()
                        .fill(Theme.surface)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(practitioner?.name ?? "Unknown")
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        Text(appointment.status.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(badgeColors.background)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(badgeColors.border, lineWidth: 1)
                            )
                            .foregroundStyle(badgeColors.foreground)
                    }

                    Text(appointment.service)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Label(dateFormatter.string(from: appointment.date), systemImage: "calendar")
                        Label(timeFormatter.string(from: appointment.date), systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    let practitioner = Practitioner(
        id: "preview",
        name: "Dr. Emily Chen",
        specialty: "Acupuncture",
        bio: "",
        photoURL: nil,
        rating: 4.9
    )
    let appointment = Appointment(
        id: "apt-preview",
        userID: "user-1",
        practitionerID: practitioner.id,
        service: "Initial Consultation",
        date: .now,
        status: .booked
    )
    AppointmentCardView(appointment: appointment, practitioner: practitioner)
        .padding()
        .background(Theme.background)
}
