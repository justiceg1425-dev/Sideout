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
    /// all) via `SettingsSync`. The second value is `startNow` — true
    /// when the phone's own "Start game" button is what triggered this,
    /// meaning the watch should start playing immediately rather than
    /// just stash the settings for a later manual start.
    var onSettingsReceived: ((GameSettings, Bool) -> Void)?

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
        Task { @MainActor in self.onSettingsReceived?(sync.settings, sync.startNow) }
    }
}
