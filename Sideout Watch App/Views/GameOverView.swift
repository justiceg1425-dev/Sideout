import SwiftUI
import SideoutEngine

struct GameOverView: View {
    @EnvironmentObject private var controller: GameSessionController

    private var winner: Team? { controller.game?.state.winner }
    private var state: GameState? { controller.game?.state }

    var body: some View {
        VStack(spacing: 0) {
            Text(winner == .a ? "WE WON" : "THEY WON")
                .font(WType.footerAmber).tracking(1.6).foregroundStyle(WColor.serve)

            Text(scoreLine)
                .font(WType.finalScore)
                .tracking(-2)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 12)

            Text("\(controller.elapsedMinutes) min")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WColor.chrome)
                .padding(.top, 6)

            Spacer(minLength: 8)

            Button {
                controller.rematch()
            } label: {
                Text("Rematch")
                    .font(WType.cardTitle)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: WMetric.buttonRadius).fill(WColor.serve))
            }
            .buttonStyle(.plain)

            Button {
                controller.doneAfterGameOver()
            } label: {
                Text("Done")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x8E8E93))
            }
            .buttonStyle(.plain)
            .padding(.top, 9)
        }
        .padding(.top, 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .background(WColor.bg)
    }

    private var scoreLine: String {
        guard let state, let winner else { return "" }
        return "\(state[winner])–\(state[winner.opponent])"
    }
}
