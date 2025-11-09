import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppState.Tab.home)

            NavigationStack {
                AppointmentsView()
            }
            .tabItem {
                Label("Appointments", systemImage: "calendar")
            }
            .tag(AppState.Tab.appointments)

            PractitionersTabView()
                .tabItem {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .tag(AppState.Tab.practitioners)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.fill")
            }
            .tag(AppState.Tab.profile)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
