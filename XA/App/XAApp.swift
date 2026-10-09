import SwiftUI
import LockedCameraCapture
import AppIntents
import UniformTypeIdentifiers

@main
struct XAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Camera alone on a regular iPhone. On a wide window the roll sits beside the viewfinder.
/// Pull down on the camera and the roll comes into view; flick up and the shutter is back.
struct RootView: View {
    @StateObject private var settings: AppSettings
    @StateObject private var camera: CameraModel
    @StateObject private var library = Library()
    @State private var showRoll = false
    @State private var showCustomize = false
    @State private var showFilm = false
    @State private var pull: CGFloat = 0
    @Environment(\.scenePhase) private var phase

    init() {
        let s = AppSettings()
        _settings = StateObject(wrappedValue: s)
        _camera = StateObject(wrappedValue: CameraModel(settings: s))
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height * 0.8
            if wide {
                HStack(spacing: 0) {
                    camView.frame(width: geo.size.width * 0.55)
                    ContactSheet(library: library)
                }
            } else {
                // The roll is a layer above the camera: swipe up for it, swipe down to put it away.
                ZStack {
                    camView
                    ContactSheet(library: library, onClose: closeRoll, onDrag: { pull = $0 })
                        .offset(y: showRoll ? max(0, pull) : geo.size.height + 40)
                        .allowsHitTesting(showRoll)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .sheet(isPresented: $showCustomize) { CustomizeView(settings: settings, camera: camera) }
        .sheet(isPresented: $showFilm, onDismiss: { camera.rebuildControls() }) { FilmPicker(camera: camera) }
        .onAppear {
            CameraSounds.shared.prepare()
            camera.library = library
            // A picture Photos wouldn't take waits here and goes in the next time it can.
            camera.fallbackFolder = Library.pendingFolder
            library.flushPending()
            camera.onStackChange = { pushContext() }
            camera.start()
            pushContext()
            syncThumb()
        }
        .onChange(of: phase) { _, p in
            // Back from Settings with Photos access changed: the roll picks it up.
            if p == .active { camera.resume(); library.refresh(); library.flushPending() }
            else if p == .background {
                camera.stop()
                // Coming back always lands on the camera: roll, viewer, pickers and settings close.
                showRoll = false; showCustomize = false; showFilm = false; pull = 0
                NotificationCenter.default.post(name: .xaBackToCamera, object: nil)
            }
        }
        .onChange(of: settings.date) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.filmDate) { _, _ in camera.syncFrameSettings() }
        .onChange(of: settings.recipe) { _, _ in camera.syncFrameSettings() }
        .onChange(of: settings.digiOSD) { _, _ in camera.syncFrameSettings() }
        .onChange(of: settings.filmAlwaysOn) { _, _ in camera.syncFrameSettings() }
        .onChange(of: settings.filmRecipe) { _, _ in camera.syncFrameSettings(); camera.updateUltraWide() }
        .onChange(of: settings.digiMegapixels) { _, _ in camera.applyResolution(); pushContext() }
        .onChange(of: settings.proMegapixels) { _, _ in camera.applyResolution() }
        .task { await ingestLockScreenShots() }
        .onChange(of: library.assets.first?.localIdentifier) { _, _ in syncThumb() }
        .onChange(of: library.authorized) { _, _ in syncThumb() }
    }

    private var camView: some View {
        CameraView(camera: camera, settings: settings, onRoll: openRoll, onCustomize: { showCustomize = true }, onFilm: { showFilm = true })
    }

    private func syncThumb() {
        guard let first = library.assets.first else { return }
        library.thumbnail(first, side: 150) { camera.showThumb($0) }
    }

    private func openRoll() { pull = 0; withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { showRoll = true } }
    private func closeRoll() { withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { showRoll = false; pull = 0 } }

    /// The Lock Screen camera cannot read the app's settings; they travel in the intent context.
    private func pushContext() {
        var c = XAContext()
        c.mode = camera.mode.rawValue
        c.simID = camera.stack.simID
        c.look = camera.stack.look.rawValue
        c.shape = camera.stack.shape.rawValue
        c.digiMegapixels = settings.digiMegapixels
        c.crunch = settings.crunch
        c.dateStyle = settings.date.style.rawValue
        c.datePlacement = settings.date.placement.rawValue
        c.dateFormat = settings.date.format.rawValue
        c.dateTime = settings.date.time
        Task { try? await XACaptureIntent.updateAppContext(c) }
    }

    /// Pictures the Lock Screen camera took wait in its session folders (it may not use Photos):
    /// each goes into Photos, and a folder is let go only once all of its pictures are in.
    private func ingestLockScreenShots() async {
        for await update in LockedCameraCaptureManager.shared.sessionContentUpdates {
            switch update {
            case .initial(let urls): for u in urls { ingest(u) }
            case .added(let u):
                // a new folder: give the camera a moment to finish writing into it
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                ingest(u)
            default: break
            }
        }
    }

    private func ingest(_ dir: URL) {
        let fm = FileManager.default
        var files: [URL] = []
        if let walk = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let f as URL in walk where (try? f.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                files.append(f)
            }
        }
        guard !files.isEmpty else { return }
        // A developed picture and the camera's own copy of the same shot: keep the developed one.
        let developed = files.filter { !$0.lastPathComponent.hasPrefix("XA-camera-") }
        let keep = developed.isEmpty ? files : developed + files.filter { $0.lastPathComponent.hasPrefix("XA-camera-") && !hasDeveloped($0, in: developed) }
        let group = DispatchGroup()
        var allOK = true
        for f in keep.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: f) else { allOK = false; continue }
            let type = UTType(filenameExtension: f.pathExtension.lowercased()) ?? .jpeg
            group.enter()
            if type.conforms(to: .movie) {
                library.save(video: f) { id in if id == nil { allOK = false }; group.leave() }
            } else {
                library.save(data: data, type: type) { ok in if !ok { allOK = false }; group.leave() }
            }
        }
        group.notify(queue: .main) {
            if allOK { Task { try? await LockedCameraCaptureManager.shared.invalidateSessionContent(at: dir) } }
        }
    }

    /// The camera's copy is left over only when its shot never finished developing; a developed
    /// picture written within a few seconds of it is the same shot.
    private func hasDeveloped(_ camera: URL, in developed: [URL]) -> Bool {
        func stamp(_ u: URL) -> Int? { u.deletingPathExtension().lastPathComponent.split(separator: "-").compactMap { Int($0) }.first { $0 > 1_000_000_000_000 } }
        guard let t = stamp(camera) else { return false }
        return developed.contains { (stamp($0) ?? 0) >= t && (stamp($0) ?? 0) - t < 60_000 }
    }
}

