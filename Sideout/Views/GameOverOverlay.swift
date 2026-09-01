import SwiftUI
import SideoutEngine

/// Shown over the scoreboard once `state.winner` is set. The watch is
/// where rematch/end actually happens — the phone never originates a
/// rally, so "Rematch" and "Done" here are a status readout mirroring the
/// watch's game-over screen, not controls. That keeps faith with "no
/// interactive chrome competing for space" while still surfacing the
/// copy deck's overlay text.
struct GameOverOverlay: View {
    @EnvironmentObject private var connectivity: PhoneConnectivityManager

    private var state: GameState? { connectivity.currentState }
    private var settings: GameSettings? { connectivity.game?.settings }

    var body: some View {
        if let state, let winner = state.winner, let settings {
            ZStack {
                PColor.bgBoard.opacity(0.97).ignoresSafeArea()
                VStack(spacing: 14) {
                    Text("\(settings.name(for: winner).uppercased()) WIN")
                        .font(.system(size: 40, weight: .heavy))
                        .foregroundStyle(PColor.serve)
                    Text("\(state[winner])–\(state[winner.opponent])")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 40) {
                        Text("Rematch").foregroundStyle(PColor.secondary)
                        Text("Done").foregroundStyle(PColor.secondary)
                    }
                    .font(PType.button)
                    .padding(.top, 8)
                }
            }
        }
    }
}
