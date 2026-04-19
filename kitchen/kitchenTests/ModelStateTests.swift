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
        #expect(DishDraftImageState.empty.statusSubtitle == "拍一张正面的菜品照，系统会自动去背景")
        #expect(DishDraftImageState.extracting(sampleImage).statusTitle == "正在识别主体")
        #expect(DishDraftImageState.processing.statusTitle == "正在优化菜品图")
        #expect(DishDraftImageState.ready(previewImage: sampleImage, fileURL: fileURL).statusTitle == "图片已就绪")
        #expect(DishDraftImageState.uploading.statusTitle == "正在上传")
        #expect(DishDraftImageState.uploadFailed(previewImage: sampleImage, fileURL: fileURL, message: "上传超时").statusSubtitle == "上传超时")
        #expect(DishDraftImageState.failed("处理异常").statusSubtitle == "处理异常")
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
}
