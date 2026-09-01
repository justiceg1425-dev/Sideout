import Foundation

enum AnnounceMode: String, Codable, CaseIterable {
    case everyRally
    case scoreChangesAndSideOutsOnly

    var label: String {
        switch self {
        case .everyRally: return "Every rally"
        case .scoreChangesAndSideOutsOnly: return "Score changes and side-outs only"
        }
    }
}

enum ReconnectBehavior: String, Codable, CaseIterable {
    case latestOnly
    case nothing

    var label: String {
        switch self {
        case .latestOnly: return "Latest only"
        case .nothing: return "Nothing"
        }
    }
}

/// Phone-only preferences: voice, announce mode, output, reconnect
/// behaviour. `GameSettings` (format/players/points/cap/first-serve) is
/// shared with the watch via `SettingsStore`; this is not.
struct AppSettings: Codable, Equatable {
    var voiceName: String = "Umpire · male"
    var volume: Double = 0.8
    var announceMode: AnnounceMode = .everyRally
    var announceGamePoint: Bool = false
    var audioOutputName: String? // nil = no Bluetooth speaker connected
    var keepScreenAwake: Bool = true
    var reconnectBehavior: ReconnectBehavior = .latestOnly

    static let `default` = AppSettings()
}

enum AppSettingsStore {
    private static let key = "com.sideout.appSettings"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
