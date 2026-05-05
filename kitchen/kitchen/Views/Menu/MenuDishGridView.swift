import SwiftUI
import UIKit

enum MenuDishLayoutMode {
    case grid
    case list
}

struct MenuDishGridView: View {
    let dishes: [Dish]
    @Binding var layoutMode: MenuDishLayoutMode
    let quantityForDish: (String) -> Int
    let onDecrease: (Dish) -> Void
    let onIncrease: (Dish) -> Void
    let onManage: ((Dish) -> Void)?
    let onDishAppear: (Dish) -> Void
    let onTapBackground: () -> Void
    let onScrollBegan: @MainActor @Sendable () -> Void
    let onScrollSettled: @MainActor @Sendable () -> Void
    let onRefresh: @MainActor @Sendable () async -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    init(
        dishes: [Dish],
        layoutMode: Binding<MenuDishLayoutMode>,
        quantityForDish: @escaping (String) -> Int,
        onDecrease: @escaping (Dish) -> Void,
        onIncrease: @escaping (Dish) -> Void,
        onManage: ((Dish) -> Void)?,
        onDishAppear: @escaping (Dish) -> Void,
        onTapBackground: @escaping () -> Void,
        onScrollBegan: @escaping @MainActor @Sendable () -> Void,
        onScrollSettled: @escaping @MainActor @Sendable () -> Void,
        onRefresh: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.dishes = dishes
        self._layoutMode = layoutMode
        self.quantityForDish = quantityForDish
        self.onDecrease = onDecrease
        self.onIncrease = onIncrease
        self.onManage = onManage
        self.onDishAppear = onDishAppear
        self.onTapBackground = onTapBackground
        self.onScrollBegan = onScrollBegan
        self.onScrollSettled = onScrollSettled
        self.onRefresh = onRefresh
    }

    private var groupedDishes: [(category: String, dishes: [Dish])] {
        var grouped: [(category: String, dishes: [Dish])] = []

        for dish in dishes {
            if let index = grouped.firstIndex(where: { $0.category == dish.category }) {
                grouped[index].dishes.append(dish)
            } else {
                grouped.append((category: dish.category, dishes: [dish]))
            }
        }

        return grouped
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            MenuScrollViewObserver(
                onScrollBegan: { onScrollBegan() },
                onScrollSettled: { onScrollSettled() }
            )
            .frame(width: 0, height: 0)

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(Array(groupedDishes.enumerated()), id: \.element.category) { index, group in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        MenuDishSectionHeader(
                            title: group.category,
                            layoutMode: $layoutMode,
                            showsLayoutToggle: index == 0
                        )
                        .padding(.horizontal, AppSpacing.md)

                        sectionContent(for: group.dishes)
                    }
                }
            }
            .padding(.top, 0)
            .padding(.bottom, AppSpacing.xxl + AppDimension.floatingButtonHeight)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable {
            await onRefresh()
        }
        .simultaneousGesture(
            TapGesture().onEnded { onTapBackground() }
        )
    }

    @ViewBuilder
    private func sectionContent(for dishes: [Dish]) -> some View {
        switch layoutMode {
        case .grid:
            LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                ForEach(dishes) { dish in
                    dishGridCard(for: dish)
                }
            }
            .padding(.horizontal, AppSpacing.md)
        case .list:
            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(dishes) { dish in
                    MenuDishListRow(
                        title: dish.name,
                        category: dish.category,
                        quantity: quantityForDish(dish.id),
                        imageURL: dish.publicImageURL(baseURL: DishImageSpec.r2PublicBaseURL),
                        onManage: onManage.map { handler in { handler(dish) } },
                        onDecrease: { onDecrease(dish) },
                        onIncrease: { onIncrease(dish) }
                    )
                    .onAppear {
                        onDishAppear(dish)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    private func dishGridCard(for dish: Dish) -> some View {
        MenuDishCard(
            title: dish.name,
            category: dish.category,
            quantity: quantityForDish(dish.id),
            imageURL: dish.publicImageURL(baseURL: DishImageSpec.r2PublicBaseURL),
            onManage: onManage.map { handler in { handler(dish) } },
            onDecrease: { onDecrease(dish) },
            onIncrease: { onIncrease(dish) }
        )
        .onAppear {
            onDishAppear(dish)
        }
    }
}

private struct MenuDishSectionHeader: View {
    let title: String
    @Binding var layoutMode: MenuDishLayoutMode
    let showsLayoutToggle: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsLayoutToggle {
                MenuDishLayoutToggle(layoutMode: $layoutMode)
                    .fixedSize()
            }
        }
        .padding(.leading, AppSpacing.xs)
    }
}

private struct MenuDishLayoutToggle: View {
    @Binding var layoutMode: MenuDishLayoutMode

