import SwiftUI
import SideoutEngine

/// Design note: the brief specifies a "Same as last time" card as the
/// screen's one-tap path and four rows that "cycle in place" below it, but
/// leaves how a *customized* game gets started unspecified — the tightest
/// screen in the app (215 pt on 41 mm) has no room for a second button.
/// Resolution: the card doubles as the single start action for whatever is
/// currently dialed in. Its title reads "Same as last time" only while the
/// draft matches the persisted settings; the moment a row is cycled it
/// becomes "Start game", and the subtitle always mirrors the live draft.
/// One card, one job, no separate control needed.
struct NewGameView: View {
    @EnvironmentObject private var controller: GameSessionController
    @State private var draft: GameSettings

    init() {
        _draft = State(initialValue: SettingsStore.load())
    }

    private var isSameAsLastTime: Bool { draft == SettingsStore.load() }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image("SideoutMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
                Text("SIDEOUT")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 8)

            startCard

            Rectangle()
                .fill(WColor.hairline)
                .frame(height: 1)
                .padding(.vertical, 8)

            VStack(spacing: 5) {
                settingsRow(label: "Format", value: draft.format == .sideOut ? "Side-out" : "Rally") {
                    draft.format = draft.format == .sideOut ? .rally : .sideOut
                }
                settingsRow(label: "Players", value: draft.players == .doubles ? "Doubles" : "Singles") {
                    draft.players = draft.players == .doubles ? .singles : .doubles
                }
                settingsRow(label: "To", value: "\(draft.pointsToWin)") {
                    draft.pointsToWin = [11, 15, 21].nextAfter(draft.pointsToWin) ?? 11
                }
                settingsRow(label: "First serve", value: draft.firstServer == .a ? "Us" : "Them") {
                    draft.firstServer = draft.firstServer == .a ? .b : .a
                }
                // Experimental -- see ExtendedRuntimeManager. Controller-
                // level (not part of `draft`/GameSettings) since it's a
                // device preference, not a game rule, and persists across
                // games rather than resetting with "same as last time."
                settingsRow(label: "Keep awake", value: controller.keepAwakeEnabled ? "On" : "Off") {
                    controller.keepAwakeEnabled.toggle()
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.top, 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .background(WColor.bg)
        // `draft` is seeded once at init from disk, so it never sees a
        // settings push that arrives while this screen is already up
        // (e.g. the phone editing team names before the watch starts a
        // game). Team names aren't cycled here — the watch has no UI for
        // them — so it's safe to always mirror the controller's copy
        // rather than treat it as a local edit to preserve. Single-value
        // closure form deliberately (not the newer two-value one) — that
        // overload needs watchOS 10, and this target's floor is 8.0 for
        // Series 3.
        .onChange(of: controller.settings.teamNames) { newNames in
            draft.teamNames = newNames
        }
    }

    private var startCard: some View {
        Button {
            controller.startGame(with: draft)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(isSameAsLastTime ? "Same as last time" : "Start game")
                    .font(WType.cardTitle)
                    .foregroundStyle(.black)
                Text(draft.summary)
                    .font(WType.cardSub)
                    .foregroundStyle(.black.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: WMetric.cardRadius).fill(WColor.serve))
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(label: String, value: String, cycle: @escaping () -> Void) -> some View {
        Button(action: cycle) {
            HStack {
                Text(label)
                    .font(WType.rowLabel)
                    .foregroundStyle(WColor.secondaryLabel)
                Spacer()
                Text(value)
                    .font(WType.rowValue)
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension WColor {
    static let secondaryLabel = Color(hex: 0x8E8E93)
}

private extension Array where Element == Int {
    func nextAfter(_ value: Int) -> Int? {
        guard let index = firstIndex(of: value) else { return first }
        return self[(index + 1) % count]
    }
}
