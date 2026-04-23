import Combine
import SwiftUI

enum AppFeedbackHint {
    case centerToast
}

@MainActor
final class AppFeedbackRouter: ObservableObject {
    static let shared = AppFeedbackRouter()

    @Published private(set) var topToasts: [UUID] = []
    @Published private(set) var centerToasts: [UUID] = []
    @Published private(set) var currentBannerID: UUID?

    private var toastStore: [UUID: AppToastData] = [:]
    private var bannerStore: [UUID: TopBannerData] = [:]
    private var bannerSeverityStore: [UUID: AppFeedbackSeverity] = [:]
    private var lastFingerprint = ""
    private var lastFingerprintDate = Date.distantPast
    private let duplicateWindow: TimeInterval

    init(duplicateWindow: TimeInterval = 1.5) {
        self.duplicateWindow = duplicateWindow
    }

    var isBannerActive: Bool {
        currentBannerID != nil
    }

    var currentBannerAutoDismissDuration: Duration? {
        guard let currentBannerID else { return nil }
        return bannerStore[currentBannerID]?.autoDismissDuration
    }

    func show(_ feedback: AppFeedback, hint: AppFeedbackHint? = nil) {
        guard shouldAccept(feedback) else { return }

        if feedback.severity.prefersBanner {
            showBanner(feedback)
            return
        }

        guard isBannerActive == false else { return }
        showToast(feedback, hint: hint)
    }

    func dismissToast(id: UUID) {
        toastStore[id] = nil
        topToasts.removeAll { $0 == id }
        centerToasts.removeAll { $0 == id }
    }

    func dismissBanner(id: UUID? = nil) {
        guard id == nil || currentBannerID == id else { return }
        if let currentBannerID {
            bannerStore[currentBannerID] = nil
            bannerSeverityStore[currentBannerID] = nil
        }
        withAnimation(bannerAnimation) {
            currentBannerID = nil
        }
    }

    internal func toast(for id: UUID) -> AppToastData? {
        toastStore[id]
    }

    internal func currentBanner() -> TopBannerData? {
        guard let currentBannerID else { return nil }
        return bannerStore[currentBannerID]
    }

    // MARK: - Private Helpers

    private func shouldAccept(_ feedback: AppFeedback) -> Bool {
        let fingerprint = feedback.semanticFingerprint
        guard fingerprint.isEmpty == false else { return true }

        let now = Date()
        if fingerprint == lastFingerprint, now.timeIntervalSince(lastFingerprintDate) < duplicateWindow {
            return false
        }

        lastFingerprint = fingerprint
        lastFingerprintDate = now
        return true
    }

    private func showToast(_ feedback: AppFeedback, hint: AppFeedbackHint?) {
        let tokens = FeedbackPresentationTokens(feedback: feedback)
        let toast = AppToastData(
            text: feedback.messageText,
            duration: .seconds(2.2),
            placement: hint == .centerToast ? .center : .top,
            showsIcon: tokens.iconSystemName != nil,
            iconSystemName: tokens.iconSystemName,
            haptic: feedback.haptic,
            foregroundColor: tokens.foregroundColor,
            backgroundColor: tokens.toastBackgroundColor
        )

        toastStore[toast.id] = toast
        withAnimation(toastAnimation) {
            switch toast.placement {
            case .top:
                topToasts = [toast.id]
            case .center:
                centerToasts = [toast.id]
            }
        }
    }

    private func showBanner(_ feedback: AppFeedback) {
        guard shouldReplaceCurrentBanner(with: feedback.severity) else { return }
        let tokens = FeedbackPresentationTokens(feedback: feedback)
        let banner = TopBannerData(
            text: feedback.messageText,
            autoDismissDuration: feedback.persistence == .persistent ? nil : .seconds(2.2),
            showsIcon: tokens.iconSystemName != nil,
            iconSystemName: tokens.iconSystemName,
            haptic: feedback.haptic,
            foregroundColor: tokens.foregroundColor,
            backgroundColor: tokens.bannerBackgroundColor
        )

        bannerStore[banner.id] = banner
        bannerSeverityStore[banner.id] = feedback.severity
        withAnimation(bannerAnimation) {
            currentBannerID = banner.id
        }
    }

    private func shouldReplaceCurrentBanner(with severity: AppFeedbackSeverity) -> Bool {
        guard let currentBannerID else { return true }
        guard let currentSeverity = bannerSeverityStore[currentBannerID] else { return true }
        return severity.rawValue >= currentSeverity.rawValue
    }

    private var toastAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.84)
    }

    private var bannerAnimation: Animation {
        .easeInOut(duration: 0.24)
    }
}

// MARK: - AppFeedback Extension

private extension AppFeedback {
    var messageText: String {
        if let message, message.isEmpty == false {
            return message
        }
        return title ?? ""
    }

    var semanticFingerprint: String {
        [
            payload.severityKey,
            title ?? "",
            message ?? "",
            payload.actionIntentKey
        ].joined(separator: "|")
    }
}

private extension AppFeedbackPayload {
    var severityKey: String {
        switch severity {
        case .info:
            return "info"
        case .success:
            return "success"
        case .warning:
            return "warning"
        case .error:
            return "error"
        }
    }

    var actionIntentKey: String {
        actionLabel ?? ""
    }
}

// MARK: - FeedbackPresentationTokens

private struct FeedbackPresentationTokens {
    let iconSystemName: String?
    let foregroundColor: Color
    let toastBackgroundColor: Color
    let bannerBackgroundColor: Color

    init(feedback: AppFeedback) {
        iconSystemName = feedback.systemImage

        switch feedback.severity {
        case .info:
            foregroundColor = AppSemanticColor.onPrimary
            toastBackgroundColor = Color.black.opacity(0.82)
            bannerBackgroundColor = AppSemanticColor.infoForeground
        case .success:
            foregroundColor = AppSemanticColor.onPrimary
            toastBackgroundColor = AppSemanticColor.success
            bannerBackgroundColor = AppSemanticColor.success
        case .warning:
            foregroundColor = AppSemanticColor.onPrimary
            toastBackgroundColor = AppSemanticColor.dangerBackground
            bannerBackgroundColor = AppSemanticColor.dangerBackground
        case .error:
            foregroundColor = AppSemanticColor.onPrimary
            toastBackgroundColor = AppSemanticColor.dangerBackground
            bannerBackgroundColor = AppSemanticColor.infoForeground
        }
    }
}
