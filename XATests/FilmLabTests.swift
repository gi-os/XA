import XCTest
import CoreImage
@testable import XA

final class FilmLabTests: XCTestCase {
    func testSpeedsPushAndPull() {
        let s = FilmStock.stock("bowery400")!
        XCTAssertEqual(s.ei(0), 400)
        XCTAssertEqual(s.ei(1), 800)
        XCTAssertEqual(s.ei(2), 1600)
        XCTAssertEqual(s.ei(-1), 200)
        XCTAssertEqual(FilmStock.stock("canal500t")!.ei(1), 1000)
        XCTAssertEqual(FilmStock.stock("chelsea100")!.ei(-2), 25)
        XCTAssertEqual(FilmStock.stock("ludlow1600")!.ei(2), 6400)
    }

    func testDXChangesWithSpeed() {
        let a = FilmStock.dx(400), b = FilmStock.dx(800)
        XCTAssertEqual(a.count, 12)
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(a[0] && a[6], "contacts are always silver")
    }

    func testPushIsClampedAndOldStacksLoad() throws {
        var st = Stack(simID: "bowery400")
        st.push = 5
        XCTAssertEqual(st.push, 2)
        st.push = 0
        XCTAssertNil(st.pushStops)
        let old = try JSONDecoder().decode(Stack.self, from: Data(#"{"simID":"nocturne","look":0,"shape":0}"#.utf8))
        XCTAssertEqual(old.push, 0)
    }

    func testEveryStockHasTablesAndDevelops() {
        // An 18% grey card in linear light (Core Image's working space), read back linear.
        let lin = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let grey = CIImage(color: CIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1, colorSpace: lin)!)
            .cropped(to: CGRect(x: 0, y: 0, width: 96, height: 72))
        let ctx = CIContext(options: [.workingColorSpace: lin])
        for st in FilmStock.all {
            XCTAssertNotNil(FilmLab.tables(st.id), st.id)
            for push in [-1, 0, 1] {
                let out = FilmLab.develop(grey, stock: st, push: push, preview: false, seed: 3)
                XCTAssertEqual(out.extent, grey.extent, st.id)
                var px = [Float](repeating: 0, count: 4)
                ctx.render(out, toBitmap: &px, rowBytes: 16, bounds: CGRect(x: 48, y: 36, width: 1, height: 1), format: .RGBAf, colorSpace: lin)
                // An 18% grey card prints as 18% grey at any push: the lab prints a pushed roll back.
                XCTAssertEqual(px[1], 0.18, accuracy: 0.045, "\(st.id) push \(push) mid grey")
                for c in 0..<3 {
                    XCTAssertTrue(px[c].isFinite, "\(st.id) push \(push)")
                    XCTAssertGreaterThan(px[c], 0.0, "\(st.id) push \(push) not black")
                    XCTAssertLessThan(px[c], 1.0, "\(st.id) push \(push) not white")
                }
            }
        }
    }

    func testEveryStockHasAFaceAtEverySpeed() {
        for st in FilmStock.all {
            for push in FilmStock.pushRange {
                XCTAssertNotNil(FilmLab.bundle.url(forResource: "box_\(st.id)_\(st.ei(push))", withExtension: "jpg"), "\(st.id) EI \(st.ei(push))")
            }
        }
    }

    func testStocksAreFilmBoxes() {
        let ids = Sim.presets.compactMap { $0.stock }
        XCTAssertEqual(Set(ids), Set(FilmStock.all.map { $0.id }))
    }
}
