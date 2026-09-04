import Foundation
import WatchKit

/// Experimental, opt-in replacement for the screen-stays-frontmost
/// behavior HKWorkoutSession used to give for free before HealthKit was
/// removed (see docs/IMPLEMENTATION_PLAN.md Phase 5 -- HealthKit needs a
/// paid Apple Developer account this project doesn't have). A workout
/// session gets an effectively unlimited background budget while
/// recording; a plain (non-workout, non-mindfulness) extended runtime
/// session's actual budget on real hardware could not be verified
/// without a physical watch -- this is genuinely untested. Play at least
/// one full game with it enabled before trusting it for a real match.
@MainActor
final class ExtendedRuntimeManager: NSObject, ObservableObject {
    private var session: WKExtendedRuntimeSession?

    func start() {
        guard session == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
    }

    func stop() {
        session?.invalidate()
        session = nil
    }
}

extension ExtendedRuntimeManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in self.session = nil }
    }
}
