import Foundation

/// The whole game is an append-only array of rally winners. Any point in
/// history is just a shorter prefix of that array, which is what makes
/// crown scrubbing cheap: `state(atRallyCount:)` replays a prefix rather
/// than maintaining separate undo state.
public final class Game {
    public let settings: GameSettings
    public private(set) var rallyWinners: [Team]

    public init(settings: GameSettings, rallyWinners: [Team] = []) {
        self.settings = settings
        self.rallyWinners = rallyWinners
    }

    public var rallyCount: Int { rallyWinners.count }

    /// The live state — the full rally history replayed to its end.
    public var state: GameState { state(atRallyCount: rallyWinners.count) }

    /// Replays the first `count` rallies and returns the resulting state.
    /// Used for both the live state (count == rallyCount) and crown
    /// scrubbing (count < rallyCount).
    public func state(atRallyCount count: Int) -> GameState {
        precondition(count >= 0 && count <= rallyWinners.count, "count out of range")

        var pointsA = 0
        var pointsB = 0
        var servingTeam = settings.firstServer
        // Doubles side-out opens at "0-0-2": the first serving side only
        // gets one server before the serve passes over.
        var serverNumber = (settings.format == .sideOut && settings.players == .doubles) ? 2 : 1
        var lastWasSideOut = false
        var winner: Team?

        func points(for team: Team) -> Int { team == .a ? pointsA : pointsB }
        func setPoints(_ value: Int, for team: Team) {
            if team == .a { pointsA = value } else { pointsB = value }
        }

        for winningTeam in rallyWinners.prefix(count) {
            guard winner == nil else { break }
            lastWasSideOut = false

            if settings.format == .rally {
                setPoints(points(for: winningTeam) + 1, for: winningTeam)
                servingTeam = winningTeam
                serverNumber = 1
            } else if winningTeam == servingTeam {
                setPoints(points(for: servingTeam) + 1, for: servingTeam)
            } else if serverNumber == 1 && settings.players == .doubles {
                serverNumber = 2
            } else {
                servingTeam = winningTeam
                serverNumber = 1
                lastWasSideOut = true
            }

            winner = Self.decideWinner(pointsA: pointsA, pointsB: pointsB, settings: settings)
        }

        let courtSide: CourtSide = points(for: servingTeam).isMultiple(of: 2) ? .right : .left

        return GameState(
            points: [pointsA, pointsB],
            servingTeam: servingTeam,
            serverNumber: serverNumber,
            serverCourtSide: courtSide,
            lastRallyWasSideOut: lastWasSideOut,
            winner: winner,
            ralliesPlayed: count
        )
    }

    private static func decideWinner(pointsA: Int, pointsB: Int, settings: GameSettings) -> Team? {
        for team in Team.allCases {
            let mine = team == .a ? pointsA : pointsB
            let theirs = team == .a ? pointsB : pointsA
            if let cap = settings.hardCap, mine >= cap {
                return team
            }
            if mine >= settings.pointsToWin && (mine - theirs) >= settings.winBy {
                return team
            }
        }
        return nil
    }

    /// Records who won the rally and appends it to history. No-ops (returns
    /// nil) if the game already has a winner.
    @discardableResult
    public func recordRally(wonBy team: Team) -> RallyOutcome? {
        guard state.winner == nil else { return nil }
        let before = state
        rallyWinners.append(team)
        let after = state
        return Self.classify(before: before, after: after, wonBy: team, settings: settings)
    }

    /// Removes the most recently recorded rally, if any.
    public func undo() {
        guard !rallyWinners.isEmpty else { return }
        rallyWinners.removeLast()
    }

    /// Classifies the outcome of a single recorded rally by diffing the
    /// state before and after. Exposed publicly so a replica (the phone,
    /// replaying a state update it received over WatchConnectivity) can
    /// classify a rally it didn't itself record.
    public static func classify(before: GameState, after: GameState, wonBy team: Team, settings: GameSettings) -> RallyOutcome {
        if after.points != before.points {
            return .pointScored(by: team)
        }
        if settings.format == .sideOut && settings.players == .doubles && after.servingTeam == before.servingTeam {
            return .serverAdvanced
        }
        return .sideOut(to: after.servingTeam)
    }

    /// Whether `team` winning the *next* rally would end the game, and
    /// whether that would be by reaching a hard cap outright (match point)
    /// or the ordinary win-by-margin target (game point). Only the side
    /// that can actually score next is eligible: the serving side under
    /// side-out scoring, either side under rally scoring.
    public func pointSignal(for team: Team) -> PointSignal? {
        let s = state
        guard s.winner == nil else { return nil }
        if settings.format == .sideOut && s.servingTeam != team { return nil }

        let mine = s[team]
        if let cap = settings.hardCap, mine + 1 == cap {
            return .matchPoint(for: team)
        }
        let theirs = s[team.opponent]
        if mine + 1 >= settings.pointsToWin && (mine + 1 - theirs) >= settings.winBy {
            return .gamePoint(for: team)
        }
        return nil
    }

    /// Assembles the spoken clip sequence for the current state, per the
    /// design brief's assembly rules. Callers that only want to speak on
    /// score-changing rallies (the "score changes and side-outs only"
    /// setting) filter on `RallyOutcome` themselves before calling this.
    public func spokenCallout() -> [SpokenClip] {
        let s = state

        if let winner = s.winner {
            return [.game, teamClip(winner)] + numberClips(for: [s[winner], s[winner.opponent]])
        }

        if s.ralliesPlayed == 0 && settings.format == .sideOut && settings.players == .doubles {
            return [.openingZeroZeroTwo]
        }

        var clips: [SpokenClip] = []
        if s.lastRallyWasSideOut {
            clips.append(.sideOut)
        }
        if pointSignal(for: s.servingTeam) != nil {
            clips.append(.gamePoint)
        }
        clips.append(contentsOf: numberClips(for: [s[s.servingTeam], s[s.receivingTeam]]))
        if settings.format == .sideOut && settings.players == .doubles {
            clips.append(.number(s.serverNumber))
        }
        return clips
    }

    private func teamClip(_ team: Team) -> SpokenClip { team == .a ? .us : .them }
    private func numberClips(for values: [Int]) -> [SpokenClip] { values.map { .number($0) } }
}
