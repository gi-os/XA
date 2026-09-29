import AVFoundation
import Vision
import CoreGraphics

/// AF-S locks on the half-press; AF-C keeps tracking while held.
enum AFMode: String, CaseIterable, Codable { case single, continuous
    var label: String { self == .single ? "AF-S" : "AF-C" }
}

/// Where focus looks: the camera's own choice, a point you tap, or the nearer eye.
enum AFArea: String, CaseIterable, Codable { case auto, point, eye
    var label: String {
        switch self {
        case .auto: return "Auto"
        case .point: return "Point"
        case .eye: return "Eye"
        }
    }
}

enum FocusGeometry {
    /// View point (0…1, top-left, portrait viewfinder) to the device's point of interest,
    /// which is in the sensor's landscape frame. The front camera's viewfinder is mirrored.
    static func devicePoint(fromView p: CGPoint, front: Bool) -> CGPoint {
        let x = min(1, max(0, p.x)), y = min(1, max(0, p.y))
        return front ? CGPoint(x: y, y: x) : CGPoint(x: y, y: 1 - x)
    }

    /// Vision's normalized point (bottom-left origin) on the portrait frame, to a view point.
    static func viewPoint(fromVision p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: 1 - p.y)
    }
}

/// Finds the nearer eye in a frame: the eye whose outline is widest belongs to the side of the
/// face turned toward the camera.
enum EyeFinder {
    static func nearerEye(in pixelBuffer: CVPixelBuffer) -> CGPoint? {
        let req = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        try? handler.perform([req])
        guard let faces = req.results, let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let lm = face.landmarks else { return nil }
        let box = face.boundingBox
        func centre(_ r: VNFaceLandmarkRegion2D?) -> (CGPoint, CGFloat)? {
            guard let r, r.pointCount > 0 else { return nil }
            let pts = r.normalizedPoints
            let xs = pts.map { CGFloat($0.x) }, ys = pts.map { CGFloat($0.y) }
            let cx = (xs.min()! + xs.max()!) / 2, cy = (ys.min()! + ys.max()!) / 2
            let width = xs.max()! - xs.min()!
            return (CGPoint(x: box.minX + cx * box.width, y: box.minY + cy * box.height), width)
        }
        let l = centre(lm.leftEye), r = centre(lm.rightEye)
        let pick: CGPoint?
        switch (l, r) {
        case let (a?, b?): pick = a.1 >= b.1 ? a.0 : b.0
        case let (a?, nil): pick = a.0
        case let (nil, b?): pick = b.0
        default: pick = CGPoint(x: box.midX, y: box.midY + box.height * 0.15)
        }
        return pick.map(FocusGeometry.viewPoint(fromVision:))
    }
}

/// Two presses: the first locks focus, the second fires the moment it lands. Or one press, straight away.
enum ShutterStyle: String, CaseIterable, Codable { case twoPress, onePress }
