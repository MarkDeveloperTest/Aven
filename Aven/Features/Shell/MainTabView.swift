import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            tab(.home) {
                HomeView()
            }
            tab(.messages) {
                MessagesView()
            }
            tab(.memories) {
                MemoriesView()
            }
            tab(.sharedDay) {
                SharedDayView()
            }
            tab(.us) {
                UsView()
            }
        }
        .tint(PremiumArrivalStyle.pinkInk)
    }

    private func tab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
        }
        .tabItem {
            Label {
                Text(tab.title)
            } icon: {
                Image(systemName: tab.systemImage)
            }
        }
        .tag(tab)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
    }
}
