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
                            statusPill(title: "待制作", value: waitingCount, tint: AppSemanticColor.infoForeground, background: AppSemanticColor.infoBackground)
                            statusPill(title: "制作中", value: cookingCount, tint: AppSemanticColor.warning, background: AppSemanticColor.warningBackground)
                            statusPill(title: "已完成", value: doneCount, tint: AppSemanticColor.primary, background: AppSemanticColor.interactiveSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)

                AppLoadingBlock(phase: ordersPhase) { groupedItems in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.lg) {
                            AppCard {
                                ForEach(groupedItems) { item in
                                    OrderItemRow(
                                        item: item,
                                        canManage: store.canManageOrders,
                                        canEditWaiting: store.canEditWaitingOrderItems,
                                        onTap: { Task { await store.cycleStatuses(for: item.itemIDs) } },
                                        onReduce: {
                                            Task {
                                                if await store.reduceWaitingItemQuantity(for: item) {
                                                    feedbackRouter.show(.low(message: "已减少 \(item.dishName) 1 份"))
                                                }
                                            }
                                        },
                                        onCancel: {
                                            Task {
                                                if await store.cancelWaitingItems(for: item) {
                                                    feedbackRouter.show(.low(message: "已取消 \(item.dishName)"))
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
                                AppButton(title: "这顿好了", style: .primary) {
                                    Task {
                                        let didFinish = await store.finishOrder()
                                        if didFinish {
                                            feedbackRouter.show(.low(message: "这顿收好了"))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)
                }

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
            .padding(.bottom, store.orderItems.contains(where: { $0.status != .cancelled }) ? AppSpacing.xl + AppDimension.toolbarButtonHeight : AppSpacing.xl)
            .accessibilityLabel("查看历史订单")
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
        store.currentOrder != nil && store.orderItems.contains(where: { $0.status != .cancelled })
    }

    private var ordersPhase: LoadingPhase<[GroupedOrderItem]> {
        if store.groupedOrderItems.isEmpty {
            return .failure(
                .empty(kind: .noData, title: "还没有出餐内容", message: "菜单页提交后，这里会直接显示当前订单。"),
                retainedValue: nil
            )
        }
        return .success(store.groupedOrderItems)
    }

    private var shoppingListBarTitle: String { "查看采购清单" }

    // MARK: - Subviews

    private var ordersShoppingListBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AppSemanticColor.border).frame(height: 1)
            Button {
                store.fetchShoppingList()
                modalRouter.present(.shoppingList)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: AppIconSize.md, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.primary)
                    Text(shoppingListBarTitle)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: AppIconSize.xs, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.textTertiary)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity, minHeight: AppDimension.toolbarButtonHeight, alignment: .leading)
                .background(AppSemanticColor.surface)
                .contentShape(Rectangle())
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
