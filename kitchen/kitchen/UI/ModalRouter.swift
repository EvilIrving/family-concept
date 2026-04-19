import Foundation
import Combine

@MainActor
final class ModalRouter<Route: Identifiable & Equatable>: ObservableObject {
    @Published private(set) var current: Route?

    private var queue: [Route] = []
    private var isDismissing = false

    func present(_ route: Route) {
        if canPresentImmediately {
            current = route
            return
        }

        enqueueIfNeeded(route)
    }

    func replace(with route: Route) {
        queue = [route]

        guard current != nil else {
            guard !isDismissing else { return }
            isDismissing = false
            current = queue.removeFirst()
            return
        }

        beginDismissalIfNeeded()
    }

    func dismiss() {
        guard current != nil else { return }
        beginDismissalIfNeeded()
    }

    func handleDismissedCurrent() {
        isDismissing = false
        current = nil
        presentNextIfNeeded()
    }

    func reset() {
        queue.removeAll()
        isDismissing = false
        current = nil
    }

    private var canPresentImmediately: Bool {
        current == nil && !isDismissing
    }

    private func enqueueIfNeeded(_ route: Route) {
        guard queue.last != route else { return }
        queue.append(route)
    }

    private func beginDismissalIfNeeded() {
        guard !isDismissing else { return }
        isDismissing = true
        current = nil
    }

    private func presentNextIfNeeded() {
        guard !queue.isEmpty else { return }
        current = queue.removeFirst()
    }
}
