import SwiftUI
import UIKit
import LinkPresentation

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var modalRouter = ModalRouter<OrdersModalRoute>()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text("当前出餐")
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("\(store.orderItems.count) 道")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: AppSpacing.xs) {
                        statusPill(title: "待制作", value: waitingCount, tint: AppColor.info, background: AppColor.infoSoft)
                        statusPill(title: "制作中", value: cookingCount, tint: AppColor.warning, background: AppColor.warningSoft)
                        statusPill(title: "已完成", value: doneCount, tint: AppColor.green800, background: AppColor.green100)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            if store.orderItems.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Spacer(minLength: 0)

                    Text("还没有出餐内容")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("菜单页提交后，这里会直接显示当前订单。")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    AppCard {
                        ForEach(store.orderItems) { item in
                            OrderItemRow(item: item, dishName: dishName(for: item.dishId), canManage: store.canManageOrders) {
                                Task {
                                    await store.cycleStatus(for: item.id)
                                }
                            }
                            if item.id != store.orderItems.last?.id {
                                Divider()
                                    .overlay(AppColor.lineSoft)
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
            }

            if store.orderItems.contains(where: { $0.status != .cancelled }) {
                ordersShoppingListBar
            }
        }
        .appPageBackground()
        .sheet(isPresented: shoppingListBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            ShoppingListSheet()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private func dishName(for dishID: String) -> String {
        store.dishes.first(where: { $0.id == dishID })?.name ?? "未知菜品"
    }

    private var waitingCount: Int {
        store.orderItems.filter { $0.status == .waiting }.count
    }

    private var cookingCount: Int {
        store.orderItems.filter { $0.status == .cooking }.count
    }

    private var doneCount: Int {
        store.orderItems.filter { $0.status == .done }.count
    }

    private var ordersShoppingListBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColor.lineSoft)
                .frame(height: 1)

            Button {
                store.fetchShoppingList()
                modalRouter.present(.shoppingList)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.green800)

                    Text(shoppingListBarTitle)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .background(AppColor.surfacePrimary)
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

private enum OrdersModalRoute: String, Identifiable {
    case shoppingList

    var id: String { rawValue }
}

private struct ShoppingListSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportPayload: SharePayload?
    @State private var toast: AppToastData?

    var body: some View {
        AppSheetContainer(
            title: "采购清单",
            dismissTitle: "关闭",
            confirmTitle: "导出",
            onDismiss: { dismiss() },
            onConfirm: exportShoppingList
        ) {
            ScrollView(showsIndicators: false) {
                AppCard {
                    ForEach(store.shoppingListItems) { item in
                        HStack(spacing: AppSpacing.sm) {
                            Text(item.ingredient)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            AppPill(title: "\(item.dishCount) 道菜", tint: AppColor.info, background: AppColor.infoSoft)
                        }
                        if item.ingredient != store.shoppingListItems.last?.ingredient {
                            Divider()
                                .overlay(AppColor.lineSoft)
                        }
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
        .presentationBackground(.clear)
        .sheet(item: $exportPayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
        .appToast($toast)
    }

    private func exportShoppingList() {
        guard let image = renderShoppingListImage() else {
            toast = AppToastData(message: "导出失败")
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
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(exportDateText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Text(item.ingredient)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("* \(item.dishCount)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.md)

                    if item.ingredient != items.last?.ingredient {
                        Divider()
                            .overlay(AppColor.lineSoft)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColor.surfacePrimary, in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("菜品 list")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColor.textTertiary)

                Text(allDishNamesText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))

            Text("Kitchen")
                .font(AppTypography.micro)
                .foregroundStyle(AppColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColor.green100, AppColor.backgroundElevated],
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
    let item: OrderItem
    let dishName: String
    let canManage: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(statusBackground)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                    }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(dishName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("\(item.quantity) 份")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canManage)
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: AppColor.info
        case .cooking: AppColor.warning
        case .done: AppColor.green800
        case .cancelled: AppColor.danger
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting: AppColor.infoSoft
        case .cooking: AppColor.warningSoft
        case .done: AppColor.green100
        case .cancelled: AppColor.dangerSoft
        }
    }
}

#Preview {
    OrdersView()
        .environmentObject(AppStore())
}
