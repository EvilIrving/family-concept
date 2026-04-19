import SwiftUI
import PhotosUI

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @StateObject private var modalRouter = ModalRouter<MenuModalRoute>()

    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var selectedCategory = "全部"
    @State private var dishFlowItem: MenuDishFlowItem?
    @State private var visibleDishCount = 12
    @FocusState private var focusedField: MenuField?

    private let quickCategories = ["自定义", "家常菜", "快手菜", "汤羹", "主食", "饮品", "甜点"]
    private let dishPageSize = 12
    private let preloadScreenCount = 12

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
        .sheet(item: cartRouteBinding, onDismiss: {
            modalRouter.handleDismissedCurrent()
        }) { route in
            menuSheet(for: route)
        }
        .fullScreenCover(item: $dishFlowItem) { item in
            MenuDishFlowContainer(
                item: item,
                quickCategories: quickCategories,
                focusedField: $focusedField,
                onDismiss: {
                    dishFlowItem = nil
                },
                onComplete: { result in
                    dishFlowItem = nil
                    handleDishFlowResult(result)
                }
            )
            .environmentObject(store)
            .interactiveDismissDisabled()
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
        }
        .onChange(of: debouncedSearchText) { _, _ in
            resetVisibleDishes()
        }
        .onChange(of: selectedCategory) { _, _ in
            resetVisibleDishes()
        }
        .onChange(of: store.dishes) { _, _ in
            resetVisibleDishes()
        }
    }

    private var menuContent: some View {
        AppLoadingBlock(
            phase: menuPhase,
            emptyView: { feedback in
                MenuEmptyStateView(
                    feedback: feedback,
                    onTap: { focusedField = nil }
                )
            }
        ) { dishes in
            Group {
                MenuDishGridView(
                    dishes: dishes,
                    quantityForDish: { store.cartQuantity(for: $0) },
                    onDecrease: { dish in
                        guard store.cartQuantity(for: dish.id) > 0 else { return }
                        store.updateCartQuantity(dishID: dish.id, delta: -1)
                    },
                    onIncrease: { dish in
                        store.addToCart(dish: dish)
                    },
                    onManage: store.canManageDishes ? { dish in
                        dishFlowItem = .edit(dish.id, AddDishDraft.editing(dish, quickCategories: quickCategories))
                    } : nil,
                    onDishAppear: handleDishAppear,
                    onTapBackground: { focusedField = nil }
                )
            }
        }
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

    private var menuPhase: LoadingPhase<[Dish]> {
        if filteredDishes.isEmpty {
            let kind: AppEmptyKind = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .noData : .noSearchResult
            return .failure(.empty(kind: kind, title: emptyMenuTitle, message: emptySearchHint), retainedValue: nil)
        }
        return .success(visibleDishes)
    }

    private var visibleDishes: [Dish] {
        Array(filteredDishes.prefix(visibleDishCount))
    }

    private func resetVisibleDishes() {
        visibleDishCount = dishPageSize
    }

    private func handleDishAppear(_ dish: Dish) {
        guard let index = visibleDishes.firstIndex(where: { $0.id == dish.id }) else { return }
        let thresholdIndex = max(0, visibleDishes.count - preloadScreenCount)
        guard index >= thresholdIndex else { return }
        guard visibleDishCount < filteredDishes.count else { return }
        visibleDishCount = min(filteredDishes.count, visibleDishCount + dishPageSize)
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
                    dishFlowItem = .add
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

    private var cartRouteBinding: Binding<MenuModalRoute?> {
        Binding(
            get: {
                guard modalRouter.current == .cart else { return nil }
                return .cart
            },
            set: { route in
                if route == .cart {
                    modalRouter.present(.cart)
                } else {
                    modalRouter.dismiss()
                }
            }
        )
    }

    @ViewBuilder
    private func menuSheet(for route: MenuModalRoute) -> some View {
        switch route {
        case .cart:
            MenuCartSheet()
                .environmentObject(store)
                .presentationBackground(.clear)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        case .addDish, .editDish:
            EmptyView()
        }
    }

    private func handleDishFlowResult(_ result: MenuDishFlowResult) {
        switch result {
        case .added(let name):
            feedbackRouter.show(.high(message: "已新增 \(name)"))
        case .updated(let name):
            feedbackRouter.show(.high(message: "已更新 \(name)"))
        case .deleted(let name):
            feedbackRouter.show(
                .low(
                    message: "\(name) 已移入归档，可在后续补充撤销能力。",
                    systemImage: "exclamationmark.triangle.fill"
                ),
                hint: .centerToast
            )
        }
    }
}

private struct MenuDishFlowContainer: View {
    @EnvironmentObject private var store: AppStore

    let item: MenuDishFlowItem
    let quickCategories: [String]
    var focusedField: FocusState<MenuField?>.Binding
    let onDismiss: () -> Void
    let onComplete: (MenuDishFlowResult) -> Void

    @StateObject private var imageCoordinator = DishImageCoordinator()
    @State private var draft: AddDishDraft
    @State private var navigationPath: [MenuDishFlowRoute] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isPhotoPickerPresented = false
    @State private var archiveConfirmationPresented = false
    @State private var currentCameraSessionID = UUID()
    @State private var isRestartingCamera = false

    init(
        item: MenuDishFlowItem,
        quickCategories: [String],
        focusedField: FocusState<MenuField?>.Binding,
        onDismiss: @escaping () -> Void,
        onComplete: @escaping (MenuDishFlowResult) -> Void
    ) {
        self.item = item
        self.quickCategories = quickCategories
        self.focusedField = focusedField
        self.onDismiss = onDismiss
        self.onComplete = onComplete
        _draft = State(initialValue: item.initialDraft)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MenuDishFormScreen(
                title: item.title,
                confirmTitle: "保存",
                requiresImage: item.isAdd,
                draft: $draft,
                quickCategories: quickCategories,
                focusedField: focusedField,
                imageCoordinator: imageCoordinator,
                archiveConfirmationPresented: $archiveConfirmationPresented,
                onDismiss: onDismiss,
                onSave: saveDish,
                onPhotoLibraryRequest: {
                    isPhotoPickerPresented = true
                },
                onCameraRequest: {
                    currentCameraSessionID = UUID()
                    navigationPath.append(.camera(currentCameraSessionID))
                },
                onDelete: item.isEdit ? {
                    archiveConfirmationPresented = true
                } : nil
            )
            .navigationDestination(for: MenuDishFlowRoute.self) { route in
                switch route {
                case .camera(let sessionID):
                    ZStack {
                        DishCameraCaptureView(
                            onCapture: { image in
                                Task {
                                    let standardized = await standardizedCropImage(from: image)
                                    await MainActor.run {
                                        navigationPath.append(
                                            .crop(
                                                CropRoute(
                                                    id: UUID(),
                                                    image: standardized,
                                                    source: .camera
                                                )
                                            )
                                        )
                                    }
                                }
                            },
                            onCancel: {
                                popLastRoute()
                            }
                        )
                        .id(sessionID)
                        .ignoresSafeArea()

                        if isRestartingCamera {
                            Color(AppSemanticColor.cameraBackdrop)
                                .ignoresSafeArea()
                                .overlay {
                                    AppLoadingIndicator(label: "正在重启相机", tone: .inverse)
                                }
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                case .crop(let route):
                    DishRecognitionView(
                        sourceImage: route.image,
                        source: route.source == .camera ? .camera : .album,
                        onConfirm: { cropped in
                            imageCoordinator.processImage(cropped)
                            popLastRoute()
                        },
                        onCancel: {
                            handleCropCancel(route)
                        }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .background(AppSemanticColor.surface)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
        .task(id: item.id) {
            await seedRemoteImageIfNeeded()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let standardized = await standardizedCropImage(from: image)
                    await MainActor.run {
                        navigationPath.append(
                            .crop(
                                CropRoute(
                                    id: UUID(),
                                    image: standardized,
                                    source: .photoLibrary
                                )
                            )
                        )
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private func popLastRoute() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    private func handleCropCancel(_ route: CropRoute) {
        popLastRoute()
        switch route.source {
        case .photoLibrary:
            isPhotoPickerPresented = true
        case .camera:
            restartCameraRoute()
        }
    }

    private func restartCameraRoute() {
        guard case .camera = navigationPath.last else { return }
        isRestartingCamera = true
        Task {
            await MainActor.run {
                currentCameraSessionID = UUID()
                navigationPath[navigationPath.count - 1] = .camera(currentCameraSessionID)
            }
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                isRestartingCamera = false
            }
        }
    }

    private func standardizedCropImage(from image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            image.standardizedForCrop()
        }.value
    }

    private func seedRemoteImageIfNeeded() async {
        guard item.isEdit,
              case let .edit(dishID, _) = item,
              let dish = store.dishes.first(where: { $0.id == dishID }),
              let remoteURL = dish.publicImageURL(baseURL: DishImageSpec.r2PublicBaseURL)
        else {
            return
        }

        guard case .empty = imageCoordinator.imageState else { return }

        if let cached = await RemoteDishImagePipeline.shared.cachedImage(for: remoteURL) {
            await MainActor.run {
                imageCoordinator.seedRemoteImage(cached, remoteURL: remoteURL)
            }
            return
        }

        do {
            let image = try await RemoteDishImagePipeline.shared.fetchImage(from: remoteURL)
            await MainActor.run {
                imageCoordinator.seedRemoteImage(image, remoteURL: remoteURL)
            }
        } catch {
            return
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

    private func saveDish() {
        draft.hasTriedSubmit = true
        draft.resetValidation()
        let pendingIngredient = draft.ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pendingIngredient.isEmpty {
            draft.ingredientTags.append(pendingIngredient)
            draft.ingredientInput = ""
        }

        let addedName = draft.trimmedName
        let finalCategory = draft.resolvedCategory
        store.error = nil

        guard imageCoordinator.hasImage || draft.editingDishID != nil else {
            draft.invalidImage = true
            draft.imageError = "请添加菜品图片"
            draft.validationTrigger += 1
            return
        }
        guard !addedName.isEmpty else {
            draft.invalidName = true
            draft.nameError = "请输入菜名"
            draft.validationTrigger += 1
            focusedField.wrappedValue = .name
            return
        }
        guard !finalCategory.isEmpty else {
            draft.invalidCategory = true
            draft.categoryError = "请输入分类"
            draft.validationTrigger += 1
            focusedField.wrappedValue = draft.selectedQuickCategory == "自定义" ? .customCategory : .name
            return
        }
        guard !draft.ingredientTags.isEmpty else {
            draft.invalidIngredients = true
            draft.ingredientError = "请添加食材"
            draft.validationTrigger += 1
            focusedField.wrappedValue = .ingredient
            return
        }

        Task {
            guard store.kitchen != nil else {
                await MainActor.run {
                    draft.imageError = "当前还没有进入 kitchen"
                }
                return
            }

            let previousImageState = imageCoordinator.imageState
            let imageFileURL: URL?
            switch imageCoordinator.imageState {
            case .ready(_, let url), .uploadFailed(_, let url, _):
                imageCoordinator.imageState = .uploading
                imageFileURL = url
            case .remote:
                imageFileURL = nil
            default:
                imageFileURL = nil
            }

            let editingDishID = draft.editingDishID
            let result: Dish?
            if let editingDishID {
                result = await store.updateDish(
                    id: editingDishID,
                    name: addedName,
                    category: finalCategory,
                    ingredients: draft.ingredientTags,
                    imageFileURL: imageFileURL
                )
            } else {
                result = await store.addDish(
                    name: addedName,
                    category: finalCategory,
                    ingredients: draft.ingredientTags,
                    imageFileURL: imageFileURL
                )
            }

            guard let dish = result else {
                await MainActor.run {
                    draft.imageError = store.error ?? "保存失败"
                    if let imageFileURL {
                        restoreUploadState(
                            previousState: previousImageState,
                            fileURL: imageFileURL,
                            message: draft.imageError ?? "保存失败"
                        )
                    }
                }
                return
            }

            if let imageFileURL {
                imageCoordinator.cleanupAfterUpload(fileURL: imageFileURL)
            }

            await MainActor.run {
                if editingDishID == nil {
                    onComplete(.added(dish.name))
                } else {
                    onComplete(.updated(dish.name))
                }
            }
        }
    }

    private func deleteDish() {
        guard let dishID = draft.editingDishID,
              let dish = store.dishes.first(where: { $0.id == dishID }) else { return }
        Task {
            await store.archiveDish(id: dish.id)
            await MainActor.run {
                onComplete(.deleted(dish.name))
            }
        }
    }
}

private struct MenuDishFormScreen: View {
    let title: String
    let confirmTitle: String
    let requiresImage: Bool
    @Binding var draft: AddDishDraft
    let quickCategories: [String]
    var focusedField: FocusState<MenuField?>.Binding
    @ObservedObject var imageCoordinator: DishImageCoordinator
    @Binding var archiveConfirmationPresented: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void
    let onPhotoLibraryRequest: () -> Void
    let onCameraRequest: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    MenuDishFlowImagePickerSection(
                        coordinator: imageCoordinator,
                        onPhotoLibraryRequest: onPhotoLibraryRequest,
                        onCameraRequest: onCameraRequest,
                        isInvalid: draft.invalidImage,
                        validationTrigger: draft.validationTrigger,
                        errorMessage: draft.imageError
                    )

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("常用分类")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppSemanticColor.textSecondary)

                        quickCategoryChips

                        if draft.selectedQuickCategory == "自定义" {
                            formTextField("自定义分类", text: $draft.customCategory, field: .customCategory)
                        }

                        if let categoryError = draft.categoryError {
                            Text(categoryError)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    formTextField("菜名", text: $draft.name, field: .name)

                    if let nameError = draft.nameError {
                        Text(nameError)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    IngredientTagInput(
                        tags: $draft.ingredientTags,
                        input: $draft.ingredientInput,
                        focusedField: focusedField,
                        isInvalid: draft.invalidIngredients,
                        validationTrigger: draft.validationTrigger,
                        errorMessage: draft.ingredientError
                    )

                    if let onDelete {
                        AppButton(
                            title: "删除菜品",
                            style: .destructive,
                            action: {
                                archiveConfirmationPresented = true
                            }
                        )
                        .confirmationDialog(
                            "删除后会归档该菜品",
                            isPresented: $archiveConfirmationPresented,
                            titleVisibility: .visible
                        ) {
                            Button("删除菜品", role: .destructive, action: onDelete)
                            Button("取消", role: .cancel) {}
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.never)
        }
        .background(AppSemanticColor.surface)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            draft.resetValidation()
            focusedField.wrappedValue = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                focusedField.wrappedValue = .name
            }
        }
        .task(id: draft.validationTrigger) {
            guard draft.validationTrigger > 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                draft.resetValidation()
            }
        }
    }

    private var isSaveDisabled: Bool {
        draft.hasTriedSubmit && !formIsComplete
    }

    private var formIsComplete: Bool {
        draft.trimmedName.isEmpty == false &&
        draft.hasCategory &&
        draft.hasIngredients &&
        (!requiresImage || imageCoordinator.hasImage)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button("关闭", action: onDismiss)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textSecondary)

            Spacer()

            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)

            Spacer()

            Button(confirmTitle, action: onSave)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(isSaveDisabled ? AppSemanticColor.textTertiary : AppSemanticColor.primary)
                .disabled(isSaveDisabled)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    private var quickCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(quickCategories, id: \.self) { category in
                    Button {
                        draft.selectedQuickCategory = category
                    } label: {
                        Text(category)
                            .font(AppTypography.micro)
                            .foregroundStyle(draft.selectedQuickCategory == category ? AppSemanticColor.onPrimary : AppSemanticColor.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .frame(height: AppDimension.compactPillHeight)
                            .background(
                                draft.selectedQuickCategory == category ? AppSemanticColor.primary : AppSemanticColor.interactiveSecondary,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formTextField(_ title: String, text: Binding<String>, field: MenuField) -> some View {
        AppTextField(
            title: title,
            text: text,
            focusedField: focusedField,
            field: field,
            height: 52,
            chrome: .card,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            submitLabel: .done,
            onSubmit: nil,
            isInvalid: field == .name ? draft.invalidName : draft.invalidCategory,
            validationTrigger: draft.validationTrigger
        )
    }
}

private struct MenuDishFlowImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    let onPhotoLibraryRequest: () -> Void
    let onCameraRequest: () -> Void
    var isInvalid: Bool = false
    var validationTrigger: Int = 0
    var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            switch coordinator.imageState {
            case .empty:
                pickerButtons
            case .processing:
                progressState("处理中…")
            case .extracting:
                progressState("识别中…")
            case .remote(let previewImage, _):
                imagePreview(previewImage, showsRemoveButton: false, showsPickerButtons: true)
            case .ready(let previewImage, _):
                imagePreview(previewImage, showsRemoveButton: true, showsPickerButtons: true)
            case .uploading:
                progressState("上传中…")
            case .uploadFailed(let previewImage, _, let message):
                VStack(spacing: AppSpacing.xs) {
                    imagePreview(previewImage, showsRemoveButton: true, showsPickerButtons: true)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.danger)
                }
            case .failed(let message):
                VStack(spacing: AppSpacing.xs) {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.danger)
                    pickerButtons
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .appValidationFeedback(isInvalid: isInvalid, trigger: validationTrigger)
    }

    private var pickerButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onPhotoLibraryRequest) {
                Label("相册", systemImage: "photo.on.rectangle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
            }
            .buttonStyle(.plain)

            Button(action: onCameraRequest) {
                Label("拍照", systemImage: "camera")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xxs)
        .background(AppSemanticColor.interactiveSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func progressState(_ title: String) -> some View {
        AppLoadingIndicator(label: title, tone: .primary, controlSize: .regular)
            .frame(maxWidth: .infinity, minHeight: AppDimension.progressBlockMinHeight)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func imagePreview(
        _ image: UIImage,
        showsRemoveButton: Bool,
        showsPickerButtons: Bool
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(AppSemanticColor.surfaceSecondary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.imagePreviewMinHeight)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(0.7)
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .clipped()

                if showsRemoveButton {
                    Button {
                        coordinator.clearImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: AppIconSize.xl))
                            .foregroundStyle(AppSemanticColor.textSecondary)
                            .padding(AppInset.badgeHorizontal)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showsPickerButtons {
                pickerButtons
            }
        }
    }
}

private struct CropRoute: Hashable {
    let id: UUID
    let image: UIImage
    let source: CropImageSource

    static func == (lhs: CropRoute, rhs: CropRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private enum MenuDishFlowRoute: Hashable {
    case camera(UUID)
    case crop(CropRoute)
}

private enum MenuDishFlowResult {
    case added(String)
    case updated(String)
    case deleted(String)
}

private enum MenuDishFlowItem: Identifiable {
    case add
    case edit(String, AddDishDraft)

    var id: String {
        switch self {
        case .add:
            return "add-dish-flow"
        case .edit(let dishID, _):
            return "edit-dish-flow-\(dishID)"
        }
    }

    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }

    var isEdit: Bool {
        !isAdd
    }

    var title: String {
        isAdd ? "新增菜品" : "编辑菜品"
    }

    var initialDraft: AddDishDraft {
        switch self {
        case .add:
            return AddDishDraft()
        case .edit(_, let draft):
            return draft
        }
    }
}

private struct MenuEmptyStateView: View {
    let feedback: AppFeedback
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer(minLength: 0)

            Text(feedback.title ?? "暂无内容")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)
                .multilineTextAlignment(.center)

            if let hint = feedback.message {
                Text(hint)
                    .font(AppTypography.body)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

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
