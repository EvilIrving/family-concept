import SwiftUI
import UIKit
import LinkPresentation

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var toastQueue: ToastQueue
    @EnvironmentObject private var bbQueue: BBQueue
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
                                        onTap: {
                                            Task {
                                                await store.cycleStatuses(for: item.itemIDs)
                                            }
                                        },
                                        onReduce: {
                                            Task {
                                                if await store.reduceWaitingItemQuantity(for: item) {
                                                    bbQueue.showBottomBanner(text: "已减少 \(item.dishName) 1 份")
                                                }
                                            }
                                        },
                                        onCancel: {
                                            Task {
                                                if await store.cancelWaitingItems(for: item) {
                                                    bbQueue.showBottomBanner(text: "已取消 \(item.dishName)")
                                                }
                                            }
                                        }
                                    )
                                    if item.id != groupedItems.last?.id {
                                        Divider()
                                            .overlay(AppSemanticColor.border)
                                    }
                                }
                            }

                            if shouldShowFinishButton {
                                AppButton(title: "这顿好了", style: .primary) {
                                    Task {
                                        let didFinish = await store.finishOrder()
                                        if didFinish {
                                            bbQueue.showBottomBanner(text: "这顿收好了")
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
        .sheet(isPresented: shoppingListBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            ShoppingListSheet()
                .environmentObject(store)
                .environmentObject(toastQueue)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: historyBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            OrderHistorySheet()
            .environmentObject(store)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var waitingCount: Int {
        store.quantity(for: .waiting)
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

    private var cookingCount: Int {
        store.quantity(for: .cooking)
    }

    private var doneCount: Int {
        store.quantity(for: .done)
    }

    private var shouldShowFinishButton: Bool {
        store.currentOrder != nil && store.orderItems.contains(where: { $0.status != .cancelled })
    }

    private var ordersShoppingListBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppSemanticColor.border)
                .frame(height: 1)

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

    private var shoppingListBarTitle: String {
        "查看采购清单"
    }

    private var shoppingListBinding: Binding<Bool> {
        Binding(
            get: {
                if case .shoppingList = modalRouter.current {
                    return true
                }
                return false
            },
            set: { isPresented in
                if isPresented {
                    modalRouter.present(.shoppingList)
                } else if case .shoppingList = modalRouter.current {
                    modalRouter.dismiss()
                }
            }
        )
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
}

private enum OrdersModalRoute: Identifiable {
    case shoppingList
    case history

    var id: String {
        switch self {
        case .shoppingList:
            return "shoppingList"
        case .history:
            return "history"
        }
    }
}

private extension OrdersView {
    var historyBinding: Binding<Bool> {
        Binding(
            get: {
                if case .history = modalRouter.current {
                    return true
                }
                return false
            },
            set: { isPresented in
                if isPresented {
                    modalRouter.present(.history)
                } else if case .history = modalRouter.current {
                    modalRouter.dismiss()
                }
            }
        )
    }
}

private struct ShoppingListSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var toastQueue: ToastQueue
    @Environment(\.dismiss) private var dismiss
    @State private var exportPayload: SharePayload?

    var body: some View {
        AppSheetContainer(
            title: "采购清单",
            dismissTitle: "关闭",
            confirmTitle: "导出",
            onDismiss: { dismiss() },
            onConfirm: exportShoppingList
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(store.shoppingListItems) { item in
                        HStack(spacing: AppSpacing.sm) {
                            Text(item.ingredient)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppSemanticColor.textPrimary)
                            Spacer()
                            AppPill(title: "\(item.dishCount) 道菜", tint: AppSemanticColor.infoForeground, background: AppSemanticColor.infoBackground)
                        }
                        .padding(.vertical, AppSpacing.sm)
                        if item.ingredient != store.shoppingListItems.last?.ingredient {
                            Divider()
                                .overlay(AppSemanticColor.border)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xxs)
            }
        }
        .presentationBackground(.clear)
        .sheet(item: $exportPayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
    }

    private func exportShoppingList() {
        guard let image = renderShoppingListImage() else {
            toastQueue.showToast(
                text: "采购清单图片生成失败，请稍后重试。",
                duration: .seconds(3),
                placement: .center,
                showsIcon: true,
                iconSystemName: "xmark.octagon.fill",
                foregroundColor: AppSemanticColor.danger,
                backgroundColor: AppSemanticColor.dangerBackground
            )
            return
        }
        exportPayload = SharePayload(items: [ShoppingListShareItemSource(image: image)])
    }

    private func renderShoppingListImage() -> UIImage? {
        let content = ShoppingListExportCard(items: store.shoppingListItems)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 360, height: nil)
        return renderer.uiImage
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ShoppingListExportCard: View {
    let items: [ShoppingListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("采购清单")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                Text(exportDateText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Text(item.ingredient)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppSemanticColor.textPrimary)
                        Text("* \(item.dishCount)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.md)

                    if item.ingredient != items.last?.ingredient {
                        Divider()
                            .overlay(AppSemanticColor.border)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("菜品 list")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppSemanticColor.textTertiary)

                Text(allDishNamesText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Text("Kitchen")
                .font(AppTypography.micro)
                .foregroundStyle(AppSemanticColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppSemanticColor.interactiveSecondary, AppSemanticColor.backgroundElevated],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var exportDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "导出时间 \(formatter.string(from: Date()))"
    }

    private var allDishNamesText: String {
        let names = items
            .flatMap(\.dishNames)
        let uniqueNames = Array(Set(names)).sorted()
        return uniqueNames.isEmpty ? "暂无菜品" : uniqueNames.joined(separator: "、")
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class ShoppingListShareItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String
    private let subtitle: String

    init(image: UIImage) {
        self.image = image

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        let timestamp = formatter.string(from: Date())

        self.title = "采购清单"
        self.subtitle = "导出时间 \(timestamp)"
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.originalURL = URL(fileURLWithPath: subtitle)
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}

private struct OrderItemRow: View {
    let item: GroupedOrderItem
    let canManage: Bool
    let canEditWaiting: Bool
    let onTap: () -> Void
    let onReduce: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onTap) {
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: AppDimension.statusDot, height: AppDimension.statusDot)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            Text(item.dishName)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppSemanticColor.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text("\(item.quantity) 份")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                                .fixedSize()
                        }
                    }

                    Spacer()

                    AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canManage)

            if canEditWaiting && item.status == .waiting {
                HStack(spacing: AppSpacing.xxs) {
                    AppIconActionButton(systemImage: "minus", tone: .neutral, action: onReduce)
                    AppIconActionButton(systemImage: "xmark", tone: .danger, action: onCancel)
                }
            }
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: AppSemanticColor.infoForeground
        case .cooking: AppSemanticColor.warning
        case .done: AppSemanticColor.primary
        case .cancelled: AppSemanticColor.danger
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting: AppSemanticColor.infoBackground
        case .cooking: AppSemanticColor.warningBackground
        case .done: AppSemanticColor.interactiveSecondary
        case .cancelled: AppSemanticColor.dangerBackground
        }
    }
}

#Preview {
    OrdersView()
        .environmentObject(AppStore())
}
