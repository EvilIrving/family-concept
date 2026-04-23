import UIKit

enum AppHapticIntent: Equatable {
    case light
    case medium
    case heavy
    case selection
    case success
    case warning
    case error
}

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let defaults: UserDefaults
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prepareAll()
    }

    func fire(_ intent: AppHapticIntent) {
        guard isEnabled else { return }
        switch intent {
        case .light:
            lightImpact.impactOccurred(intensity: 0.8)
            lightImpact.prepare()
        case .medium:
            mediumImpact.impactOccurred(intensity: 0.85)
            mediumImpact.prepare()
        case .heavy:
            heavyImpact.impactOccurred()
            heavyImpact.prepare()
        case .selection:
            selection.selectionChanged()
            selection.prepare()
        case .success:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .warning:
            notification.notificationOccurred(.warning)
            notification.prepare()
        case .error:
            notification.notificationOccurred(.error)
            notification.prepare()
        }
    }

    func triggerLightImpact() { fire(.light) }
    func triggerMediumImpact() { fire(.medium) }
    func triggerErrorNotification() { fire(.error) }

    private var isEnabled: Bool {
        defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
        notification.prepare()
    }
}
