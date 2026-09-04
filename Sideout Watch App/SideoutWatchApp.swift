import SwiftUI

@main
struct SideoutWatchApp: App {
    @StateObject private var connectivity: WatchConnectivityManager
    @StateObject private var controller: GameSessionController

    init() {
        let connectivity = WatchConnectivityManager()
        _connectivity = StateObject(wrappedValue: connectivity)
        _controller = StateObject(wrappedValue: GameSessionController(connectivity: connectivity))
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
