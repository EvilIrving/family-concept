import SwiftUI
import UIKit
import LinkPresentation

/// 采购清单 Sheet 组件
struct ShoppingListSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @Environment(\.dismiss) private var dismiss
    @State private var exportPayload: SharePayload?

    var body: some View {
        AppSheetContainer(
            title: L10n.tr("Shopping List"),
            dismissTitle: L10n.tr("Close"),
            confirmTitle: L10n.tr("Export"),
            onDismiss: { dismiss() },
            onConfirm: exportShoppingList
        ) {
            if store.shoppingListItems.isEmpty {
                AppErrorPlaceholder(
                    feedback: .empty(
                        kind: .noData,
                        title: L10n.tr("Shopping list is empty"),
                        message: L10n.tr("Place an order from Menu first; ingredients will appear here automatically.")
                    )
                )
            } else {
                ScrollView(showsIndicators: false) {
                    AppCardList {
                        ForEach(store.shoppingListItems) { item in
                            HStack(spacing: AppSpacing.sm) {
                                Text(item.ingredient)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppSemanticColor.textPrimary)
                                Spacer()
                                AppPill(title: L10n.tr("%lld dishes", item.dishCount), tint: AppSemanticColor.infoForeground, background: AppSemanticColor.infoBackground)
                            }
                            if item.ingredient != store.shoppingListItems.last?.ingredient {
                                Divider().overlay(AppSemanticColor.border)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $exportPayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
    }

    private func exportShoppingList() {
        guard let image = renderShoppingListImage() else {
            feedbackRouter.show(
                .low(
                    message: L10n.tr("Could not create shopping list image. Try again later."),
                    systemImage: "xmark.octagon.fill"
                ),
                placement: .centerToast
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

// MARK: - Supporting Types

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShoppingListExportCard: View {
    let items: [ShoppingListItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(L10n.tr("Shopping List"))
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
                        Text(L10n.tr("format.starDishCount", item.dishCount))
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
                Text(L10n.tr("Required dishes"))
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

            Text(L10n.tr("Kitchen • Shopping List"))
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
        formatter.locale = Locale(identifier: AppLanguage.resolved().rawValue)
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        return L10n.tr("Exported %@", formatter.string(from: Date()))
    }

    private var allDishNamesText: String {
        let names = items
            .flatMap(\.dishNames)
        let uniqueNames = Array(Set(names)).sorted()
        return uniqueNames.isEmpty ? L10n.tr("No dishes yet") : uniqueNames.joined(separator: L10n.tr("punctuation.listCommaSpace"))
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class ShoppingListShareItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String
    private let subtitle: String

    init(image: UIImage) {
        self.image = image

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.resolved().rawValue)
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        let timestamp = formatter.string(from: Date())

        self.title = L10n.tr("Shopping List")
        self.subtitle = L10n.tr("Exported %@", timestamp)
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
