import AVFoundation
import CoreGraphics

/// iPhone Duo, the foldable. Closed, XA is the phone camera on the outer display. Open and held
/// tall, the inner display is the back of a camera: the controls on the top half, the viewfinder
/// on the bottom half, nothing on the fold between them (see DuoCameraView).
enum Duo {
    /// This phone has the Duo's two front cameras, the outer one and the inner one.
    static let isDuo: Bool = {
        if #available(iOS 27.1, *) {
            let found = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInOuterUltraWideCamera, .builtInInnerUltraWideCamera],
                mediaType: .video, position: .unspecified)
            return !found.devices.isEmpty
        }
        return false
    }()

    /// A screen with room for the back of the camera above the viewfinder: the inner display held
    /// tall (669 × 951 points). No iPhone screen is near 560 points wide, and the outer display is
    /// 466, so the size alone tells.
    static func innerTall(_ size: CGSize) -> Bool {
        size.width >= 560 && size.height >= size.width * 1.2
    }

    /// Points kept clear either side of the fold.
    static let foldGap: CGFloat = 22
}
