import Foundation

extension APIEndpoints {
    enum Feedback {
        static func submit(
            message: String,
            contactPlatform: FeedbackContactPlatform,
            contactHandle: String
        ) -> Endpoint<OKResult> {
            Endpoint(
                path: "/api/v1/feedback",
                method: "POST",
                body: SubmitFeedbackBody(
                    message: message,
                    contactPlatform: contactPlatform.rawValue,
                    contactHandle: contactHandle
                ),
                requiresAuth: true
            )
        }
    }
}

enum FeedbackContactPlatform: String, CaseIterable, Identifiable {
    case tg
    case whatsapp
    case ins
    case x

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tg:
            return "TG"
        case .whatsapp:
            return "WhatsApp"
        case .ins:
            return "Ins"
        case .x:
            return "X"
        }
    }
}

struct SubmitFeedbackBody: Encodable {
    let message: String
    let contactPlatform: String
    let contactHandle: String

    enum CodingKeys: String, CodingKey {
        case message
        case contactPlatform = "contact_platform"
        case contactHandle = "contact_handle"
    }
}
