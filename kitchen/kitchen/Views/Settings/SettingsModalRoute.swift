import Foundation

/// Settings 页面路由枚举
enum SettingsModalRoute: Identifiable, Equatable {
    case member(MemberSheetToken)
    case upgrade

    var id: String {
        switch self {
        case .member(let token):
            return token.id
        case .upgrade:
            return "upgrade"
        }
    }

    var token: MemberSheetToken? {
        switch self {
        case .member(let token):
            return token
        case .upgrade:
            return nil
        }
    }
}

/// 成员 Sheet 标识
struct MemberSheetToken: Identifiable, Equatable {
    let accountID: String
    var id: String { accountID }
}
