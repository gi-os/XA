import Foundation

/// Where the last launch got to. XA crashed on launch on an iPhone Duo with no crash report
/// reaching TestFlight, and the simulator (no camera) never runs the camera's start. So every
/// step of a launch is written down, and on disk before the step runs: a launch that dies leaves
/// its last step at the end of the file. Files > On My iPhone > XA > Diagnostics: launch.txt is
/// this launch, launch-previous.txt the one before. Only the app writes it (the Lock Screen
/// camera never calls `begin`, so its steps go nowhere), and only until the launch is over.
enum LaunchLog {
    private static let queue = DispatchQueue(label: "xa.launchlog")
    private static var handle: FileHandle?
    private static let start = Date()

    static var folder: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }

    /// First thing in a launch: last launch's log becomes launch-previous.txt.
    static func begin() {
        queue.sync {
            guard handle == nil, let dir = folder else { return }
            let fm = FileManager.default
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let now = dir.appendingPathComponent("launch.txt"), prev = dir.appendingPathComponent("launch-previous.txt")
            try? fm.removeItem(at: prev)
            try? fm.moveItem(at: now, to: prev)
            fm.createFile(atPath: now.path, contents: nil)
            handle = try? FileHandle(forWritingTo: now)
        }
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?"))"
        mark("launch XA \(version), \(model), iOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
    }

    /// One step, on disk before it runs. Any queue.
    static func mark(_ step: String) {
        let t = String(format: "%7.3f", Date().timeIntervalSince(start))
        let line = "\(t)  \(Thread.isMainThread ? "main" : "bg  ")  \(step)\n"
        queue.sync {
            guard let h = handle, let d = line.data(using: .utf8) else { return }
            h.write(d)
            try? h.synchronize()
        }
    }

    /// The launch is over (the app has been up a while): nothing more is written.
    static func end() {
        mark("up")
        queue.sync { try? handle?.close(); handle = nil }
    }

    /// A report that came in later (MetricKit's crashes and hangs), kept beside the logs.
    static func save(_ data: Data, named name: String) {
        guard let dir = folder else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent(name), options: .atomic)
    }

    private static var model: String {
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}
