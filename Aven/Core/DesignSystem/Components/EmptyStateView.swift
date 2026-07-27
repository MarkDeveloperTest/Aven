import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            Text(message)
        }
    }
}
