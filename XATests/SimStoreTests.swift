import XCTest
@testable import XA

/// Custom films are never lost to a list that won't decode (see SimStore).
final class SimStoreTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "SimStoreTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func sim(_ name: String) -> Sim {
        var s = Sim.neutral
        s.id = "custom-\(name)"
        s.name = name
        return s
    }

    func testAFilmThatCantBeReadDoesntTakeTheOthersWithIt() throws {
        let d = defaults()
        SimStore.save([sim("one"), sim("two")], d)
        // a film written by a future XA: a field this one doesn't know the type of
        var list = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(d.data(forKey: SimStore.key))) as? [[String: Any]])
        var broken = list[0]
        broken["box"] = "a shape this version has never seen"
        list.insert(broken, at: 1)
        let data = try JSONSerialization.data(withJSONObject: list)
        d.set(data, forKey: SimStore.key)

        let loaded = SimStore.load(d)
        XCTAssertEqual(loaded.map(\.name), ["one", "two"])
        XCTAssertEqual(d.data(forKey: SimStore.backupKey), data, "the whole list is kept as it was")
    }

    func testAListThatReadsKeepsNoBackup() {
        let d = defaults()
        SimStore.save([sim("one")], d)
        XCTAssertEqual(SimStore.load(d).map(\.name), ["one"])
        XCTAssertNil(d.data(forKey: SimStore.backupKey))
    }

    /// A custom film as XA 1.0 saves it: every later version must read it.
    func testA1_0FilmStillDecodes() throws {
        let saved = try JSONEncoder().encode([sim("golden")])
        let json = String(decoding: saved, as: UTF8.self)
        let back = SimStore.decode(Data(json.utf8))
        XCTAssertEqual(back.lost, 0)
        XCTAssertEqual(back.sims.first?.name, "golden")
    }
}
