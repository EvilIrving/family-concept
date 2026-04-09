import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsAddDish = false
    @State private var name = ""
    @State private var category = ""
    @State private var ingredients = ""
    @State private var toast: AppToastData?

    var body: some View {
        AppScrollPage {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("菜单")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("卡片化展示菜单，点一下就追加到当前活跃订单。")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        } content: {
            AppCard {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("今日菜单")
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("共 \(store.activeDishes.count) 道菜，优先展示仍可点的内容。")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    Spacer()
                    AppButton(title: "新增", systemImage: "plus", style: .secondary, fullWidth: false) {
                        showsAddDish = true
                    }
                }
            }

            ForEach(store.activeDishes) { dish in
                DishCard(dish: dish) {
                    store.addToOrder(dish: dish)
                    toast = AppToastData(message: "已把 \(dish.name) 加入当前订单")
                }
            }
        }
        .sheet(isPresented: $showsAddDish) {
            AppSheetContainer(
                title: "新增菜品",
                subtitle: "直接添加到当前菜单",
                dismissTitle: "取消",
                confirmTitle: "保存",
                onDismiss: {
                    showsAddDish = false
                },
                onConfirm: saveDish
            ) {
                VStack(spacing: AppSpacing.sm) {
                    sheetTextField("菜名", text: $name)
                    sheetTextField("分类", text: $category)
                    sheetTextField("食材，用、分隔", text: $ingredients)
                }
            }
            .presentationBackground(.clear)
            .presentationDetents([.height(360)])
        }
        .appToast($toast)
    }

    private func saveDish() {
        let addedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addDish(name: name, category: category, ingredientsText: ingredients)
        guard !addedName.isEmpty else { return }
        name = ""
        category = ""
        ingredients = ""
        showsAddDish = false
        toast = AppToastData(message: "已新增 \(addedName)")
    }

    private func sheetTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(AppTypography.body)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColor.lineSoft, lineWidth: 1)
            }
    }
}

private struct DishCard: View {
    let dish: Dish
    let onAdd: () -> Void

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(dish.name)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColor.textPrimary)
                        AppPill(title: dish.category)
                    }

                    Text(dish.ingredients.joined(separator: "、"))
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.textOnBrand)
                        .frame(width: 42, height: 42)
                        .background(AppColor.green800, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
