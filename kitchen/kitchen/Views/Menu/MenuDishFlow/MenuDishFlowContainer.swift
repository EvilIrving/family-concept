import SwiftUI
import PhotosUI

struct MenuDishFlowContainer: View {
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
                onEditImageRequest: {
                    reopenCurrentImageForEditing()
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
        case .existingCover:
            break
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

    private func reopenCurrentImageForEditing() {
        let image: UIImage?
        switch imageCoordinator.imageState {
        case .ready(let previewImage, _), .uploadFailed(let previewImage, _, _), .remote(let previewImage, _):
            image = previewImage
        default:
            image = nil
        }

        guard let image else { return }

        navigationPath.append(
            .crop(
                CropRoute(
                    id: UUID(),
                    image: image,
                    source: .existingCover
                )
            )
        )
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
