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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                    ForEach(dishes) { dish in
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
                .padding(AppSpacing.md)
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { onTapBackground() }
        )
    }
}
