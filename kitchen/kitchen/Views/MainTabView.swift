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
    @State private var selectedTab: MainTab = .menu

    var body: some View {
        ZStack(alignment: .bottom) {
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

            HStack(spacing: AppSpacing.xs) {
                ForEach(MainTab.allCases, id: \.title) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(AppTypography.micro)
                        }
                        .foregroundStyle(selectedTab == tab ? AppColor.green800 : AppColor.textTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                        .fill(AppColor.green100)
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.xs)
            .background(AppColor.surfacePrimary, in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .stroke(AppColor.lineSoft, lineWidth: 1)
            }
            .shadow(color: AppShadow.cardColor, radius: 20, x: 0, y: 10)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .appPageBackground()
    }
}
