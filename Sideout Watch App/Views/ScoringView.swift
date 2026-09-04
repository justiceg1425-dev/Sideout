import SwiftUI
import SideoutEngine

/// The screen that exists for 95% of the app's life. One screen deep,
/// always — no sheets, no navigation push, not even for scrubbing (that's
/// an overlay state of this same screen, not a separate one).
struct ScoringView: View {
    @EnvironmentObject private var controller: GameSessionController
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var crownPosition: Double = 0
    @State private var scrubIdleTask: Task<Void, Never>?
    @State private var pressStart: Date?
    @State private var lastInstantUndoAt: Date?

    private var state: GameState? { controller.currentState }
    private var settings: GameSettings { controller.settings }
    private var isScrubbing: Bool { controller.isScrubbing }

    var body: some View {
        crownScrubbingContent
            .sheet(isPresented: $controller.showEndGameMenu) {
                EndGameMenu()
            }
            .animation(.easeOut(duration: 0.14), value: state?.points)
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: state?.serverCourtSide)
            .animation(.easeInOut(duration: 0.2), value: state?.serverNumber)
    }

    private var screenContent: some View {
        ZStack {
            WColor.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                scoreRow
                    .frame(maxHeight: .infinity)
                footer
            }
            .padding(.top, WMetric.screenPaddingTop)
            .padding(.bottom, WMetric.screenPaddingBottom)

            hiddenDoubleTapButton
        }
        .overlay(
            RoundedRectangle(cornerRadius: WMetric.barRadius)
                .stroke(WColor.scrub, lineWidth: isScrubbing ? 1 : 0)
                .ignoresSafeArea()
        )
    }

    /// The parameterized `digitalCrownRotation(from:through:by:sensitivity:
    /// isContinuous:isHapticFeedbackEnabled:)` overload — native clamping
    /// with a resistance wall at each end, a tuned sensitivity curve,
    /// `by: 1` quantized stepping — needs a newer watchOS than this app's
    /// floor (8.0, for Series 3 support). Rather than give every device
    /// the reduced fallback, this branches: capable OS versions get the
    /// full original design, and only pre-watchOS-9 devices fall back to
    /// the plain single-binding form with hand-rolled clamping below.
    ///
    /// The exact version gate here (9.0) is a best guess made without
    /// Xcode access — verify it once by Option-clicking
    /// `digitalCrownRotation` in Xcode and checking the `@available` on
    /// the parameterized overload. If it's wrong, Xcode's error message
    /// on the `#available` branch will name the correct minimum directly.
    @ViewBuilder
    private var crownScrubbingContent: some View {
        if #available(watchOS 9.0, *) {
            screenContent
                .focusable(true)
                .digitalCrownRotation(
                    $crownPosition,
                    from: 0,
                    through: Double(controller.game?.rallyCount ?? 0),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: false
                )
                .onChange(of: crownPosition) { newValue in handleCrownChange(newValue) }
                .onChange(of: isScrubbing) { scrubbing in if !scrubbing { crownPosition = 0 } }
        } else {
            screenContent
                .focusable(true)
                .digitalCrownRotation($crownPosition)
                .onChange(of: crownPosition) { newValue in handleCrownChange(newValue) }
                .onChange(of: isScrubbing) { scrubbing in if !scrubbing { crownPosition = 0 } }
        }
    }

    /// Shared by both crown paths above. On the watchOS 9+ path the
    /// system has already clamped and stepped `newValue`, so the clamp
    /// here is a no-op that changes nothing; on the fallback path it's
    /// the only clamping that happens. Either way this re-syncs the raw
    /// binding after every change so it can't drift past either end
    /// while the player keeps turning the crown.
    private func handleCrownChange(_ newValue: Double) {
        let maxBack = Double(controller.game?.rallyCount ?? 0)
        let clamped = min(max(newValue, 0), maxBack)
        if clamped != crownPosition {
            crownPosition = clamped
        }

        let rounded = Int(clamped.rounded())

        // The very first detent back from a truly live state instantly
        // undoes the last rally instead of entering preview mode — see
        // GameSessionController.instantUndoLastRally. crownPosition is
        // reset to 0 right after, same pattern already used elsewhere
        // (onChange(of: isScrubbing) below) when a scrub concludes, so
        // the crown's frame of reference matches the new live state.
        // The debounce guards against that reset itself re-triggering
        // this branch if the system reports another value before the
        // physical crown has caught up -- genuinely unverified without
        // a real watch; tighten or remove if it feels laggy or, worse,
        // double-fires on-device.
        if !controller.isScrubbing, rounded == 1 {
            let now = Date()
            if lastInstantUndoAt.map({ now.timeIntervalSince($0) > 0.3 }) ?? true {
                lastInstantUndoAt = now
                controller.instantUndoLastRally()
                crownPosition = 0
            }
            return
        }

        controller.setScrubPosition(rounded)
        armScrubIdleTimeout()
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        if isScrubbing {
            ScrubTickLadder(current: state?.ralliesPlayed ?? 0, total: controller.game?.rallyCount ?? 0)
                .padding(.horizontal, 12)
        } else if !isLuminanceReduced {
            HStack {
                Text(settings.name(for: .a).uppercased())
                    .font(WType.header).tracking(1.4).foregroundStyle(WColor.chrome)
                Spacer()
                linkDot
                Spacer()
                Text(settings.name(for: .b).uppercased())
                    .font(WType.header).tracking(1.4).foregroundStyle(WColor.chrome)
            }
            .padding(.horizontal, 18)
        }
    }

    private var linkDot: some View {
        Group {
            if controller.connectivity.isReachable {
                Circle().fill(WColor.serve)
            } else {
                Circle().strokeBorder(WColor.chrome, lineWidth: 1)
            }
        }
        .frame(width: 7, height: 7)
    }

    // MARK: - Score row

    private var scoreRow: some View {
        HStack(spacing: 0) {
            scoreHalf(for: .a)
            Rectangle()
                .fill(isScrubbing ? WColor.scrubDim : WColor.hairline)
                .frame(width: 1, height: WMetric.gutterHeight)
                .opacity(isLuminanceReduced ? 0 : 1)
                .frame(width: WMetric.gutterWidth)
                .contentShape(Rectangle())
            scoreHalf(for: .b)
        }
        .opacity(isLuminanceReduced ? 0.42 : 1)
    }

    private func scoreHalf(for team: Team) -> some View {
        let s = state
        let isServing = s?.servingTeam == team
        let digitColor: Color = {
            if isScrubbing { return isServing ? WColor.scrub : WColor.scrubDim }
            if isLuminanceReduced { return .white }
            return isServing ? WColor.scoreLive : WColor.scoreIdle
        }()
        let barColor: Color = isScrubbing ? WColor.scrub : (isLuminanceReduced ? .white : WColor.serve)

        return VStack(spacing: 11) {
            Text("\(s?[team] ?? 0)")
                .font(WType.score(isLuminanceReduced ? .semibold : .bold))
                .monospacedDigit()
                .lineLimit(1)
                // A fixed 96pt fits one digit fine but clips two (hard-cap
                // games run up to 25) -- shrink-to-fit instead of a hand
                // picked smaller size for double digits, so it can't clip
                // at any value rather than just the common ones tested.
                .minimumScaleFactor(0.5)
                .foregroundStyle(digitColor)
                // Roll transition approximates the spec's 140 ms vertical
                // roll + scale punch; exact spring tuning is a device pass.
                .id("\(team)-\(s?[team] ?? 0)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

            ServeBarView(
                isServingHalf: isServing,
                serverNumber: s?.serverNumber ?? 1,
                courtSide: s?.serverCourtSide ?? .right,
                geometry: WMetric.serveBarGeometry,
                color: barColor,
                hollow: isScrubbing
            )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            // Commits on touch-up, not touch-down, so a paddle graze can't
            // score. A single gesture (rather than a competing Long Press
            // recognizer) tracks its own duration and travel so "held for
            // the menu" and "released as a scoring tap" can never both
            // fire for the same touch.
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if pressStart == nil { pressStart = Date() }
                }
                .onEnded { value in
                    defer { pressStart = nil }
                    let travel = hypot(value.translation.width, value.translation.height)
                    guard travel < 40 else { return }

                    if isScrubbing {
                        controller.commitScrubAsLive()
                        return
                    }

                    let heldDuration = pressStart.map { Date().timeIntervalSince($0) } ?? 0
                    if heldDuration >= 0.5 {
                        controller.showEndGameMenu = true
                    } else {
                        controller.recordRally(wonBy: team)
                    }
                }
        )
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if isScrubbing {
            Text(controller.scrubStatusText)
                .font(WType.footerAmber).tracking(1.4).foregroundStyle(WColor.scrub)
        } else if !isLuminanceReduced {
            if let signal = pointSignalText {
                Text(signal)
                    .font(WType.footerAmber).tracking(1.6).foregroundStyle(WColor.serve)
            } else {
                Text("TO \(settings.pointsToWin)")
                    .font(WType.footer).tracking(1.2).foregroundStyle(WColor.chromeDim)
            }
        }
    }

    private var pointSignalText: String? {
        guard let game = controller.game, let s = state, s.winner == nil else { return nil }
        if let signal = game.pointSignal(for: s.servingTeam) {
            switch signal {
            case .gamePoint: return "GAME POINT"
            case .matchPoint: return "MATCH POINT"
            }
        }
        return nil
    }

    // MARK: - Double Tap (Series 9+)

    /// A hidden, non-hit-testable control so the system Double Tap hand
    /// gesture (routed independently of on-screen touch) can still trigger
    /// "our side won" without competing with the touch-up drag gesture
    /// above it. Verify this composition on-device — `handGestureShortcut`
    /// semantics with a fully transparent, non-interactive control are not
    /// something that can be confirmed without a physical Series 9+.
    ///
    /// `handGestureShortcut` needs watchOS 11 (confirmed by a real build
    /// error — the original 10.0 guess was off by one major version) —
    /// gated so this app still builds and runs down to watchOS 8
    /// (Series 3), where Double Tap hardware doesn't exist anyway and
    /// this whole control is simply absent.
    @ViewBuilder
    private var hiddenDoubleTapButton: some View {
        if #available(watchOS 11.0, *) {
            Button {
                controller.recordRally(wonBy: .a)
            } label: {
                Color.clear
            }
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .handGestureShortcut(.primaryAction)
            .opacity(isScrubbing ? 0 : 1)
        }
    }

    private func armScrubIdleTimeout() {
        scrubIdleTask?.cancel()
        scrubIdleTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                controller.cancelScrubToLive()
                crownPosition = 0
            }
        }
    }
}

private struct ScrubTickLadder: View {
    let current: Int // ralliesPlayed at the scrubbed position
    let total: Int

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    tick(forRallyIndex: index)
                }
            }
            .frame(width: proxy.size.width, alignment: .center)
        }
        .frame(height: 12)
    }

    private func tick(forRallyIndex index: Int) -> some View {
        let isCurrentEdge = index == current - 1
        let isRedoTail = index >= current
        let height: CGFloat = isCurrentEdge ? 12 : 5
        let color: Color = isCurrentEdge ? WColor.scrub : (isRedoTail ? WColor.scrub.opacity(0.45) : WColor.scrubDim)
        return RoundedRectangle(cornerRadius: 1)
            .fill(color)
            .frame(width: 3, height: height)
    }
}

private extension WMetric {
    static let serveBarGeometry = ServeBarGeometry(
        zoneWidth: WMetric.serveBarHalfWidth - 2 * WMetric.serveBarInset,
        barHeight: WMetric.serveBarZoneHeight,
        singleWidth: 34,
        doubleWidth: 15,
        doubleGap: 4,
        cornerRadius: WMetric.barRadius
    )
}
