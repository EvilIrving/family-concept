import Foundation
import Testing
import UIKit
@testable import kitchen

@MainActor
@Suite("Model 状态与派生逻辑")
struct ModelStateTests {

    @Test("Dish ingredients 可以解析合法 JSON")
    func dishIngredientsParsesValidJSON() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "番茄炒蛋", category: "家常",
            imageKey: nil, ingredientsJson: "[\"番茄\",\"鸡蛋\"]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        #expect(dish.ingredients == ["番茄", "鸡蛋"])
    }

    @Test("Dish ingredients 遇到非法 JSON 返回空数组")
    func dishIngredientsReturnsEmptyOnInvalidJSON() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "not json",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        #expect(dish.ingredients.isEmpty)
    }

    @Test("Dish archivedAt 有值时视为已归档")
    func dishIsArchivedWhenArchivedAtHasValue() {
        let archived = Dish(
            id: "1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: "2026-01-01"
        )
        let active = Dish(
            id: "2", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        #expect(archived.isArchived)
        #expect(active.isArchived == false)
    }

    @Test("Dish publicImageURL 按 baseURL 和 imageKey 拼接公开地址")
    func dishPublicImageURLBuildsFullURL() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "红烧肉", category: "热菜",
            imageKey: "menu/ribs.png", ingredientsJson: "[]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        #expect(dish.publicImageURL(baseURL: "https://img.example.com")?.absoluteString == "https://img.example.com/menu/ribs.png")
        #expect(dish.publicImageURL(baseURL: "https://img.example.com/")?.absoluteString == "https://img.example.com/menu/ribs.png")
        #expect(dish.publicImageURL(baseURL: "") == nil)
    }

    @Test("Member 缺少 nickName 字段时解码为空字符串")
    func memberDecodesMissingNicknameAsEmptyString() throws {
        let json = """
        {
          "id": "m1",
          "kitchen_id": "k1",
          "account_id": "a1",
          "role": "member",
          "status": "active",
          "joined_at": "2026-04-16T08:00:00Z",
          "removed_at": null
        }
        """

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let member = try decoder.decode(Member.self, from: Data(json.utf8))

        #expect(member.nickName.isEmpty)
    }

    @Test("ItemStatus title 返回中文状态文案")
    func itemStatusTitles() {
        #expect(ItemStatus.waiting.title == "待制作")
        #expect(ItemStatus.cooking.title == "制作中")
        #expect(ItemStatus.done.title == "已完成")
        #expect(ItemStatus.cancelled.title == "已取消")
    }

    @Test("KitchenRole title 返回中文角色文案")
    func kitchenRoleTitles() {
        #expect(KitchenRole.owner.title == "管理员")
        #expect(KitchenRole.admin.title == "副管理员")
        #expect(KitchenRole.member.title == "成员")
    }

    @Test("DishDraftImageState 为每个阶段提供标题和说明")
    func dishDraftImageStateProvidesStatusCopy() {
        let sampleImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
            UIColor.red.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
        }
        let fileURL = URL(fileURLWithPath: "/tmp/dish.png")

        #expect(DishDraftImageState.empty.statusTitle == "待添加图片")
        #expect(DishDraftImageState.empty.statusSubtitle == "拍照或选图后，可在方形取景框内调整菜品构图")
        #expect(DishDraftImageState.processing.statusTitle == "正在优化菜品图")
        #expect(DishDraftImageState.remote(previewImage: sampleImage, remoteURL: URL(string: "https://img.example.com/dish.png")!).statusSubtitle == "当前正在使用已上传图片")
        #expect(DishDraftImageState.ready(previewImage: sampleImage, fileURL: fileURL).statusTitle == "图片已就绪")
        #expect(DishDraftImageState.uploading.statusTitle == "正在上传")
        #expect(DishDraftImageState.uploadFailed(previewImage: sampleImage, fileURL: fileURL, message: "上传超时").statusSubtitle == "上传超时")
        #expect(DishDraftImageState.failed("处理异常").statusSubtitle == "处理异常")
    }

    @Test("DishImageCoordinator 将远端图片作为可展示但不可上传的初始状态")
    func dishImageCoordinatorSeedsRemoteImage() {
        let coordinator = DishImageCoordinator()
        let sampleImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
            UIColor.blue.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
        }
        let remoteURL = URL(string: "https://img.example.com/seed.png")!

        coordinator.seedRemoteImage(sampleImage, remoteURL: remoteURL)

        #expect(coordinator.hasImage)
        guard case .remote(let previewImage, let seededURL) = coordinator.imageState else {
            Issue.record("Expected remote seeded state")
            return
        }
        #expect(previewImage.pngData() == sampleImage.pngData())
        #expect(seededURL == remoteURL)
    }

    @Test("DishImageCoordinator 仅在空态时接受远端设种")
    func dishImageCoordinatorDoesNotOverrideLocalImage() {
        let coordinator = DishImageCoordinator()
        let localImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
            UIColor.green.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
        }
        let remoteImage = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in
            UIColor.orange.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 8, height: 8)).fill()
        }
        let localURL = URL(fileURLWithPath: "/tmp/local-dish.png")
        let remoteURL = URL(string: "https://img.example.com/seed.png")!
        coordinator.imageState = .ready(previewImage: localImage, fileURL: localURL)

        coordinator.seedRemoteImage(remoteImage, remoteURL: remoteURL)

        guard case .ready(let previewImage, let fileURL) = coordinator.imageState else {
            Issue.record("Expected local ready state to be preserved")
            return
        }
        #expect(previewImage.pngData() == localImage.pngData())
        #expect(fileURL == localURL)
    }

    @Test("LoadingPhase 支持首次加载与完成流转")
    func loadingPhaseSupportsInitialFlow() {
        let loading = LoadingPhase<[String]>.initialLoading(label: "加载中")
        let success = LoadingPhase<[String]>.success(["a", "b"])

        #expect(loading.isLoading)
        #expect(loading.retainedValue == nil)
        #expect(success.isLoading == false)
        #expect(success.retainedValue == ["a", "b"])
    }

    @Test("LoadingPhase 支持带旧内容的刷新与失败态")
    func loadingPhaseSupportsRefreshAndFailure() {
        let refreshing = LoadingPhase<[String]>.refreshing(["old"], label: "刷新中")
        let failure = LoadingPhase<[String]>.failure(.network(), retainedValue: ["old"])

        #expect(refreshing.isLoading)
        #expect(refreshing.retainedValue == ["old"])
        #expect(refreshing == .loading(LoadingContext(mode: .refresh, label: "刷新中", retainedValue: ["old"])))
        #expect(failure.feedback?.kind == .network)
        #expect(failure.retainedValue == ["old"])
    }

    @Test("AppFeedback empty 支持语义 kind 与默认 override")
    func emptyFeedbackCarriesSemanticKind() {
        let feedback = AppFeedback.empty(kind: .noSearchResult)

        #expect(feedback.haptic == nil)
        #expect(feedback.emptyKind == .noSearchResult)
        #expect(feedback.kind == .empty(.noSearchResult))
        #expect(feedback.title == nil)
        #expect(feedback.message == nil)
        #expect(feedback.systemImage == nil)
    }

    @Test("LoadingPhase 通过 failure 承载 empty feedback")
    func loadingPhaseCarriesEmptyFeedbackThroughFailure() {
        let phase = LoadingPhase<[String]>.failure(
            .empty(kind: .noData, title: "还没有内容"),
            retainedValue: nil
        )

        #expect(phase.feedback?.emptyKind == .noData)
        #expect(phase.feedback?.title == "还没有内容")
        #expect(phase.retainedValue == nil)
    }

    @Test("LoadingPhase empty 与 error 在同一 feedback 层级")
    func loadingPhaseTreatsEmptyAndErrorsAsPeerFeedback() {
        let empty = LoadingPhase<[String]>.failure(.empty(kind: .noData), retainedValue: nil)
        let network = LoadingPhase<[String]>.failure(.network(), retainedValue: nil)
        let auth = LoadingPhase<[String]>.failure(.auth(), retainedValue: nil)
        let generic = LoadingPhase<[String]>.failure(.generic(), retainedValue: nil)

        #expect(empty.feedback?.kind == .empty(.noData))
        #expect(network.feedback?.kind == .network)
        #expect(auth.feedback?.kind == .auth)
        #expect(generic.feedback?.kind == .generic)
    }

    @Test("LoadingPhase 支持明确的 progress loading")
    func loadingPhaseSupportsProgressContext() {
        let phase = LoadingPhase<Void>.progress(0.45, label: "上传中")

        #expect(phase.isLoading)
        guard case .loading(let context) = phase else {
            Issue.record("Expected progress loading context")
            return
        }
        #expect(context.mode == .progress)
        #expect(context.label == "上传中")
        #expect(context.progress == 0.45)
    }

    @Test("AppFeedbackRouter 将 info payload 路由到 toast")
    func appFeedbackRouterRoutesInfoPayloadToToast() {
        let router = AppFeedbackRouter(duplicateWindow: 0.2)

        let result = router.show(.low(message: "已复制邀请码"))

        guard case .shown(let id) = result else {
            Issue.record("Expected shown toast")
            return
        }
        #expect(router.topToasts.first == id)
        #expect(router.topToasts.count == 1)
        #expect(router.centerToasts.isEmpty)
        #expect(router.currentBannerID == nil)
        #expect(router.isBannerActive == false)
    }

    @Test("AppFeedbackRouter 将 success payload 路由到 toast")
    func appFeedbackRouterRoutesSuccessPayloadToToast() {
        let router = AppFeedbackRouter(duplicateWindow: 0.2)

        let result = router.show(.high(message: "保存成功"))

        guard case .shown(let id) = result else {
            Issue.record("Expected shown toast")
            return
        }
        #expect(router.topToasts.first == id)
        #expect(router.topToasts.count == 1)
        #expect(router.centerToasts.isEmpty)
        #expect(router.currentBannerID == nil)
        #expect(router.isBannerActive == false)
    }

    @Test("AppFeedbackRouter 在 banner active 时返回 blockedByActiveBanner")
    func appFeedbackRouterReportsToastBlockedWhenBannerIsActive() {
        let router = AppFeedbackRouter(duplicateWindow: 0.2)

        router.show(.network(message: "保存成功"))
        let result = router.show(.low(message: "已复制邀请码"))

        #expect(result == .blockedByActiveBanner)
        #expect(router.currentBannerID != nil)
        #expect(router.topToasts.isEmpty)
        #expect(router.centerToasts.isEmpty)
    }

    @Test("AppFeedbackRouter 在短时间窗口内抑制重复消息")
    func appFeedbackRouterSuppressesDuplicateMessages() {
        let router = AppFeedbackRouter(duplicateWindow: 5)

        router.show(.low(message: "重复消息"))
        let result = router.show(.low(message: "重复消息"))

        #expect(result == .ignoredDuplicate)
        #expect(router.topToasts.count == 1)
        #expect(router.centerToasts.isEmpty)
        #expect(router.currentBannerID == nil)
    }

    @Test("相同文案但不同 severity 不会被语义指纹去重")
    func semanticFingerprintDoesNotSuppressDifferentSeverity() {
        let router = AppFeedbackRouter(duplicateWindow: 5)

        router.show(.low(message: "重复消息"))
        let firstToastID = router.topToasts.first
        router.show(.network(title: "重复消息", message: "重复消息"))

        #expect(router.topToasts.count == 1)
        #expect(router.topToasts.first == firstToastID)
        #expect(router.currentBannerID != nil)
    }

    @Test("相同文案但不同 action intent 不会被语义指纹去重")
    func semanticFingerprintDoesNotSuppressDifferentActionIntent() {
        let router = AppFeedbackRouter(duplicateWindow: 5)

        router.show(.low(message: "重复消息", actionLabel: "重试"))
        let firstToastID = router.topToasts.first
        router.show(.low(message: "重复消息", actionLabel: "查看"))

        #expect(router.topToasts.count == 1)
        #expect(router.topToasts.first != firstToastID)
        #expect(router.centerToasts.count == 0)
        #expect(router.currentBannerID == nil)
    }

    @Test("persistent error banner 不自动消失")
    func persistentErrorBannerDoesNotAutoDismiss() {
        let router = AppFeedbackRouter(duplicateWindow: 0.2)

        router.show(.network())

        #expect(router.currentBannerID != nil)
        #expect(router.currentBannerAutoDismissDuration == nil)
    }

    @Test("低 severity banner 不能替换高 severity banner")
    func lowerSeverityBannerDoesNotReplaceHigherSeverityBanner() throws {
        let router = AppFeedbackRouter(duplicateWindow: 0.2)

        router.show(.auth(message: "登录失效"))
        let firstBannerID = try #require(router.currentBannerID)
        let warningFeedback = AppFeedback(
            kind: .generic,
            payload: AppFeedbackPayload(
                title: "提醒",
                message: "请稍后处理",
                icon: "exclamationmark.triangle",
                severity: .warning,
                persistence: .persistent
            )
        )

        let result = router.show(warningFeedback)

        #expect(result == .blockedByActiveBanner)
        #expect(router.currentBannerID == firstBannerID)
    }

    @Test("AppFeedbackRouter 支持显式 placement 覆盖 severity 默认位置")
    func appFeedbackRouterSupportsExplicitPlacementOverride() throws {
        let router = AppFeedbackRouter(duplicateWindow: 0.2)

        let successBanner = router.show(.high(message: "保存成功"), placement: .topBanner)
        let bannerID: UUID
        guard case .shown(let shownBannerID) = successBanner else {
            Issue.record("Expected shown banner")
            return
        }
        bannerID = shownBannerID
        #expect(router.currentBannerID == bannerID)

        router.dismissBanner(id: bannerID)
        let centerToast = router.show(.low(message: "已复制邀请码"), placement: .centerToast)

        guard case .shown(let toastID) = centerToast else {
            Issue.record("Expected shown center toast")
            return
        }
        #expect(router.centerToasts.first == toastID)
        #expect(router.topToasts.isEmpty)
    }

    @Test("展示态带意图的 feedback 只在首次展示时触发一次震动")
    func presentationHapticsFireOnceForPresentation() {
        var triggered: [AppHapticIntent] = []
        let haptics = AppFeedbackPresentationHaptics { intent in
            triggered.append(intent)
        }
        let presentationID = UUID()

        haptics.notePresented(id: presentationID, intent: .error)
        haptics.notePresented(id: presentationID, intent: .error)

        #expect(triggered == [.error])
    }

    @Test("展示态无意图的 feedback 不触发震动")
    func presentationHapticsDoNotFireWhenIntentAbsent() {
        var triggered: [AppHapticIntent] = []
        let haptics = AppFeedbackPresentationHaptics { intent in
            triggered.append(intent)
        }

        haptics.notePresented(id: UUID(), intent: nil)

        #expect(triggered.isEmpty)
    }

    @Test("被 router 丢弃或抑制的 feedback 不触发展示震动")
    func droppedOrSuppressedFeedbackNeverReachPresentationHaptics() throws {
        let router = AppFeedbackRouter(duplicateWindow: 5)

        router.show(.network(message: "保存成功"))
        router.show(.low(message: "已复制邀请码"))
        router.show(.auth(message: "重复消息"))
        let firstBannerID = try #require(router.currentBannerID)
        router.dismissBanner(id: firstBannerID)
        router.show(.auth(message: "重复消息"))

        #expect(router.topToasts.isEmpty)
        #expect(router.currentBannerID == nil)
    }

    @Test("兼容工厂方法仍然构建 payload 语义")
    func compatibilityFactoriesBuildPayloadSemantics() {
        let low = AppFeedback.low(message: "已复制邀请码")
        let high = AppFeedback.high(message: "保存成功")

        #expect(low.payload.severity == .info)
        #expect(low.payload.persistence == .autoDismiss)
        #expect(high.payload.severity == .success)
        #expect(high.payload.persistence == .autoDismiss)
    }
}
