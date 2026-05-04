import SwiftUI

private enum MainTab: CaseIterable {
    case menu
    case orders
    case settings

    var title: String {
        switch self {
        case .menu: L10n.tr("Menu")
        case .orders: L10n.tr("Orders")
        case .settings: L10n.tr("Settings")
        }
    }

    var icon: String {
        switch self {
        case .menu: "square.grid.2x2"
        case .orders: "fork.knife"
        case .settings: "slider.horizontal.3"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .menu

    private var tabBinding: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue != selectedTab {
                    HapticManager.shared.fire(.selection)
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabBinding) {
            MenuView()
                .tag(MainTab.menu)
                .tabItem {
                    Label(MainTab.menu.title, systemImage: MainTab.menu.icon)
                }

            OrdersView()
                .tag(MainTab.orders)
                .tabItem {
                    Label(MainTab.orders.title, systemImage: MainTab.orders.icon)
                }

            SettingsView()
                .tag(MainTab.settings)
                .tabItem {
                    Label(MainTab.settings.title, systemImage: MainTab.settings.icon)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appPageBackground()
        .toolbarBackground(AppSemanticColor.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(AppSemanticColor.primary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppStore())
}
