import SwiftUI

/// 基础调色板：仅由 `AppSemanticColor` 引用，UI 代码禁止直接使用。
///
/// 设计逻辑（参考 Figma 教程六步法）：
/// 1. 灰度先行，先把页面骨架确定下来。
/// 2. 主色：家庭厨房协作 App，调性=新鲜/有秩序/可恢复 → 取叶绿 H≈140°、S≈45%。
/// 3. 反馈色：成功复用品牌绿，警告暖琥珀，错误偏暖珊瑚红，提示用低饱和雾蓝绿，整体调性统一。
/// 4. 主色调色板：在 H/S 不变的前提下，按 L 每档约 -8 ~ -12 生成 50→900 共十档。
/// 5. 灰度色板：以同一 H 为基底，S 在 8–20 之间随档位轻微浮动，让灰色带有“呼吸感”。
/// 6. 命名：统一数字档位（50 / 100 / 200 / … / 900），便于跨成员/同语义对齐。
///
/// Dark 模式：每个色板内做镜像反转（50↔900、100↔800、…、400↔500）。
/// 这样语义层无需感知 colorScheme，主按钮 (`green600`) 在暗色下自动取到合适亮度。
enum AppPalette {
    // MARK: - Brand / Leaf Green
    static let green50  = Color("green50")
    static let green100 = Color("green100")
    static let green200 = Color("green200")
    static let green300 = Color("green300")
    static let green400 = Color("green400")
    static let green500 = Color("green500") // 品牌基准
    static let green600 = Color("green600")
    static let green700 = Color("green700")
    static let green800 = Color("green800")
    static let green900 = Color("green900")

    // MARK: - Tinted Neutral
    static let gray50  = Color("gray50")
    static let gray100 = Color("gray100")
    static let gray200 = Color("gray200")
    static let gray300 = Color("gray300")
    static let gray400 = Color("gray400")
    static let gray500 = Color("gray500")
    static let gray600 = Color("gray600")
    static let gray700 = Color("gray700")
    static let gray800 = Color("gray800")
    static let gray900 = Color("gray900")

    // MARK: - Status (harmonized saturation)
    static let warning     = Color("warning")
    static let warningSoft = Color("warningSoft")
    static let danger      = Color("danger")
    static let dangerSoft  = Color("dangerSoft")
    static let info        = Color("info")
    static let infoSoft    = Color("infoSoft")

    // MARK: - Warm decorative accent（小面积装饰，不做大块铺底）
    static let cream   = Color("cream")
    static let apricot = Color("apricot")

    // MARK: - Surface
    /// 卡片/弹层表面：light 近白、dark 取略亮于背景的深墨绿，独立于灰阶以保证暗色下卡片可见。
    static let surface = Color("surface")

    // MARK: - Special
    /// 深墨色：light 取近黑墨绿、dark 取近白冷调；用于正文、相机控制等强对比场景。
    static let inkBlack = Color("inkBlack")
    /// 不随主题切换的纯白/纯黑，用于品牌按钮文字、相机底等不应反转的场景。
    static let pureWhite = Color.white
    static let pureBlack = Color.black
}
