import SwiftUI

private enum MainTab: CaseIterable {
    case menu
    case orders
    case settings

    var title: String {
        switch self {
        case .menu: "菜单"
        case .orders: "订单"
        case .settings: "设置"
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
    @EnvironmentObject private var store: AppStore
    @State private var selectedTab: MainTab = .menu

    var body: some View {
        Group {
            switch selectedTab {
            case .menu:
                MenuView()
            case .orders:
                OrdersView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appPageBackground()
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppSemanticColor.border)
                .frame(height: 1)

            HStack(spacing: AppSpacing.xs) {
                ForEach(MainTab.allCases, id: \.title) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: AppIconSize.lg, weight: .semibold))
                            Text(tab.title)
                                .font(AppTypography.micro)
                        }
                        .foregroundStyle(selectedTab == tab ? AppSemanticColor.primary : AppSemanticColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDimension.tabBarItemHeight)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                        .fill(AppSemanticColor.interactiveSecondary)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .background(AppSemanticColor.surface.ignoresSafeArea(edges: .bottom))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppStore())
}