    var body: some View {
        Button {
            HapticManager.shared.fire(.selection)
            layoutMode = layoutMode == .grid ? .list : .grid
        } label: {
            Image(systemName: layoutMode.systemImage)
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppComponentColor.Segmented.selectedForeground)
                .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)
                .background(AppComponentColor.Segmented.selectedBackground, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .stroke(AppComponentColor.Segmented.border, lineWidth: AppBorderWidth.hairline)
        }
        .accessibilityLabel(layoutMode.accessibilityLabel)
    }
}

private extension MenuDishLayoutMode {
    var systemImage: String {
        switch self {
        case .grid:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .grid:
            return "当前为双列布局，点击切换为单列布局"
        case .list:
            return "当前为单列布局，点击切换为双列布局"
        }
    }
}

private struct MenuDishListRow: View {
    let title: String
    let category: String
    let quantity: Int
    let imageURL: URL?
    let onManage: (() -> Void)?
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    private let imageSide: CGFloat = 106

    var body: some View {
        AppCard(padding: 0) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(category)
                        .font(AppTypography.micro)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                dishArtwork

                quantityControl
            }
            .frame(minHeight: 104)
            .padding(AppSpacing.sm)
        }
        .onTapGesture(count: 2) {
            onManage?()
        }
    }

    private var dishArtwork: some View {
        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
            .fill(.clear)
            .frame(width: imageSide, height: imageSide)
            .overlay {
                if let imageURL {
                    RemoteDishImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(AppSpacing.xs)
                    }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var quantityControl: some View {
        VStack(spacing: AppSpacing.xxs) {
            if quantity > 0 {
                AppIconActionButton(
                    systemImage: "minus",
                    tone: .neutral,
                    action: onDecrease
                )

                Text("\(quantity)")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                    .frame(minWidth: AppDimension.quantityBadgeMinWidth)
                    .frame(height: AppDimension.iconButtonSide)
            }

            AppIconActionButton(
                systemImage: "plus",
                tone: .brand,
                action: onIncrease
            )
        }
        .frame(width: AppDimension.iconButtonSide)
    }
}

private struct MenuScrollViewObserver: UIViewRepresentable {
    let onScrollBegan: @MainActor @Sendable () -> Void
    let onScrollSettled: @MainActor @Sendable () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onScrollBegan: onScrollBegan,
            onScrollSettled: onScrollSettled
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            onScrollBegan: onScrollBegan,
            onScrollSettled: onScrollSettled
        )

        DispatchQueue.main.async {
            context.coordinator.attach(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        private var onScrollBegan: @MainActor @Sendable () -> Void
        private var onScrollSettled: @MainActor @Sendable () -> Void
        private weak var scrollView: UIScrollView?
        private weak var forwardingDelegate: UIScrollViewDelegate?
        private var isScrolling = false

        init(
            onScrollBegan: @escaping @MainActor @Sendable () -> Void,
            onScrollSettled: @escaping @MainActor @Sendable () -> Void
        ) {
            self.onScrollBegan = onScrollBegan
            self.onScrollSettled = onScrollSettled
        }

        deinit {
            if scrollView?.delegate === self {
                scrollView?.delegate = forwardingDelegate
            }
        }

        func update(
            onScrollBegan: @escaping @MainActor @Sendable () -> Void,
            onScrollSettled: @escaping @MainActor @Sendable () -> Void
        ) {
            self.onScrollBegan = onScrollBegan
            self.onScrollSettled = onScrollSettled
        }

        func attach(from view: UIView) {
            guard let resolvedScrollView = view.enclosingScrollView else { return }
            guard scrollView !== resolvedScrollView || resolvedScrollView.delegate !== self else { return }

            if scrollView?.delegate === self {
                scrollView?.delegate = forwardingDelegate
            }

            forwardingDelegate = resolvedScrollView.delegate
            scrollView = resolvedScrollView
            resolvedScrollView.delegate = self
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || forwardingDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if forwardingDelegate?.responds(to: selector) == true {
                return forwardingDelegate
            }

            return super.forwardingTarget(for: selector)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            markScrolling()
            forwardingDelegate?.scrollViewWillBeginDragging?(scrollView)
        }

        func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
            markScrolling()
            forwardingDelegate?.scrollViewWillBeginDecelerating?(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            forwardingDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)

            if !decelerate {
                markSettled()
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            forwardingDelegate?.scrollViewDidEndDecelerating?(scrollView)
            markSettled()
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            forwardingDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
            markSettled()
        }

        private func markScrolling() {
            guard !isScrolling else { return }
            isScrolling = true
            MainActor.assumeIsolated {
                onScrollBegan()
            }
        }

        private func markSettled() {
            guard isScrolling else { return }
            isScrolling = false
            MainActor.assumeIsolated {
                onScrollSettled()
            }
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        sequence(first: superview, next: { $0?.superview })
            .first { $0 is UIScrollView } as? UIScrollView
    }
}
