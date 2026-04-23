import SwiftUI

struct MenuDishGridView: View {
    let dishes: [Dish]
    let quantityForDish: (String) -> Int
    let onDecrease: (Dish) -> Void
    let onIncrease: (Dish) -> Void
    let onManage: ((Dish) -> Void)?
    let onDishAppear: (Dish) -> Void
    let onTapBackground: () -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

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
            .padding(.bottom, AppSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { onTapBackground() }
        )
    }
}
