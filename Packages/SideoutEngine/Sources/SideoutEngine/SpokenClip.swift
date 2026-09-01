import Foundation

/// The closed vocabulary of pre-rendered audio clips. Nothing outside this
/// enum is speakable — see the design brief's "Spoken vocabulary" section.
public enum SpokenClip: Equatable, Sendable {
    case number(Int) // 0...25
    case sideOut
    case game
    case us
    case them
    case gamePoint
    case openingZeroZeroTwo

    /// The bundled clip's resource name (without extension).
    public var clipName: String {
        switch self {
        case .number(let n): return Self.numberWords[n] ?? "\(n)"
        case .sideOut: return "side_out"
        case .game: return "game"
        case .us: return "us"
        case .them: return "them"
        case .gamePoint: return "game_point"
        case .openingZeroZeroTwo: return "zero_zero_two"
        }
    }

    /// Best-effort English rendering, for on-screen debug or VoiceOver — not
    /// used for the pre-rendered audio path itself.
    public var displayWord: String {
        switch self {
        case .number(let n): return Self.numberWords[n] ?? "\(n)"
        case .sideOut: return "side out"
        case .game: return "game"
        case .us: return "us"
        case .them: return "them"
        case .gamePoint: return "game point"
        case .openingZeroZeroTwo: return "zero zero two"
        }
    }

    private static let numberWords: [Int: String] = [
        0: "zero", 1: "one", 2: "two", 3: "three", 4: "four", 5: "five",
        6: "six", 7: "seven", 8: "eight", 9: "nine", 10: "ten",
        11: "eleven", 12: "twelve", 13: "thirteen", 14: "fourteen", 15: "fifteen",
        16: "sixteen", 17: "seventeen", 18: "eighteen", 19: "nineteen", 20: "twenty",
        21: "twenty-one", 22: "twenty-two", 23: "twenty-three", 24: "twenty-four", 25: "twenty-five"
    ]
}
