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
        VStack(spacing: 10) {
            Viewfinder(camera: camera)
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { if camera.flash { Color.white.opacity(0.7) } }
            if camera.mode == .digi { StackRow(stack: camera.stack, onTap: {}) }
            HStack(spacing: 2) {
                ForEach(CaptureMode.allCases) { m in
                    let on = camera.mode == m
                    Button { camera.mode = m } label: {
                        Text(m.title).font(XA.display(18))
                            .padding(.horizontal, 18).padding(.vertical, 7)
                            .foregroundStyle(on ? .black : .white.opacity(0.82))
                            .background(on ? (m == .digi ? XA.orange : Color.white) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3).background(XA.fill, in: Capsule())
            HStack(spacing: 28) {
                Button { open() } label: {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 18))
                        .frame(width: 50, height: 50).background(XA.fill)
                }
                .buttonStyle(.plain).accessibilityLabel("Open XA")
                Button { camera.shoot() } label: { Capsule().fill(Color.white).frame(width: 118, height: 40) }
                    .buttonStyle(.plain).accessibilityLabel("Take picture")
                RoundButton(size: 50, action: { camera.flip() }) { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 20)) }
                    .accessibilityLabel("Switch camera")
            }
            .frame(height: 76)
        }
        .padding(.horizontal, 11)
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .environment(\.scenePhase, .active)
        .task {
            await loadContext()
            camera.library = Library()
            camera.start()
        }
    }

    private func loadContext() async {
        guard let ctx = try? await XACaptureIntent.appContext else { return }
        camera.mode = CaptureMode(rawValue: ctx.mode) ?? .digi
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
