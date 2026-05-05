import Nuke
import SwiftUI
import PhotosUI

struct MenuDishFlowContainer: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter

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
    @State private var currentCameraSessionID = UUID()
    @State private var isSaving = false

    private let originalDraft: AddDishDraft

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
        let initial = item.initialDraft
        _draft = State(initialValue: initial)
        self.originalDraft = initial
    }

    private var isFormValid: Bool {
        !draft.trimmedName.isEmpty &&
        draft.hasCategory &&
        draft.hasIngredients &&
        (imageCoordinator.hasImage || draft.editingDishID != nil)
    }

    private var hasNewImage: Bool {
        switch imageCoordinator.imageState {
        case .ready, .uploadFailed:
            return true
        default:
            return false
        }
    }

    private var isDirty: Bool {
        guard item.isEdit else { return true }
        if draft.trimmedName != originalDraft.trimmedName { return true }
        if draft.resolvedCategory != originalDraft.resolvedCategory { return true }
        let pending = draft.ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines)
        var current = draft.ingredientTags
        if !pending.isEmpty { current.append(pending) }
        if current != originalDraft.ingredientTags { return true }
        if hasNewImage { return true }
        return false
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MenuDishFormScreen(
                title: item.title,
                confirmTitle: L10n.tr("Save"),
                canSave: isFormValid,
                draft: $draft,
                quickCategories: quickCategories,
                focusedField: focusedField,
                imageCoordinator: imageCoordinator,
                isSaving: isSaving,
                onDismiss: onDismiss,
                onSave: saveDish,
                onPhotoLibraryRequest: {
                    isPhotoPickerPresented = true
                },
                onCameraRequest: {
                    currentCameraSessionID = UUID()
                    navigationPath.append(.camera(currentCameraSessionID))
                },
                onDelete: deleteActionIfEditing
            )
            .navigationDestination(for: MenuDishFlowRoute.self) { route in
                switch route {
                case .camera(let sessionID):
                    DishCameraCaptureView(
                        onCapture: { image in
                            imageCoordinator.extractAndProcess(image)
                            if case .camera = navigationPath.last {
                                popLastRoute()
                            }
                        },
                        onCancel: {
                            popLastRoute()
                        }
                    )
                    .id(sessionID)
                    .ignoresSafeArea()
                    .toolbar(.hidden, for: .navigationBar)
                case .crop(let route):
                    DishFramingView(
                        sourceImage: route.image,
                        inputSource: route.source == .camera ? .camera : .album,
                        onConfirm: { cropped in
                            imageCoordinator.processImage(cropped)
                            handleCropConfirm(route)
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
        .overlay {
            if isSaving {
                savingOverlay
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSaving)
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
        .task(id: item.id) {
            await seedRemoteImageIfNeeded()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        imageCoordinator.extractAndProcess(image)
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var savingOverlay: some View {
        ZStack {
            AppSemanticColor.surface.opacity(0.75)
                .ignoresSafeArea()
                .contentShape(Rectangle())
            AppLoadingIndicator(label: L10n.tr("Saving…"), tone: .primary, controlSize: .large)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .fill(AppSemanticColor.surface)
                )
                .appShadow(AppShadow.card)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
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

    private func handleCropConfirm(_ route: CropRoute) {
        popLastRoute()
        guard route.source == .camera else { return }
        guard case .camera = navigationPath.last else { return }
        popLastRoute()
    }

    private func restartCameraRoute() {
        guard case .camera = navigationPath.last else { return }
        Task {
            await MainActor.run {
                popLastRoute()
            }
            try? await Task.sleep(for: .milliseconds(150))
            await MainActor.run {
                currentCameraSessionID = UUID()
                navigationPath.append(.camera(currentCameraSessionID))
            }
        }
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

        if let cached = ImagePipeline.shared.cache[remoteURL]?.image {
            await MainActor.run {
                imageCoordinator.seedRemoteImage(cached, remoteURL: remoteURL)
            }
            return
        }

        do {
            let image = try await ImagePipeline.shared.image(for: remoteURL)
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
        guard !isSaving else { return }
        guard isFormValid else { return }
        if item.isEdit, !isDirty {
            onDismiss()
            return
        }
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
            draft.validationTrigger += 1
            return
        }
        guard !addedName.isEmpty else {
            draft.invalidName = true
            draft.validationTrigger += 1
            feedbackRouter.show(.low(message: L10n.tr("Enter a dish name")), placement: .centerToast)
            focusedField.wrappedValue = .name
            return
        }
        guard !finalCategory.isEmpty else {
            draft.invalidCategory = true
            draft.validationTrigger += 1
            feedbackRouter.show(.low(message: L10n.tr("Enter a category")), placement: .centerToast)
            focusedField.wrappedValue = draft.selectedQuickCategory == "Custom" ? .customCategory : .name
            return
        }
        guard !draft.ingredientTags.isEmpty else {
            draft.invalidIngredients = true
            draft.validationTrigger += 1
            feedbackRouter.show(.low(message: L10n.tr("Please add ingredients")), placement: .centerToast)
            focusedField.wrappedValue = .ingredient
            return
        }

        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            guard store.kitchen != nil else {
                feedbackRouter.show(.low(message: L10n.tr("No active kitchen")), placement: .centerToast)
                return
            }

            let previousImageState = imageCoordinator.imageState
            let imageFileURL: URL?
            switch imageCoordinator.imageState {
            case .ready(_, let url), .uploadFailed(_, let url, _):
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
                let errorMsg = store.error ?? L10n.tr("Save failed")
                feedbackRouter.show(.low(message: errorMsg), placement: .centerToast)
                if let imageFileURL {
                    restoreUploadState(
                        previousState: previousImageState,
                        fileURL: imageFileURL,
                        message: errorMsg
                    )
                }
                return
            }

            if let imageFileURL {
                imageCoordinator.cleanupAfterUpload(fileURL: imageFileURL)
            }

            if editingDishID == nil {
                onComplete(.added(dish.name))
            } else {
                onComplete(.updated(dish.name))
            }
        }
    }

    private var deleteActionIfEditing: (() async -> Void)? {
        guard item.isEdit else { return nil }
        return { await deleteDish() }
    }

    private func deleteDish() async {
        guard let dishID = draft.editingDishID,
              let dish = store.dishes.first(where: { $0.id == dishID }) else { return }
        isSaving = true
        await store.archiveDish(id: dish.id)
        isSaving = false
        onComplete(.deleted(dish.name))
    }
}
