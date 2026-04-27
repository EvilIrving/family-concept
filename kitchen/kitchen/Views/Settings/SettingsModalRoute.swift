import Foundation

/// Settings 页面路由枚举
enum SettingsModalRoute: Identifiable, Equatable {
    case member(MemberSheetToken)
    case upgrade
    case feedback

    var id: String {
        switch self {
        case .member(let token):
            return token.id
        case .upgrade:
            return "upgrade"
        case .feedback:
            return "feedback"
        }
    }

    var token: MemberSheetToken? {
        switch self {
        case .member(let token):
            return token
        case .upgrade, .feedback:
            return nil
        }
    }
}

/// 成员 Sheet 标识
struct MemberSheetToken: Identifiable, Equatable {
    let accountID: String
    var id: String { accountID }
}
