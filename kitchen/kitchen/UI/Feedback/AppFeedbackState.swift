import SwiftUI

enum AppFeedbackSeverity: Int, Equatable {
    case info
    case success
    case warning
    case error

    var defaultPlacement: AppFeedbackPlacement {
        .centerToast
    }

    var defaultHaptic: AppHapticIntent? {
        switch self {
        case .info:
            return nil
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

enum AppFeedbackPlacement: Equatable {
    case topBanner
    case topToast
    case centerToast
}

enum AppFeedbackPersistence: Equatable {
    case autoDismiss
    case persistent
}

struct AppFeedbackPayload: Equatable {
    let title: String?
    let message: String?
    let icon: String?
    let actionLabel: String?
    let severity: AppFeedbackSeverity
    let persistence: AppFeedbackPersistence
    let placement: AppFeedbackPlacement?

    init(
        title: String? = nil,
        message: String? = nil,
        icon: String? = nil,
        actionLabel: String? = nil,
        severity: AppFeedbackSeverity = .info,
        persistence: AppFeedbackPersistence = .autoDismiss,
        placement: AppFeedbackPlacement? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionLabel = actionLabel
        self.severity = severity
        self.placement = placement
        let resolvedPlacement = placement ?? severity.defaultPlacement
        self.persistence = resolvedPlacement == .topBanner ? persistence : .autoDismiss
    }
}

enum AppFeedbackKind: Equatable {
    case empty(AppEmptyKind)
    case network
    case auth
    case generic
}

enum AppEmptyKind: Equatable {
    case noData
    case noSearchResult
    case noPermission
    case missingResource
}

struct AppFeedback: Equatable {
    let kind: AppFeedbackKind
    let payload: AppFeedbackPayload
    /// 明确的触觉意图。`nil` 时走 severity 的默认映射；`.some(nil)` 语义不存在——如需"显式不震动"，使用 `silenced`。
    private let explicitHaptic: AppHapticIntent?
    private let hapticIsExplicit: Bool

    init(
        kind: AppFeedbackKind,
        payload: AppFeedbackPayload,
        haptic: AppHapticIntent? = nil,
        hapticExplicit: Bool = false
    ) {
        self.kind = kind
        self.payload = payload
        self.explicitHaptic = haptic
        self.hapticIsExplicit = hapticExplicit
    }

    var haptic: AppHapticIntent? {
        hapticIsExplicit ? explicitHaptic : payload.severity.defaultHaptic
    }

    /// 覆盖触觉意图（包括显式静音）。
    func withHaptic(_ intent: AppHapticIntent?) -> AppFeedback {
        AppFeedback(kind: kind, payload: payload, haptic: intent, hapticExplicit: true)
    }

    static func empty(
        kind: AppEmptyKind = .noData,
        title: String? = nil,
        message: String? = nil,
        systemImage: String? = nil
    ) -> AppFeedback {
        AppFeedback(
            kind: .empty(kind),
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                severity: .info
            )
        )
    }

    static func network(
        title: String = L10n.tr("Network issue"),
        message: String? = L10n.tr("Check your connection and retry"),
        systemImage: String = "wifi.exclamationmark"
    ) -> AppFeedback {
        AppFeedback(
            kind: .network,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                severity: .error,
                persistence: .persistent,
                placement: .topBanner
            )
        )
    }

    static func auth(
        title: String = L10n.tr("Sign-in expired"),
        message: String? = L10n.tr("Please sign in again to continue"),
        systemImage: String = "lock.slash"
    ) -> AppFeedback {
        AppFeedback(
            kind: .auth,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                severity: .error,
                persistence: .persistent,
                placement: .topBanner
            )
        )
    }

    static func generic(
        title: String = L10n.tr("Load failed"),
        message: String? = L10n.tr("Try again later"),
        systemImage: String = "exclamationmark.triangle"
    ) -> AppFeedback {
        AppFeedback(
            kind: .generic,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                severity: .error
            )
        )
    }

    static func low(
        title: String? = nil,
        message: String? = nil,
        systemImage: String? = nil,
        actionLabel: String? = nil,
        haptic: AppHapticIntent? = nil
    ) -> AppFeedback {
        AppFeedback(
            kind: .generic,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                actionLabel: actionLabel,
                severity: .info
            ),
            haptic: haptic,
            hapticExplicit: haptic != nil
        )
    }

    static func high(
        title: String? = nil,
        message: String? = nil,
        systemImage: String? = nil,
        actionLabel: String? = nil,
        haptic: AppHapticIntent? = nil
    ) -> AppFeedback {
        AppFeedback(
            kind: .generic,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                actionLabel: actionLabel,
                severity: .success
            ),
            haptic: haptic,
            hapticExplicit: haptic != nil
        )
    }

    var emptyKind: AppEmptyKind? {
        if case .empty(let kind) = kind {
            return kind
        }
        return nil
    }

    var title: String? {
        payload.title
    }

    var message: String? {
        payload.message
    }

    var systemImage: String? {
        payload.icon
    }

    var severity: AppFeedbackSeverity {
        payload.severity
    }

    var persistence: AppFeedbackPersistence {
        payload.persistence
    }
}

enum LoadingMode: Equatable {
    case initial
    case refresh
    case progress
}

struct LoadingContext<Value> {
    let mode: LoadingMode
    let label: String?
    let progress: Double?
    let retainedValue: Value?

    init(
        mode: LoadingMode,
        label: String? = nil,
        progress: Double? = nil,
        retainedValue: Value? = nil
    ) {
        self.mode = mode
        self.label = label
        self.progress = progress
        self.retainedValue = retainedValue
    }

    var hasRetainedValue: Bool {
        retainedValue != nil
    }
}

enum LoadingPhase<Value> {
    case idle
    case loading(LoadingContext<Value>)
    case success(Value)
    case failure(AppFeedback, retainedValue: Value?)

    static func initialLoading(label: String? = nil) -> LoadingPhase<Value> {
        .loading(LoadingContext(mode: .initial, label: label))
    }

    static func refreshing(_ retainedValue: Value, label: String? = nil) -> LoadingPhase<Value> {
        .loading(LoadingContext(mode: .refresh, label: label, retainedValue: retainedValue))
    }

    static func progress(
        _ progress: Double,
        label: String? = nil,
        retainedValue: Value? = nil
    ) -> LoadingPhase<Value> {
        .loading(LoadingContext(mode: .progress, label: label, progress: progress, retainedValue: retainedValue))
    }

    var retainedValue: Value? {
        switch self {
        case .idle:
            return nil
        case .loading(let context):
            return context.retainedValue
        case .success(let value):
            return value
        case .failure(_, let retainedValue):
            return retainedValue
        }
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var feedback: AppFeedback? {
        if case .failure(let feedback, _) = self {
            return feedback
        }
        return nil
    }
}

extension LoadingPhase where Value == Void {
    static func loading(label: String? = nil) -> LoadingPhase<Void> {
        .loading(LoadingContext(mode: .initial, label: label))
    }

    static func succeeded() -> LoadingPhase<Void> {
        .success(())
    }
}

extension LoadingContext: Equatable where Value: Equatable {}

extension LoadingPhase: Equatable where Value: Equatable {}
