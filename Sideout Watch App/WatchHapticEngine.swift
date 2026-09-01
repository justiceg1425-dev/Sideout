import WatchKit
import SideoutEngine

/// Fires the instant the tap commits, from the watch's own copy of the
/// engine — it never awaits the phone. See the feedback matrix in the
/// design brief: each of the three rally outcomes gets its own haptic
/// signature, distinct from the other two and from scrub ticks.
struct WatchHapticEngine {
    func play(for outcome: RallyOutcome) {
        switch outcome {
        case .pointScored:
            WKInterfaceDevice.current().play(.success)
        case .serverAdvanced:
            WKInterfaceDevice.current().play(.directionUp)
        case .sideOut:
            WKInterfaceDevice.current().play(.retry)
        }
    }

    func playScrubTick(atBoundary: Bool) {
        WKInterfaceDevice.current().play(atBoundary ? .stop : .click)
    }
}
