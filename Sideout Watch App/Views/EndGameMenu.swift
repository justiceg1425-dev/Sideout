import SwiftUI

/// The only place a sheet is allowed, and never over the live scoring
/// screen itself — reached only via long press.
struct EndGameMenu: View {
    @EnvironmentObject private var controller: GameSessionController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Button("End game") {
                controller.endGame()
                dismiss()
            }
            .foregroundStyle(WColor.serve)

            Button("Switch sides") {
                dismiss()
            }
            .foregroundStyle(.white)

            Button("Resume") {
                controller.resumeFromMenu()
                dismiss()
            }
            .foregroundStyle(WColor.chrome)
        }
        .buttonStyle(.plain)
        .font(WType.cardTitle)
        .padding()
        .background(WColor.bg)
    }
}
