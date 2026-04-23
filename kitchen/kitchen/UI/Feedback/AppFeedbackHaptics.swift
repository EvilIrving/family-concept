import SwiftUI

/// 触觉反馈展示协调器。按 presentation id 去重，避免同一个 toast/banner 多次触发。
@MainActor
final class AppFeedbackPresentationHaptics {
    private var firedPresentationIDs: Set<UUID> = []
    private let perform: @MainActor (AppHapticIntent) -> Void

    init(perform: @MainActor @escaping (AppHapticIntent) -> Void = AppFeedbackPresentationHaptics.performDefaultHaptic) {
        self.perform = perform
    }

    internal func notePresentedToast(_ toast: AppToastData) {
        notePresented(id: toast.id, intent: toast.haptic)
    }

    internal func notePresentedBanner(_ banner: TopBannerData) {
        notePresented(id: banner.id, intent: banner.haptic)
    }

    func notePresented(id: UUID, intent: AppHapticIntent?) {
        guard firedPresentationIDs.contains(id) == false else { return }
        firedPresentationIDs.insert(id)
        guard let intent else { return }
        perform(intent)
    }

    private static func performDefaultHaptic(for intent: AppHapticIntent) {
        HapticManager.shared.fire(intent)
    }
}
