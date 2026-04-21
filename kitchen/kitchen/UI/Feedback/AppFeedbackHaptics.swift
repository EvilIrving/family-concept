import SwiftUI

/// 触觉反馈管理器
@MainActor
final class AppFeedbackPresentationHaptics {
    private var firedPresentationIDs: Set<UUID> = []
    private let perform: @MainActor (AppFeedbackLevel) -> Void

    init(perform: @MainActor @escaping (AppFeedbackLevel) -> Void = AppFeedbackPresentationHaptics.performDefaultHaptic) {
        self.perform = perform
    }

    internal func notePresentedToast(_ toast: AppToastData) {
        notePresented(id: toast.id, level: toast.feedbackLevel)
    }

    internal func notePresentedBanner(_ banner: TopBannerData) {
        notePresented(id: banner.id, level: .high)
    }

    func notePresented(id: UUID, level: AppFeedbackLevel) {
        guard firedPresentationIDs.contains(id) == false else { return }
        firedPresentationIDs.insert(id)
        guard level == .high else { return }
        perform(level)
    }

    private static func performDefaultHaptic(for level: AppFeedbackLevel) {
        switch level {
        case .high:
            HapticManager.shared.triggerMediumImpact()
        case .low, .neutral:
            break
        }
    }
}
