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
}

/// 持久化保存当前 App 语言；首次启动默认 English，不跟随系统语言
@MainActor
final class AppLanguageStore: ObservableObject {
    static let storageKey = "appLanguageCode"

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.language = stored.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    var locale: Locale {
        Locale(identifier: language.rawValue)
    }
}
