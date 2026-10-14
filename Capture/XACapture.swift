import SwiftUI
import LockedCameraCapture
import AppIntents

/// The Lock Screen camera. It is what the camera button, Control Center, the Lock Screen and
/// the Action button open while the phone is locked, and what makes XA a Launch Camera option.
@main
struct XACaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCameraView(session: session)
        }
    }
}

struct LockedCameraView: View {
    let session: LockedCameraCaptureSession
    @StateObject private var settings: AppSettings
    @StateObject private var camera: CameraModel
    @State private var started = false

    init(session: LockedCameraCaptureSession) {
        self.session = session
        let s = AppSettings()
        let folder = session.sessionContentURL
        _settings = StateObject(wrappedValue: s)
        // built once (a StateObject's value is made lazily, on first use)
        _camera = StateObject(wrappedValue: {
            let c = CameraModel(settings: s)
            c.fallbackFolder = folder
            return c
        }())
    }

    var body: some View {
        // The same camera screen as the app, so the Lock Screen, the Action button and Camera
        // Control open exactly what you know. Anything that needs the unlocked app opens it.
        CameraView(camera: camera, settings: settings, onRoll: { open("roll") }, onCustomize: { open("customize") },
                   onFilm: { open("film") }, modes: LockSettings.modes, lockScreen: true,
                   onLink: { open("link", link: $0) })
        .environment(\.scenePhase, .active)
        .task {
            CameraSounds.shared.prepare()
            // The camera opens at once, while the app's settings come in (it used to wait for
            // them, up to 0.6 s, before it even started). Until they're applied the viewfinder
            // stays dark, so it still opens in the right mode with the right film instead of
            // switching a moment later. The system ends a Lock Screen camera that isn't capturing
            // within a few seconds, so this never waits long.
            camera.holdViewfinder(true)
            camera.start()
            if let l = await Self.lockSettings(within: 0.6) { apply(l) }
            camera.holdViewfinder(false)
            started = true
            // A late answer still counts, as long as nothing has been shot yet.
            if camera.lastShot == nil, camera.developing == 0, let l = await Self.lockSettings(within: 2.5) {
                if camera.lastShot == nil && camera.developing == 0 { apply(l) }
            }
        }
    }

    private func apply(_ l: LockSettings) {
        l.apply(to: settings)
        camera.adopt(l)
    }

    /// The app's settings from the intent's app context, or nil if they don't come in time.
    static func lockSettings(within seconds: Double) async -> LockSettings? {
        final class Once: @unchecked Sendable {
            private let l = NSLock(); private var done = false
            func claim() -> Bool { l.lock(); defer { l.unlock() }; if done { return false }; done = true; return true }
        }
        let once = Once()
        let ctx: XAContext? = await withCheckedContinuation { (c: CheckedContinuation<XAContext?, Never>) in
            Task { let v = try? await XACaptureIntent.appContext; if once.claim() { c.resume(returning: v) } }
            Task { try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9)); if once.claim() { c.resume(returning: nil) } }
        }
        guard let ctx else { return nil }
        if let l = LockSettings.decode(ctx.settings) { return l }
        // an older app's context: what it had
        var l = LockSettings()
        let m = CaptureMode(rawValue: ctx.mode) ?? .digi
        l.mode = LockSettings.modes.contains(m) ? m : .digi
        let st = Stack(simID: ctx.simID, look: Look(rawValue: ctx.look) ?? .none, shape: FrameShape(rawValue: ctx.shape) ?? .none)
        if l.mode == .film { l.filmStack = st } else { l.digiStack = st }
        l.digiMegapixels = ctx.digiMegapixels
        l.crunch = ctx.crunch
        l.date = DateConfig(style: DateStyle(rawValue: ctx.dateStyle) ?? .quartz,
                            placement: DatePlacement(rawValue: ctx.datePlacement) ?? .follow,
                            format: DateFormat(rawValue: ctx.dateFormat) ?? .own, time: ctx.dateTime)
        l.filmDate = l.date
        return l
    }

    /// Into the app (Face ID first), once the shots in hand are saved: the system puts the camera
    /// away the moment the app opens, and anything still developing would be cut short. A QR
    /// code's link goes along, for the app to open in the browser.
    private func open(_ destination: String, link: URL? = nil) {
        Task { @MainActor in
            var waited = 0
            while camera.developing > 0 && waited < 40 { try? await Task.sleep(nanoseconds: 100_000_000); waited += 1 }
            let activity = NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
            var info: [String: Any] = ["open": destination]
            if let link { info["link"] = link.absoluteString }
            activity.userInfo = info
            try? await session.openApplication(for: activity)
        }
    }
}
