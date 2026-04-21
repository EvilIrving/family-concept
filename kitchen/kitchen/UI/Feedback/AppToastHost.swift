import SwiftUI

/// Toast 和 Banner 的宿主 ViewModifier
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
                                AppToastView(toast: toast)
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
                                AppToastView(toast: toast)
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
                        AppBannerView(banner: banner)
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
}
