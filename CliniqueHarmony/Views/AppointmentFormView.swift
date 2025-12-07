import SwiftUI

private enum AppointmentSchedulingConfig {
    static let timeSlots: [String] = [
        "09:00 AM", "10:00 AM", "11:00 AM",
        "12:00 PM", "01:00 PM", "02:00 PM",
        "03:00 PM", "04:00 PM", "05:00 PM"
    ]

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

    static func combinedDate(from date: Date, timeString: String) -> Date? {
        guard let time = timeFormatter.date(from: timeString) else { return nil }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return Calendar.current.date(from: components)
    }
}

struct AppointmentCreateView: View {
    @EnvironmentObject private var appState: AppState

    private let presetPractitionerID: Practitioner.ID?
    private let presetService: String?

    init(presetPractitionerID: Practitioner.ID? = nil, presetService: String? = nil) {
        self.presetPractitionerID = presetPractitionerID
        self.presetService = presetService
    }

    var body: some View {
        if let practitionerID = presetPractitionerID,
           let practitioner = appState.practitioners.first(where: { $0.id == practitionerID }),
           let service = presetService, !service.isEmpty {
            PresetAppointmentBookingView(
                mode: .create(practitioner: practitioner, service: service)
            )
        } else {
            AppointmentCreateFormView()
        }
    }
}

struct AppointmentEditView: View {
    @EnvironmentObject private var appState: AppState

    let appointment: Appointment

