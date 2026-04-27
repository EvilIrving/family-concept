import SwiftUI
import UIKit

struct MenuDishGridView: View {
    let dishes: [Dish]
    let quantityForDish: (String) -> Int
    let onDecrease: (Dish) -> Void
    let onIncrease: (Dish) -> Void
    let onManage: ((Dish) -> Void)?
    let onDishAppear: (Dish) -> Void
    let onTapBackground: () -> Void
    let onScrollBegan: @MainActor @Sendable () -> Void
    let onScrollSettled: @MainActor @Sendable () -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    init(
        dishes: [Dish],
        quantityForDish: @escaping (String) -> Int,
        onDecrease: @escaping (Dish) -> Void,
        onIncrease: @escaping (Dish) -> Void,
        onManage: ((Dish) -> Void)?,
        onDishAppear: @escaping (Dish) -> Void,
        onTapBackground: @escaping () -> Void,
        onScrollBegan: @escaping @MainActor @Sendable () -> Void,
        onScrollSettled: @escaping @MainActor @Sendable () -> Void
    ) {
        self.dishes = dishes
        self.quantityForDish = quantityForDish
        self.onDecrease = onDecrease
        self.onIncrease = onIncrease
        self.onManage = onManage
        self.onDishAppear = onDishAppear
        self.onTapBackground = onTapBackground
        self.onScrollBegan = onScrollBegan
        self.onScrollSettled = onScrollSettled
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
                ForEach(groupedDishes, id: \.category) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(group.category)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                            .padding(.leading, AppSpacing.lg)
                            .padding(.trailing, AppSpacing.md)

                        LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                            ForEach(group.dishes) { dish in
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
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
            }
            .padding(.top, 0)
            .padding(.bottom, AppSpacing.xxl + AppDimension.floatingButtonHeight)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { onTapBackground() }
        )
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
