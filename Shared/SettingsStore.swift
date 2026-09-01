import Foundation
import SideoutEngine

/// Persists the last-used `GameSettings` for the "Same as last time" path on
/// both the watch's New Game screen and the phone's Setup screen.
public enum SettingsStore {
    private static let key = "com.sideout.lastGameSettings"

    public static func load() -> GameSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(GameSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    public static func save(_ settings: GameSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
