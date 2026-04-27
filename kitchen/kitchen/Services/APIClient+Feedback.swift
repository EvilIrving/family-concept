import Foundation

extension APIClient {
    func submitFeedback(
        message: String,
        contactPlatform: FeedbackContactPlatform,
        contactHandle: String,
        authToken: String
    ) async throws -> OKResult {
        try await request(
            APIEndpoints.Feedback.submit(
                message: message,
                contactPlatform: contactPlatform,
                contactHandle: contactHandle
            ),
            authToken: authToken
        )
    }
}
