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

    fileprivate func toast(for id: UUID) -> AppToastData? {
        toastStore[id]
    }

    fileprivate func currentBanner() -> TopBannerData? {
        guard let currentBannerID else { return nil }
        return bannerStore[currentBannerID]
    }

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
            feedbackLevel: tokens.hapticLevel,
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

private struct FeedbackPresentationTokens {
    let iconSystemName: String?
    let foregroundColor: Color
    let toastBackgroundColor: Color
    let bannerBackgroundColor: Color
    let hapticLevel: AppFeedbackLevel

    init(feedback: AppFeedback) {
        iconSystemName = feedback.systemImage
        hapticLevel = feedback.severity.presentationLevel

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

private struct AppToastData: Identifiable {
    enum Placement {
        case top
        case center
    }

    let id = UUID()
    var text: String
    var duration: Duration = .seconds(2.2)
    var placement: Placement = .top
    var showsIcon: Bool = false
    var iconSystemName: String? = nil
    var feedbackLevel: AppFeedbackLevel = .low
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = Color.black.opacity(0.82)
}

private struct TopBannerData: Identifiable {
    let id = UUID()
    var text: String
    var autoDismissDuration: Duration? = .seconds(2.2)
    var showsIcon: Bool = false
    var iconSystemName: String? = nil
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = AppSemanticColor.infoForeground
}

@MainActor
final class AppFeedbackPresentationHaptics {
    private var firedPresentationIDs: Set<UUID> = []
    private let perform: @MainActor (AppFeedbackLevel) -> Void

    init(perform: @MainActor @escaping (AppFeedbackLevel) -> Void = AppFeedbackPresentationHaptics.performDefaultHaptic) {
        self.perform = perform
    }

    fileprivate func notePresentedToast(_ toast: AppToastData) {
        notePresented(id: toast.id, level: toast.feedbackLevel)
    }

    fileprivate func notePresentedBanner(_ banner: TopBannerData) {
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

struct AppToastHost: ViewModifier {
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @State private var presentationHaptics = AppFeedbackPresentationHaptics()

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top + AppSpacing.xl
            let bottomInset = proxy.safeAreaInsets.bottom + AppSpacing.lg

            content
                .overlay(alignment: .top) {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(feedbackRouter.topToasts, id: \.self) { id in
                            if let toast = feedbackRouter.toast(for: id) {
                                toastView(for: toast)
                                    .frame(maxWidth: .infinity)
                                    .onAppear {
                                        presentationHaptics.notePresentedToast(toast)
                                    }
                                    .task(id: toast.id) {
                                        try? await Task.sleep(for: toast.duration)
                                        await MainActor.run {
                                            feedbackRouter.dismissToast(id: toast.id)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.top, topInset)
                    .padding(.horizontal, AppSpacing.md)
                    .allowsHitTesting(false)
                }
                .overlay {
                    ZStack {
                        ForEach(feedbackRouter.centerToasts, id: \.self) { id in
                            if let toast = feedbackRouter.toast(for: id) {
                                toastView(for: toast)
                                    .frame(maxWidth: .infinity)
                                    .onAppear {
                                        presentationHaptics.notePresentedToast(toast)
                                    }
                                    .task(id: toast.id) {
                                        try? await Task.sleep(for: toast.duration)
                                        await MainActor.run {
                                            feedbackRouter.dismissToast(id: toast.id)
                                        }
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, topInset)
                    .padding(.bottom, bottomInset)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .top) {
                    if let banner = feedbackRouter.currentBanner() {
                        topBannerView(for: banner)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, topInset)
                            .onAppear {
                                presentationHaptics.notePresentedBanner(banner)
                            }
                            .task(id: banner.id) {
                                guard let autoDismissDuration = banner.autoDismissDuration else { return }
                                try? await Task.sleep(for: autoDismissDuration)
                                await MainActor.run {
                                    feedbackRouter.dismissBanner(id: banner.id)
                                }
                            }
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: feedbackRouter.topToasts)
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: feedbackRouter.centerToasts)
                .animation(.easeInOut(duration: 0.24), value: feedbackRouter.currentBannerID)
        }
    }

    private func toastView(for toast: AppToastData) -> some View {
        HStack(spacing: AppSpacing.sm) {
            if toast.showsIcon {
                Image(systemName: toast.iconSystemName ?? "info.circle.fill")
                    .foregroundStyle(toast.foregroundColor)
            }

            Text(toast.text)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(toast.foregroundColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .frame(maxWidth: 280)
        .background(toast.backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .transition(
            .asymmetric(
                insertion: .move(edge: toast.placement == .top ? .top : .bottom).combined(with: .opacity),
                removal: .scale(scale: 0.92).combined(with: .opacity)
            )
        )
        .shadow(color: AppSemanticColor.shadowSubtle, radius: 16, y: 8)
    }

    private func topBannerView(for banner: TopBannerData) -> some View {
        HStack(spacing: AppSpacing.sm) {
            if banner.showsIcon {
                Image(systemName: banner.iconSystemName ?? "info.circle.fill")
                    .foregroundStyle(banner.foregroundColor)
            }

            Text(banner.text)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(banner.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(banner.backgroundColor, in: Capsule())
        .transition(.move(edge: .top).combined(with: .opacity))
        .shadow(color: AppSemanticColor.shadowSubtle, radius: 16, y: 8)
    }
}

extension View {
    func appToastHost() -> some View {
        modifier(AppToastHost())
    }
}
