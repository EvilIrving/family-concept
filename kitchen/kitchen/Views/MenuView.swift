import SwiftUI

fileprivate enum MenuField {
    case name
    case customCategory
    case ingredient
}

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsAddDish = false
    @State private var showsCart = false
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = "全部"
    @State private var name = ""
    @State private var selectedQuickCategory = "家常菜"
    @State private var customCategory = ""
    @State private var ingredientTags: [String] = []
    @State private var ingredientInput = ""
    @State private var validationMessage: String?
    @State private var toast: AppToastData?
    @FocusState private var focusedField: MenuField?

    private let quickCategories = ["家常菜", "快手菜", "汤羹", "主食", "饮品", "甜点", "其他"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppCard {
                searchBar

                categoryChips(categories: filterCategories, selection: $selectedCategory)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                        ForEach(filteredDishes) { dish in
                            MenuDishCard(
                                title: dish.name,
                                category: dish.category,
                                quantity: store.cartQuantity(for: dish.id),
                                onDecrease: {
                                    guard store.cartQuantity(for: dish.id) > 0 else { return }
                                    store.updateCartQuantity(dishID: dish.id, delta: -1)
                                },
                                onIncrease: {
                                    store.addToCart(dish: dish)
                                }
                            )
                        }
                    }

                    if filteredDishes.isEmpty {
                        AppCard {
                            Text("没有找到匹配的菜品")
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppColor.textPrimary)
                            Text(emptySearchHint)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
            }

            menuCartBar
        }
        .appPageBackground()
        .sheet(isPresented: $showsAddDish) {
            AppSheetContainer(
                title: "新增菜品",
                dismissTitle: "取消",
                confirmTitle: "保存",
                onDismiss: dismissAddDish,
                onConfirm: saveDish
            ) {
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        sheetTextField("菜名", text: $name)
                            .focused($focusedField, equals: .name)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("常用分类")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColor.textSecondary)

                            categoryChips(categories: quickCategories, selection: $selectedQuickCategory)

                            if selectedQuickCategory == "其他" {
                                sheetTextField("自定义分类", text: $customCategory)
                                    .focused($focusedField, equals: .customCategory)
                            }
                        }

                        IngredientTagInput(tags: $ingredientTags, input: $ingredientInput, focusedField: $focusedField)

                        if let validationMessage {
                            Text(validationMessage)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .presentationBackground(AppColor.surfacePrimary)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .onAppear {
                validationMessage = nil
                focusedField = .name
            }
        }
        .sheet(isPresented: $showsCart) {
            CartSheet()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
        }
        .appToast($toast)
    }

    private func saveDish() {
        let addedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = resolvedCategory
        guard !addedName.isEmpty else {
            validationMessage = "请输入菜名"
            focusedField = .name
            return
        }
        guard !finalCategory.isEmpty else {
            validationMessage = "请先选一个分类"
            focusedField = selectedQuickCategory == "其他" ? .customCategory : .name
            return
        }

        Task {
            await store.addDish(name: addedName, category: finalCategory, ingredients: ingredientTags)
            name = ""
            selectedQuickCategory = "家常菜"
            customCategory = ""
            ingredientTags = []
            ingredientInput = ""
            validationMessage = nil
            showsAddDish = false
            toast = AppToastData(message: "已新增 \(addedName)")
        }
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

    private var resolvedCategory: String {
        let custom = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedQuickCategory == "其他" ? custom : selectedQuickCategory
    }

    private var filterCategories: [String] {
        ["全部"] + store.dishCategories
    }

    private var filteredDishes: [Dish] {
        store.activeDishes.filter { dish in
            let matchesCategory = selectedCategory == "全部" || dish.category == selectedCategory
            let keyword = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = keyword.isEmpty || dish.name.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSearch
        }
    }

    private var emptySearchHint: String {
        if store.canManageDishes {
            "换个关键词，或点搜索栏右侧「新增」。"
        } else {
            "换个关键词试试。"
        }
    }

    private var menuCartBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColor.lineSoft)
                .frame(height: 1)

            Button {
                showsCart = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.green800)

                    Text(cartBarTitle)
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

    private var cartBarTitle: String {
        if store.cartCount == 0 {
            "购物车 · 暂无菜品"
        } else {
            "共 \(store.cartCount) 件 · 点单菜品"
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: AppSpacing.md),
            GridItem(.flexible(), spacing: AppSpacing.md)
        ]
    }

    private var searchBar: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.textTertiary)
                TextField("搜菜名", text: $searchText)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColor.lineSoft, lineWidth: 1)
            }

            if store.canManageDishes {
                Button {
                    showsAddDish = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("新增")
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundStyle(AppColor.green800)
                    .padding(.horizontal, AppSpacing.xs)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新增菜品")
            }
        }
    }

    private func categoryChips(categories: [String], selection: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selection.wrappedValue = category
                    } label: {
                        Text(category)
                            .font(AppTypography.micro)
                            .foregroundStyle(selection.wrappedValue == category ? AppColor.textOnBrand : AppColor.green800)
                            .padding(.horizontal, AppSpacing.sm)
                            .frame(height: 32)
                            .background(
                                selection.wrappedValue == category ? AppColor.green800 : AppColor.green100,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dismissAddDish() {
        name = ""
        selectedQuickCategory = "家常菜"
        customCategory = ""
        ingredientTags = []
        ingredientInput = ""
        validationMessage = nil
        showsAddDish = false
    }
}

private struct IngredientTagInput: View {
    @Binding var tags: [String]
    @Binding var input: String
    var focusedField: FocusState<MenuField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("食材")
                .font(AppTypography.micro)
                .foregroundStyle(AppColor.textSecondary)

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
                .focused(focusedField, equals: .ingredient)
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
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
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
                            .frame(maxWidth: .infinity)
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
                                        AppIconActionButton(systemImage: "minus", tone: .neutral) {
                                            store.updateCartQuantity(itemID: item.id, delta: -1)
                                        }
                                        Text("\(item.quantity)")
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppColor.textPrimary)
                                            .frame(minWidth: 24, alignment: .center)
                                        AppIconActionButton(systemImage: "plus", tone: .brand) {
                                            store.updateCartQuantity(itemID: item.id, delta: 1)
                                        }
                                        AppIconActionButton(systemImage: "xmark", tone: .danger) {
                                            store.removeFromCart(itemID: item.id)
                                        }
                                    }
                                }
                                if item.id != store.cartItems.last?.id {
                                    Divider().overlay(AppColor.lineSoft)
                                }
                            }
                        }

                        AppButton(title: "提交下单", systemImage: "checkmark") {
                            Task {
                                await store.submitCart()
                                toast = AppToastData(message: "已下单")
                                dismiss()
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
            }
            .background(AppColor.backgroundBase)
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

#Preview {
    MenuView()
        .environmentObject(AppStore())
}
