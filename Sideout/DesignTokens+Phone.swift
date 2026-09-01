import SwiftUI

enum PColor {
    static let bgBoard = Color(hex: 0x0B0B0C)
    static let bgApp = Color.black
    static let card = Color(hex: 0x1C1C1E)
    static let control = Color(hex: 0x2C2C2E)
    static let scoreLive = Color.white
    static let scoreIdle = Color(hex: 0x5B5B60)
    static let label = Color(hex: 0xF2F2F4)
    static let serve = Color(hex: 0xFFB020)
    static let meta = Color(hex: 0x3A3A3C)
    static let secondary = Color(hex: 0x8E8E93)
    static let warnBg = Color(hex: 0x1C1508)
    static let warnFg = Color(hex: 0xC98A18)
}

enum PType {
    static let boardScore = Font.system(size: 230, weight: .bold, design: .rounded)
    static let boardTeam = Font.system(size: 26, weight: .bold)
    static let boardBand = Font.system(size: 24, weight: .heavy)
    static let boardFooter = Font.system(size: 17, weight: .bold)
    static let boardWarn = Font.system(size: 11, weight: .bold)
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let rowLabel = Font.system(size: 17, weight: .regular)
    static let rowValue = Font.system(size: 17, weight: .regular)
    static let button = Font.system(size: 17, weight: .semibold)
    static let sectionHeader = Font.system(size: 13, weight: .semibold)
    static let segment = Font.system(size: 14, weight: .semibold)
}

enum PMetric {
    static let boardPaddingTop: CGFloat = 26
    static let boardPaddingBottom: CGFloat = 20
    static let panelSpacing: CGFloat = 18
    static let serveBarZoneWidth: CGFloat = 330
    static let serveBarZoneHeight: CGFloat = 22
    static let listMargin: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let groupRadius: CGFloat = 14
    static let segmentTrackRadius: CGFloat = 9
    static let pillRadius: CGFloat = 7
    static let barRadius: CGFloat = 5

    static let serveBarGeometry = ServeBarGeometry(
        zoneWidth: serveBarZoneWidth,
        barHeight: serveBarZoneHeight,
        singleWidth: 132,
        doubleWidth: 66,
        doubleGap: 10,
        cornerRadius: barRadius
    )
}
