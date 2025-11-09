import SwiftUI

struct ServiceCardView: View {
    let service: Service
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    AsyncRemoteImage(url: service.imageURL) {
                        Rectangle()
                            .fill(Theme.surface)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.6),
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Label {
                            Text(service.title)
                                .font(.headline)
                        } icon: {
                            Image(systemName: service.iconName)
                                .font(.headline)
                        }
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.white)

                        Text(service.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    .padding(16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ServiceCardView(
        service: Service(
            id: "preview",
            title: "Massage Therapy",
            description: "Therapeutic touch for relaxation and pain relief.",
            imageURL: URL(string: "https://example.com"),
            iconName: "heart.fill"
        ),
        action: {}
    )
    .padding()
    .background(Theme.background)
}
