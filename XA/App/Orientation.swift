import SwiftUI
import UIKit

/// The camera stays portrait, like the system camera; the photo viewer turns with the phone.
/// Info.plist allows every orientation and this decides, screen by screen.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var allowed: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.allowed
    }
}

enum Orientation {
    /// Let the screen turn (the viewer) or hold it upright and turn it back (the camera).
    static func allow(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.allowed = mask
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for w in ws.windows { w.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
            if mask == .portrait { ws.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) }
        }
    }
}
