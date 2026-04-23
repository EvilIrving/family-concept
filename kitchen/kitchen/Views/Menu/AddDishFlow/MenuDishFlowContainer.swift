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
    @State private var archiveConfirmationPresented = false
    @State private var currentCameraSessionID = UUID()

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
                    deleteDish()
                } : nil
            )
            .navigationDestination(for: MenuDishFlowRoute.self) { route in
                switch route {
                case .camera(let sessionID):
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
            feedbackRouter.show(.low(message: "请输入菜名"), hint: .centerToast)
            focusedField.wrappedValue = .name
            return
        }
        guard !finalCategory.isEmpty else {
            draft.invalidCategory = true
            draft.validationTrigger += 1
            feedbackRouter.show(.low(message: "请输入分类"), hint: .centerToast)
            focusedField.wrappedValue = draft.selectedQuickCategory == "自定义" ? .customCategory : .name
            return
        }
        guard !draft.ingredientTags.isEmpty else {
            draft.invalidIngredients = true
            draft.validationTrigger += 1
            feedbackRouter.show(.low(message: "请添加食材"), hint: .centerToast)
            focusedField.wrappedValue = .ingredient
            return
        }

        Task {
            guard store.kitchen != nil else {
                await MainActor.run {
                    feedbackRouter.show(.low(message: "当前还没有进入 kitchen"), hint: .centerToast)
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
                    let errorMsg = store.error ?? "保存失败"
                    feedbackRouter.show(.low(message: errorMsg), hint: .centerToast)
                    if let imageFileURL {
                        restoreUploadState(
                            previousState: previousImageState,
                            fileURL: imageFileURL,
                            message: errorMsg
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
