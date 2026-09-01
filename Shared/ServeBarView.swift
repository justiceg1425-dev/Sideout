import SwiftUI
import SideoutEngine

/// The serve bar: the app's one novel component, carrying all three
/// dimensions of serve state (which side, server 1 vs 2, court half) with
/// no legend and no reliance on hue. See the design brief's "serve bar"
/// section for the full rationale — presence, segment count, and position
/// are pre-attentive, so the eye resolves them before it resolves a glyph.
struct ServeBarGeometry {
    let zoneWidth: CGFloat
    let barHeight: CGFloat
    let singleWidth: CGFloat
    let doubleWidth: CGFloat
    let doubleGap: CGFloat
    let cornerRadius: CGFloat
}

struct ServeBarView: View {
    let isServingHalf: Bool
    let serverNumber: Int
    let courtSide: CourtSide
    let geometry: ServeBarGeometry
    let color: Color
    let hollow: Bool

    var body: some View {
        HStack(spacing: 0) {
            if courtSide == .right { Spacer(minLength: 0) }
            if isServingHalf {
                bars
            }
            if courtSide == .left { Spacer(minLength: 0) }
        }
        .frame(width: geometry.zoneWidth, height: geometry.barHeight)
    }

    @ViewBuilder
    private var bars: some View {
        if serverNumber >= 2 {
            HStack(spacing: geometry.doubleGap) {
                bar(width: geometry.doubleWidth)
                bar(width: geometry.doubleWidth)
            }
        } else {
            bar(width: geometry.singleWidth)
        }
    }

    @ViewBuilder
    private func bar(width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: geometry.cornerRadius)
        Group {
            if hollow {
                shape.strokeBorder(color, lineWidth: 1)
            } else {
                shape.fill(color)
            }
        }
        .frame(width: width, height: geometry.barHeight)
    }
}
