import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @StateObject private var modalRouter = ModalRouter<MenuModalRoute>()

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = "全部"
    @State private var dishFlowItem: MenuDishFlowItem?
    @State private var visibleDishCount = 12
    @FocusState private var focusedField: MenuField?

    private let quickCategories = ["自定义", "家常菜", "快手菜", "汤羹", "主食", "饮品", "甜点"]
    private let dishPageSize = 12
    private let preloadScreenCount = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                MenuSearchBar(
                    searchText: $searchText,
                    focusedField: $focusedField,
                    canManageDishes: store.canManageDishes,
                    onAddDish: { dishFlowItem = .add }
                )
                MenuCategoryChips(
                    categories: filterCategories,
                    selection: $selectedCategory
                )
            }
            .padding(AppSpacing.md)
            .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
            }
            .appShadow(AppShadow.card)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.xxs)

            menuContent
            if store.cartCount > 0 {
                MenuCartBar(
                    cartCount: store.cartCount,
                    onTap: { modalRouter.present(.cart) }
                )
            }
        }
        .appPageBackground()
        .sheet(item: cartRouteBinding, onDismiss: {
            modalRouter.handleDismissedCurrent()
        }) { route in
            menuSheet(for: route)
        }
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
            .interactiveDismissDisabled()
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
        }
        .onChange(of: debouncedSearchText) { _, _ in
            resetVisibleDishes()
        }
        .onChange(of: selectedCategory) { _, _ in
            resetVisibleDishes()
        }
        .onChange(of: store.dishes) { _, _ in
            resetVisibleDishes()
        }
    }

    private var menuContent: some View {
        AppLoadingBlock(
            phase: menuPhase,
            emptyView: { feedback in
                MenuEmptyStateView(
                    feedback: feedback,
                    onTap: { focusedField = nil }
                )
            }
        ) { dishes in
            MenuDishGridView(
                dishes: dishes,
                quantityForDish: { store.cartQuantity(for: $0) },
                onDecrease: { dish in
                    guard store.cartQuantity(for: dish.id) > 0 else { return }
                    store.updateCartQuantity(dishID: dish.id, delta: -1)
                },
                onIncrease: { dish in
                    store.addToCart(dish: dish)
                },
                onManage: store.canManageDishes ? { dish in
                    dishFlowItem = .edit(dish.id, AddDishDraft.editing(dish, quickCategories: quickCategories))
                } : nil,
                onDishAppear: handleDishAppear,
                onTapBackground: { focusedField = nil }
            )
        } onRetry: {
            Task { await store.fetchAll() }
        }
    }

    private var filterCategories: [String] {
        ["全部"] + store.dishCategories
    }

    private var filteredDishes: [Dish] {
        let keyword = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.activeDishes.filter { dish in
            let matchesCategory = selectedCategory == "全部" || dish.category == selectedCategory
            let matchesSearch = keyword.isEmpty || dish.name.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSearch
        }
    }

    private var menuPhase: LoadingPhase<[Dish]> {
        if store.isLoading && !filteredDishes.isEmpty {
            return .refreshing(visibleDishes, label: "刷新菜单")
        }
        if let feedback = store.menuFeedback {
            return .failure(feedback, retainedValue: filteredDishes.isEmpty ? nil : visibleDishes)
        }
        if !store.hasLoadedKitchenData && filteredDishes.isEmpty {
            return .initialLoading(label: "加载菜单")
        }
        if filteredDishes.isEmpty {
            let kind: AppEmptyKind = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .noData : .noSearchResult
            return .failure(.empty(kind: kind, title: emptyMenuTitle, message: emptySearchHint), retainedValue: nil)
        }
        return .success(visibleDishes)
    }

    private var visibleDishes: [Dish] {
        Array(filteredDishes.prefix(visibleDishCount))
    }

    private func resetVisibleDishes() {
        visibleDishCount = dishPageSize
    }

    private func handleDishAppear(_ dish: Dish) {
        guard let index = visibleDishes.firstIndex(where: { $0.id == dish.id }) else { return }
        let thresholdIndex = max(0, visibleDishes.count - preloadScreenCount)
        guard index >= thresholdIndex else { return }
        guard visibleDishCount < filteredDishes.count else { return }
        visibleDishCount = min(filteredDishes.count, visibleDishCount + dishPageSize)
    }

    private var emptySearchHint: String {
        store.canManageDishes ? "换个关键词，或点搜索栏右侧「新增」。" : "换个关键词试试。"
    }

    private var emptyMenuTitle: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "菜单还没有菜品" : "没有找到匹配的菜品"
    }

    private var cartRouteBinding: Binding<MenuModalRoute?> {
        Binding(
            get: {
                guard modalRouter.current == .cart else { return nil }
                return .cart
            },
            set: { route in
                if route == .cart {
                    modalRouter.present(.cart)
                } else {
                    modalRouter.dismiss()
                }
            }
        )
    }

    @ViewBuilder
    private func menuSheet(for route: MenuModalRoute) -> some View {
        switch route {
        case .cart:
            MenuCartSheet()
                .environmentObject(store)
                .presentationBackground(.clear)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private func handleDishFlowResult(_ result: MenuDishFlowResult) {
        switch result {
        case .added(let name):
            feedbackRouter.show(.low(message: "已新增 \(name)"))
        case .updated(let name):
            feedbackRouter.show(.low(message: "已更新 \(name)"))
        case .deleted(let name):
            feedbackRouter.show(
                .low(
                    message: "\(name) 已移入归档",
                    systemImage: "checkmark.circle.fill"
                ),
                hint: .centerToast
            )
        }
    }
}
