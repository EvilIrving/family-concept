import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let defaults: UserDefaults
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prepareAll()
    }

    func triggerLightImpact() {
        guard defaults.object(forKey: "hapticsEnabled") as? Bool ?? true else { return }
        lightImpact.impactOccurred(intensity: 0.8)
        lightImpact.prepare()
    }

    func triggerMediumImpact() {
        guard defaults.object(forKey: "hapticsEnabled") as? Bool ?? true else { return }
        mediumImpact.impactOccurred(intensity: 0.85)
        mediumImpact.prepare()
    }

    func triggerErrorNotification() {
        guard defaults.object(forKey: "hapticsEnabled") as? Bool ?? true else { return }
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }
}
