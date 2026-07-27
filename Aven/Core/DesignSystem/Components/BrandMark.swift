import SwiftUI

struct BrandMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
                .overlay {
                    Circle()
                        .stroke(Color(red: 0.76, green: 0.68, blue: 0.54), lineWidth: 1)
                        .padding(6)
                }
            Image(systemName: "heart.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color(red: 0.76, green: 0.68, blue: 0.54))
        }
        .frame(width: 88, height: 88)
        .shadow(color: .black.opacity(0.14), radius: 14, y: 8)
        .accessibilityLabel(Text("brand.mark.accessibility"))
    }
}
