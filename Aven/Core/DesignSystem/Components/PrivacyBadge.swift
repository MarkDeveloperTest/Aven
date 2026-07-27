import SwiftUI

struct PrivacyBadge: View {
    let title: LocalizedStringResource

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: "lock.fill")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(red: 0.38, green: 0.36, blue: 0.33))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.72), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
    }
}
