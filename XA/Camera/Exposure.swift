import Foundation

/// Ported from Roll's Exposure.kt: the shutter and ISO dials, the priority modes and the
/// rebalance that keeps the metered exposure when one half is held.
enum ExposureMode: String, CaseIterable, Codable {
    case auto, shutter, iso, manual

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .shutter: return "Shutter"
        case .iso: return "ISO"
        case .manual: return "Manual"
        }
    }
    var manualAe: Bool { self != .auto }
    var holdsShutter: Bool { self == .shutter || self == .manual }
    var holdsIso: Bool { self == .iso || self == .manual }

    static func from(holdsShutter s: Bool, holdsIso i: Bool) -> ExposureMode {
        switch (s, i) {
        case (true, true): return .manual
        case (true, false): return .shutter
        case (false, true): return .iso
        default: return .auto
        }
    }
}

enum Exposure {
    static let nanosPerSecond: Int64 = 1_000_000_000
    /// Denominators, fast to slow: 1/8000 … 1".
    static let shutterStops: [Int64] = [8000, 4000, 2000, 1000, 500, 250, 125, 60, 30, 15, 8, 4, 2, 1]
    static let isoStops: [Int] = [50, 100, 200, 400, 800, 1600, 3200, 6400]

    static func shutterLabel(_ nanos: Int64) -> String {
        if nanos <= 0 { return "—" }
        if nanos >= nanosPerSecond {
            let seconds = Double(nanos) / Double(nanosPerSecond)
            return seconds >= 10 ? "\(Int(seconds))\"" : String(format: "%.1f\"", seconds)
        }
        let denominator = max(1, Int(Double(nanosPerSecond) / Double(nanos)))
        return "1/\(denominator)"
    }

    static func isoLabel(_ iso: Int) -> String { "ISO \(iso)" }

    static func stopToNanos(_ denominator: Int64) -> Int64 {
        denominator <= 0 ? nanosPerSecond : nanosPerSecond / denominator
    }

    /// The dial clamps instead of wrapping.
    static func stepIndex(size: Int, index: Int, notches: Int) -> Int {
        if size <= 0 { return 0 }
        return min(max(index + notches, 0), size - 1)
    }

    static func shutterAt(_ index: Int) -> Int64 {
        let i = min(max(index, 0), shutterStops.count - 1)
        return stopToNanos(shutterStops[i])
    }

    static func isoAt(_ index: Int) -> Int {
        isoStops[min(max(index, 0), isoStops.count - 1)]
    }

    static func nearestShutterIndex(_ nanos: Int64) -> Int {
        var best = 0
        var bestD = Int64.max
        for (i, s) in shutterStops.enumerated() {
            let d = abs(stopToNanos(s) - nanos)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    static func nearestIsoIndex(_ iso: Int) -> Int {
        var best = 0
        var bestD = Int.max
        for (i, s) in isoStops.enumerated() {
            let d = abs(s - iso)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    /// ISO past the sensor becomes gain after the readout.
    static func splitIso(_ wanted: Int, sensorMax: Int) -> (iso: Int, boost: Int) {
        if wanted <= sensorMax { return (wanted, 100) }
        let boost = Int(Int64(wanted) * 100 / Int64(max(sensorMax, 1)))
        return (sensorMax, min(max(boost, 100), 3199))
    }

    /// Hold one half and let the metered exposure pick the other.
    static func rebalance(meteredShutter: Int64, meteredIso: Int, heldShutter: Int64?, heldIso: Int?,
                          shutterRange: ClosedRange<Int64>, isoRange: ClosedRange<Int>) -> (shutter: Int64, iso: Int) {
        let metered: Double = Double(meteredShutter) * Double(meteredIso)
        func cs(_ v: Int64) -> Int64 { min(max(v, shutterRange.lowerBound), shutterRange.upperBound) }
        func ci(_ v: Int) -> Int { min(max(v, isoRange.lowerBound), isoRange.upperBound) }
        if let s = heldShutter, let i = heldIso { return (cs(s), ci(i)) }
        if let s = heldShutter {
            let shutter = cs(s)
            let iso = ci(Int((metered / Double(shutter)).rounded()))
            return (shutter, iso)
        }
        if let i = heldIso {
            let iso = ci(i)
            let shutter = cs(Int64((metered / Double(iso)).rounded()))
            return (shutter, iso)
        }
        return (cs(meteredShutter), ci(meteredIso))
    }

    static func withinRange(shutter: Int64, iso: Int, shutterRange: ClosedRange<Int64>, isoRange: ClosedRange<Int>) -> Bool {
        shutterRange.contains(shutter) && isoRange.contains(iso)
    }

    /// White balance presets for the PRO strip. 0 = auto.
    static let whiteBalance: [(label: String, kelvin: Float)] = [
        ("AUTO", 0), ("DAY", 5500), ("CLOUD", 6500), ("SHADE", 7500), ("TUNG", 3200), ("FLUO", 4000),
    ]
}
