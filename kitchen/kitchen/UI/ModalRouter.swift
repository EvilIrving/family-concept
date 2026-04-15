import Foundation
import Combine

@MainActor
final class ModalRouter<Route: Identifiable>: ObservableObject {
    @Published private(set) var current: Route?

    private var pending: Route?

    func present(_ route: Route) {
        guard current == nil else {
            pending = route
            current = nil
            return
        }
        current = route
    }

    func transition(to route: Route) {
        pending = route
        current = nil
    }

    func dismiss() {
        current = nil
    }

    func didDismissCurrent() {
        guard let next = pending else { return }
        pending = nil
        current = next
    }

    func reset() {
        pending = nil
        current = nil
    }
}
