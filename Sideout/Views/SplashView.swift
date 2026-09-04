import SwiftUI

/// Shown for a beat on launch so the app doesn't feel like it's just
/// snapping straight to Setup — there's no real async work to wait on
/// (WCSession activation and settings load are both effectively
/// instant), this is purely a branded moment before the first screen.
struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            Image("SideoutMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .scaleEffect(pulse ? 1.0 : 0.94)
                .opacity(pulse ? 1.0 : 0.7)

            Text("SIDEOUT")
                .font(.system(size: 20, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(.white)

            ProgressView()
                .tint(PColor.serve)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PColor.bgApp.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
