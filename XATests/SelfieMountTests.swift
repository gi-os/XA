import Testing
import CoreGraphics
@testable import XA

/// How the selfie camera's sensor is mounted, from the two cameras' rotation coordinators.
struct SelfieMountTests {
    /// The coordinators' horizon-level capture angles at each hold (0 upright, 90 top to the right,
    /// 180 upside down, 270 top to the left): the back camera's is 90 + the hold, the selfie
    /// camera's turns the other way, from 90 upright on iPhone 16 and before, from 0 on iPhone 17.
    static func angles(frontUpright: CGFloat, hold: CGFloat) -> (front: CGFloat, back: CGFloat) {
        (Hold.norm(frontUpright - hold), Hold.norm(90 + hold))
    }

    @Test(arguments: [CGFloat(0), 90, 180, 270])
    func iPhone16AndBeforeKeepTheOldTurn(hold: CGFloat) {
        let a = Self.angles(frontUpright: 90, hold: hold)
        #expect(SelfieMount.from(front: a.front, back: a.back) == 270)
    }

    @Test(arguments: [CGFloat(0), 90, 180, 270])
    func iPhone17SensorSitsAQuarterTurnRound(hold: CGFloat) {
        let a = Self.angles(frontUpright: 0, hold: hold)
        #expect(SelfieMount.from(front: a.front, back: a.back) == 0)
    }

    /// The original selfie's Exif tag at the old mount is what it always was, for every hold.
    @Test func exifTagsAtTheOldMount() {
        let tags = [CGFloat(0), 90, 180, 270].map { SelfieMount.exifTag(turnedThenMirrored: 270 + $0) }
        #expect(tags == [7, 2, 5, 4])
    }
}
