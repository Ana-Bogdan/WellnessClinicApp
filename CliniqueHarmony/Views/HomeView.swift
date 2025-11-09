import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                services
            }
            .background(Theme.background)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .safeAreaPadding(.bottom, 80)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to CLINIQUE HARMONY,")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(appState.user.name)
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Ready to continue your wellness journey?")
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.9))

                Button {
                    appState.selectedTab = .practitioners
                } label: {
                    Text("Book an Appointment")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundStyle(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.gradient()
                .ignoresSafeArea()
        )
    }

    private var services: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Our Services")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 24)

            LazyVStack(spacing: 20) {
                ForEach(appState.services) { service in
                    ServiceCardView(service: service) {
                        appState.selectedTab = .practitioners
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Theme.background)
                .offset(y: -32)
        )
        .padding(.top, -32)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
