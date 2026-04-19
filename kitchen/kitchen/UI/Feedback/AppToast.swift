import Combine
import SwiftUI

struct AppToastData: Identifiable {
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

struct BottomBannerData: Identifiable {
    let id = UUID()
    var text: String
    var duration: Duration = .seconds(2.2)
    var showsIcon: Bool = false
    var iconSystemName: String? = nil
    var foregroundColor: Color = AppSemanticColor.onPrimary
    var backgroundColor: Color = AppSemanticColor.infoForeground
}

@MainActor
final class ToastQueue: ObservableObject {
    static let shared = ToastQueue()

    @Published private(set) var topToasts: [AppToastData] = []
    @Published private(set) var centerToasts: [AppToastData] = []

    private let maxTopToastCount = 2
    private let maxCenterToastCount = 5

    private let maxQueuedTopToastCount = 2
    private var queuedTopToasts: [AppToastData] = []

    private init() {}

    func showToast(_ toast: AppToastData) {
        enqueueToast(toast)
    }

    func showToast(
        text: String,
        duration: Duration = .seconds(2.2),
        placement: AppToastData.Placement = .top,
        showsIcon: Bool = false,
        iconSystemName: String? = nil,
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        showToast(
            AppToastData(
                text: text,
                duration: duration,
                placement: placement,
                showsIcon: showsIcon,
                iconSystemName: iconSystemName,
                foregroundColor: foregroundColor ?? AppSemanticColor.onPrimary,
                backgroundColor: backgroundColor ?? Color.black.opacity(0.82)
            )
        )
    }

    func dismissToast(id: UUID) {
        let removedTop = removeToast(with: id, from: &topToasts)
        let removedCenter = removeToast(with: id, from: &centerToasts)
        guard removedTop || removedCenter else { return }
        pumpTopToasts()
    }

    private func enqueueToast(_ toast: AppToastData) {
        switch toast.placement {
        case .top:
            resolveTopToast(toast)
        case .center:
            resolveCenterToast(toast)
        }
    }

    private func pumpTopToasts() {
        while topToasts.count < maxTopToastCount, !queuedTopToasts.isEmpty {
            let nextToast = queuedTopToasts.removeFirst()
            withAnimation(toastAnimation) {
                topToasts.insert(nextToast, at: 0)
            }
        }
    }

    private func resolveTopToast(_ incoming: AppToastData) {
        withAnimation(toastAnimation) {
            topToasts.insert(incoming, at: 0)
            if topToasts.count > maxTopToastCount, let displaced = topToasts.popLast() {
                queuedTopToasts.insert(displaced, at: 0)
                if queuedTopToasts.count > maxQueuedTopToastCount {
                    queuedTopToasts.removeLast()
                }
            }
        }
    }

    private func resolveCenterToast(_ incoming: AppToastData) {
        withAnimation(toastAnimation) {
            centerToasts.insert(incoming, at: 0)
            if centerToasts.count > maxCenterToastCount {
                centerToasts.removeLast()
            }
        }
    }

    private func removeToast(with id: UUID, from toasts: inout [AppToastData]) -> Bool {
        let initialCount = toasts.count
        withAnimation(toastAnimation) {
            toasts.removeAll { $0.id == id }
        }
        return toasts.count != initialCount
    }

    private var toastAnimation: Animation {
        .spring(response: 0.34, dampingFraction: 0.84)
    }
}

@MainActor
final class BBQueue: ObservableObject {
    static let shared = BBQueue()

    @Published private(set) var currentBanner: BottomBannerData?

    private var queuedBanners: [BottomBannerData] = []

    private init() {}

    func showBottomBanner(_ banner: BottomBannerData) {
        if currentBanner == nil {
            withAnimation(bottomBannerAnimation) {
                currentBanner = banner
            }
            return
        }

        queuedBanners.append(banner)
    }

    func showBottomBanner(
        text: String,
        duration: Duration = .seconds(2.2),
        showsIcon: Bool = false,
        iconSystemName: String? = nil,
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        showBottomBanner(
            BottomBannerData(
                text: text,
                duration: duration,
                showsIcon: showsIcon,
                iconSystemName: iconSystemName,
                foregroundColor: foregroundColor ?? AppSemanticColor.onPrimary,
                backgroundColor: backgroundColor ?? AppSemanticColor.infoForeground
            )
        )
    }

    func dismissBottomBanner(id: UUID? = nil) {
        guard id == nil || currentBanner?.id == id else { return }
        withAnimation(bottomBannerAnimation) {
            currentBanner = nil
        }
        pumpQueue()
    }

    private func pumpQueue() {
        guard currentBanner == nil, let nextBanner = queuedBanners.first else { return }
        queuedBanners.removeFirst()
        withAnimation(bottomBannerAnimation) {
            currentBanner = nextBanner
        }
    }

    private var bottomBannerAnimation: Animation {
        .easeInOut(duration: 0.24)
    }
}

struct AppToastHost: ViewModifier {
    @EnvironmentObject private var toastQueue: ToastQueue
    @EnvironmentObject private var bbQueue: BBQueue

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top + AppSpacing.xl
            let bottomInset = proxy.safeAreaInsets.bottom + AppSpacing.lg

            content
                .overlay(alignment: .top) {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(toastQueue.topToasts) { toast in
                            toastView(for: toast)
                                .frame(maxWidth: .infinity)
                                .task(id: toast.id) {
                                    try? await Task.sleep(for: toast.duration)
                                    await MainActor.run {
                                        toastQueue.dismissToast(id: toast.id)
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
                        ForEach(Array(toastQueue.centerToasts.enumerated()), id: \.element.id) { index, toast in
                            toastView(for: toast)
                                .frame(maxWidth: .infinity)
                                .offset(y: CGFloat(index) * -68)
                                .zIndex(Double(toastQueue.centerToasts.count - index))
                                .task(id: toast.id) {
                                    try? await Task.sleep(for: toast.duration)
                                    await MainActor.run {
                                        toastQueue.dismissToast(id: toast.id)
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
                    if let banner = bbQueue.currentBanner {
                        bottomBannerView(for: banner)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.bottom, bottomInset)
                            .task(id: banner.id) {
                                try? await Task.sleep(for: banner.duration)
                                await MainActor.run {
                                    bbQueue.dismissBottomBanner(id: banner.id)
                                }
                            }
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: toastQueue.topToasts.map(\.id))
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: toastQueue.centerToasts.map(\.id))
                .animation(.easeInOut(duration: 0.24), value: bbQueue.currentBanner?.id)
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
