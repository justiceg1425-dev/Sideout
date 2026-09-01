import SwiftUI

@main
struct SideoutWatchApp: App {
    @StateObject private var connectivity: WatchConnectivityManager
    @StateObject private var workout: WorkoutManager
    @StateObject private var controller: GameSessionController

    init() {
        let connectivity = WatchConnectivityManager()
        let workout = WorkoutManager()
        _connectivity = StateObject(wrappedValue: connectivity)
        _workout = StateObject(wrappedValue: workout)
        _controller = StateObject(wrappedValue: GameSessionController(connectivity: connectivity, workout: workout))
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(controller)
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var controller: GameSessionController

    var body: some View {
        switch controller.screen {
        case .newGame:
            NewGameView()
        case .scoring:
            ScoringView()
        case .gameOver:
            GameOverView()
        }
    }
}
