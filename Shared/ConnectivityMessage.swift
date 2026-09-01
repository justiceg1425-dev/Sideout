import Foundation
import SideoutEngine

/// The whole message sent watch -> phone. It carries the entire append-only
/// rally array rather than deltas — per the handoff, that's what makes
/// reconnection idempotent: the phone just replaces its replica wholesale.
public struct ConnectivityMessage: Codable, Equatable {
    public var settings: GameSettings
    public var rallyWinners: [Team]
    public var sentAt: Date

    public init(settings: GameSettings, rallyWinners: [Team], sentAt: Date = Date()) {
        self.settings = settings
        self.rallyWinners = rallyWinners
        self.sentAt = sentAt
    }

    public func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConnectivityError.encodingFailed
        }
        return dict
    }

    public static func from(dictionary: [String: Any]) throws -> ConnectivityMessage {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try JSONDecoder().decode(ConnectivityMessage.self, from: data)
    }
}

public enum ConnectivityError: Error {
    case encodingFailed
}
