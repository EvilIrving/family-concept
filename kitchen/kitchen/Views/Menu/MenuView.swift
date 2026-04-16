import SwiftUI
import PhotosUI

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var modalRouter = ModalRouter<MenuModalRoute>()
    @StateObject private var imageCoordinator = DishImageCoordinator()

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = "全部"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var addDishDraft = AddDishDraft()
    @State private var toast: AppToastData?
    @State private var dishPendingArchive: Dish?
    @FocusState private var focusedField: MenuField?

    private let quickCategories = ["自定义", "家常菜", "快手菜", "汤羹", "主食", "饮品", "甜点"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                searchBar
                categoryChips(categories: filterCategories, selection: $selectedCategory)
            }
            .padding(AppSpacing.md)
            .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
            }
            .appShadow(AppShadow.card)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.lg)

            menuContent
            if store.cartCount > 0 {
                menuCartBar
            }
        }
        .appPageBackground()
        .sheet(isPresented: addDishBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            MenuAddDishSheet(
                title: sheetTitle,
                confirmTitle: "保存",
                requiresImage: requiresDishImage,
                draft: $addDishDraft,
                quickCategories: quickCategories,
                selectedPhotoItem: $selectedPhotoItem,
                focusedField: $focusedField,
                imageCoordinator: imageCoordinator,
                onDismiss: dismissAddDish,
                onSave: saveDish,
                onCameraRequest: { modalRouter.transition(to: .camera) },
                onDelete: editDeleteAction
            )
        }
        .sheet(isPresented: cartBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            MenuCartSheet()
                .environmentObject(store)
                .presentationBackground(.clear)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await presentCrop(for: image, source: .photoLibrary)
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: cameraBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            DishCameraCaptureView(
                onCapture: { image in
                    Task {
                        await presentCrop(for: image, source: .camera)
                    }
                },
                onCancel: {
                    modalRouter.transition(to: draftRoute)
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: cropBinding, onDismiss: { modalRouter.didDismissCurrent() }) { presentation in
            DishPhotoCropView(
                sourceImage: presentation.image,
                onConfirm: { cropped in
                    imageCoordinator.processImage(cropped)
                    modalRouter.transition(to: draftRoute)
                },
                onCancel: {
                    switch presentation.source {
                    case .camera:
                        modalRouter.transition(to: .camera)
                    case .photoLibrary:
                        modalRouter.transition(to: draftRoute)
                    }
                }
            )
        }
        .appToast($toast)
        .confirmationDialog(
            "删除后会归档该菜品",
            isPresented: archiveDialogBinding,
            titleVisibility: .visible
        ) {
            Button("删除菜品", role: .destructive) {
                guard let dish = dishPendingArchive else { return }
                Task {
                    await store.archiveDish(id: dish.id)
                    toast = AppToastData(message: "已删除 \(dish.name)")
                    dishPendingArchive = nil
                }
            }
            Button("取消", role: .cancel) {
                dishPendingArchive = nil
            }
        }
    }

    private var menuContent: some View {
        Group {
            if filteredDishes.isEmpty {
                MenuEmptyStateView(
                    title: emptyMenuTitle,
                    hint: emptySearchHint,
                    onTap: { focusedField = nil }
                )
            } else {
                MenuDishGridView(
                    dishes: filteredDishes,
                    quantityForDish: { store.cartQuantity(for: $0) },
                    onDecrease: { dish in
                        guard store.cartQuantity(for: dish.id) > 0 else { return }
                        store.updateCartQuantity(dishID: dish.id, delta: -1)
                    },
                    onIncrease: { dish in
                        store.addToCart(dish: dish)
                    },
                    onManage: store.canManageDishes ? { dish in
                        beginEditing(dish)
                    } : nil,
                    onTapBackground: { focusedField = nil }
                )
            }
        }
    }

    private var dishHasImage: Bool {
        imageCoordinator.hasImage
    }

    private var sheetTitle: String {
        isEditingDish ? "编辑菜品" : "新增菜品"
    }

    private var requiresDishImage: Bool {
        !isEditingDish
    }

    private var editDeleteAction: (() -> Void)? {
        guard isEditingDish else { return nil }
        return { confirmArchiveCurrentDish() }
    }

    private func saveDish() {
        addDishDraft.hasTriedSubmit = true
        addDishDraft.resetValidation()
        let pendingIngredient = addDishDraft.ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pendingIngredient.isEmpty {
            addDishDraft.ingredientTags.append(pendingIngredient)
            addDishDraft.ingredientInput = ""
        }

        let addedName = addDishDraft.trimmedName
        let finalCategory = addDishDraft.resolvedCategory
        store.error = nil

        guard dishHasImage || addDishDraft.editingDishID != nil else {
            addDishDraft.invalidImage = true
            addDishDraft.imageError = "请添加菜品图片"
            addDishDraft.validationTrigger += 1
            return
        }
        guard !addedName.isEmpty else {
            addDishDraft.invalidName = true
            addDishDraft.nameError = "请输入菜名"
            addDishDraft.validationTrigger += 1
            focusedField = .name
            return
        }
        guard !finalCategory.isEmpty else {
            addDishDraft.invalidCategory = true
            addDishDraft.categoryError = "请输入分类"
            addDishDraft.validationTrigger += 1
            focusedField = addDishDraft.selectedQuickCategory == "自定义" ? .customCategory : .name
            return
        }
        guard !addDishDraft.ingredientTags.isEmpty else {
            addDishDraft.invalidIngredients = true
            addDishDraft.ingredientError = "请添加食材"
            addDishDraft.validationTrigger += 1
            focusedField = .ingredient
            return
        }

        Task {
            guard store.kitchen != nil else {
                addDishDraft.imageError = "当前还没有进入 kitchen"
                return
            }

            let previousImageState = imageCoordinator.imageState
            let imageFileURL: URL?
            switch imageCoordinator.imageState {
            case .ready(_, let url), .uploadFailed(_, let url, _):
                imageCoordinator.imageState = .uploading
                imageFileURL = url
            default:
                imageFileURL = nil
            }

            let editingDishID = addDishDraft.editingDishID
            let result: Dish?
            if let editingDishID {
                result = await store.updateDish(
                    id: editingDishID,
                    name: addedName,
                    category: finalCategory,
                    ingredients: addDishDraft.ingredientTags,
                    imageFileURL: imageFileURL
                )
            } else {
                result = await store.addDish(
                    name: addedName,
                    category: finalCategory,
                    ingredients: addDishDraft.ingredientTags,
                    imageFileURL: imageFileURL
                )
            }

            guard let dish = result else {
                addDishDraft.imageError = store.error ?? "保存失败"
                if let imageFileURL {
                    restoreUploadState(
                        previousState: previousImageState,
                        fileURL: imageFileURL,
                        message: addDishDraft.imageError ?? "保存失败"
                    )
                }
                return
            }

            if let imageFileURL {
                imageCoordinator.cleanupAfterUpload(fileURL: imageFileURL)
            }

            let savedName = dish.name
            resetAddDishDraft()
            modalRouter.dismiss()
            if editingDishID == nil {
                toast = AppToastData(message: "已新增 \(savedName)")
            } else {
                toast = AppToastData(message: "已更新 \(savedName)")
            }
        }
    }

    private func restoreUploadState(previousState: DishDraftImageState, fileURL: URL, message: String) {
        switch previousState {
        case .uploadFailed(let previewImage, _, _), .ready(let previewImage, _):
            imageCoordinator.imageState = .uploadFailed(
                previewImage: previewImage,
                fileURL: fileURL,
                message: message
            )
        default:
            imageCoordinator.imageState = .failed(message)
        }
    }

    private func resetAddDishDraft() {
        addDishDraft = AddDishDraft()
        imageCoordinator.clearImage()
    }

    private func beginEditing(_ dish: Dish) {
        addDishDraft = .editing(dish, quickCategories: quickCategories)
        imageCoordinator.clearImage()
        modalRouter.present(.editDish(dish.id))
    }

    private func confirmArchiveCurrentDish() {
        guard let dishID = addDishDraft.editingDishID,
              let dish = store.dishes.first(where: { $0.id == dishID }) else { return }
        modalRouter.dismiss()
        resetAddDishDraft()
        dishPendingArchive = dish
    }

    @MainActor
    private func presentCrop(for image: UIImage, source: CropImageSource) async {
        let standardized = await Task.detached(priority: .userInitiated) {
            image.standardizedForCrop()
        }.value
        modalRouter.transition(to: .crop(CropPresentation(image: standardized, source: source)))
    }

    private var filterCategories: [String] {
        ["全部"] + store.dishCategories
    }

    private var filteredDishes: [Dish] {
        let keyword = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.activeDishes.filter { dish in
            let matchesCategory = selectedCategory == "全部" || dish.category == selectedCategory
            let matchesSearch = keyword.isEmpty || dish.name.localizedCaseInsensitiveContains(keyword)
            return matchesCategory && matchesSearch
        }
    }

    private var emptySearchHint: String {
        store.canManageDishes ? "换个关键词，或点搜索栏右侧「新增」。" : "换个关键词试试。"
    }

    private var emptyMenuTitle: String {
        debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "菜单还没有菜品" : "没有找到匹配的菜品"
    }

    private var menuCartBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppSemanticColor.border)
                .frame(height: 1)

            Button {
                modalRouter.present(.cart)
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: AppIconSize.md, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.primary)

                    Text(cartBarTitle)
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

    private var cartBarTitle: String {
        "已选 \(store.cartCount) 道菜"
    }

    private var searchBar: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppSemanticColor.textTertiary)

                AppTextField(
                    title: "搜菜名",
                    text: $searchText,
                    focusedField: $focusedField,
                    field: .search,
                    height: 50,
                    chrome: .inline,
                    autocapitalization: .never,
                    autocorrectionDisabled: true,
                    submitLabel: .search,
                    onSubmit: nil,
                    isInvalid: false,
                    validationTrigger: 0
                )

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        focusedField = .search
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppSemanticColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppDimension.barControlHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
                    .allowsHitTesting(false)
            }

            if store.canManageDishes {
                Button {
                    modalRouter.present(.addDish)
                } label: {
                    HStack(spacing: AppGap.tight) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: AppIconSize.lg, weight: .semibold))
                        Text("新增")
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundStyle(AppSemanticColor.primary)
                    .padding(.horizontal, AppSpacing.xs)
                    .frame(height: AppDimension.barControlHeight)
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
                            .foregroundStyle(selection.wrappedValue == category ? AppSemanticColor.onPrimary : AppSemanticColor.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .frame(height: AppDimension.compactPillHeight)
                            .background(
                                selection.wrappedValue == category ? AppSemanticColor.primary : AppSemanticColor.interactiveSecondary,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func dismissAddDish() {
        resetAddDishDraft()
        modalRouter.dismiss()
    }

    private var isPresentingAddDish: Bool {
        if case .addDish = modalRouter.current {
            return true
        }
        if case .editDish = modalRouter.current {
            return true
        }
        return false
    }

    private var isEditingDish: Bool {
        if case .editDish = modalRouter.current {
            return true
        }
        return addDishDraft.editingDishID != nil
    }

    private var draftRoute: MenuModalRoute {
        if let editingDishID = addDishDraft.editingDishID {
            return .editDish(editingDishID)
        }
        return .addDish
    }

    private var archiveDialogBinding: Binding<Bool> {
        Binding(
            get: { dishPendingArchive != nil },
            set: { isPresented in
                if !isPresented {
                    dishPendingArchive = nil
                }
            }
        )
    }

    private var addDishBinding: Binding<Bool> {
        Binding(
            get: { isPresentingAddDish },
            set: { isPresented in
                if isPresented {
                    modalRouter.present(.addDish)
                } else if isPresentingAddDish {
                    modalRouter.dismiss()
                }
            }
        )
    }

    private var cartBinding: Binding<Bool> {
        Binding(
            get: {
                if case .cart = modalRouter.current {
                    return true
                }
                return false
            },
            set: { isPresented in
                if isPresented {
                    modalRouter.present(.cart)
                } else if case .cart = modalRouter.current {
                    modalRouter.dismiss()
                }
            }
        )
    }

    private var cameraBinding: Binding<Bool> {
        Binding(
            get: {
                if case .camera = modalRouter.current {
                    return true
                }
                return false
            },
            set: { isPresented in
                if isPresented {
                    modalRouter.present(.camera)
                } else if case .camera = modalRouter.current {
                    modalRouter.dismiss()
                }
            }
        )
    }

    private var cropBinding: Binding<CropPresentation?> {
        Binding(
            get: {
                if case .crop(let presentation) = modalRouter.current {
                    return presentation
                }
                return nil
            },
            set: { presentation in
                if let presentation {
                    modalRouter.present(.crop(presentation))
                } else if case .crop = modalRouter.current {
                    modalRouter.dismiss()
                }
            }
        )
    }
}

private struct MenuEmptyStateView: View {
    let title: String
    let hint: String
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer(minLength: 0)

            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(hint)
                .font(AppTypography.body)
                .foregroundStyle(AppSemanticColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct MenuDishGridView: View {
    let dishes: [Dish]
    let quantityForDish: (String) -> Int
    let onDecrease: (Dish) -> Void
    let onIncrease: (Dish) -> Void
    let onManage: ((Dish) -> Void)?
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
                    }
                }
                .padding(AppSpacing.md)
            }
//            .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
//            .overlay {
//                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
//                    .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
//            }
//            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { onTapBackground() }
        )
    }
}
