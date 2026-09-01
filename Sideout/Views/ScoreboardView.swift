import SwiftUI
import SideoutEngine

/// The primary display. No interactive chrome — this is a display, not a
/// control. Landscape, propped courtside, read from the far baseline.
struct ScoreboardView: View {
    @EnvironmentObject private var appModel: PhoneAppModel
    @EnvironmentObject private var connectivity: PhoneConnectivityManager

    private var state: GameState? { connectivity.currentState }
    private var settings: GameSettings? { connectivity.game?.settings }

    var body: some View {
        ZStack(alignment: .top) {
            PColor.bgBoard.ignoresSafeArea()

            VStack(spacing: 0) {
                if connectivity.isStale { staleStrip }

                HStack(spacing: 0) {
                    panel(for: .a)
                    Rectangle()
                        .fill(Color(hex: 0x1C1C1E))
                        .frame(width: 1)
                        .padding(.vertical, 20)
                    panel(for: .b)
                }
                .opacity(connectivity.isStale ? 0.45 : 1)
                .frame(maxHeight: .infinity)

                if let settings {
                    Text(settings.footerCaption)
                        .font(PType.boardFooter)
                        .tracking(3)
                        .foregroundStyle(PColor.meta)
                        .padding(.bottom, PMetric.boardPaddingBottom)
                }
            }
            .padding(.top, PMetric.boardPaddingTop)

            sideOutBand
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.5) {
            appModel.screen = .settings
        }
        .animation(.easeOut(duration: 0.16), value: state?.points)
        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: state?.serverCourtSide)
        .animation(.easeInOut(duration: 0.2), value: state?.serverNumber)
    }

    // MARK: - Panels

    private func panel(for team: Team) -> some View {
        let isServing = state?.servingTeam == team
        let digits = state?[team] ?? 0
        let isGamePoint = isServing && gamePointLabel != nil

        return VStack(spacing: PMetric.panelSpacing) {
            Text(isGamePoint ? "\(teamName(team)) · \(gamePointLabel ?? "")" : teamName(team))
                .font(PType.boardTeam)
                .tracking(5)
                .foregroundStyle(isGamePoint ? PColor.serve : (isServing ? PColor.label : PColor.scoreIdle))

            Text("\(digits)")
                .font(PType.boardScore)
                .monospacedDigit()
                .tracking(digits >= 10 ? -14 : -10)
                .foregroundStyle(isServing ? PColor.scoreLive : PColor.scoreIdle)
                .id("\(team)-\(digits)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

            ServeBarView(
                isServingHalf: isServing,
                serverNumber: state?.serverNumber ?? 1,
                courtSide: state?.serverCourtSide ?? .right,
                geometry: PMetric.serveBarGeometry,
                color: PColor.serve,
                hollow: false
            )

            if appModel.showSecondServerLabel && isServing && (state?.serverNumber ?? 1) == 2 {
                Text("SECOND SERVER")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PColor.serve)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func teamName(_ team: Team) -> String {
        (settings?.name(for: team) ?? (team == .a ? "Us" : "Them")).uppercased()
    }

    private var gamePointLabel: String? {
        guard let game = connectivity.game, let s = state, s.winner == nil, s.servingTeam == game.state.servingTeam else { return nil }
        switch game.pointSignal(for: s.servingTeam) {
        case .gamePoint: return "GAME POINT"
        case .matchPoint: return "MATCH POINT"
        case nil: return nil
        }
    }

    // MARK: - Side out band

    @ViewBuilder
    private var sideOutBand: some View {
        if appModel.showSideOutBand {
            VStack {
                Spacer()
                Text("SIDE OUT")
                    .font(PType.boardBand)
                    .tracking(5)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(PColor.serve)
            }
            .transition(.move(edge: .bottom))
            .ignoresSafeArea()
        }
    }

    // MARK: - Stale strip

    private var staleStrip: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text("LAST HEARD FROM WATCH \(elapsedSinceLastHeard) AGO")
                .font(PType.boardWarn)
                .tracking(2)
                .foregroundStyle(PColor.warnFg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(PColor.warnBg)
        }
    }

    private var elapsedSinceLastHeard: String {
        guard let lastHeard = connectivity.lastHeard else { return "--:--" }
        let seconds = max(0, Int(Date().timeIntervalSince(lastHeard)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
