import Foundation

public enum Team: String, Codable, CaseIterable, Hashable, Sendable {
    case a
    case b

    public var opponent: Team { self == .a ? .b : .a }
}
