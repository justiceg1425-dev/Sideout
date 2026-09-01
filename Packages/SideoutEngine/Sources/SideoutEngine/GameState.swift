import Foundation

public struct GameState: Equatable, Sendable {
    /// Indexed by team: points[0] is .a, points[1] is .b.
    public var points: [Int]
    public var servingTeam: Team
    public var serverNumber: Int
    public var serverCourtSide: CourtSide
    public var lastRallyWasSideOut: Bool
    public var winner: Team?
    public var ralliesPlayed: Int

    public subscript(team: Team) -> Int {
        points[team == .a ? 0 : 1]
    }

    public var receivingTeam: Team { servingTeam.opponent }
}

public enum RallyOutcome: Equatable, Sendable {
    case pointScored(by: Team)
    case serverAdvanced
    case sideOut(to: Team)
}

public enum PointSignal: Equatable, Sendable {
    case gamePoint(for: Team)
    case matchPoint(for: Team)
}
