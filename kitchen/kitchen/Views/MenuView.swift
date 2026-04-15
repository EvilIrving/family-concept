import SwiftUI
import PhotosUI

fileprivate enum MenuField {
    case name
    case customCategory
    case ingredient
    case search
}

private struct CropPresentation: Identifiable {
    let id = UUID()
    let image: UIImage
}

private enum MenuModalRoute: Identifiable {
    case addDish
    case cart
    case camera
    case crop(CropPresentation)

    var id: String {
        switch self {
        case .addDish:
            return "add-dish"
        case .cart:
            return "cart"
        case .camera:
            return "camera"
        case .crop(let presentation):
            return "crop-\(presentation.id.uuidString)"
        }
    }
}

struct MenuView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var modalRouter = ModalRouter<MenuModalRoute>()
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

    @StateObject private var imageCoordinator = DishImageCoordinator()
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let quickCategories = ["家常菜", "快手菜", "汤羹", "主食", "饮品", "甜点", "其他"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppCard {
                searchBar

                categoryChips(categories: filterCategories, selection: $selectedCategory)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)

            if filteredDishes.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Spacer(minLength: 0)

                    Text(emptyMenuTitle)
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(emptySearchHint)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                        ForEach(filteredDishes) { dish in
                            MenuDishCard(
                                title: dish.name,
                                category: dish.category,
                                quantity: store.cartQuantity(for: dish.id),
                                imageURL: dish.publicImageURL(baseURL: DishImageSpec.r2PublicBaseURL),
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
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        focusedField = nil
                    }
                )
            }

            menuCartBar
        }
        .appPageBackground()
        .sheet(isPresented: addDishBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            AppSheetContainer(
                title: "新增菜品",
                dismissTitle: "关闭",
                confirmTitle: "保存",
                onDismiss: dismissAddDish,
                onConfirm: saveDish
            ) {
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        DishImagePickerSection(
                            coordinator: imageCoordinator,
                            selectedPhotoItem: $selectedPhotoItem,
                            onCameraRequest: { modalRouter.transition(to: .camera) }
                        )

                        sheetTextField("菜名", text: $name, field: .name)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("常用分类")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColor.textSecondary)

                            categoryChips(categories: quickCategories, selection: $selectedQuickCategory)

                            if selectedQuickCategory == "其他" {
                                sheetTextField("自定义分类", text: $customCategory, field: .customCategory)
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
                .scrollDismissesKeyboard(.never)
            }
            .presentationBackground(AppColor.surfacePrimary)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .onAppear {
                validationMessage = nil
                focusedField = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    guard isPresentingAddDish else { return }
                    focusedField = .name
                }
            }
        }
        .sheet(isPresented: cartBinding, onDismiss: { modalRouter.didDismissCurrent() }) {
            CartSheet()
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

    private func saveDish() {
        let addedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalCategory = resolvedCategory
        store.error = nil
        validationMessage = nil
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
            guard store.kitchen != nil else {
                validationMessage = "当前还没有进入 kitchen"
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
                ingredients: ingredientTags,
                imageFileURL: imageFileURL
            ) else {
                validationMessage = store.error ?? "保存失败"
                if let imageFileURL {
                    restoreUploadState(previousState: previousImageState, fileURL: imageFileURL, message: validationMessage ?? "保存失败")
                }
                return
            }

            if let imageFileURL {
                imageCoordinator.cleanupAfterUpload(fileURL: imageFileURL)
            }

            // Reset and close
            let savedName = dish.name
            name = ""
            selectedQuickCategory = "家常菜"
            customCategory = ""
            ingredientTags = []
            ingredientInput = ""
            validationMessage = nil
            imageCoordinator.clearImage()
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

    private func sheetTextField(_ title: String, text: Binding<String>, field: MenuField) -> some View {
        AppTextField(
            title: title,
            text: text,
            focusedField: $focusedField,
            field: field,
            height: 52,
            chrome: .card,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            submitLabel: .done,
            onSubmit: nil,
            isInvalid: false,
            validationTrigger: 0
        )
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

    private var emptyMenuTitle: String {
        if debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            "菜单还没有菜品"
        } else {
            "没有找到匹配的菜品"
        }
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
        name = ""
        selectedQuickCategory = "家常菜"
        customCategory = ""
        ingredientTags = []
        ingredientInput = ""
        validationMessage = nil
        imageCoordinator.clearImage()
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

private struct DishImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onCameraRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("菜品图片")
                .font(AppTypography.micro)
                .foregroundStyle(AppColor.textSecondary)

            switch coordinator.imageState {
            case .empty:
                pickerButtons

            case .processing:
                HStack {
                    ProgressView()
                        .tint(AppColor.green800)
                    Text("处理中…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))

            case .cropping:
                HStack {
                    ProgressView()
                        .tint(AppColor.green800)
                    Text("裁剪中…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))

            case .ready(let previewImage, _):
                imagePreview(previewImage)

            case .uploading:
                HStack {
                    ProgressView()
                        .tint(AppColor.green800)
                    Text("上传中…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))

            case .uploadFailed(let previewImage, _, let message):
                VStack(spacing: AppSpacing.xs) {
                    imagePreview(previewImage)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.danger)
                }

            case .failed(let message):
                VStack(spacing: AppSpacing.xs) {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.danger)
                    pickerButtons
                }

            }
        }
    }

    private var pickerButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("相册", systemImage: "photo.on.rectangle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.green800)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColor.green100, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)

            Button {
                onCameraRequest()
            } label: {
                Label("拍照", systemImage: "camera")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.green800)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColor.green100, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(AppColor.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            Button {
                coordinator.clearImage()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(AppSpacing.xs)
            }
            .buttonStyle(.plain)
        }
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

            AppTextField(
                title: "添加食材",
                text: $input,
                focusedField: focusedField,
                field: .ingredient,
                height: 52,
                chrome: .card,
                autocapitalization: .never,
                autocorrectionDisabled: true,
                submitLabel: .done,
                onSubmit: { commitTag() },
                isInvalid: false,
                validationTrigger: 0
            )
            .onChange(of: input) { _, newValue in
                if newValue.last == " " {
                    commitTag()
                }
            }
        }
    }

    private func commitTag() {
        let tag = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        if !tag.isEmpty { tags.append(tag) }
        focusedField.wrappedValue = .ingredient
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
        AppSheetContainer(
            title: "购物车",
            dismissTitle: "关闭",
            confirmTitle: "提交下单",
            onDismiss: { dismiss() },
            onConfirm: {
                Task {
                    await store.submitCart()
                    toast = AppToastData(message: "已下单")
                    dismiss()
                }
            }
        ) {
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
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .appToast($toast)
    }
}

#Preview {
    MenuView()
        .environmentObject(AppStore())
}
