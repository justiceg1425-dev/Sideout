import Foundation
import Combine
import SideoutEngine

enum WatchScreen: Equatable {
    case newGame
    case scoring
    case gameOver
}

/// Owns the live game and is the source of truth for input. `Game` is a
/// reference type mutated in place, so this republishes a snapshot
/// (`currentState`) explicitly after every action rather than relying on
/// SwiftUI to notice internal mutation of an unchanged object reference.
@MainActor
final class GameSessionController: ObservableObject {
    @Published private(set) var game: Game?
    @Published private(set) var currentState: GameState?
    @Published private(set) var screen: WatchScreen = .newGame
    @Published var settings: GameSettings = SettingsStore.load()
    @Published private(set) var scrubOffset: Int? // nil = live; n = n rallies back
    @Published private(set) var lastOutcome: RallyOutcome?
    @Published var showEndGameMenu = false

    var isScrubbing: Bool { scrubOffset != nil }

    var scrubStatusText: String {
        guard let offset = scrubOffset else { return "" }
        if offset >= (game?.rallyCount ?? 0) { return "START OF GAME" }
        return offset == 1 ? "1 RALLY BACK" : "\(offset) RALLIES BACK"
    }

    let connectivity: WatchConnectivityManager
    private let haptics = WatchHapticEngine()
    private let extendedRuntime = ExtendedRuntimeManager()
    private var gameStartDate: Date?

    /// Opt-in, off by default -- see ExtendedRuntimeManager for why this
    /// isn't just always-on the way HKWorkoutSession used to be.
    @Published var keepAwakeEnabled: Bool = UserDefaults.standard.bool(forKey: GameSessionController.keepAwakeKey) {
        didSet { UserDefaults.standard.set(keepAwakeEnabled, forKey: GameSessionController.keepAwakeKey) }
    }
    private static let keepAwakeKey = "com.sideout.watch.keepAwakeEnabled"

    /// No longer tied to a HealthKit workout (that required a paid Apple
    /// Developer account the free/personal team here doesn't have) — just
    /// wall-clock time since `startGame`, for the "X min" line on
    /// GameOverView.
    var elapsedMinutes: Int {
        guard let gameStartDate else { return 0 }
        return max(0, Int(Date().timeIntervalSince(gameStartDate) / 60))
    }

    init(connectivity: WatchConnectivityManager) {
        self.connectivity = connectivity
        connectivity.onSettingsReceived = { [weak self] settings, startNow in
            self?.applyReceivedSettings(settings, startNow: startNow)
        }
    }

    // MARK: - Lifecycle

    /// Settings pushed from the phone's Setup screen (team names, above
    /// all — the watch has no UI of its own to set those). Never
    /// overwrites a game already in progress; it only affects what the
    /// *next* game starts with. `startNow` means the phone's own "Start
    /// game" button triggered this push — start playing immediately so
    /// both devices land in the same game together, instead of leaving
    /// the watch sitting on NewGameView needing a separate manual tap.
    func applyReceivedSettings(_ settings: GameSettings, startNow: Bool) {
        guard game == nil else { return }
        self.settings = settings
        SettingsStore.save(settings)
        if startNow {
            startGame(with: settings)
        }
    }

    func startGame(with settings: GameSettings) {
        self.settings = settings
        SettingsStore.save(settings)
        game = Game(settings: settings)
        scrubOffset = nil
        lastOutcome = nil
        screen = .scoring
        gameStartDate = Date()
        if keepAwakeEnabled {
            extendedRuntime.start()
        }
        refresh()
        sync()
    }

    func startSameAsLastTime() {
        startGame(with: SettingsStore.load())
    }

    // MARK: - Scoring input

    func recordRally(wonBy team: Team) {
        guard let game, !isScrubbing else { return }
        guard let outcome = game.recordRally(wonBy: team) else { return }
        lastOutcome = outcome
        haptics.play(for: outcome)
        refresh()
        sync()
        if game.state.winner != nil {
            extendedRuntime.stop()
            screen = .gameOver
        }
    }

    // MARK: - Crown scrubbing

    /// One-motion "oops, wrong side" fix: removes the last rally
    /// immediately, with no separate tap to commit -- unlike
    /// `commitScrubAsLive`, which only applies a truncation that scrub
    /// preview has already dialed in. Only for the very first crown
    /// detent back from a truly live state; see
    /// ScoringView.handleCrownChange for why that distinction matters
    /// (further detents still go through the safer preview+tap path,
    /// so casually overshooting the crown can't silently erase several
    /// real points at once).
    func instantUndoLastRally() {
        guard let game, game.rallyCount > 0, !isScrubbing else { return }
        let winners = Array(game.rallyWinners.dropLast())
        self.game = Game(settings: game.settings, rallyWinners: winners)
        haptics.playInstantUndo()
        refresh()
        sync()
    }

    /// `position` is the crown's bound value: 0 = live, increasing = further
    /// back in history. Called on every crown change; internally clamps and
    /// fires the per-detent / boundary haptics.
    func setScrubPosition(_ position: Int) {
        guard let game else { return }
        let clamped = min(max(position, 0), game.rallyCount)
        let previous = scrubOffset ?? 0
        guard clamped != previous else { return }
        scrubOffset = clamped == 0 ? nil : clamped
        haptics.playScrubTick(atBoundary: clamped == 0 || clamped == game.rallyCount)
        refresh()
    }

    /// A tap while scrubbing resumes live scoring from the current
    /// position, truncating the redo tail.
    func commitScrubAsLive() {
        guard let game, let offset = scrubOffset else { return }
        let keepCount = game.rallyCount - offset
        let winners = Array(game.rallyWinners.prefix(keepCount))
        self.game = Game(settings: game.settings, rallyWinners: winners)
        scrubOffset = nil
        refresh()
        sync()
    }

    /// Idle 6 s while scrubbing snaps back to live, untouched.
    func cancelScrubToLive() {
        guard scrubOffset != nil else { return }
        scrubOffset = nil
        refresh()
    }

    // MARK: - End game menu

    func endGame() {
        extendedRuntime.stop()
        game = nil
        currentState = nil
        scrubOffset = nil
        showEndGameMenu = false
        screen = .newGame
    }

    func resumeFromMenu() {
        showEndGameMenu = false
    }

    func rematch() {
        guard let settings = game?.settings else { return }
        startGame(with: settings)
    }

    func doneAfterGameOver() {
        game = nil
        currentState = nil
        screen = .newGame
    }

    // MARK: - Private

    private func refresh() {
        guard let game else { currentState = nil; return }
        if let offset = scrubOffset {
            currentState = game.state(atRallyCount: max(0, game.rallyCount - offset))
        } else {
            currentState = game.state
        }
    }

    private func sync() {
        guard let game else { return }
        connectivity.send(ConnectivityMessage(settings: game.settings, rallyWinners: game.rallyWinners))
    }
}
