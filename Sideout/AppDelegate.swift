import UIKit

/// The scoreboard is landscape-only (propped on a bench, read from the
/// baseline); setup and settings are portrait. `PhoneRootView` flips this
/// lock as it switches screens.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
