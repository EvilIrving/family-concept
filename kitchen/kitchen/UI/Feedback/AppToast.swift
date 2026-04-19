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
    private var bannerStore: [UUID: BottomBannerData] = [:]
    private var lastMessage = ""
    private var lastMessageDate = Date.distantPast
    private let duplicateWindow: TimeInterval

    init(duplicateWindow: TimeInterval = 1.5) {
        self.duplicateWindow = duplicateWindow
    }

    var isBannerActive: Bool {
        currentBannerID != nil
    }

    func show(_ feedback: AppFeedback, hint: AppFeedbackHint? = nil) {
        guard shouldAccept(feedback) else { return }

        switch feedback.level {
        case .high:
            showBanner(feedback)
        case .low, .neutral:
            guard isBannerActive == false else { return }
            showToast(feedback, hint: hint)
        }
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
        }
        withAnimation(bannerAnimation) {
            currentBannerID = nil
        }
    }

    fileprivate func toast(for id: UUID) -> AppToastData? {
        toastStore[id]
    }

    fileprivate func currentBanner() -> BottomBannerData? {
        guard let currentBannerID else { return nil }
        return bannerStore[currentBannerID]
    }

    private func shouldAccept(_ feedback: AppFeedback) -> Bool {
        let message = feedback.messageText
        guard message.isEmpty == false else { return true }

        let now = Date()
        if message == lastMessage, now.timeIntervalSince(lastMessageDate) < duplicateWindow {
            return false
        }

        lastMessage = message
        lastMessageDate = now
        return true
    }

    private func showToast(_ feedback: AppFeedback, hint: AppFeedbackHint?) {
        let toast = AppToastData(
            text: feedback.messageText,
            duration: .seconds(2.2),
            placement: hint == .centerToast ? .center : .top,
            showsIcon: feedback.systemImage != nil,
            iconSystemName: feedback.systemImage,
            foregroundColor: feedback.level == .high ? AppSemanticColor.danger : AppSemanticColor.onPrimary,
            backgroundColor: feedback.level == .high ? AppSemanticColor.dangerBackground : Color.black.opacity(0.82)
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
        let banner = BottomBannerData(
            text: feedback.messageText,
            duration: .seconds(2.2),
            showsIcon: feedback.systemImage != nil,
            iconSystemName: feedback.systemImage,
            foregroundColor: AppSemanticColor.onPrimary,
            backgroundColor: AppSemanticColor.infoForeground
        )

        bannerStore[banner.id] = banner
        withAnimation(bannerAnimation) {
            currentBannerID = banner.id
        }
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
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = Color.black.opacity(0.82)
}

private struct BottomBannerData: Identifiable {
    let id = UUID()
    var text: String
    var duration: Duration = .seconds(2.2)
    var showsIcon: Bool = false
    var iconSystemName: String? = nil
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = AppSemanticColor.infoForeground
}

struct AppToastHost: ViewModifier {
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter

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
                .overlay(alignment: .bottom) {
                    if let banner = feedbackRouter.currentBanner() {
                        bottomBannerView(for: banner)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, bottomInset)
                            .task(id: banner.id) {
                                try? await Task.sleep(for: banner.duration)
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

    private func bottomBannerView(for banner: BottomBannerData) -> some View {
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .shadow(color: AppSemanticColor.shadowSubtle, radius: 16, y: 8)
    }
}

extension View {
    func appToastHost() -> some View {
        modifier(AppToastHost())
    }
}
