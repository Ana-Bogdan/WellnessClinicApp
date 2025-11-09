import SwiftUI

struct AppointmentsView: View {
    @EnvironmentObject private var appState: AppState

    private enum Filter: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
        case canceled = "Canceled"
    }

    @State private var selectedFilter: Filter = .upcoming
    @State private var appointmentPendingDeletion: Appointment?
    @State private var showDeleteConfirmation = false
    @State private var bannerMessage: String?
    @State private var showBanner = false

    private var appointmentsForSelectedFilter: [Appointment] {
        switch selectedFilter {
        case .upcoming:
            return upcomingAppointments
        case .past:
            return pastAppointments
        case .canceled:
            return canceledAppointments
        }
    }

    private var upcomingAppointments: [Appointment] {
        let now = Date()
        return appState.appointments
            .filter { $0.status == .booked && $0.date >= now }
            .sorted(by: { $0.date < $1.date })
    }

    private var pastAppointments: [Appointment] {
        let now = Date()
        return appState.appointments
            .filter { $0.status == .completed || $0.date < now }
            .sorted(by: { $0.date > $1.date })
    }

    private var canceledAppointments: [Appointment] {
        appState.appointments
            .filter { $0.status == .canceled }
            .sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(Filter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            List {
                if appointmentsForSelectedFilter.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(appointmentsForSelectedFilter) { appointment in
                        NavigationLink {
                            AppointmentEditView(appointment: appointment)
                        } label: {
                            AppointmentCardView(
                                appointment: appointment,
                                practitioner: appState.practitioners.first(where: { $0.id == appointment.practitionerID })
                            )
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                appointmentPendingDeletion = appointment
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("My Appointments")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(bannerOverlay, alignment: .top)
        .onChange(of: appState.appointmentsBannerMessage) { message in
            guard let message else { return }
            bannerMessage = message

            if message.localizedCaseInsensitiveContains("created") || message.localizedCaseInsensitiveContains("updated") {
                selectedFilter = .upcoming
            } else if message.localizedCaseInsensitiveContains("canceled") {
                selectedFilter = .canceled
            }

            withAnimation {
                showBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    showBanner = false
                }
                if appState.appointmentsBannerMessage == message {
                    appState.appointmentsBannerMessage = nil
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    AppointmentCreateView()
                } label: {
                    Label("Create Appointment", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("createAppointmentButton")
            }
        }
        .confirmationDialog(
            "Delete Appointment",
            isPresented: $showDeleteConfirmation,
            presenting: appointmentPendingDeletion
        ) { appointment in
            Button("Delete Appointment", role: .destructive) {
                delete(appointment)
            }
            Button("Cancel", role: .cancel) {
                appointmentPendingDeletion = nil
            }
        } message: { appointment in
            Text("Are you sure you want to delete the appointment for \(appointment.service)? This action cannot be undone.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(emptyStateTitle)
                .font(.headline)
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .upcoming:
            return "No upcoming appointments"
        case .past:
            return "No past appointments"
        case .canceled:
            return "No canceled appointments"
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .upcoming:
            return "Schedule your next wellness visit to see it here."
        case .past:
            return "Completed appointments will appear here."
        case .canceled:
            return "Canceled appointments will be stored for your reference."
        }
    }

    private func delete(_ appointment: Appointment) {
        appState.deleteAppointment(id: appointment.id)
        appointmentPendingDeletion = nil
    }

    private var bannerOverlay: some View {
        Group {
            if showBanner, let bannerMessage {
                Text(bannerMessage)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.75))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppointmentsView()
            .environmentObject(AppState())
    }
}
