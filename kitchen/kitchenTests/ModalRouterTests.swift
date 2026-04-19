import Testing
@testable import kitchen

@MainActor
struct ModalRouterTests {

    @Test func presentsImmediatelyWhenIdle() {
        let router = ModalRouter<TestRoute>()

        router.present(.a)

        #expect(router.current == .a)
    }

    @Test func queuesRoutesInFIFOOrderDuringPresentation() {
        let router = ModalRouter<TestRoute>()

        router.present(.a)
        router.present(.b)
        router.present(.c)

        #expect(router.current == .a)

        router.dismiss()
        #expect(router.current == nil)

        router.handleDismissedCurrent()
        #expect(router.current == .b)

        router.dismiss()
        router.handleDismissedCurrent()
        #expect(router.current == .c)
    }

    @Test func replaceKeepsOnlyLatestRoute() {
        let router = ModalRouter<TestRoute>()

        router.present(.a)
        router.replace(with: .b)
        router.replace(with: .c)

        #expect(router.current == nil)

        router.handleDismissedCurrent()
        #expect(router.current == .c)
    }

    @Test func replaceDuringDismissWindowPresentsReplacementAfterDismissal() {
        let router = ModalRouter<TestRoute>()

        router.present(.a)
        router.dismiss()
        router.replace(with: .b)

        #expect(router.current == nil)

        router.handleDismissedCurrent()
        #expect(router.current == .b)
    }

    @Test func presentDuringDismissWindowResumesInOrder() {
        let router = ModalRouter<TestRoute>()

        router.present(.a)
        router.dismiss()
        router.present(.b)

        #expect(router.current == nil)

        router.handleDismissedCurrent()
        #expect(router.current == .b)
    }

    @Test func skipsDuplicateQueuedRoutesUsingFullEquatableMatch() {
        let router = ModalRouter<TestRoute>()

        router.present(.payload("same"))
        router.present(.payload("next"))
        router.present(.payload("next"))
        router.present(.payload("other"))

        router.dismiss()
        router.handleDismissedCurrent()
        #expect(router.current == .payload("next"))

        router.dismiss()
        router.handleDismissedCurrent()
        #expect(router.current == .payload("other"))
    }

    @Test func allowsSameIdentityWithDifferentPayload() {
        let router = ModalRouter<TestRoute>()

        router.present(.payload("first"))
        router.present(.payload("second"))

        router.dismiss()
        router.handleDismissedCurrent()
        #expect(router.current == .payload("second"))
    }

    @Test func resetClearsCurrentAndQueue() {
        let router = ModalRouter<TestRoute>()

        router.present(.a)
        router.present(.b)
        router.reset()

        #expect(router.current == nil)

        router.handleDismissedCurrent()
        #expect(router.current == nil)
    }
}

private enum TestRoute: Identifiable, Equatable {
    case a
    case b
    case c
    case payload(String)

    var id: String {
        switch self {
        case .a:
            return "route"
        case .b:
            return "route"
        case .c:
            return "route"
        case .payload:
            return "payload"
        }
    }
}
