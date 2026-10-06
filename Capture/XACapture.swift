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

    init(session: LockedCameraCaptureSession) {
        self.session = session
        let s = AppSettings()
        _settings = StateObject(wrappedValue: s)
        let c = CameraModel(settings: s)
        c.fallbackFolder = session.sessionContentURL
        _camera = StateObject(wrappedValue: c)
    }

    var body: some View {
        // The same camera screen as the app, so the Lock Screen, the Action button and Camera
        // Control open exactly what you know. Anything that needs the unlocked app opens it.
        CameraView(camera: camera, settings: settings, onRoll: { open() }, onCustomize: { open() }, onFilm: {}, modes: [.digi, .film, .pro])
        .environment(\.scenePhase, .active)
        .onAppear {
            // The camera first, at once: the system ends a Lock Screen camera that has not
            // started capturing within a few seconds, and nothing else may hold it up.
            // No Photos here (the Lock Screen camera may not touch the library): pictures go to
            // this session's folder and the app moves them into Photos the next time it opens.
            camera.library = nil
            camera.start()
        }
        .task {
            await loadContext()
            CameraSounds.shared.prepare()
        }
    }

    /// The app's last settings, if the system hands them over quickly.
    private func loadContext() async {
        let ctx: XAContext? = await withTaskGroup(of: XAContext?.self) { g in
            g.addTask { try? await XACaptureIntent.appContext }
            g.addTask { try? await Task.sleep(nanoseconds: 1_500_000_000); return nil }
            let first = await g.next() ?? nil
            g.cancelAll()
            return first
        }
        guard let ctx else { return }
        let m = CaptureMode(rawValue: ctx.mode) ?? .digi
        camera.mode = m == .video ? .digi : m
        camera.stack = Stack(simID: ctx.simID, look: Look(rawValue: ctx.look) ?? .none, shape: FrameShape(rawValue: ctx.shape) ?? .none)
        settings.digiMegapixels = ctx.digiMegapixels
        settings.crunch = ctx.crunch
        settings.date = DateConfig(style: DateStyle(rawValue: ctx.dateStyle) ?? .quartz,
                                   placement: DatePlacement(rawValue: ctx.datePlacement) ?? .follow,
                                   format: DateFormat(rawValue: ctx.dateFormat) ?? .own, time: ctx.dateTime)
        camera.syncFrameSettings()
    }

    private func open() {
        Task {
            let activity = NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
            try? await session.openApplication(for: activity)
        }
    }
}
