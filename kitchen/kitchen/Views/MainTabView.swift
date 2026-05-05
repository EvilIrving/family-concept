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
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: MainTab = .menu
    @State private var dishFlowItem: MenuDishFlowItem?
    @Namespace private var tabSelectionNamespace
    @FocusState private var focusedField: MenuField?

    private var quickCategories: [String] {
        ["Custom"] + store.dishCategories
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent

            MainFloatingTabBar(
                selectedTab: selectedTab,
                namespace: tabSelectionNamespace,
                canAddDish: store.canManageDishes,
                onSelect: selectTab,
                onAddDish: { dishFlowItem = .add }
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appPageBackground()
        .tint(AppSemanticColor.primary)
        .fullScreenCover(item: $dishFlowItem) { item in
            MenuDishFlowContainer(
                item: item,
                quickCategories: quickCategories,
                focusedField: $focusedField,
                onDismiss: { dishFlowItem = nil },
                onComplete: { result in
                    dishFlowItem = nil
                    handleDishFlowResult(result)
                }
            )
            .environmentObject(store)
            .environmentObject(feedbackRouter)
            .appToastHost()
            .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            MenuView()
                .opacity(selectedTab == .menu ? 1 : 0)
                .allowsHitTesting(selectedTab == .menu)

            OrdersView()
                .opacity(selectedTab == .orders ? 1 : 0)
                .allowsHitTesting(selectedTab == .orders)

            SettingsView()
                .opacity(selectedTab == .settings ? 1 : 0)
                .allowsHitTesting(selectedTab == .settings)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 88)
        }
    }

    private func selectTab(_ tab: MainTab) {
        guard tab != selectedTab else { return }
        HapticManager.shared.fire(.selection)
        if reduceMotion {
            selectedTab = tab
        } else {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
                selectedTab = tab
            }
        }
    }

    private func handleDishFlowResult(_ result: MenuDishFlowResult) {
        switch result {
        case .added(let name):
            feedbackRouter.show(.low(message: L10n.tr("Added %@", name)))
        case .updated(let name):
            feedbackRouter.show(.low(message: L10n.tr("Updated %@", name)))
        case .deleted(let name):
            feedbackRouter.show(
                .low(
                    message: L10n.tr("%@ archived", name),
                    systemImage: "checkmark.circle.fill"
                ),
                placement: .centerToast
            )
        }
    }
}

private struct MainFloatingTabBar: View {
    let selectedTab: MainTab
    let namespace: Namespace.ID
    let canAddDish: Bool
    let onSelect: (MainTab) -> Void
    let onAddDish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    MainFloatingTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: namespace,
                        onSelect: onSelect
                    )
                }
            }
            .padding(AppSpacing.xs)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppSemanticColor.surface.opacity(0.82), lineWidth: AppBorderWidth.regular)
            }
            .shadow(color: AppSemanticColor.shadowSubtle, radius: 18, y: 8)

            if canAddDish {
                Button(action: onAddDish) {
                    Image(systemName: "plus")
                        .font(.system(size: AppIconSize.display, weight: .medium))
                        .foregroundStyle(AppSemanticColor.primary)
                        .frame(width: 72, height: 72)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppSemanticColor.surface.opacity(0.82), lineWidth: AppBorderWidth.regular)
                        }
                        .shadow(color: AppSemanticColor.shadowSubtle, radius: 18, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("Add Dish"))
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.28, extraBounce: 0.08), value: selectedTab)
    }
}

private struct MainFloatingTabButton: View {
    let tab: MainTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let onSelect: (MainTab) -> Void

    var body: some View {
        Button {
            onSelect(tab)
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: AppIconSize.display, weight: .medium))
                .foregroundStyle(isSelected ? AppSemanticColor.primary : AppSemanticColor.textSecondary)
                .frame(width: 72, height: AppDimension.tabBarItemHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(AppSemanticColor.surfaceTertiary.opacity(0.72))
                            .matchedGeometryEffect(id: "main-tab-selection", in: namespace)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppStore())
        .environmentObject(AppFeedbackRouter.shared)
}
