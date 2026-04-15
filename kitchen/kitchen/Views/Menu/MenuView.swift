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

            menuContent
            menuCartBar
        }
        .appPageBackground()
        .sheet(isPresented: addDishBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            MenuAddDishSheet(
                draft: $addDishDraft,
                quickCategories: quickCategories,
                selectedPhotoItem: $selectedPhotoItem,
                focusedField: $focusedField,
                imageCoordinator: imageCoordinator,
                onDismiss: dismissAddDish,
                onSave: saveDish,
                onCameraRequest: { modalRouter.transition(to: .camera) }
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
                    await MainActor.run {
                        modalRouter.transition(to: .crop(CropPresentation(image: image)))
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
        .fullScreenCover(isPresented: cameraBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            DishCameraCaptureView(
                onCapture: { image in
                    imageCoordinator.processImage(image)
                    modalRouter.transition(to: .addDish)
                },
                onCancel: {
                    modalRouter.transition(to: .addDish)
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: cropBinding, onDismiss: { modalRouter.didDismissCurrent() }) { presentation in
            DishPhotoCropView(
                sourceImage: presentation.image,
                onConfirm: { cropped in
                    imageCoordinator.processImage(cropped)
                    modalRouter.transition(to: .addDish)
                },
                onCancel: {
                    modalRouter.transition(to: .addDish)
                }
            )
        }
        .appToast($toast)
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
                    onTapBackground: { focusedField = nil }
                )
            }
        }
    }

    private func saveDish() {
        let addedName = addDishDraft.trimmedName
        let finalCategory = addDishDraft.resolvedCategory
        store.error = nil
        addDishDraft.validationMessage = nil

        guard !addedName.isEmpty else {
            addDishDraft.validationMessage = "请输入菜名"
            focusedField = .name
            return
        }
        guard !finalCategory.isEmpty else {
            addDishDraft.validationMessage = "请先选一个分类"
            focusedField = addDishDraft.selectedQuickCategory == "其他" ? .customCategory : .name
            return
        }

        Task {
            guard store.kitchen != nil else {
                addDishDraft.validationMessage = "当前还没有进入 kitchen"
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

            guard let dish = await store.addDish(
                name: addedName,
                category: finalCategory,
                ingredients: addDishDraft.ingredientTags,
                imageFileURL: imageFileURL
            ) else {
                addDishDraft.validationMessage = store.error ?? "保存失败"
                if let imageFileURL {
                    restoreUploadState(
                        previousState: previousImageState,
                        fileURL: imageFileURL,
                        message: addDishDraft.validationMessage ?? "保存失败"
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
            toast = AppToastData(message: "已新增 \(savedName)")
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
                .fill(AppColor.lineSoft)
                .frame(height: 1)

            Button {
                modalRouter.present(.cart)
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
        store.cartCount == 0 ? "购物车 · 暂无菜品" : "共 \(store.cartCount) 件 · 点单菜品"
    }

    private var searchBar: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.textTertiary)

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
                    .allowsHitTesting(false)
            }

            if store.canManageDishes {
                Button {
                    modalRouter.present(.addDish)
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
        resetAddDishDraft()
        modalRouter.dismiss()
    }

    private var isPresentingAddDish: Bool {
        if case .addDish = modalRouter.current {
            return true
        }
        return false
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
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(hint)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer(minLength: 0)
        }
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
    let onTapBackground: () -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                ForEach(dishes) { dish in
                    MenuDishCard(
                        title: dish.name,
                        category: dish.category,
                        quantity: quantityForDish(dish.id),
                        imageURL: dish.publicImageURL(baseURL: DishImageSpec.r2PublicBaseURL),
                        onDecrease: { onDecrease(dish) },
                        onIncrease: { onIncrease(dish) }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            TapGesture().onEnded { onTapBackground() }
        )
    }
}
