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
        .onAppear {
            // Just answer the system's own orientation query correctly
            // from the start (AppDelegate.orientationLock feeds
            // application(_:supportedInterfaceOrientationsFor:)) — don't
            // force a geometry update this early. requestGeometryUpdate
            // called before the window scene is fully active is a known
            // source of a launch that boots but renders a blank white
            // window, which is exactly what calling it from an
            // onChange(..., initial: true) at launch risked.
            AppDelegate.orientationLock = orientationMask(for: appModel.screen)
            UIApplication.shared.isIdleTimerDisabled = appModel.appSettings.keepScreenAwake && appModel.screen == .scoreboard
        }
        .onChange(of: appModel.screen) { _, screen in
            lockOrientation(for: screen)
        }
        .onChange(of: appModel.appSettings.keepScreenAwake) { _, keepAwake in
            UIApplication.shared.isIdleTimerDisabled = keepAwake && appModel.screen == .scoreboard
        }
    }

    private func orientationMask(for screen: PhoneScreen) -> UIInterfaceOrientationMask {
        screen == .scoreboard ? .landscape : .portrait
    }

    /// Only called from screen-change navigation, after the app is
    /// already active — safe timing for `requestGeometryUpdate`, unlike
    /// during launch itself.
    private func lockOrientation(for screen: PhoneScreen) {
        let mask = orientationMask(for: screen)
        AppDelegate.orientationLock = mask
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
        UIApplication.shared.isIdleTimerDisabled = appModel.appSettings.keepScreenAwake && screen == .scoreboard
    }
}
