import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @StateObject private var modalRouter = ModalRouter<OrdersModalRoute>()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.xs) {
                            statusPill(title: L10n.tr("To cook"), value: waitingCount, tint: AppSemanticColor.infoForeground, background: AppSemanticColor.infoBackground)
                            statusPill(title: L10n.tr("Cooking"), value: cookingCount, tint: AppSemanticColor.warning, background: AppSemanticColor.warningBackground)
                            statusPill(title: L10n.tr("Done"), value: doneCount, tint: AppSemanticColor.primary, background: AppSemanticColor.interactiveSecondary)
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
                    skeletonView: nil as (() -> EmptyView)?,
                    content: { groupedItems in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: AppSpacing.lg) {
                                AppCard {
                                    ForEach(groupedItems) { item in
                                        OrderItemRow(
                                            item: item,
                                            canChangeStatus: store.canManageOrders,
                                            canEditWaiting: store.canEditWaitingOrderItems,
                                            onTap: { Task { await store.cycleStatuses(for: item.itemIDs) } },
                                            onReduce: {
                                                Task {
                                                    if await store.reduceWaitingItemQuantity(for: item) {
                                                        feedbackRouter.show(.low(message: L10n.tr("Removed 1 serving of %@", item.dishName)))
                                                    }
                                                }
                                            },
                                            onCancel: {
                                                Task {
                                                    if await store.cancelWaitingItems(for: item) {
                                                        feedbackRouter.show(.low(message: L10n.tr("Cancelled %@", item.dishName)))
                                                    }
                                                }
                                            }
                                        )
                                        if item.id != groupedItems.last?.id {
                                            Divider().overlay(AppSemanticColor.border)
                                        }
                                    }
                                }

                                if shouldShowFinishButton {
                                    AppButton(title: L10n.tr("Meal's ready"), role: .primary) {
                                        Task {
                                            let didFinish = await store.finishOrder()
                                            if didFinish {
                                                feedbackRouter.show(.low(message: L10n.tr("Meal wrapped up")))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.md)
                        .scrollClipDisabled()
                    },
                    onRetry: { Task { await store.refreshOrderItems() } }
                )

                if store.orderItems.contains(where: { $0.status != .cancelled }) {
                    ordersShoppingListBar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .appPageBackground()

            FloatButton(systemImage: "clock.arrow.circlepath") {
                Task {
                    await store.fetchOrderHistory()
                    modalRouter.present(.history)
                }
            }
            .padding(.trailing, AppSpacing.md)
            .padding(.bottom, store.orderItems.contains(where: { $0.status != .cancelled }) ? AppSpacing.xl + shoppingListBarHeight : AppSpacing.xl)
            .accessibilityLabel(L10n.tr("View order history"))
        }
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

    private var shoppingListBarTitle: String { L10n.tr("View shopping list") }
    private var shoppingListBarHeight: CGFloat { 40 }

    // MARK: - Subviews

    private var ordersShoppingListBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppSemanticColor.border).frame(height: 1)
            Button {
                HapticManager.shared.fire(.selection)
                store.fetchShoppingList()
                modalRouter.present(.shoppingList)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: AppIconSize.sm, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.primary)
                    Text(shoppingListBarTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppSemanticColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity, minHeight: shoppingListBarHeight, alignment: .leading)
                .background(AppSemanticColor.surface)
            }
            .buttonStyle(.plain)
        }
    }

    private func ordersSheet(for route: OrdersModalRoute) -> some View {
        Group {
            switch route {
            case .shoppingList:
                ShoppingListSheet()
                    .environmentObject(store)
                    .environmentObject(feedbackRouter)
            case .history:
                OrderHistorySheet()
                    .environmentObject(store)
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
