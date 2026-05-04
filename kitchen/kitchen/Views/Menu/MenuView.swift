import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @StateObject private var modalRouter = ModalRouter<MenuModalRoute>()

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = "All"
    @State private var dishFlowItem: MenuDishFlowItem?
    @State private var visibleDishCount = 12
    @State private var isCartButtonCollapsed = false
    @State private var scrollSettleTask: Task<Void, Never>?
    @State private var scrollActivityGeneration = 0
    @FocusState private var focusedField: MenuField?

    private let dishPageSize = 12
    private let preloadScreenCount = 12
    private let cartButtonRevealDelay: Duration = .seconds(1)

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
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
            .background(AppSemanticColor.background)

            menuContent
        }
        .overlay(alignment: .bottomTrailing) {
            if store.cartCount > 0 {
                MenuCartBar(
                    cartCount: store.cartCount,
                    isCollapsed: isCartButtonCollapsed,
                    onTap: { modalRouter.present(.cart) }
                )
                .padding(.trailing, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
                .transition(.move(edge: .trailing).combined(with: .opacity))
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
        .onChange(of: store.cartCount) { oldCount, newCount in
            if newCount == 0 {
                scrollSettleTask?.cancel()
                isCartButtonCollapsed = false
            } else if oldCount == 0 {
                isCartButtonCollapsed = false
            }
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
            },
            skeletonView: {
                MenuDishGridSkeletonView()
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
                onTapBackground: { focusedField = nil },
                onScrollBegan: handleMenuScrollBegan,
                onScrollSettled: handleMenuScrollSettled
            )
        } onRetry: {
            Task { await store.fetchAll() }
        }
    }

    private var filterCategories: [String] {
        ["All"] + store.dishCategories
    }

    private var quickCategories: [String] {
        ["Custom"] + store.dishCategories
    }

    private var filteredDishes: [Dish] {
        let keyword = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.activeDishes.filter { dish in
            let matchesCategory = selectedCategory == "All" || dish.category == selectedCategory
            let matchesSearch = keyword.isEmpty || dish.name.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSearch
        }
    }

    private var menuPhase: LoadingPhase<[Dish]> {
        if store.isLoading && !filteredDishes.isEmpty {
            return .refreshing(visibleDishes, label: L10n.tr("Refreshing menu"))
        }
        if let feedback = store.menuFeedback {
            return .failure(feedback, retainedValue: filteredDishes.isEmpty ? nil : visibleDishes)
        }
        if !store.hasLoadedKitchenData && filteredDishes.isEmpty {
            return .initialLoading(label: L10n.tr("Loading menu"))
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
        store.canManageDishes ? L10n.tr("menu.emptySearch.hintWhenCanAdd") : L10n.tr("menu.emptySearch.tryOtherKeywordShort")
    }

    private var emptyMenuTitle: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.tr("Menu is empty") : L10n.tr("No matching dishes")
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
            feedbackRouter.show(.low(message: L10n.tr("Added %@", name)))
        case .updated(let name):
            feedbackRouter.show(.low(message: L10n.tr("Updated %@", name)))
        case .deleted(let name):
            feedbackRouter.show(
                .low(
                    message: L10n.tr("%@ archived", name),
                    systemImage: "checkmark.circle.fill"
                ),
                hint: .centerToast
            )
        }
    }

    private func handleMenuScrollBegan() {
        guard store.cartCount > 0 else { return }
        scrollActivityGeneration += 1
        scrollSettleTask?.cancel()
        collapseCartButton()
    }

    private func handleMenuScrollSettled() {
        guard store.cartCount > 0 else { return }
        scrollActivityGeneration += 1
        let generation = scrollActivityGeneration

        scrollSettleTask?.cancel()
        scrollSettleTask = Task { @MainActor in
            try? await Task.sleep(for: cartButtonRevealDelay)
            guard !Task.isCancelled, generation == scrollActivityGeneration else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                isCartButtonCollapsed = false
            }
        }
    }

    private func collapseCartButton() {
        guard !isCartButtonCollapsed else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isCartButtonCollapsed = true
        }
    }
}
