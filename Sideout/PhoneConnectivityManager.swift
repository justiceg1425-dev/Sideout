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

    var onUpdate: ((Update) -> Void)?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var staleTimer: Timer?
    private static let staleThreshold: TimeInterval = 45

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
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let message = try? ConnectivityMessage.from(dictionary: applicationContext) else { return }
        Task { @MainActor in self.apply(message) }
    }
}
