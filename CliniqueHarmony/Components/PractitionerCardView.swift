import SwiftUI

struct PractitionerCardView: View {
    let practitioner: Practitioner

    var body: some View {
        VStack(spacing: 0) {
            AsyncRemoteImage(url: practitioner.photoURL) {
                Rectangle()
                    .fill(Theme.surface)
            }
            .aspectRatio(4 / 3, contentMode: .fit)

            VStack(alignment: .leading, spacing: 8) {
                Text(practitioner.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(practitioner.specialty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color(.systemYellow))

                    Text(String(format: "%.1f", practitioner.rating))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    PractitionerCardView(
        practitioner: Practitioner(
            id: "preview",
            name: "Dr. Emily Chen",
            specialty: "Acupuncture",
            bio: "",
            photoURL: nil,
            rating: 4.9
        )
    )
    .padding()
    .background(Theme.background)
}
