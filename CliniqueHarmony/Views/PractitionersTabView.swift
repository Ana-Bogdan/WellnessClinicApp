import SwiftUI

struct PractitionersTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedSpecialty: String = "All"

    private var specialties: [String] {
        let unique = Set(appState.practitioners.map(\.specialty))
        return ["All"] + unique.sorted()
    }

    private var filteredPractitioners: [Practitioner] {
        appState.practitioners.filter { practitioner in
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let lower = searchText.lowercased()
                matchesSearch = practitioner.name.lowercased().contains(lower)
                || practitioner.specialty.lowercased().contains(lower)
            }

            let matchesSpecialty = selectedSpecialty == "All" || practitioner.specialty == selectedSpecialty
            return matchesSearch && matchesSpecialty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    searchSection

                    if filteredPractitioners.isEmpty {
                        emptyState
                    } else {
                        practitionersGrid
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Find a Practitioner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var searchSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search by name or specialty...", text: $searchText)
                    .textInputAutocapitalization(.never)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)

            Menu {
                Picker("Specialty", selection: $selectedSpecialty) {
                    ForEach(specialties, id: \.self) { specialty in
                        Text(specialty).tag(specialty)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text(selectedSpecialty == "All" ? "All Specialties" : selectedSpecialty)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            }
        }
    }

    private var practitionersGrid: some View {
        LazyVStack(spacing: 20) {
            ForEach(filteredPractitioners) { practitioner in
                NavigationLink(value: practitioner) {
                    PractitionerCardView(practitioner: practitioner)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: Practitioner.self) { practitioner in
            PractitionerDetailView(practitioner: practitioner)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("No practitioners found")
                .font(.headline)

            Text("Try adjusting your search or filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    PractitionersTabView()
        .environmentObject(AppState())
}
