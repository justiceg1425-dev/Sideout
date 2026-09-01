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
    let workout: WorkoutManager
    private let haptics = WatchHapticEngine()

    init(connectivity: WatchConnectivityManager, workout: WorkoutManager) {
        self.connectivity = connectivity
        self.workout = workout
        workout.requestAuthorization()
    }

    // MARK: - Lifecycle

    func startGame(with settings: GameSettings) {
        self.settings = settings
        SettingsStore.save(settings)
        game = Game(settings: settings)
        scrubOffset = nil
        lastOutcome = nil
        screen = .scoring
        workout.start()
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
            workout.stop()
            screen = .gameOver
        }
    }

    // MARK: - Crown scrubbing

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
        workout.stop()
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
