import SwiftUI
import LockedCameraCapture
import AppIntents
import UniformTypeIdentifiers
import Photos
import StoreKit

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
    /// The roll is built a moment after launch (or when first opened), not with the camera:
    /// laying out its first day, and asking Photos about every print on it, held the camera up.
    @State private var rollMounted = false
    /// A QR code's link from the Lock Screen camera, opened in the browser once the app is up.
    @State private var pendingLink: URL?
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    init() {
        let s = AppSettings()
        _settings = StateObject(wrappedValue: s)
        // made once (a StateObject's value is made lazily, on first use), and the camera starts
        // opening right then, not once the whole first screen has been built and appeared
        _camera = StateObject(wrappedValue: {
            let c = CameraModel(settings: s)
            c.openEarly()
            return c
        }())
    }

    // In pieces: as one chain of modifiers it was too much for the compiler to type-check.
    var body: some View {
        lifecycle(pictureHooks(settingsHooks(layout)))
    }

    private var layout: some View {
        GeometryReader { geo in
            // Side by side only on an iPad. On an iPhone the window turns only for the photo
            // viewer, and the layout must not change under it (that closed the viewer).
            let wide = UIDevice.current.userInterfaceIdiom == .pad && geo.size.width > geo.size.height * 0.8
            if wide {
                HStack(spacing: 0) {
                    camView.frame(width: geo.size.width * 0.55)
                    ContactSheet(library: library)
                }
            } else {
                // The roll is a layer above the camera: swipe up for it, swipe down to put it away.
                ZStack {
                    camView.accessibilityHidden(showRoll)
                    if rollMounted {
                        ContactSheet(library: library, onClose: closeRoll, onDrag: { pull = $0 })
                            .offset(y: showRoll ? max(0, pull) : geo.size.height + 40)
                            .allowsHitTesting(showRoll)
                            .accessibilityHidden(!showRoll)
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .sheet(isPresented: $showCustomize, onDismiss: { pushContext() }) { CustomizeView(settings: settings, camera: camera) }
        .sheet(isPresented: $showFilm, onDismiss: { camera.rebuildControls(); pushContext() }) { FilmPicker(camera: camera) }
    }

    /// Launch, coming and going, the roll, and the Lock Screen camera handing over.
    private func lifecycle<V: View>(_ v: V) -> some View {
        v
        .onAppear {
            camera.onStackChange = { pushContext() }
            camera.start()
            CameraSounds.shared.prepare()
            camera.library = library
            // A picture Photos wouldn't take waits here and goes in the next time it can.
            camera.fallbackFolder = Library.pendingFolder
            pushContext()
            syncThumb()
            // Photos after the camera: the first look at a big library is slow on the main thread.
            DispatchQueue.main.async { library.refresh(); library.flushPending { camera.countKept() } }
        }
        .onChange(of: phase) { _, p in phaseChanged(p) }
        // The camera sleeps under the roll: no capture, no develop, no hardware shutter.
        .onChange(of: showRoll) { _, open in
            camera.captureButtonsEnabled = !open && !showCustomize && !showFilm
            if open { camera.stop() } else if phase == .active { camera.resume() }
        }
        .onChange(of: showCustomize) { _, open in camera.captureButtonsEnabled = !open && !showRoll && !showFilm }
        .onChange(of: showFilm) { _, open in camera.captureButtonsEnabled = !open && !showRoll && !showCustomize }
        .task { await ingestLockScreenShots() }
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            rollMounted = true
            // the tip jar listens for tips that finish later (Ask to Buy), once the camera is up
            if TipJar.enabled { _ = TipJar.shared }
        }
        // The Lock Screen camera opened the app (its roll, settings or film buttons).
        .onContinueUserActivity(NSUserActivityTypeLockedCameraCapture) { a in
            switch a.userInfo?["open"] as? String {
            case "roll": openRoll()
            case "customize": showCustomize = true
            case "film": showFilm = true
            case "link":
                if let s = a.userInfo?["link"] as? String, let u = URL(string: s) {
                    pendingLink = u
                    if phase == .active { openPendingLink() }
                }
            default: break
            }
        }
    }

    private func phaseChanged(_ p: ScenePhase) {
        // Back from Settings with Photos access changed: the roll picks it up.
        // iOS takes the GPU away in the background: a shot still developing goes on on the CPU
        if p != .background { Encoder.foreground = true }
        if p == .active {
            openPendingLink()
            if !showRoll { camera.resume() }
            library.refresh(); library.flushPending { camera.countKept() }
            // pictures the Lock Screen camera left while the app wasn't running
            Task { await ingestAll() }
        } else if p == .background {
            Encoder.foreground = false
            pushContext()   // the Lock Screen camera opens with exactly this
            camera.stop()
            // Coming back always lands on the camera: roll, viewer, pickers and settings close.
            showRoll = false; showCustomize = false; showFilm = false; pull = 0
            NotificationCenter.default.post(name: .xaBackToCamera, object: nil)
        }
    }

    /// Every setting the Lock Screen camera needs goes to it the moment it changes.
    private func settingsHooks<V: View>(_ v: V) -> some View {
        v
        .onChange(of: settings.date) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.filmDate) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.recipe) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.digiOSD) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.filmAlwaysOn) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.filmRecipe) { old, new in
            camera.syncFrameSettings(); camera.updateUltraWide(); pushContext()
            if old.scan != new.scan { camera.applyResolution() }   // a drum scan takes the whole sensor
        }
        .onChange(of: settings.digiMegapixels) { _, _ in camera.applyResolution(); pushContext() }
    }

    private func pictureHooks<V: View>(_ v: V) -> some View {
        v
        .onChange(of: settings.proMegapixels) { _, _ in camera.applyResolution() }
        .onChange(of: settings.crunch) { _, _ in pushContext() }
        .onChange(of: settings.noise) { _, _ in camera.syncFrameSettings(); pushContext() }
        .onChange(of: settings.flash) { _, _ in pushContext() }
        .onChange(of: settings.sounds) { _, _ in pushContext() }
        .onChange(of: camera.favorites) { _, _ in pushContext() }
        .onChange(of: library.assets.first?.localIdentifier) { _, _ in syncThumb() }
        .onChange(of: library.authorized) { _, _ in syncThumb() }
    }

    private var camView: some View {
        CameraView(camera: camera, settings: settings, onRoll: openRoll, onCustomize: { showCustomize = true }, onFilm: { showFilm = true })
    }

    private func syncThumb() {
        guard let first = library.assets.first else { camera.showThumb(nil); return }
        library.thumbnail(first, side: 150) { camera.showThumb($0) }
    }

    /// The browser opens a moment after the app is up (asked any sooner, iOS can ignore it).
    private func openPendingLink() {
        guard let u = pendingLink else { return }
        pendingLink = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { openURL(u) }
    }

    private func openRoll() {
        pull = 0
        // not built yet: built below the screen first, then slid up
        guard rollMounted else { rollMounted = true; DispatchQueue.main.async { openRoll() }; return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { showRoll = true }
    }
    private func closeRoll() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { showRoll = false; pull = 0 }
        // Back from looking at the pictures: the moment to ask for a rating, once XA has been
        // used for a while (see ReviewPrompt), never in the middle of shooting.
        if ReviewPrompt.due {
            ReviewPrompt.asked()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { requestReview() }
        }
    }

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
        c.settings = LockSettings.current(settings, camera: camera).encoded()
        Task { await ContextPusher.shared.push(c) }
    }

    // MARK: the Lock Screen camera's pictures

    /// The session folders the Lock Screen camera left, as the system hands them over.
    private func ingestLockScreenShots() async {
        for await update in LockedCameraCaptureManager.shared.sessionContentUpdates {
            switch update {
            case .initial(let urls): for u in urls { await ingest(u) }
            case .added(let u): await ingest(u)
            default: break
            }
        }
    }

    /// Every folder there is now (in case an update was missed).
    private func ingestAll() async {
        for u in LockedCameraCaptureManager.shared.sessionContentURLs { await ingest(u) }
    }

    /// One session folder: pictures the camera put in Photos are adopted onto the roll, developed
    /// pictures go into Photos, shots it didn't get to develop are developed here with their own
    /// recipe. Each file is removed once it's safely in; the folder is let go when it's empty.
    @MainActor private static var inFlight = Set<String>()
    private func ingest(_ dir: URL) async {
        let key = dir.standardizedFileURL.path
        guard !Self.inFlight.contains(key) else { return }
        Self.inFlight.insert(key)
        defer { Self.inFlight.remove(key) }
        let fm = FileManager.default
        let pictures: Set<String> = ["heic", "heif", "jpg", "jpeg", "png", "dng"]
        let movies: Set<String> = ["mov", "mp4"]
        func list() -> [URL] {
            ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
        func stem(_ u: URL) -> String { String(u.lastPathComponent.split(separator: ".").first ?? "") }
        // 1. already in Photos: onto the roll, and the shot's leftovers go
        for m in list() where m.pathExtension == "asset" {
            let s = stem(m)
            if let id = try? String(contentsOf: m, encoding: .utf8),
               PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).count > 0 || !Self.canRead {
                library.adopt(id)
                for f in list() where stem(f) == s { try? fm.removeItem(at: f) }
            } else {
                try? fm.removeItem(at: m)   // never committed: the files below bring it in
            }
        }
        // 2. what's left, one picture at a time
        let files = list()
        let developed = Set(files.filter { pictures.contains($0.pathExtension.lowercased()) && !$0.lastPathComponent.contains(".camera.") }.map(stem))
        for f in files {
            let ext = f.pathExtension.lowercased()
            let name = f.lastPathComponent
            if movies.contains(ext) {
                let id = await withCheckedContinuation { c in library.save(video: f) { c.resume(returning: $0) } }
                if id == nil { continue }
            } else if pictures.contains(ext) {
                if name.contains(".camera.") {
                    let s = stem(f)
                    if developed.contains(s) { try? fm.removeItem(at: f); continue }   // its developed picture is here
                    // never developed: develop it now with its recipe, else keep the camera's picture
                    let recipeURL = dir.appendingPathComponent("\(s).json")
                    let made: (Data, UTType)? = await Task.detached(priority: .userInitiated) { [camera] in
                        guard let data = try? Data(contentsOf: f) else { return nil }
                        let r = (try? Data(contentsOf: recipeURL)).flatMap { try? JSONDecoder().decode(LockShot.self, from: $0) }
                        if let r, let out = camera.developLeftover(data, recipe: r) { return out }
                        // not developable: the camera's own picture, a selfie re-tagged to show as it was seen
                        let original = r.map { $0.front ? CameraModel.selfieOriginal(data, turn: CGFloat($0.turn ?? 0)) : data } ?? data
                        return (original, UTType(filenameExtension: ext) ?? .jpeg)
                    }.value
                    guard let made else { continue }
                    let ok = await withCheckedContinuation { c in library.save(data: made.0, type: made.1) { c.resume(returning: $0) } }
                    guard ok else { continue }
                    try? fm.removeItem(at: f); try? fm.removeItem(at: recipeURL)
                } else if name.hasPrefix("XA-camera-") {
                    // an older build's backup: dropped when a developed picture of the same moment is here
                    if Self.legacyHasDeveloped(f, in: files) { try? fm.removeItem(at: f); continue }
                    let ok = await withCheckedContinuation { c in library.save(file: f, type: UTType(filenameExtension: ext) ?? .jpeg) { c.resume(returning: $0) } }
                    if ok { try? fm.removeItem(at: f) }
                } else {
                    let ok = await withCheckedContinuation { c in library.save(file: f, type: UTType(filenameExtension: ext) ?? .jpeg) { c.resume(returning: $0) } }
                    if ok { try? fm.removeItem(at: f) }
                }
            }
        }
        // 3. nothing worth keeping left: the folder goes
        let left = list().filter { pictures.contains($0.pathExtension.lowercased()) || movies.contains($0.pathExtension.lowercased()) }
        if left.isEmpty {
            try? await LockedCameraCaptureManager.shared.invalidateSessionContent(at: dir)
        }
    }

    /// Whether XA may look in Photos (with add-only access a marker is trusted as it is).
    private static var canRead: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }

    /// An older build's backup (XA-camera-<ms>-<n>) next to its developed picture (XA-<ms>-<n>,
    /// written within a minute after it).
    private static func legacyHasDeveloped(_ camera: URL, in files: [URL]) -> Bool {
        func stamp(_ u: URL) -> Int? { u.deletingPathExtension().lastPathComponent.split(separator: "-").compactMap { Int($0) }.first { $0 > 1_000_000_000_000 } }
        guard let t = stamp(camera) else { return false }
        return files.contains { f in
            let n = f.lastPathComponent
            guard !n.hasPrefix("XA-camera-"), !n.contains(".camera."), let s = stamp(f) else { return false }
            return s >= t && s - t < 60_000
        }
    }
}

/// The app context is written one at a time, the newest winning (a burst of changes each
/// started its own write, and an older one could land last).
actor ContextPusher {
    static let shared = ContextPusher()
    private var latest: XAContext?
    private var busy = false
    func push(_ c: XAContext) async {
        latest = c
        guard !busy else { return }
        busy = true
        while let next = latest {
            latest = nil
            try? await XACaptureIntent.updateAppContext(next)
        }
        busy = false
    }
}
