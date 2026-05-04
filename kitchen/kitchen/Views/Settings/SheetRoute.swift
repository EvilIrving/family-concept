import Foundation

enum SheetRoute: Identifiable, Equatable {
    case member(MemberSheetToken)
    case upgrade
    case feedback
    case history

    var id: String {
        switch self {
        case .member(let token):
            return token.id
        case .upgrade:
            return "upgrade"
        case .feedback:
            return "feedback"
        case .history:
            return "history"
        }
    }

    var token: MemberSheetToken? {
        switch self {
        case .member(let token):
            return token
        case .upgrade, .feedback, .history:
            return nil
        }
    }
}

struct MemberSheetToken: Identifiable, Equatable {
    let accountID: String
    var id: String { accountID }
}
