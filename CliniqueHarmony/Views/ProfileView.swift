import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                personalInformationSection
                logoutButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(appState.user.name)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(20)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient().ignoresSafeArea(edges: .top))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.bottom, -12)
    }

    private var personalInformationSection: some View {
        section(title: "Personal Information") {
            profileRow(icon: "envelope", title: "Email", subtitle: appState.user.email)
            Divider()
                .padding(.leading, 52)
            profileRow(icon: "phone", title: "Phone", subtitle: appState.user.phone)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0, content: content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
    }

    private func profileRow(icon: String, title: String, subtitle: String?) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(Theme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var logoutButton: some View {
        Button {
            // Future logout logic
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Log Out")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .foregroundStyle(Theme.accent)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppState())
    }
}
