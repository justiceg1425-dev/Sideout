import Foundation
import SideoutEngine

/// Phone -> watch settings push (team names, and anything else edited on
/// the phone's Setup screen). The mirror image of `ConnectivityMessage`,
/// which only flows watch -> phone. `WCSession` application context is
/// directional and per-slot, so this doesn't collide with
/// `ConnectivityMessage` on the wire — each side has its own outgoing
/// context, delivered independently to the other side.
///
/// Without this, team names typed on the phone would only ever be saved
/// locally on the phone — the watch is what actually starts games and
/// constructs the authoritative `GameSettings`, so the phone has no way
/// to influence the next game without pushing settings across first.
public struct SettingsSync: Codable, Equatable {
    public var settings: GameSettings
    /// True when this push should start a game immediately on the watch,
    /// not just stash settings for later — set when the phone's own
    /// "Start game" buttons are what triggered the push, so both devices
    /// end up in a game together instead of the watch needing a separate
    /// manual tap.
    public var startNow: Bool
    public var sentAt: Date

    public init(settings: GameSettings, startNow: Bool = false, sentAt: Date = Date()) {
        self.settings = settings
        self.startNow = startNow
        self.sentAt = sentAt
    }

    public func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConnectivityError.encodingFailed
        }
        return dict
    }

    public static func from(dictionary: [String: Any]) throws -> SettingsSync {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try JSONDecoder().decode(SettingsSync.self, from: data)
    }
}
