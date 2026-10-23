import CoreGraphics
import Foundation

/// How the phone is held, as one camera-independent number: the clockwise quarter turns from a
/// portrait-upright picture (0 portrait, 90 top to the right, 180 upside down, 270 top to the
/// left). The viewfinder, the photo and VIDEO all take it from here.
///
/// It comes from gravity: whichever edge of the phone points down. The back camera's rotation
/// coordinator (90 for a portrait hold) only stands in when there's no gravity reading: on the
/// Lock Screen camera it kept the hold the phone had when the camera opened, so landscape shots
/// came out portrait and portrait ones sideways. Neither depends on how the selfie camera's
/// sensor is mounted. Like the system Camera, a phone held flat (pointing at a table, or up at a
/// ceiling) keeps the last hold it was sure of.
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

    /// iPhone Duo: how far the viewfinder's picture turns, clockwise, on the screen it is on. The
    /// frames come upright for the phone's own portrait (`portraitAngle`); the inner display held
    /// tall is that portrait on its side. A rotation coordinator given a layer on the screen says
    /// the angle the frames would need there (`a`): the difference is the turn. A selfie frame is
    /// mirrored, so it turns the other way. No reading, no turn.
    static func finderTurn(preview a: CGFloat?, front: Bool) -> CGFloat {
        guard let a else { return 0 }
        let d = norm(a - portraitAngle)
        return front ? norm(360 - d) : d
    }

    /// Gravity's z (out of the screen) says the phone is nearly horizontal: which way is up can't
    /// be told. In above 0.85 (about 32° from flat), out below 0.75, so it doesn't flicker.
    static func isFlat(z: Double, was: Bool) -> Bool { abs(z) > (was ? 0.75 : 0.85) }

    /// The hold from gravity in the phone's own frame (x toward the right edge, y toward the top,
    /// in g, the way CoreMotion reports it): the edge pointing most down. Upright, gravity runs
    /// down the screen (y = -1): 0. The left edge down is the top to the right: 90. Top down: 180.
    /// The right edge down is the top to the left: 270. Near a diagonal it keeps `was` until the
    /// new edge is clearly lower (about 5° past it), so a shot at 45° doesn't flip-flop.
    static func turn(gravityX x: Double, y: Double, was: CGFloat? = nil) -> CGFloat {
        let fresh: CGFloat = abs(y) >= abs(x) ? (y <= 0 ? 0 : 180) : (x < 0 ? 90 : 270)
        guard let was, was != fresh else { return fresh }
        let down: Double
        switch norm(was) {
        case 0: down = -y
        case 90: down = -x
        case 180: down = y
        default: down = x
        }
        let most = max(abs(x), abs(y))
        return down > most * 0.82 ? norm(was) : fresh
    }
}

/// How the phone is held, and the last hold it was sure of. Keep under CameraModel's lock.
struct HoldState: Equatable {
    /// The newest hold from the coordinator.
    private(set) var raw: CGFloat?
    /// The newest hold from gravity while the phone was not flat. Once there is one, the
    /// coordinator only stands in when gravity stops coming.
    private(set) var fromGravity: CGFloat?
    /// The newest hold while the phone was not flat.
    private(set) var confident: CGFloat?
    private(set) var flat = false
    var turn: CGFloat { confident ?? raw ?? 0 }

    mutating func coordinator(turn t: CGFloat) {
        raw = t
        if !flat && fromGravity == nil { confident = t }
    }

    /// Gravity in the phone's frame (see `Hold.turn(gravityX:y:was:)`): the hold, unless the
    /// phone is flat, when the last one stays.
    mutating func gravity(x: Double, y: Double, z: Double) {
        flat = Hold.isFlat(z: z, was: flat)
        guard !flat else { return }
        let t = Hold.turn(gravityX: x, y: y, was: fromGravity)
        fromGravity = t
        confident = t
    }

    /// Gravity's x and y stop counting (iPhone Duo open on the inner display, where the motion
    /// frame needn't be the camera's): from here the coordinator says the hold again.
    mutating func forgetGravity() {
        fromGravity = nil
        flat = false
        if let raw { confident = raw }
    }

    /// Only how flat the phone is (no x and y to go on): the coordinator decides.
    mutating func gravity(z: Double) {
        flat = Hold.isFlat(z: z, was: flat)
        // picked up again: the coordinator is trusted again
        if !flat, fromGravity == nil, let r = raw { confident = r }
    }
}
