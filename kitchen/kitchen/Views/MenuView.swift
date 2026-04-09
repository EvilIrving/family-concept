import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsAddDish = false
    @State private var showsCart = false
    @State private var name = ""
    @State private var category = ""
    @State private var ingredientTags: [String] = []
    @State private var ingredientInput = ""
    @State private var toast: AppToastData?

    var body: some View {
        AppScrollPage {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("菜单")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppColor.textPrimary)
            }
        } content: {
            AppCard {
                HStack(alignment: .center) {
                    Text("今日菜单")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    AppButton(title: "新增", systemImage: "plus", style: .secondary, fullWidth: false) {
                        showsAddDish = true
                    }
                }
            }

            ForEach(store.activeDishes) { dish in
                DishCard(dish: dish) {
                    store.addToCart(dish: dish)
                    toast = AppToastData(message: "\(dish.name) 已加入购物车")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                showsCart = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "cart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColor.textOnBrand)
                        .frame(width: 56, height: 56)
                        .background(AppColor.green800, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    if store.cartCount > 0 {
                        Text("\(store.cartCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(AppColor.danger, in: Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.bottom, AppSpacing.md)
            .padding(.trailing, AppSpacing.md)
        }
        .sheet(isPresented: $showsAddDish) {
            AppSheetContainer(
                title: "新增菜品",
                dismissTitle: "取消",
                confirmTitle: "保存",
                onDismiss: { showsAddDish = false },
                onConfirm: saveDish
            ) {
                VStack(spacing: AppSpacing.sm) {
                    sheetTextField("菜名", text: $name)
                    sheetTextField("分类", text: $category)
                    IngredientTagInput(tags: $ingredientTags, input: $ingredientInput)
                }
            }
            .presentationBackground(.clear)
            .presentationDetents([.height(400)])
        }
        .sheet(isPresented: $showsCart) {
            CartSheet()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .appToast($toast)
    }

    private func saveDish() {
        let addedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addDish(name: name, category: category, ingredients: ingredientTags)
        guard !addedName.isEmpty else { return }
        name = ""
        category = ""
        ingredientTags = []
        ingredientInput = ""
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

private struct IngredientTagInput: View {
    @Binding var tags: [String]
    @Binding var input: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            FlowLayout(spacing: AppSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textPrimary)
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(AppColor.surfaceSecondary, in: Capsule())
                    .overlay(Capsule().stroke(AppColor.lineSoft, lineWidth: 1))
                }
            }

            TextField("添加食材", text: $input)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 52)
                .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .stroke(AppColor.lineSoft, lineWidth: 1)
                }
                .onChange(of: input) { _, newValue in
                    commitIfNeeded(newValue)
                }
                .onSubmit { commitCurrentInput() }
        }
    }

    private func commitIfNeeded(_ value: String) {
        guard let last = value.last else { return }
        if last == " " || last == "、" || last == "," {
            let tag = value.dropLast().trimmingCharacters(in: .whitespaces)
            if !tag.isEmpty { tags.append(tag) }
            input = ""
        }
    }

    private func commitCurrentInput() {
        let tag = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tag.isEmpty { tags.append(tag) }
        input = ""
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct CartSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var toast: AppToastData?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if store.cartItems.isEmpty {
                        Text("购物车是空的")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.top, AppSpacing.xl)
                    } else {
                        AppCard {
                            ForEach(store.cartItems) { item in
                                HStack(spacing: AppSpacing.sm) {
                                    Text(item.dishName)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    HStack(spacing: AppSpacing.xs) {
                                        Button {
                                            store.updateCartQuantity(itemID: item.id, delta: -1)
                                        } label: {
                                            Image(systemName: "minus")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(AppColor.textSecondary)
                                                .frame(width: 30, height: 30)
                                                .background(AppColor.surfaceSecondary, in: Circle())
                                        }
                                        Text("\(item.quantity)")
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppColor.textPrimary)
                                            .frame(minWidth: 24, alignment: .center)
                                        Button {
                                            store.updateCartQuantity(itemID: item.id, delta: 1)
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(AppColor.textOnBrand)
                                                .frame(width: 30, height: 30)
                                                .background(AppColor.green800, in: Circle())
                                        }
                                        Button {
                                            store.removeFromCart(itemID: item.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(AppColor.danger)
                                                .frame(width: 30, height: 30)
                                                .background(AppColor.dangerSoft, in: Circle())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                if item.id != store.cartItems.last?.id {
                                    Divider().overlay(AppColor.lineSoft)
                                }
                            }
                        }

                        AppButton(title: "提交下单", systemImage: "checkmark") {
                            store.submitCart()
                            toast = AppToastData(message: "已下单")
                            dismiss()
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColor.background)
            .navigationTitle("购物车")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .appToast($toast)
        }
    }
}

private struct DishCard: View {
    let dish: Dish
    let onAdd: () -> Void

    var body: some View {
        AppCard {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(dish.name)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    AppPill(title: dish.category)
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
