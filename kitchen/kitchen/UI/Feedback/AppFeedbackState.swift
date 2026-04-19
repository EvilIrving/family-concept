import SwiftUI

enum AppFeedbackLevel: Equatable {
    case low
    case neutral
    case high
}

struct AppFeedbackPayload: Equatable {
    let title: String?
    let message: String?
    let icon: String?
    let actionLabel: String?

    init(
        title: String? = nil,
        message: String? = nil,
        icon: String? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionLabel = actionLabel
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
    let level: AppFeedbackLevel
    let kind: AppFeedbackKind
    let payload: AppFeedbackPayload

    static func empty(
        kind: AppEmptyKind = .noData,
        title: String? = nil,
        message: String? = nil,
        systemImage: String? = nil
    ) -> AppFeedback {
        AppFeedback(
            level: .neutral,
            kind: .empty(kind),
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage
            )
        )
    }

    static func network(
        title: String = "网络连接异常",
        message: String? = "请检查网络后重试",
        systemImage: String = "wifi.exclamationmark"
    ) -> AppFeedback {
        AppFeedback(
            level: .high,
            kind: .network,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage
            )
        )
    }

    static func auth(
        title: String = "登录状态已失效",
        message: String? = "请重新登录后继续",
        systemImage: String = "lock.slash"
    ) -> AppFeedback {
        AppFeedback(
            level: .high,
            kind: .auth,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage
            )
        )
    }

    static func generic(
        title: String = "加载失败",
        message: String? = "请稍后重试",
        systemImage: String = "exclamationmark.triangle"
    ) -> AppFeedback {
        AppFeedback(
            level: .high,
            kind: .generic,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage
            )
        )
    }

    static func low(
        title: String? = nil,
        message: String? = nil,
        systemImage: String? = nil,
        actionLabel: String? = nil
    ) -> AppFeedback {
        AppFeedback(
            level: .low,
            kind: .generic,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                actionLabel: actionLabel
            )
        )
    }

    static func high(
        title: String? = nil,
        message: String? = nil,
        systemImage: String? = nil,
        actionLabel: String? = nil
    ) -> AppFeedback {
        AppFeedback(
            level: .high,
            kind: .generic,
            payload: AppFeedbackPayload(
                title: title,
                message: message,
                icon: systemImage,
                actionLabel: actionLabel
            )
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
