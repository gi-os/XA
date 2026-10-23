import CoreGraphics

/// iPhone Duo, the foldable. Closed, XA is the phone camera on the outer display. Open and held
/// tall, the inner display is the back of a camera: the controls on the top half, the viewfinder
/// on the bottom half, nothing on the fold between them (see DuoCameraView).
enum Duo {
    /// A screen with room for the back of the camera above the viewfinder: the inner display held
    /// tall (669 × 951 points). No iPhone screen is near 560 points wide, and the outer display is
    /// 466, so the size alone tells.
    static func innerTall(_ size: CGSize) -> Bool {
        size.width >= 560 && size.height >= size.width * 1.2
    }

    /// The inner display held sideways (951 × 669 points). It doesn't keep to XA's portrait
    /// lock, so the back of the camera is turned back to stand as it does held tall. No iPhone
    /// screen turned sideways is 560 points high.
    static func innerWide(_ size: CGSize) -> Bool {
        size.width >= 560 && size.height >= 560 && size.width > size.height
    }

    /// The outer display (or any phone screen as short): wider for its height than any iPhone
    /// (they are over 2:1), with room for a rail of controls beside the viewfinder.
    static func outer(_ size: CGSize) -> Bool {
        size.width > 0 && size.width < 560 && size.height < size.width * 1.7
    }

    /// The outer display's sidebar has the clock, battery and the camera light at its top: the
    /// rail in it starts below them.
    static let statusClearance: CGFloat = 96

    /// Points kept clear either side of the fold.
    static let foldGap: CGFloat = 22
}