    var body: some View {
        if let practitioner = appState.practitioners.first(where: { $0.id == appointment.practitionerID }) {
            PresetAppointmentBookingView(
                mode: .edit(appointment: appointment, practitioner: practitioner)
            )
        } else {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Practitioner not found")
                    .font(.headline)
                Text("This appointment can’t be edited because the practitioner details are missing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .navigationTitle("Update Appointment")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PresetAppointmentBookingView: View {
    enum Mode {
        case create(practitioner: Practitioner, service: String)
        case edit(appointment: Appointment, practitioner: Practitioner)

        var title: String {
            switch self {
            case .create:
                return "Book Appointment"
            case .edit:
                return "Update Appointment"
            }
        }

        var primaryActionTitle: String {
            switch self {
            case .create:
                return "Confirm Booking"
            case .edit:
                return "Update Appointment"
            }
        }

        var successMessage: String {
            switch self {
            case .create:
                return "Appointment booked successfully!"
            case .edit:
                return "Appointment updated successfully!"
            }
        }

        var practitioner: Practitioner {
            switch self {
            case .create(let practitioner, _),
                 .edit(_, let practitioner):
                return practitioner
            }
        }

        var service: String {
            switch self {
            case .create(_, let service):
                return service
            case .edit(let appointment, _):
                return appointment.service
            }
        }

        var appointment: Appointment? {
            switch self {
            case .create:
                return nil
            case .edit(let appointment, _):
                return appointment
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var selectedDate: Date
    @State private var selectedTime: String?
    @State private var showCancelConfirmation = false
    @State private var localErrorMessage: String?
    @State private var isProcessing = false

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .create:
            _selectedDate = State(initialValue: Date())
            _selectedTime = State(initialValue: AppointmentSchedulingConfig.timeSlots.first)
        case .edit(let appointment, _):
            _selectedDate = State(initialValue: appointment.date)
            let existingTime = AppointmentSchedulingConfig.timeFormatter.string(from: appointment.date)
            let initialSlot = AppointmentSchedulingConfig.timeSlots.contains(existingTime) ? existingTime : AppointmentSchedulingConfig.timeSlots.first
            _selectedTime = State(initialValue: initialSlot)
        }
    }

    private var showCancelButton: Bool {
        guard case .edit(let appointment, _) = mode else { return false }
        return appointment.status != .canceled
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                datePickerSection
                timeSelectionSection
                actionButtons
            }
            .padding(24)
            .padding(.bottom, 120)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .confirmationDialog(
            "Cancel Appointment",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            if case .edit(let appointment, _) = mode {
                Button("Cancel Appointment", role: .destructive) {
                    Task {
                        await appState.cancelAppointment(id: appointment.id)
                        showCancelConfirmation = false
                        dismiss()
                    }
                }
            }
            Button("Keep Appointment", role: .cancel) { }
        } message: {
            Text("Are you sure you want to cancel this appointment? This action cannot be undone.")
        }
    }

    private var header: some View {
        let practitioner = mode.practitioner

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                AsyncRemoteImage(url: practitioner.photoURL) {
                    Circle().fill(Theme.surface)
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(practitioner.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color(.systemYellow))
                        Text(String(format: "%.1f", practitioner.rating))
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 1.0, green: 0.97, blue: 0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(mode.service)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
    }

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Select Date", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(Theme.primary)

            DatePicker(
                "Appointment date",
                selection: $selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            .labelsHidden()
        }
    }

    private var timeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Select Time", systemImage: "clock")
                .font(.headline)
                .foregroundStyle(Theme.primary)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppointmentSchedulingConfig.timeSlots, id: \.self) { time in
                    Button {
                        selectedTime = time
                        localErrorMessage = nil
                    } label: {
                        Text(time)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedTime == time ? Theme.primary.opacity(0.15) : Color.white)
                            .foregroundStyle(selectedTime == time ? Theme.primary : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selectedTime == time ? Theme.primary : Color.gray.opacity(0.2), lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let localErrorMessage {
                Text(localErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: {
                Task {
                    await primaryAction()
                }
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(mode.primaryActionTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primary)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .disabled(isProcessing)

            if showCancelButton {
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel Appointment")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundStyle(Color.red)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.red, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }

    private func primaryAction() async {
        guard let selectedTime else {
            localErrorMessage = "Please select a time slot."
            return
        }

        guard let appointmentDate = AppointmentSchedulingConfig.combinedDate(from: selectedDate, timeString: selectedTime) else {
            localErrorMessage = "Unable to schedule this appointment. Please try another time."
            return
        }

        guard appointmentDate >= Date() else {
            localErrorMessage = "Please choose a future date and time."
            return
        }

        isProcessing = true
        localErrorMessage = nil

        do {
            switch mode {
            case .create(let practitioner, let service):
                await appState.createAppointment(
                    practitionerID: practitioner.id,
                    service: service,
                    date: appointmentDate,
                    status: .booked
                )
                
                // Check for errors from repository
                if let errorMsg = appState.appointmentsErrorMessage {
                    localErrorMessage = errorMsg
                    isProcessing = false
                    return
                }
                
            case .edit(let appointment, let practitioner):
                let updated = Appointment(
                    id: appointment.id,
                    userID: appointment.userID,
                    practitionerID: practitioner.id,
                    service: appointment.service,
                    date: appointmentDate,
                    status: appointment.status == .canceled ? .booked : appointment.status
                )
                await appState.updateAppointment(updated)
                
                // Check for errors from repository
                if let errorMsg = appState.appointmentsErrorMessage {
                    localErrorMessage = errorMsg
                    isProcessing = false
                    return
                }
            }
            
            isProcessing = false
            appState.selectedTab = .appointments
            dismiss()
        }
    }

}

private struct AppointmentCreateFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPractitionerID: String
    @State private var selectedServiceID: String
    @State private var appointmentDate: Date = Date()
    @State private var selectedTimeSlot: String = ""
    @State private var selectedStatus: AppointmentStatus = .booked
    @State private var validationMessage: String?
    @State private var isProcessing = false

    init() {
        _selectedPractitionerID = State(initialValue: "")
        _selectedServiceID = State(initialValue: "")
    }

    var body: some View {
        Form {
            Section("Practitioner") {
                Picker("Practitioner", selection: $selectedPractitionerID) {
                    ForEach(appState.practitioners) { practitioner in
                        Text(practitioner.name).tag(practitioner.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Section("Service") {
                Picker("Service", selection: $selectedServiceID) {
                    ForEach(appState.services) { service in
                        Text(service.title).tag(service.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Section("Appointment Date") {
                DatePicker(
                    "Appointment date",
                    selection: $appointmentDate,
                    in: Date()...,
                    displayedComponents: .date
                )
            }

            Section("Time Slot") {
                Picker("Time slot", selection: $selectedTimeSlot) {
                    Text("Select a time").tag("")
                    ForEach(AppointmentSchedulingConfig.timeSlots, id: \.self) { slot in
                        Text(slot).tag(slot)
                    }
                }
            }

            Section("Status") {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(AppointmentStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(Color.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Create Appointment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(isProcessing)
            }
        }
        .onAppear {
            if selectedPractitionerID.isEmpty {
                selectedPractitionerID = appState.practitioners.first?.id ?? ""
            }

            if selectedServiceID.isEmpty {
                selectedServiceID = appState.services.first?.id ?? ""
            }

            if selectedTimeSlot.isEmpty {
                selectedTimeSlot = AppointmentSchedulingConfig.timeSlots.first ?? ""
            }
        }
    }

    private func save() async {
        validationMessage = nil

        guard !selectedPractitionerID.isEmpty,
              let practitioner = appState.practitioners.first(where: { $0.id == selectedPractitionerID }) else {
            validationMessage = "Please choose a practitioner."
            return
        }

        guard !selectedServiceID.isEmpty,
              let service = appState.services.first(where: { $0.id == selectedServiceID }) else {
            validationMessage = "Please choose a service."
            return
        }

        guard !selectedTimeSlot.isEmpty else {
            validationMessage = "Please select a time slot."
            return
        }

        guard let combinedDate = AppointmentSchedulingConfig.combinedDate(from: appointmentDate, timeString: selectedTimeSlot) else {
            validationMessage = "Unable to schedule this appointment. Try another time."
            return
        }

        guard combinedDate >= Date() else {
            validationMessage = "Please choose a future date and time."
            return
        }

        isProcessing = true
        
        await appState.createAppointment(
            practitionerID: practitioner.id,
            service: service.title,
            date: combinedDate,
            status: selectedStatus
        )
        
        // Check for errors from repository
        if let errorMsg = appState.appointmentsErrorMessage {
            validationMessage = errorMsg
            isProcessing = false
            return
        }

        isProcessing = false
        appState.selectedTab = .appointments
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AppointmentCreateView()
            .environmentObject(AppState())
    }
}

#Preview("Preset Create") {
    NavigationStack {
        AppointmentCreateView(
            presetPractitionerID: AppState().practitioners.first?.id,
            presetService: "Initial Consultation"
        )
        .environmentObject(AppState())
    }
}

#Preview("Edit") {
    NavigationStack {
        let state = AppState()
        if let existing = state.appointments.first {
            AppointmentEditView(appointment: existing)
                .environmentObject(state)
        }
    }
}
