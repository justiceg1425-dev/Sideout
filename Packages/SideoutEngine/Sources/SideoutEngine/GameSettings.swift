import Foundation

public enum ScoringFormat: String, Codable, Sendable, CaseIterable {
    case sideOut
    case rally
}

public enum PlayerCount: String, Codable, Sendable, CaseIterable {
    case singles
    case doubles
}

public enum CourtSide: String, Codable, Sendable {
    case right
    case left
}

public struct GameSettings: Codable, Equatable, Sendable {
    public var format: ScoringFormat
    public var players: PlayerCount
    public var pointsToWin: Int
    public var winBy: Int
    public var hardCap: Int?
    public var firstServer: Team
    public var teamNames: [Team: String]

    public init(
        format: ScoringFormat = .sideOut,
        players: PlayerCount = .doubles,
        pointsToWin: Int = 11,
        winBy: Int = 2,
        hardCap: Int? = nil,
        firstServer: Team = .a,
        teamNames: [Team: String] = [.a: "Us", .b: "Them"]
    ) {
        self.format = format
        self.players = players
        self.pointsToWin = pointsToWin
        self.winBy = winBy
        self.hardCap = hardCap
        self.firstServer = firstServer
        self.teamNames = teamNames
    }

    public static let `default` = GameSettings()

    public func name(for team: Team) -> String {
        teamNames[team] ?? (team == .a ? "Us" : "Them")
    }

    /// The "Same as last time" subtitle: "Side-out · doubles · 11 · we serve"
    public var summary: String {
        let formatName = format == .sideOut ? "Side-out" : "Rally"
        let playersName = players == .singles ? "singles" : "doubles"
        let serveName = firstServer == .a ? "we serve" : "they serve"
        return "\(formatName) · \(playersName) · \(pointsToWin) · \(serveName)"
    }

    /// Scoreboard footer, e.g. "SIDE-OUT · TO 11 · WIN BY 2" or "SIDE-OUT · TO 21 · CAP 25"
    public var footerCaption: String {
        let formatName = format == .sideOut ? "SIDE-OUT" : "RALLY"
        if let hardCap {
            return "\(formatName) · TO \(pointsToWin) · CAP \(hardCap)"
        }
        return "\(formatName) · TO \(pointsToWin) · WIN BY \(winBy)"
    }
}
