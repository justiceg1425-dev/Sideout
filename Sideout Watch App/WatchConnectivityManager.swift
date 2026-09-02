import Foundation
import WatchConnectivity
import SideoutEngine

/// The watch is the source of truth for input and never waits on the
/// phone. This just best-effort pushes state — `updateApplicationContext`
/// always carries the latest snapshot, which is exactly what a replica
/// that replaces (rather than accumulates) state wants on reconnect.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var isReachable = false

    /// Fires when the phone pushes edited settings (team names, above
    /// all) via `SettingsSync`. The watch is still the only thing that
    /// can actually *start* a game, but this is how phone-only settings
    /// reach it beforehand.
    var onSettingsReceived: ((GameSettings) -> Void)?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(_ message: ConnectivityMessage) {
        guard let session, session.activationState == .activated else { return }
        guard let dict = try? message.asDictionary() else { return }
        try? session.updateApplicationContext(dict)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let sync = try? SettingsSync.from(dictionary: applicationContext) else { return }
        Task { @MainActor in self.onSettingsReceived?(sync.settings) }
    }
}
