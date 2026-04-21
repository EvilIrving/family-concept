import Foundation

/// Settings 页面路由枚举
enum SettingsModalRoute: Identifiable, Equatable {
    case member(MemberSheetToken)

    var id: String {
        switch self {
        case .member(let token):
            return token.id
        }
    }

    var token: MemberSheetToken {
        switch self {
        case .member(let token):
            return token
        }
    }
}

/// 成员 Sheet 标识
struct MemberSheetToken: Identifiable, Equatable {
    let accountID: String
    var id: String { accountID }
}
