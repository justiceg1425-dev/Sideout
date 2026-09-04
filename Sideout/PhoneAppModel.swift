import Foundation
import Combine
import SideoutEngine

enum PhoneScreen: Equatable {
    case setup
    case scoreboard
    case settings
}

/// Orchestrates the phone side: owns the WCSession replica, decides what
/// (if anything) to speak for each update per the announce settings, and
/// tracks which screen is showing so `SideoutApp` can lock orientation.
@MainActor
final class PhoneAppModel: ObservableObject {
    @Published var screen: PhoneScreen = .setup
    @Published var appSettings: AppSettings = AppSettingsStore.load() {
        didSet { AppSettingsStore.save(appSettings) }
    }
    @Published private(set) var lastOutcome: RallyOutcome?
    @Published private(set) var showSideOutBand = false
    @Published private(set) var showSecondServerLabel = false
    /// Purely cosmetic — see SplashView. Nothing here actually waits on
    /// this; it just holds the splash on screen for a beat.
    @Published private(set) var isLaunching = true

    let connectivity: PhoneConnectivityManager
    let announcer = AudioAnnouncer()

    init(connectivity: PhoneConnectivityManager) {
        self.connectivity = connectivity
        connectivity.onUpdate = { [weak self] update in
            self?.handle(update)
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            self?.isLaunching = false
        }
    }

    var currentState: GameState? { connectivity.currentState }
    var settings: GameSettings? { connectivity.game?.settings }

    func startWatchingScoreboard() {
        screen = .scoreboard
    }

    /// Pushes settings edited on the phone's Setup screen (team names
    /// above all — the watch has no way to set those itself) to the
    /// watch, so the *next* game it starts picks them up.
    func pushSettingsToWatch(_ settings: GameSettings) {
        connectivity.sendSettings(settings)
    }

    private func handle(_ update: PhoneConnectivityManager.Update) {
        lastOutcome = update.outcome
        announcer.volume = Float(appSettings.volume)

        if screen != .scoreboard, update.newState.ralliesPlayed > 0 {
            screen = .scoreboard
        }

        switch update.outcome {
        case .pointScored:
            break
        case .serverAdvanced:
            flashSecondServerLabel()
        case .sideOut:
            flashSideOutBand()
        }

        speak(for: update)
    }

    private func speak(for update: PhoneConnectivityManager.Update) {
        if appSettings.announceMode == .scoreChangesAndSideOutsOnly, case .serverAdvanced = update.outcome {
            return // the haptic and the split bar carry this outcome alone
        }
        if update.isBurst, appSettings.reconnectBehavior == .nothing {
            return
        }

        guard let game = connectivity.game else { return }
        var clips = game.spokenCallout()

        if update.isBurst, clips.first == .sideOut {
            // "The gap crossed a side-out" — that moment has passed; only
            // the current numbers matter for a catch-up burst.
            clips.removeFirst()
        }
        if !appSettings.announceGamePoint {
            clips.removeAll { $0 == .gamePoint }
        }
        announcer.speak(clips)
    }

    private func flashSideOutBand() {
        showSideOutBand = true
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            showSideOutBand = false
        }
    }

    private func flashSecondServerLabel() {
        showSecondServerLabel = true
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            showSecondServerLabel = false
        }
    }
}
