import SwiftUI

struct PractitionerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let practitioner: Practitioner

    private struct AppointmentCreateRoute: Hashable {
        let practitioner: Practitioner
        let service: String
    }

    private let availableServices: [String: [(name: String, duration: String)]] = [
        "Massage Therapy": [
            (name: "Swedish Massage", duration: "60 min"),
            (name: "Deep Tissue Massage", duration: "60 min"),
            (name: "Hot Stone Massage", duration: "90 min")
        ],
        "Acupuncture": [
            (name: "Initial Consultation", duration: "90 min"),
            (name: "Follow-up Session", duration: "60 min"),
            (name: "Pain Management", duration: "60 min")
        ],
        "Nutritional Counseling": [
            (name: "Initial Assessment", duration: "60 min"),
            (name: "Follow-up Consultation", duration: "45 min"),
            (name: "Meal Planning Session", duration: "45 min")
        ],
        "Mental Health": [
            (name: "Initial Consultation", duration: "60 min"),
            (name: "Therapy Session", duration: "50 min"),
            (name: "Couples Therapy", duration: "60 min")
        ]
    ]

    init(practitioner: Practitioner) {
        self.practitioner = practitioner
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                contentSection
                    .padding(.bottom, 120)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .navigationDestination(for: AppointmentCreateRoute.self) { route in
            AppointmentCreateView(
                presetPractitionerID: route.practitioner.id,
                presetService: route.service
            )
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .topLeading) {
            AsyncRemoteImage(url: practitioner.photoURL) {
                Rectangle()
                    .fill(Theme.surface)
            }
            .aspectRatio(4 / 3, contentMode: .fit)

            LinearGradient(
                colors: [Color.black.opacity(0.4), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: 400)
        .padding(.horizontal, 18)
    }

    private var contentSection: some View {
        VStack(spacing: 24) {
            infoSection
            bioSection
            servicesSection
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: 400)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(practitioner.name)
                        .font(.title2.weight(.semibold))
                    Text(practitioner.specialty)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primary.opacity(0.1))
                        .foregroundStyle(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(.systemYellow))
                    Text(String(format: "%.1f", practitioner.rating))
                        .font(.footnote.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 1.0, green: 0.97, blue: 0.88))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 12)
    }

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline.weight(.semibold))
            Text(practitioner.bio)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Services")
                .font(.subheadline.weight(.semibold))

            if let services = availableServices[practitioner.specialty], !services.isEmpty {
                ForEach(Array(services.enumerated()), id: \.offset) { _, service in
                    NavigationLink(value: AppointmentCreateRoute(practitioner: practitioner, service: service.name)) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(service.name)
                                        .font(.footnote.weight(.semibold))
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                        Text(service.duration)
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Book")
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.primary.opacity(0.1))
                                    .foregroundStyle(Theme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No services listed for this practitioner yet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PractitionerDetailView(
        practitioner: AppState().practitioners.first!
    )
    .environmentObject(AppState())
}
