import Foundation
import WatchConnectivity
import SideoutEngine

/// The phone is a replica plus the speaker — it never originates a rally.
/// On receiving a state update it diffs against its own copy to decide
/// which outcome to animate/speak, then replaces its state wholesale, so a
/// burst of catch-up rallies produces exactly one callout instead of a
/// queue of stale ones.
@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {
    struct Update {
        let outcome: RallyOutcome
        let isBurst: Bool
        let newState: GameState
    }

    @Published private(set) var game: Game?
    @Published private(set) var currentState: GameState?
    @Published private(set) var lastHeard: Date?
    @Published private(set) var isStale = false
    /// True WCSession reachability — distinct from `currentState != nil`,
    /// which only ever reflects "have we received a game," not whether
    /// the watch is actually paired and reachable right now. Conflating
    /// the two was the bug behind Setup's "Watch not connected" label
    /// showing before any game had ever synced, even with a working pair.
    @Published private(set) var isReachable = false

    var onUpdate: ((Update) -> Void)?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var staleTimer: Timer?
    private static let staleThreshold: TimeInterval = 45

    #if DEBUG
    /// The rally history for `simulateRally`, kept separately from any
    /// real `game` so a debug session never collides with a real watch
    /// connecting mid-test.
    private var debugRallyWinners: [Team] = []

    /// Feeds a fake watch update through the exact same `apply(_:)` path
    /// a real WCSession delivery uses — so this is a genuine test of the
    /// reaction pipeline (outcome classification, audio, side-out band,
    /// staleness), not a separate mock of it. Built to let the real
    /// end-to-end behavior be verified on real hardware without a
    /// physical watch, after the physical Series 3 turned out to be
    /// unreachable by any supported path (see docs/IMPLEMENTATION_PLAN.md).
    func simulateRally(wonBy team: Team, settings: GameSettings) {
        debugRallyWinners.append(team)
        apply(ConnectivityMessage(settings: settings, rallyWinners: debugRallyWinners))
    }

    /// Starts over with a fresh fake game under new settings.
    func resetDebugSimulation() {
        debugRallyWinners = []
        game = nil
        currentState = nil
    }
    #endif

    /// Pushes settings edited on the phone (team names, in particular —
    /// the only thing the phone can set that the watch can't) to the
    /// watch. This is this session's own outgoing application context;
    /// it doesn't collide with the watch's outgoing context that
    /// `ConnectivityMessage` arrives through.
    func sendSettings(_ settings: GameSettings) {
        guard let session, session.activationState == .activated else { return }
        guard let dict = try? SettingsSync(settings: settings).asDictionary() else { return }
        try? session.updateApplicationContext(dict)
    }

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
        staleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStaleness() }
        }
    }

    private func refreshStaleness() {
        guard let lastHeard else { isStale = false; return }
        isStale = Date().timeIntervalSince(lastHeard) > Self.staleThreshold
    }

    private func apply(_ message: ConnectivityMessage) {
        let previousState = game?.state
        let previousCount = game?.rallyCount ?? 0

        let newGame = Game(settings: message.settings, rallyWinners: message.rallyWinners)
        game = newGame
        currentState = newGame.state
        lastHeard = Date()
        isStale = false

        guard let previousState else { return }
        let newCount = message.rallyWinners.count
        guard newCount > previousCount, let outcome = Self.diff(before: previousState, after: newGame.state) else { return }

        onUpdate?(Update(outcome: outcome, isBurst: newCount - previousCount > 1, newState: newGame.state))
    }

    /// Unlike `Game.classify`, this doesn't assume a single rally — a
    /// reconnection can deliver several at once. It classifies by the
    /// shape of the change between two full states instead.
    private static func diff(before: GameState, after: GameState) -> RallyOutcome? {
        guard before != after else { return nil }
        if after.points != before.points {
            let scoringTeam: Team = after[.a] > before[.a] ? .a : .b
            return .pointScored(by: scoringTeam)
        }
        if after.servingTeam != before.servingTeam {
            return .sideOut(to: after.servingTeam)
        }
        if after.serverNumber != before.serverNumber {
            return .serverAdvanced
        }
        return nil
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let message = try? ConnectivityMessage.from(dictionary: applicationContext) else { return }
        Task { @MainActor in self.apply(message) }
    }
}
