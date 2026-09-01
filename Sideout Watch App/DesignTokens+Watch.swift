import SwiftUI

enum WColor {
    static let bg = Color.black
    static let scoreLive = Color.white
    static let scoreIdle = Color(hex: 0x5B5B60)
    static let serve = Color(hex: 0xFFB020)
    static let onServe = Color.black
    static let chrome = Color(hex: 0x6E6E73)
    static let chromeDim = Color(hex: 0x48484A)
    static let hairline = Color(hex: 0x242426)
    static let scrub = Color(hex: 0x35C8E8)
    static let scrubDim = Color(hex: 0x1F5C68)
    static let aodScore = Color.white.opacity(0.42)
}

enum WType {
    static func score(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 96, weight: weight, design: .rounded)
    }
    static let finalScore = Font.system(size: 56, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 15, weight: .bold)
    static let rowLabel = Font.system(size: 12, weight: .regular)
    static let rowValue = Font.system(size: 12, weight: .semibold)
    static let cardSub = Font.system(size: 10, weight: .semibold)
    static let header = Font.system(size: 10, weight: .semibold)
    static let footer = Font.system(size: 10, weight: .semibold)
    static let footerAmber = Font.system(size: 10, weight: .bold)
}

enum WMetric {
    static let screenPaddingTop: CGFloat = 14
    static let screenPaddingBottom: CGFloat = 12
    static let screenPaddingHorizontal: CGFloat = 12
    static let gutterWidth: CGFloat = 10
    static let gutterHeight: CGFloat = 86
    static let serveBarZoneHeight: CGFloat = 9
    static let serveBarHalfWidth: CGFloat = 83
    static let serveBarInset: CGFloat = 6
    static let cardRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 13
    static let barRadius: CGFloat = 2
}
