import CoreGraphics
import Foundation

/// How the phone is held, as one camera-independent number: the clockwise quarter turns from a
/// portrait-upright picture (0 portrait, 90 top to the right, 180 upside down, 270 top to the
/// left). The viewfinder, the photo and VIDEO all take it from here.
///
/// It is read from the back camera's rotation coordinator, whose angle is 90 for a portrait
/// hold, also while the selfie camera is in use, so the selfie camera never depends on how its
/// own sensor is mounted. Like the system Camera, a phone held flat (pointing at a table, or up
/// at a ceiling) keeps the last hold it was sure of.
enum Hold {
    /// The back camera's connection angle for a portrait hold.
    static let portraitAngle: CGFloat = 90

    static func norm(_ d: CGFloat) -> CGFloat {
        let q = (d / 90).rounded() * 90
        let r = q.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// The back camera's capture angle → the hold.
    static func turn(backAngle a: CGFloat) -> CGFloat { norm(a - portraitAngle) }
    /// The hold → the back camera's photo connection angle.
    static func backAngle(turn t: CGFloat) -> CGFloat { norm(portraitAngle + t) }
    /// The turn for a frame that is already upright for a portrait hold. A selfie frame is also
    /// mirrored, so it turns the other way: turned, then mirrored, is mirrored, then turned back.
    static func frameTurn(_ t: CGFloat, front: Bool) -> CGFloat { front ? norm(360 - t) : t }

    /// Gravity's z (out of the screen) says the phone is nearly horizontal: which way is up can't
    /// be told. In above 0.85 (about 32° from flat), out below 0.75, so it doesn't flicker.
    static func isFlat(z: Double, was: Bool) -> Bool { abs(z) > (was ? 0.75 : 0.85) }
}

/// The hold the camera reports, and the last one it was sure of. Keep under CameraModel's lock.
struct HoldState: Equatable {
    /// The newest hold from the coordinator.
    private(set) var raw: CGFloat?
    /// The newest hold while the phone was not flat.
    private(set) var confident: CGFloat?
    private(set) var flat = false
    var turn: CGFloat { confident ?? raw ?? 0 }

    mutating func coordinator(turn t: CGFloat) {
        raw = t
        if !flat { confident = t }
    }

    mutating func gravity(z: Double) {
        flat = Hold.isFlat(z: z, was: flat)
        // picked up again: the coordinator is trusted again
        if !flat, let r = raw { confident = r }
    }
}
