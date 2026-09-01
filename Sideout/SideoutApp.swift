import SwiftUI
import AVFoundation
import UIKit

@main
struct SideoutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var connectivity: PhoneConnectivityManager
    @StateObject private var appModel: PhoneAppModel

    init() {
        let connectivity = PhoneConnectivityManager()
        _connectivity = StateObject(wrappedValue: connectivity)
        _appModel = StateObject(wrappedValue: PhoneAppModel(connectivity: connectivity))

        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environmentObject(connectivity)
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
        }
    }
}

struct PhoneRootView: View {
    @EnvironmentObject private var appModel: PhoneAppModel
    @EnvironmentObject private var connectivity: PhoneConnectivityManager

    var body: some View {
        ZStack {
            switch appModel.screen {
            case .setup:
                SetupView()
            case .scoreboard:
                ScoreboardView()
                GameOverOverlay()
            case .settings:
                SettingsView()
            }
        }
        .onChange(of: appModel.screen, initial: true) { _, screen in
            lockOrientation(for: screen)
        }
        .onChange(of: appModel.appSettings.keepScreenAwake) { _, keepAwake in
            UIApplication.shared.isIdleTimerDisabled = keepAwake && appModel.screen == .scoreboard
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = appModel.appSettings.keepScreenAwake && appModel.screen == .scoreboard
        }
    }

    private func lockOrientation(for screen: PhoneScreen) {
        let mask: UIInterfaceOrientationMask = screen == .scoreboard ? .landscape : .portrait
        AppDelegate.orientationLock = mask
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        UIApplication.shared.isIdleTimerDisabled = appModel.appSettings.keepScreenAwake && screen == .scoreboard
    }
}
