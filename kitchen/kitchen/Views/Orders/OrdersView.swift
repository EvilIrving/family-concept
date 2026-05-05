import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @StateObject private var modalRouter = ModalRouter<OrdersModalRoute>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(spacing: AppSpacing.xs) {
                        statusPill(title: L10n.tr("To cook"), value: waitingCount, tint: AppSemanticColor.pendingForeground, background: AppSemanticColor.pendingBackground)
                        statusPill(title: L10n.tr("Cooking"), value: cookingCount, tint: AppSemanticColor.warning, background: AppSemanticColor.warningBackground)
                        statusPill(title: L10n.tr("Done"), value: doneCount, tint: AppSemanticColor.success, background: AppSemanticColor.successBackground)
                    }

                    if shouldShowShoppingListEntry {
                        Button {
                            openShoppingList()
                        } label: {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "list.bullet.rectangle.fill")
                                    .font(.system(size: AppIconSize.md, weight: .semibold))
                                    .foregroundStyle(AppSemanticColor.primary)
                                    .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)
                                    .background(AppSemanticColor.interactiveSecondary, in: Circle())
                                Text(L10n.tr("View shopping list"))
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppSemanticColor.textPrimary)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: AppIconSize.xs, weight: .semibold))
                                    .foregroundStyle(AppSemanticColor.textTertiary)
                            }
                            .frame(minHeight: AppDimension.regularControlHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            AppLoadingBlock(
                phase: ordersPhase,
                emptyView: { feedback in
                    AppErrorPlaceholder(feedback: feedback)
                },
                skeletonView: { OrdersListSkeleton() },
                content: { groupedItems in
                    List {
                        Section {
                            ForEach(groupedItems) { item in
                                orderRow(for: item)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.md, bottom: 0, trailing: AppSpacing.md))
                        .listRowSeparatorTint(AppSemanticColor.border)
                        .listRowBackground(AppComponentColor.Card.background)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, AppSpacing.lg, for: .scrollContent)
                    .contentMargins(.bottom, AppSpacing.md, for: .scrollContent)
                },
                onRetry: { Task { await store.refreshOrderItems() } }
            )

            if shouldShowFinishButton {
                finishOrderButton
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appPageBackground()
        .sheet(item: modalRouteBinding, onDismiss: { modalRouter.handleDismissedCurrent() }) { route in
            ordersSheet(for: route)
        }
    }

    // MARK: - Computed Properties

    private var waitingCount: Int { store.quantity(for: .waiting) }
    private var cookingCount: Int { store.quantity(for: .cooking) }
    private var doneCount: Int { store.quantity(for: .done) }

    private var shouldShowFinishButton: Bool {
        store.canFinishCurrentOrder
    }

    private var ordersPhase: LoadingPhase<[GroupedOrderItem]> {
        if store.isLoading && !store.groupedOrderItems.isEmpty {
            return .refreshing(store.groupedOrderItems, label: L10n.tr("Refreshing orders"))
        }
        if let feedback = store.ordersFeedback {
            return .failure(feedback, retainedValue: store.orderItems.isEmpty ? nil : store.groupedOrderItems)
        }
        if store.isLoading && store.orderItems.isEmpty {
            return .initialLoading(label: L10n.tr("Loading orders"))
        }
        if store.groupedOrderItems.isEmpty {
            return .failure(
                .empty(kind: .noData, title: L10n.tr("No active meals yet"), message: L10n.tr("Submit from Menu — your active order shows up here.")),
                retainedValue: nil
            )
        }
        return .success(store.groupedOrderItems)
    }

    private var shouldShowShoppingListEntry: Bool {
        store.orderItems.contains { $0.status != .cancelled }
    }

    // MARK: - Subviews

    private var finishOrderButton: some View {
        AppButton(title: L10n.tr("Meal's ready"), role: .primary) {
            Task {
                let didFinish = await store.finishOrder()
                if didFinish {
                    feedbackRouter.show(.low(message: L10n.tr("Meal wrapped up")))
                }
            }
        }
    }

    private func openShoppingList() {
        HapticManager.shared.fire(.selection)
        store.fetchShoppingList()
        modalRouter.present(.shoppingList)
    }

    private func orderRow(for item: GroupedOrderItem) -> some View {
        OrderItemRow(
            item: item,
            canChangeStatus: store.canManageOrders,
            canEditWaiting: store.canEditWaitingOrderItems,
            onTap: { Task { await store.cycleStatuses(for: item.itemIDs) } },
            onReduce: { reduceWaitingItem(item) },
            onCancel: { cancelWaitingItem(item) }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if store.canEditWaitingOrderItems && item.status == .waiting {
                Button(role: .destructive) {
                    cancelWaitingItem(item)
                } label: {
                    Label(L10n.tr("Cancel"), systemImage: "xmark")
                }

                Button {
                    reduceWaitingItem(item)
                } label: {
                    Label(L10n.tr("Remove 1 serving"), systemImage: "minus")
                }
                .tint(AppSemanticColor.textSecondary)
            }
        }
    }

    private func reduceWaitingItem(_ item: GroupedOrderItem) {
        Task {
            if await store.reduceWaitingItemQuantity(for: item) {
                feedbackRouter.show(.low(message: L10n.tr("Removed 1 serving of %@", item.dishName)))
            }
        }
    }

    private func cancelWaitingItem(_ item: GroupedOrderItem) {
        Task {
            if await store.cancelWaitingItems(for: item) {
                feedbackRouter.show(.low(message: L10n.tr("Cancelled %@", item.dishName)))
            }
        }
    }

    private func ordersSheet(for route: OrdersModalRoute) -> some View {
        Group {
            switch route {
            case .shoppingList:
                ShoppingListSheet()
                    .environmentObject(store)
                    .environmentObject(feedbackRouter)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func statusPill(title: String, value: Int, tint: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.micro)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(background, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var modalRouteBinding: Binding<OrdersModalRoute?> {
        Binding(
            get: { modalRouter.current },
            set: { route in
                if let route { modalRouter.present(route) } else { modalRouter.dismiss() }
            }
        )
    }
}

#Preview {
    OrdersView()
        .environmentObject(AppStore())
}

private struct OrdersListSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: AppSpacing.sm) {
                    SkeletonPrimitive(cornerRadius: AppRadius.pill)
                        .frame(width: AppDimension.statusDot, height: AppDimension.statusDot)
                    SkeletonPrimitive(cornerRadius: AppRadius.sm)
                        .frame(width: 140, height: 16)
                    SkeletonPrimitive(cornerRadius: AppRadius.pill)
                        .frame(width: 30, height: 16)
                    Spacer()
                    SkeletonPrimitive(cornerRadius: AppRadius.pill)
                        .frame(width: 56, height: 22)
                }
                .frame(minHeight: AppDimension.listRowMinHeight)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(AppComponentColor.Card.background)

                if index < 4 {
                    Divider().overlay(AppSemanticColor.border)
                        .padding(.leading, AppSpacing.md)
                }
            }
        }
        .background(
            AppComponentColor.Card.background,
            in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }
}
