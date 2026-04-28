import Foundation

/// 显式查找本地化字符串：当前语言 → 英语 → 返回 key
///
/// SwiftUI 的 `Text("...")`、`Button("...")` 等接收 `LocalizedStringKey` 的 API 会
/// 通过环境 `\.locale` 自动本地化，业务代码无需调用本工具。
///
/// 仅在以下场景使用 `L10n.tr`:
/// - 已解析为 `String` 的文案：变量、`Text(stringVar)`、Toast、alert message、
///   `accessibilityLabel(_ String)`、模型显示名、服务层兜底错误等
/// - 需要带参数插值的本地化文案
enum L10n {
    /// 当前 App 语言代码（由 `AppLanguageStore` 控制）。读取最新值，避免缓存。
    private static var currentLanguageCode: String {
        UserDefaults.standard.string(forKey: AppLanguageStore.storageKey) ?? "en"
    }

    /// 解析本地化字符串。回退顺序：当前语言 → en → key 原样返回
    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let resolved = lookup(key: key, language: currentLanguageCode)
            ?? lookup(key: key, language: "en")
            ?? key

        guard !args.isEmpty else { return resolved }
        return String(format: resolved, locale: Locale(identifier: currentLanguageCode), arguments: args)
    }

    private static func lookup(key: String, language: String) -> String? {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return fallbackFromMainBundle(key: key)
        }
        let value = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
        return value == "__MISSING__" ? nil : value
    }

    private static func fallbackFromMainBundle(key: String) -> String? {
        let value = Bundle.main.localizedString(forKey: key, value: "__MISSING__", table: nil)
        return value == "__MISSING__" ? nil : value
    }
}
