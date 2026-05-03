import SwiftUI
import Combine

/// 支持的 App 内界面语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    /// Picker 选项展示名称（始终用该语言自身的名字，避免随当前语言切换显示混乱）
    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    static func resolved(storedLanguageCode: String? = UserDefaults.standard.string(forKey: AppLanguageStore.storageKey)) -> AppLanguage {
        if let storedLanguageCode, let storedLanguage = AppLanguage(rawValue: storedLanguageCode) {
            return storedLanguage
        }

        return Locale.preferredLanguages.compactMap { preferredLanguage in
            AppLanguage.matching(preferredLanguage)
        }.first ?? .english
    }

    private static func matching(_ languageIdentifier: String) -> AppLanguage? {
        let locale = Locale(identifier: languageIdentifier)
        let languageCode = locale.language.languageCode?.identifier
        let scriptCode = locale.language.script?.identifier

        switch languageCode {
        case "en":
            return .english
        case "ja":
            return .japanese
        case "ko":
            return .korean
        case "zh":
            return scriptCode == "Hant" ? .traditionalChinese : .simplifiedChinese
        default:
            return nil
        }
    }
}

/// 持久化保存用户自定义 App 语言；未设置时跟随支持的系统语言，否则回退 English。
@MainActor
final class AppLanguageStore: ObservableObject {
    nonisolated static let storageKey = "appLanguageCode"

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        self.language = AppLanguage.resolved()
    }

    var locale: Locale {
        Locale(identifier: language.rawValue)
    }
}
