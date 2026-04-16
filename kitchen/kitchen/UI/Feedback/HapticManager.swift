import UIKit

enum HapticEvent {
    case newDishAdded
    case dishCompleted
    case statusChanged
    case error
}

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let defaults: UserDefaults
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prepareAll()
    }

    func trigger(_ event: HapticEvent) {
        guard defaults.object(forKey: "hapticsEnabled") as? Bool ?? true else { return }

        switch event {
        case .newDishAdded:
            heavyImpact.impactOccurred(intensity: 1.0)
            heavyImpact.prepare()
        case .dishCompleted:
            notification.notificationOccurred(.success)
            notification.prepare()
        case .statusChanged:
            mediumImpact.impactOccurred(intensity: 0.85)
            mediumImpact.prepare()
        case .error:
            notification.notificationOccurred(.error)
            notification.prepare()
        }
    }

    private func prepareAll() {
        heavyImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }
}
