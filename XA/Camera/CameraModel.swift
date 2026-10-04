import AVFoundation
import CoreMotion
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// The PRO strip's five dials.
enum ProControl: String, CaseIterable, Identifiable {
    case wb, ev, shutter, iso, focus
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wb: return "WB"
        case .ev: return "EV"
        case .shutter: return "S"
        case .iso: return "ISO"
        case .focus: return "FOCUS"
        }
    }
}

/// The camera. A shutter that never waits: the press takes the picture and everything slow
/// (the sim, the look, the shape, the date back, the encode, the save) drains through a queue
/// behind the live viewfinder.
final class CameraModel: NSObject, ObservableObject {
    // VIDEO
    @Published var videoLook: VideoLook = .clean { didSet { UserDefaults.standard.set(videoLook.rawValue, forKey: "videoLook"); lock.lock(); frameVideoLook = videoLook; lock.unlock() } }
    @Published private(set) var recording = false
    @Published private(set) var recordSeconds: Double = 0
    // FOCUS
    /// Where focus is aimed, in viewfinder coordinates (0…1, top-left). Nil when the camera chooses.
    @Published private(set) var focusPoint: CGPoint?
    /// The half-press has locked focus and exposure.
    @Published private(set) var focusLocked = false
    /// Half-press held (on-screen shutter or a held hardware button).
    @Published private(set) var halfPressed = false
    private var focusObservation: NSKeyValueObservation?
    private var _eyeTracking = false

    /// The take so far: which tape from which second.
    @Published private(set) var segments: [TakeSegment] = []
    @Published var mode: CaptureMode = .digi { didSet { modeChanged(oldValue) } }
    @Published var stack = Stack(simID: "nocturne") { didSet { stackChanged() } }
    @Published private(set) var authorized: Bool?
    @Published private(set) var front = false
    @Published private(set) var developing = 0
    @Published private(set) var flash = false
    /// BOOTH: which of the four shots is coming (1…4) while a session runs, and the countdown to it.
    @Published private(set) var boothShot: Int? { didSet { if boothShot != oldValue { syncFrameSettings() } } }
    @Published private(set) var boothCount: Int?
    @Published private(set) var hasCameraControl = false
    @Published private(set) var lastShot: UIImage?
    /// DIGI's instant review: the shot held on the viewfinder for a moment, with its file number.
    @Published private(set) var reviewing = false
    @Published private(set) var reviewFile = ""
    static let reviewSeconds: Double = 1.2
    @Published private(set) var lenses: [Lens] = []
    @Published private(set) var zoom: CGFloat = 1
    /// Device zoom factor x this = the number iOS shows (0.5 when there's an ultra wide).
    @Published private(set) var zoomMultiplier: CGFloat = 1
    @Published private(set) var photoSize: CGSize = .zero
    @Published private(set) var histogram: [Float] = []
    /// What the camera is metering right now, for the PRO panel.
    @Published private(set) var meterShutter: Double = 1.0 / 60
    @Published private(set) var meterISO: Float = 100
    /// The lens's f-number, for the PRO panel.
    @Published private(set) var aperture: Float = 1.8
    /// Photo sizes PRO can ask the sensor for, in megapixels, smallest first.
    @Published private(set) var proOptions: [Int] = []

    // PRO dials. nil means auto.
    @Published var proControl: ProControl = .ev
    @Published var ev: Float = 0 { didSet { if ev != oldValue { applyPro() } } }
    @Published var shutterIndex: Int? { didSet { if shutterIndex != oldValue { applyPro() } } }
    @Published var isoIndex: Int? { didSet { if isoIndex != oldValue { applyPro() } } }
    @Published var wbIndex: Int = 0 { didSet { if wbIndex != oldValue { applyPro() } } }
    @Published var focusIndex: Int? { didSet { if focusIndex != oldValue { applyPro() } } }

    /// A plain session, or in FILM (with the XA finder) a multi-camera one that also streams the ultra-wide.
    private(set) var session: AVCaptureSession = AVCaptureSession()
    let settings: AppSettings
    weak var preview: PreviewView?
    var library: Library?
    /// Where the Lock Screen camera saves when Photos is not available to it.
    var fallbackFolder: URL?

    private let photoOutput = AVCapturePhotoOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioQueue = DispatchQueue(label: "xa.audio")
    private var audioInput: AVCaptureDeviceInput?
    private var frameVideoLook: VideoLook = .clean
    private var _wantRecord = false
    private var _lockedTurn: CGFloat?
    private var frameSegments: [TakeSegment] = []
    private var _recorder: VideoRecorder?
    private let fx = VideoFX()
    private var recordTimer: Timer?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "xa.session")
    private let frameQueue = DispatchQueue(label: "xa.frames")
    private let developQueue = DispatchQueue(label: "xa.develop", qos: .userInitiated)
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var frontFlag = false
    private var frameCount = 0
    private var previewAngle: CGFloat = 90
    private var angleObservation: NSKeyValueObservation?
    /// How far the photo will be turned from the viewfinder frame, clockwise, in degrees.
    private var _turn: CGFloat = 0

    // Read on the frame queue.
    private let lock = NSLock()
    private var _frameMode: CaptureMode = .digi
    private var _develop = DevelopSettings()
    private var _latest: CIImage?
    // Instant review, read on the frame queue: until when the viewfinder holds, whether the held
    // frame has been drawn, and the last frame shown (the one that gets held).
    private var _reviewUntil: CFTimeInterval = 0
    private var _reviewDrawn = true
    private var _lastShown: CIImage?
    private var reviewToken = 0
    // Mode switch: DIGI's processing fades in or out over half a second.
    private var _switchStart: CFTimeInterval = 0
    private var _toDigi = true
    /// The fade starts on the first frame after the switch, not on the tap, so a slow frame
    /// never eats the start of it.
    private var _switchPending = false
    // Per-shot photo sizes: the output is set to the largest once, so switching modes never
    // reconfigures the session.
    private var digiDims = CMVideoDimensions(width: 4032, height: 3024)
    // BOOTH: the running session, the shots developed so far for each sheet, and the eyes
    // DOLL last found in the viewfinder.
    private var boothSession = 0
    private var boothFrames: [Int: [Int: UIImage]] = [:]
    private var _boothEyes: Booth.Eyes?
    private var eyesBusy = false
    // FILM's finder: how far the rangefinder's second image sits off, and what drives it.
    private let motion = CMMotionManager()
    private var patchShift: CGFloat = 0
    /// A damped spring for the patch's second image: position, velocity, stiffness, damping.
    private struct PatchSpring {
        var pos: CGFloat = 0, vel: CGFloat = 0, k: CGFloat = 70, zeta: CGFloat = 0.5
        mutating func step(_ dt: CGFloat) {
            let c = 2 * zeta * k.squareRoot()
            for _ in 0..<2 {
                let a = -k * pos - c * vel
                vel += a * dt / 2
                pos += vel * dt / 2
            }
            pos = max(-1.2, min(1.2, pos))
        }
    }
    private var patch = PatchSpring()
    private var lastLens: Float = -1
    // FILM's ultra-wide: the second camera behind the finder's surround.
    private let uwOutput = AVCaptureVideoDataOutput()
    private var uwInput: AVCaptureDeviceInput?
    private var multiCam = false
    private var _uw: CIImage?
    private var _uwRatio: CGFloat = 2
    private var _uwGain = CIVector(x: 1, y: 1, z: 1)
    private var uwCount = 0
    /// The viewfinder's landscape length (see XAFinder.long), set by the view.
    private var _finderLong: CGFloat = 4
    /// How far the finder's markings have swung with the camera's motion; they settle back.
    @Published private(set) var finderSway: CGSize = .zero
    private var sway: CGSize = .zero
    private let eyeQueue = DispatchQueue(label: "xa.eyes", qos: .userInitiated)
    private var proDims = CMVideoDimensions(width: 4032, height: 3024)

    init(settings: AppSettings) {
        self.settings = settings
        super.init()

        if let v = VideoLook(rawValue: UserDefaults.standard.integer(forKey: "videoLook")) { videoLook = v; frameVideoLook = v }
        let last = CaptureMode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .digi
        switch settings.openIn {
        case .last: mode = last
        case .digi: mode = .digi
        case .pro: mode = .pro
        case .film: mode = .film
        }
        stack = Self.loadStack(for: mode)
        _toDigi = mode.developed
        syncFrameSettings()
    }

    /// The last viewfinder frame, small, for the editors' previews.
    var latestFrame: CIImage? { lock.lock(); defer { lock.unlock() }; return _latest }

    /// DIGI (and VIDEO) and FILM each keep their own loaded film.
    static func stackKey(_ m: CaptureMode) -> String { m == .film ? "filmStack" : "stack" }
    static func loadStack(for m: CaptureMode) -> Stack {
        var s: Stack = AppSettings.load(stackKey(m)) ?? Stack(simID: m == .film ? "bowery400" : "nocturne")
        let isStock = FilmCatalog.sim(s.simID)?.stock != nil
        if m == .film && !isStock { s = Stack(simID: "bowery400") }
        if m != .film && isStock { s.simID = "nocturne"; s.pushStops = nil }
        return s
    }

    func syncFrameSettings() {
        var d = DevelopSettings()
        d.film = mode == .film
        d.stack = stack
        d.megapixels = settings.digiMegapixels
        d.noise = settings.noise
        d.date = mode == .film ? settings.filmDate : settings.date
        d.filmRecipe = settings.filmRecipe
        d.recipe = settings.recipe
        if mode == .booth {
            d.booth = settings.boothSkin
            d.deco = settings.boothDeco.step((boothShot ?? 1) - 1)
        }
        lock.lock(); _develop = d; _frameMode = mode; lock.unlock()
    }

    /// How much of DIGI's processing the viewfinder shows right now, 0…1, eased.
    private func digiAmount() -> CGFloat {
        lock.lock(); let start = _switchStart, toDigi = _toDigi; lock.unlock()
        let t: CGFloat = min(1, max(0, CGFloat((CACurrentMediaTime() - start) / 0.55)))
        let eased: CGFloat = 1 - (1 - t) * (1 - t) * (1 - t)
        return toDigi ? eased : 1 - eased
    }

    private func frameState() -> (CaptureMode, DevelopSettings) {
        lock.lock(); defer { lock.unlock() }
        return (_frameMode, _develop)
    }

    private func stackChanged() {
        if let data = try? JSONEncoder().encode(stack) { UserDefaults.standard.set(data, forKey: Self.stackKey(mode)) }
        syncFrameSettings()
        onStackChange?()
    }
    var onStackChange: (() -> Void)?

    private func modeChanged(_ old: CaptureMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "mode")
        if old != mode {
            skipReview()
            lock.lock(); _switchPending = true; _switchStart = CACurrentMediaTime(); _toDigi = mode.developed; lock.unlock()
            if old == .video && recording { stopRecording() }
            if (old == .film) != (mode == .film) { stack = Self.loadStack(for: mode) }
            // BOOTH turns the camera round to face you, and back when you leave.
            if old == .booth { cancelBooth(); setFront(false) }
            updateMotion()
            updateUltraWide()
            if mode == .booth { setFront(true) }
        }
        syncFrameSettings()
        guard old != mode, input != nil else { return }
        let m = mode
        publishPhotoSize(m)
        sessionQueue.async {
            self.applyProOnQueue(m)
            if m == .video { self.addAudioIfNeeded() }
        }
        preparePhotos()
        // Camera Control is rebuilt once the fade is over, so it cannot stall the feed during it.
        sessionQueue.asyncAfter(deadline: .now() + 0.7) {
            guard self.mode == m, let dev = self.device else { return }
            self.session.beginConfiguration()
            self.addControls(dev, m)
            self.session.commitConfiguration()
        }
        onStackChange?()
    }

    // MARK: session

    func start() {
        updateMotion()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true; sessionQueue.async { self.configure() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { self.authorized = ok }
                if ok { self.sessionQueue.async { self.configure() } }
            }
        default: authorized = false
        }
        updateUltraWide()
    }

    func stop() {
        cancelBooth()
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }
    func resume() { sessionQueue.async { if !self.session.isRunning && self.input != nil { self.session.startRunning() } } }

    private static func backCamera() -> AVCaptureDevice? {
        let kinds: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        for k in kinds { if let d = AVCaptureDevice.default(k, for: .video, position: .back) { return d } }
        return nil
    }

    private func configure() {
        guard input == nil else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let dev = Self.backCamera(), let inp = try? AVCaptureDeviceInput(device: dev), session.canAddInput(inp) else {
            session.commitConfiguration(); return
        }
        session.addInput(inp)
        device = dev; input = inp
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .quality
        if photoOutput.isAppleProRAWSupported { photoOutput.isAppleProRAWEnabled = settings.digiZero }
        applyCapturePolicy(flash: settings.flash != .off)
        let m = mode
        setupPhotoOutput(dev, m)
        addControls(dev, m)
        session.commitConfiguration()
        setupLenses(dev)
        applyRotation()
        session.startRunning()
        applyProOnQueue(m)
        if m == .booth { switchCamera(toFront: true) }
        DispatchQueue.main.async { self.preparePhotos() }
    }

    private func setupPhotoOutput(_ dev: AVCaptureDevice, _ m: CaptureMode) {
        let dims = dev.activeFormat.supportedMaxPhotoDimensions
        func px(_ d: CMVideoDimensions) -> Int { Int(d.width) * Int(d.height) }
        func mp(_ d: CMVideoDimensions) -> Int { CaptureMode.megapixels(CGSize(width: CGFloat(d.width), height: CGFloat(d.height))) }
        guard let largest = dims.max(by: { px($0) < px($1) }) else { return }
        let options = Array(Set(dims.map(mp))).sorted()
        if px(photoOutput.maxPhotoDimensions) != px(largest) { photoOutput.maxPhotoDimensions = largest }
        let digi = dims.filter { px($0) <= CaptureMode.digi.maxSensorPixels }.max(by: { px($0) < px($1) }) ?? largest
        var pro = largest
        let want = settings.proMegapixels
        if want > 0, let chosen = dims.filter({ mp($0) <= want }).max(by: { px($0) < px($1) }) { pro = chosen }
        lock.lock(); digiDims = digi; proDims = pro; lock.unlock()
        DispatchQueue.main.async { self.proOptions = options; self.publishPhotoSize(m) }
    }

    private func shotDims(_ m: CaptureMode) -> CMVideoDimensions {
        lock.lock(); defer { lock.unlock() }
        return m == .pro ? proDims : digiDims
    }

    private func publishPhotoSize(_ m: CaptureMode) {
        let d = shotDims(m)
        photoSize = CGSize(width: CGFloat(d.width), height: CGFloat(d.height))
    }

    /// Re-read the resolution settings.
    func applyResolution() {
        syncFrameSettings()
        let m = mode
        sessionQueue.async {
            guard let dev = self.device else { return }
            // Only the per-shot size changes; the session is left alone.
            self.setupPhotoOutput(dev, m)
        }
    }

    private func setupLenses(_ dev: AVCaptureDevice) {
        let sw: [CGFloat] = dev.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let mult: CGFloat = dev.displayVideoZoomFactorMultiplier
        let maxZ: CGFloat = min(dev.activeFormat.videoMaxZoomFactor, 20)
        let stops = Lenses.stops(switchOvers: sw, maxZoom: maxZ, multiplier: mult)
        let main = Lenses.main(switchOvers: sw, multiplier: mult)
        if (try? dev.lockForConfiguration()) != nil {
            dev.videoZoomFactor = min(main, maxZ)
            dev.unlockForConfiguration()
        }
        let ap = dev.lensAperture
        DispatchQueue.main.async { self.lenses = stops; self.zoom = main; self.zoomMultiplier = mult; if ap > 0 { self.aperture = ap } }
    }

    /// Camera Control. DIGI: slide through sims or looks. PRO: exposure or zoom.
    private func addControls(_ dev: AVCaptureDevice, _ m: CaptureMode) {
        guard session.supportsControls else { return }
        for c in session.controls { session.removeControl(c) }
        let zoom = AVCaptureSystemZoomSlider(device: dev) { [weak self] z in
            DispatchQueue.main.async { self?.zoom = z }
        }
        if m.usesFilm {
            let sims = FilmCatalog.sims(for: m)
            let simTitles = sims.map { $0.title.capitalized }
            let simPicker = AVCaptureIndexPicker("Sim", symbolName: "film", localizedIndexTitles: simTitles)
            let loaded = FilmCatalog.sim(stack.simID)?.id
            simPicker.selectedIndex = sims.firstIndex { $0.id == loaded } ?? 0
            simPicker.setActionQueue(.main) { [weak self] i in
                guard let self else { return }
                self.stack.simID = sims[min(sims.count - 1, max(0, i))].id
            }
            let lookPicker = AVCaptureIndexPicker("Look", symbolName: "camera.filters", localizedIndexTitles: Look.allCases.map { $0.title.capitalized })
            lookPicker.selectedIndex = stack.look.rawValue
            lookPicker.setActionQueue(.main) { [weak self] i in
                self?.stack.look = Look(rawValue: i) ?? .none
            }
            let first: AVCaptureControl = settings.digiSlide == .sim || m == .film ? simPicker : lookPicker
            let second: AVCaptureControl = settings.digiSlide == .sim || m == .film ? lookPicker : simPicker
            for c in [first, second] where session.canAddControl(c) && (m == .digi || c === simPicker) { session.addControl(c) }
        } else if m == .booth {
            if session.canAddControl(zoom) { session.addControl(zoom) }
        } else if m == .video {
            let looks = AVCaptureIndexPicker("Look", symbolName: "film", localizedIndexTitles: VideoLook.allCases.map { $0.title.capitalized })
            looks.selectedIndex = videoLook.rawValue
            looks.setActionQueue(.main) { [weak self] i in self?.videoLook = VideoLook(rawValue: i) ?? .clean }
            for c in [looks, zoom] as [AVCaptureControl] where session.canAddControl(c) { session.addControl(c) }
        } else {
            let bias = AVCaptureSystemExposureBiasSlider(device: dev) { [weak self] b in
                DispatchQueue.main.async { if self?.ev != b { self?.ev = b } }
            }
            let order: [AVCaptureControl] = settings.proSlide == .exposure ? [bias, zoom] : [zoom, bias]
            for c in order where session.canAddControl(c) { session.addControl(c) }
        }
        if m.usesFilm, session.canAddControl(zoom) { session.addControl(zoom) }
        session.setControlsDelegate(self, queue: sessionQueue)
        DispatchQueue.main.async { self.hasCameraControl = true }
    }

    func rebuildControls() {
        let m = mode
        sessionQueue.async {
            guard let dev = self.device else { return }
            self.session.beginConfiguration()
            self.addControls(dev, m)
            self.session.commitConfiguration()
        }
    }

    private func applyRotation() {
        guard let dev = device else { return }
        let rc = AVCaptureDevice.RotationCoordinator(device: dev, previewLayer: nil)
        rotation = rc
        // The viewfinder stays upright for the portrait UI; the photograph turns with the phone.
        let portrait: CGFloat = 90
        if let c = uwOutput.connection(with: .video) {
            if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = false }
            if c.isVideoRotationAngleSupported(portrait) { c.videoRotationAngle = portrait }
        }
        if let c = videoOutput.connection(with: .video) {
            // The connection never mirrors: with the selfie camera, mirror and turn together came
            // out upside down. XA turns and mirrors the frames itself (see `upright`).
            if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = false }
            let a = c.isVideoRotationAngleSupported(portrait) ? portrait : rc.videoRotationAngleForHorizonLevelCapture
            // The selfie camera's frames come in as the sensor reads them and XA turns them.
            let set: CGFloat = frontFlag ? 0 : a
            if c.isVideoRotationAngleSupported(set) { c.videoRotationAngle = set }
            previewAngle = a
        }
        angleObservation = rc.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] rc, _ in
            guard let self else { return }
            var t = rc.videoRotationAngleForHorizonLevelCapture - self.previewAngle
            while t < 0 { t += 360 }
            while t >= 360 { t -= 360 }
            self.lock.lock(); self._turn = t; self.lock.unlock()
        }
    }

    /// The selfie camera's picture is never turned: it is saved the way the viewfinder shows it.
    private var turn: CGFloat { lock.lock(); defer { lock.unlock() }; return frontFlag ? 0 : _turn }

    /// Turn a frame clockwise by a multiple of 90°, keeping it at the origin.
    /// A viewfinder frame or a selfie made portrait and, for the selfie camera, mirrored the way
    /// a mirror shows you. The selfie camera's frames and photos arrive as its sensor reads them,
    /// landscape, and the same turn makes both upright, so what you see is what is saved. Its
    /// sensor sits the other way round from the back camera's: a three-quarter turn, not a quarter.
    static func upright(_ img: CIImage, mirror: Bool) -> CIImage {
        var out = img
        if out.extent.width > out.extent.height { out = rotated(out, clockwise: mirror ? 270 : 90) }
        if mirror {
            let w = out.extent.width
            out = out.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w + out.extent.minX * 2, ty: 0))
        }
        return out
    }

    static func rotated(_ img: CIImage, clockwise deg: CGFloat) -> CIImage {
        guard deg != 0 else { return img }
        let r = img.transformed(by: CGAffineTransform(rotationAngle: -deg * .pi / 180))
        return r.transformed(by: CGAffineTransform(translationX: -r.extent.minX, y: -r.extent.minY))
    }

    func flip() {
        sessionQueue.async {
            // the selfie camera has no ultra-wide: back to the plain session first
            if self.multiCam { self.rebuildSession(multi: false) }
            self.switchCamera(toFront: !self.frontFlag)
        }
    }

    /// Front or back, whichever it isn't already.
    func setFront(_ want: Bool) {
        sessionQueue.async { if self.frontFlag != want { self.switchCamera(toFront: want) } }
    }

    /// On the session queue.
    private func switchCamera(toFront: Bool) {
        do {
            guard let old = self.input else { return }
            let dev: AVCaptureDevice? = toFront ? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) : Self.backCamera()
            guard let dev, let inp = try? AVCaptureDeviceInput(device: dev) else { return }
            self.session.beginConfiguration()
            self.session.removeInput(old)
            if self.session.canAddInput(inp) { self.session.addInput(inp); self.input = inp; self.device = dev } else { self.session.addInput(old) }
            let m = self.mode
            if let d = self.device { self.setupPhotoOutput(d, m); self.addControls(d, m) }
            self.session.commitConfiguration()
            self.frontFlag = toFront
            if let d = self.device { self.setupLenses(d) }
            DispatchQueue.main.async { self.front = toFront }
            self.applyRotation()
            self.applyProOnQueue(m)
        }
    }

    /// Zoom to a device factor. Pinches and slides set it directly, frame by frame, the way the
    /// system camera does; lens buttons ramp.
    func setZoom(_ f: CGFloat, ramp: Bool = false) {
        sessionQueue.async {
            guard let dev = self.device, (try? dev.lockForConfiguration()) != nil else { return }
            let hi: CGFloat = min(dev.maxAvailableVideoZoomFactor, 20 / max(dev.displayVideoZoomFactorMultiplier, 0.01))
            let z = min(max(f, dev.minAvailableVideoZoomFactor), hi)
            if ramp { dev.ramp(toVideoZoomFactor: z, withRate: 14) } else { dev.cancelVideoZoomRamp(); dev.videoZoomFactor = z }
            dev.unlockForConfiguration()
            DispatchQueue.main.async { self.zoom = z }
        }
    }

    // MARK: PRO exposure, white balance, focus

    private func applyPro() {
        let m = mode
        sessionQueue.async { self.applyProOnQueue(m) }
    }

    private func applyProOnQueue(_ m: CaptureMode) {
        guard let dev = device, (try? dev.lockForConfiguration()) != nil else { return }
        defer { dev.unlockForConfiguration() }
        let pro = m == .pro
        let (sIdx, iIdx, wb, fIdx, bias) = DispatchQueue.main.sync { (shutterIndex, isoIndex, wbIndex, focusIndex, ev) }
        // Exposure.
        if pro && (sIdx != nil || iIdx != nil) && dev.isExposureModeSupported(.custom) {
            let meteredShutter = Int64(dev.exposureDuration.seconds * 1e9)
            let meteredIso = Int(dev.iso)
            let fmt = dev.activeFormat
            let lo = Int64(fmt.minExposureDuration.seconds * 1e9)
            let hi = Int64(min(fmt.maxExposureDuration.seconds, 1) * 1e9)
            let r = Exposure.rebalance(meteredShutter: max(meteredShutter, 1), meteredIso: max(meteredIso, 1),
                                       heldShutter: sIdx.map { Exposure.shutterAt($0) }, heldIso: iIdx.map { Exposure.isoAt($0) },
                                       shutterRange: max(lo, 1)...max(hi, max(lo, 1)), isoRange: Int(fmt.minISO)...Int(fmt.maxISO))
            let duration = CMTime(value: r.shutter, timescale: 1_000_000_000)
            dev.setExposureModeCustom(duration: duration, iso: Float(r.iso), completionHandler: nil)
        } else if dev.isExposureModeSupported(.continuousAutoExposure) {
            dev.exposureMode = .continuousAutoExposure
            let b = pro ? bias : 0
            let clamped = min(max(b, dev.minExposureTargetBias), dev.maxExposureTargetBias)
            dev.setExposureTargetBias(clamped, completionHandler: nil)
        }
        // White balance.
        if pro && wb > 0 && dev.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            let k = Exposure.whiteBalance[min(wb, Exposure.whiteBalance.count - 1)].kelvin
            var g = dev.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: k, tint: 0))
            let mx = dev.maxWhiteBalanceGain
            g.redGain = min(max(g.redGain, 1), mx)
            g.greenGain = min(max(g.greenGain, 1), mx)
            g.blueGain = min(max(g.blueGain, 1), mx)
            dev.setWhiteBalanceModeLocked(with: g, completionHandler: nil)
        } else if dev.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            dev.whiteBalanceMode = .continuousAutoWhiteBalance
        }
        // Focus.
        if pro, let f = fIdx, dev.isLockingFocusWithCustomLensPositionSupported {
            dev.setFocusModeLocked(lensPosition: Float(f) / 10, completionHandler: nil)
        } else if dev.isFocusModeSupported(.continuousAutoFocus) {
            dev.focusMode = .continuousAutoFocus
        }
    }

    /// Labels for the strip.
    func label(_ c: ProControl) -> String {
        switch c {
        case .wb: return Exposure.whiteBalance[min(wbIndex, Exposure.whiteBalance.count - 1)].label
        case .ev: return String(format: "%+.1f", ev)
        case .shutter: return shutterIndex.map { Exposure.shutterLabel(Exposure.shutterAt($0)) } ?? "AUTO"
        case .iso: return isoIndex.map { "\(Exposure.isoAt($0))" } ?? "AUTO"
        case .focus: return focusIndex.map { $0 == 10 ? "∞" : String(format: "MF.%d", $0) } ?? "AF"
        }
    }

    /// Number of positions on the dial for a control, and the current one. Position 0 is auto.
    func dial(_ c: ProControl) -> (count: Int, index: Int) {
        switch c {
        case .wb: return (Exposure.whiteBalance.count, wbIndex)
        case .ev: return (13, Int(((ev + 2) * 3).rounded()))
        case .shutter: return (Exposure.shutterStops.count + 1, (shutterIndex ?? -1) + 1)
        case .iso: return (Exposure.isoStops.count + 1, (isoIndex ?? -1) + 1)
        case .focus: return (12, (focusIndex ?? -1) + 1)
        }
    }

    func setDial(_ c: ProControl, _ i: Int) {
        let n = dial(c).count
        let v = min(max(i, 0), n - 1)
        switch c {
        case .wb: wbIndex = v
        case .ev: ev = Float(v) / 3 - 2
        case .shutter: shutterIndex = v == 0 ? nil : v - 1
        case .iso: isoIndex = v == 0 ? nil : v - 1
        case .focus: focusIndex = v == 0 ? nil : v - 1
        }
    }

    /// The roll button shows the newest picture on the roll, from launch on.
    func showThumb(_ img: UIImage?) { if let img { lastShot = img } }

    // MARK: focus

    /// Point focus: aim focus and exposure at a spot in the viewfinder.
    func focus(at viewPoint: CGPoint) {
        guard mode != .pro || focusIndex == nil else { return }
        focusPoint = viewPoint
        focusLocked = false
        if settings.sounds && mode != .video { CameraSounds.shared.play(.focus) }
        let continuous = settings.afMode == .continuous
        let front = self.front
        // In the XA finder the picture sits inside the frame: aim where the tap lands on it.
        let target = (mode == .film && settings.filmRecipe.xaFinder) ? (finderToPicture(viewPoint) ?? viewPoint) : viewPoint
        sessionQueue.async { self.aim(target, front: front, continuous: continuous) }
    }

    private func aim(_ viewPoint: CGPoint, front: Bool, continuous: Bool) {
        guard let dev = device, (try? dev.lockForConfiguration()) != nil else { return }
        defer { dev.unlockForConfiguration() }
        let p = FocusGeometry.devicePoint(fromView: viewPoint, front: front)
        if dev.isFocusPointOfInterestSupported { dev.focusPointOfInterest = p }
        let fm: AVCaptureDevice.FocusMode = continuous ? .continuousAutoFocus : .autoFocus
        if dev.isFocusModeSupported(fm) { dev.focusMode = fm }
        if dev.isExposurePointOfInterestSupported { dev.exposurePointOfInterest = p }
        if dev.isExposureModeSupported(.continuousAutoExposure) && dev.exposureMode != .custom { dev.exposureMode = .continuousAutoExposure }
    }

    /// Back to the camera's own choice.
    func resetFocus() {
        focusPoint = nil
        focusLocked = false
        sessionQueue.async {
            guard let dev = self.device, (try? dev.lockForConfiguration()) != nil else { return }
            defer { dev.unlockForConfiguration() }
            let c = CGPoint(x: 0.5, y: 0.5)
            if dev.isFocusPointOfInterestSupported { dev.focusPointOfInterest = c }
            if dev.isExposurePointOfInterestSupported { dev.exposurePointOfInterest = c }
            if dev.isFocusModeSupported(.continuousAutoFocus) { dev.focusMode = .continuousAutoFocus }
            if dev.exposureMode != .custom && dev.isExposureModeSupported(.continuousAutoExposure) { dev.exposureMode = .continuousAutoExposure }
            dev.isSubjectAreaChangeMonitoringEnabled = false
        }
    }

    /// First stage: focus (and, in AF-S, exposure) lock where it is aimed.
    func halfPress() {
        skipReview()
        guard mode != .video, !halfPressed else { return }
        halfPressed = true
        if settings.sounds { CameraSounds.shared.play(.focus) }
        guard mode != .pro || focusIndex == nil else { focusLocked = true; return }
        let single = settings.afMode == .single
        let point = focusPoint ?? CGPoint(x: 0.5, y: 0.5)
        let front = self.front
        sessionQueue.async {
            guard let dev = self.device, (try? dev.lockForConfiguration()) != nil else { return }
            let p = FocusGeometry.devicePoint(fromView: point, front: front)
            if dev.isFocusPointOfInterestSupported { dev.focusPointOfInterest = p }
            if dev.isExposurePointOfInterestSupported { dev.exposurePointOfInterest = p }
            if single, dev.isFocusModeSupported(.autoFocus) { dev.focusMode = .autoFocus }
            dev.unlockForConfiguration()
            // Locked once the lens stops moving.
            self.focusObservation = dev.observe(\.isAdjustingFocus, options: [.new]) { [weak self] d, _ in
                guard let self, !d.isAdjustingFocus else { return }
                self.focusObservation = nil
                if single, (try? d.lockForConfiguration()) != nil {
                    if d.isExposureModeSupported(.locked) && d.exposureMode != .custom { d.exposureMode = .locked }
                    d.unlockForConfiguration()
                }
                DispatchQueue.main.async {
                    guard self.halfPressed else { return }
                    self.focusLocked = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                }
            }
            if !dev.isAdjustingFocus && !single {
                DispatchQueue.main.async { if self.halfPressed { self.focusLocked = true } }
            }
        }
    }

    /// Second stage: fire, then let go of the lock.
    func fullPress() {
        if mode == .video { toggleRecording(); return }
        shoot()
        releaseHalfPress()
    }

    func releaseHalfPress() {
        guard halfPressed else { return }
        halfPressed = false
        focusLocked = false
        focusObservation = nil
        let point = focusPoint
        let front = self.front
        sessionQueue.async {
            guard let dev = self.device, (try? dev.lockForConfiguration()) != nil else { return }
            if dev.exposureMode == .locked && dev.isExposureModeSupported(.continuousAutoExposure) { dev.exposureMode = .continuousAutoExposure }
            dev.unlockForConfiguration()
            if let point { self.aim(point, front: front, continuous: true) } else if dev.isFocusModeSupported(.continuousAutoFocus), (try? dev.lockForConfiguration()) != nil {
                dev.focusMode = .continuousAutoFocus
                dev.unlockForConfiguration()
            }
        }
    }

    /// Eye AF: every few frames, find the nearer eye and aim there. In AF-S a held half-press freezes it.
    private func trackEye(_ pb: CVPixelBuffer) {
        guard let eye = EyeFinder.nearerEye(in: pb) else { return }
        DispatchQueue.main.async {
            guard self.settings.afArea == .eye, self.mode != .pro || self.focusIndex == nil else { return }
            if self.halfPressed && self.settings.afMode == .single { return }
            self.focusPoint = eye
            let front = self.front
            self.sessionQueue.async { self.aim(eye, front: front, continuous: true) }
        }
    }

    // MARK: swiping through films

    /// Next or previous tape in VIDEO.
    func stepTape(_ by: Int) {
        let all = VideoLook.allCases, n = all.count
        let i = all.firstIndex(of: videoLook) ?? 0
        videoLook = all[((i + by) % n + n) % n]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func stepSim(_ by: Int) {
        let ids: [String] = FilmCatalog.sims(for: mode).map { $0.id }
        let loaded = FilmCatalog.sim(stack.simID)?.id
        let i = ids.firstIndex(where: { $0 == loaded }) ?? 0
        let n = ids.count
        stack.simID = ids[((i + by) % n + n) % n]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Push or pull the loaded stock a stop: swipe up on its box to push, down to pull.
    func stepPush(_ by: Int) {
        guard mode == .film, FilmStock.stock(FilmCatalog.sim(stack.simID)?.stock) != nil else { return }
        let before = stack.push
        stack.push = before + by
        if stack.push != before { UISelectionFeedbackGenerator().selectionChanged() }
    }

    func stepLook(_ by: Int) {
        let all = Look.allCases
        let i = all.firstIndex(of: stack.look) ?? 0
        let n = all.count
        stack.look = all[((i + by) % n + n) % n]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: video

    /// The microphone joins the session the first time VIDEO is used.
    private func addAudioIfNeeded() {
        guard audioInput == nil else { return }
        let add = {
            guard let mic = AVCaptureDevice.default(for: .audio), let inp = try? AVCaptureDeviceInput(device: mic) else { return }
            self.session.beginConfiguration()
            if self.session.canAddInput(inp) { self.session.addInput(inp); self.audioInput = inp }
            if self.session.canAddOutput(self.audioOutput) {
                self.session.addOutput(self.audioOutput)
                self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
            }
            self.session.commitConfiguration()
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: add()
        case .notDetermined: AVCaptureDevice.requestAccess(for: .audio) { ok in if ok { self.sessionQueue.async { add() } } }
        default: break
        }
    }

    func toggleRecording() { recording ? stopRecording() : startRecording() }

    private func startRecording() {
        guard !recording else { return }
        fx.reset()
        // The turn locks when the clip starts, so a take never flips halfway.
        lock.lock(); _wantRecord = true; _lockedTurn = _turn; frameSegments = []; lock.unlock()
        segments = []
        recording = true
        recordSeconds = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.lock.lock(); let d = self._recorder?.duration ?? 0; let segs = self.frameSegments; self.lock.unlock()
            self.recordSeconds = d
            if segs != self.segments { self.segments = segs }
        }
    }

    func stopRecording() {
        guard recording else { return }
        recordTimer?.invalidate(); recordTimer = nil
        lock.lock(); let r = _recorder; _recorder = nil; _wantRecord = false; _lockedTurn = nil; let segs = frameSegments; lock.unlock()
        recording = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let r else { return }
        developing += 1
        r.finish { url in
            DispatchQueue.main.async {
                self.developing = max(0, self.developing - 1)
                guard let url else { return }
                if let lib = self.library {
                    lib.save(video: url) { id in if let id { TakeSegment.store(segs, for: id) } }
                } else if let dir = self.fallbackFolder {
                    try? FileManager.default.moveItem(at: url, to: dir.appendingPathComponent(url.lastPathComponent))
                }
            }
        }
    }

    // MARK: shooting

    /// The settings for one shot in mode `m`. A fresh object every time (each has its own id);
    /// the same recipe is handed to the output ahead of time so its buffers are ready.
    private func photoSettings(_ m: CaptureMode) -> (AVCapturePhotoSettings, zero: Bool) {
        let settingsP: AVCapturePhotoSettings
        let zero = m == .film && settings.digiZero && zeroFormat != nil
        if zero, let raw = zeroFormat {
            settingsP = AVCapturePhotoSettings(rawPixelFormatType: raw)
        } else if m == .pro && settings.proFormat == .heif && photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settingsP = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settingsP = AVCapturePhotoSettings()
        }
        let want: AVCapturePhotoOutput.QualityPrioritization = settings.flash != .off && m != .pro ? .balanced : m.prioritization
        settingsP.photoQualityPrioritization = want.rawValue <= photoOutput.maxPhotoQualityPrioritization.rawValue ? want : photoOutput.maxPhotoQualityPrioritization
        settingsP.maxPhotoDimensions = shotDims(m)
        let fm: AVCaptureDevice.FlashMode = settings.flash == .on ? .on : (settings.flash == .auto ? .auto : .off)
        if photoOutput.supportedFlashModes.contains(fm) { settingsP.flashMode = fm }
        // XA plays its own shutter; the system click is dropped where the law allows it.
        if settings.sounds && photoOutput.isShutterSoundSuppressionSupported { settingsP.isShutterSoundSuppressionEnabled = true }
        return (settingsP, zero)
    }

    /// Warm the photo pipeline for the next shot, so the first press doesn't wait while the
    /// camera allocates its buffers. Called when the session starts and whenever the recipe changes.
    func preparePhotos() {
        guard input != nil, mode != .video else { return }
        let (template, _) = photoSettings(mode)
        sessionQueue.async {
            self.photoOutput.setPreparedPhotoSettingsArray([template]) { _, _ in }
        }
    }

    /// The shot is taken from the moment of the press. With zero shutter lag that is literally
    /// true (the frame comes from the press), so the click, the blink and the review start right
    /// away instead of when the camera reports back. With the flash or RAW the camera has to make
    /// a new exposure, so those wait for it.
    func shoot() {
        guard authorized == true, input != nil else { return }
        if mode == .video { toggleRecording(); return }
        if mode == .booth { boothPress(); return }
        fire(booth: nil)
    }

    private func fire(booth: (session: Int, index: Int)?) {
        guard authorized == true, input != nil else { return }
        let pressed = CACurrentMediaTime()
        skipReview()
        let m = mode
        let (settingsP, zero) = photoSettings(m)
        syncFrameSettings()
        var (_, dev) = frameState()
        if let booth { dev.deco = settings.boothDeco.step(booth.index) }
        let id = settingsP.uniqueID
        pending[id] = Shot(mode: m, develop: dev, crunch: settings.crunch, date: Date(), zero: zero, pressed: pressed, booth: booth, front: front)
        let instant = settings.flash == .off && !zero && photoOutput.isZeroShutterLagEnabled
        if instant {
            answered.insert(id)
            if settings.sounds { CameraSounds.shared.play(.shutter) }
            if m.usesFilm && settings.instantReview { startReview() }
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (m == .booth ? 0.22 : 0.08)) { self.flash = false }
        } else if settings.sounds && settingsP.isShutterSoundSuppressionEnabled {
            quietShots.insert(id)
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        developing += 1
        let rc = rotation
        // Off the main thread: whatever the screen is busy drawing can't hold the shot up.
        sessionQueue.async {
            if let c = self.photoOutput.connection(with: .video) {
                if self.frontFlag {
                    // The selfie camera is shot exactly as the viewfinder shows it: upright and
                    // mirrored, the same turn and the same mirror as the frames. Its horizon
                    // angle came out upside down once mirrored.
                    if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = false }
                    if c.isVideoRotationAngleSupported(0) { c.videoRotationAngle = 0 }
                } else {
                    if let rc {
                        let a = rc.videoRotationAngleForHorizonLevelCapture
                        if c.isVideoRotationAngleSupported(a) { c.videoRotationAngle = a }
                    }
                    if c.isVideoMirroringSupported && !c.automaticallyAdjustsVideoMirroring { c.automaticallyAdjustsVideoMirroring = true }
                }
            }
            self.photoOutput.capturePhoto(with: settingsP, delegate: self)
        }
    }

    /// How long the last shot took, for Customize: press → taken → photo → developed.
    @Published private(set) var lastTiming = ""
    private var timing: (taken: Double, photo: Double) = (0, 0)
    /// Shots that already clicked and blinked at the press.
    private var answered: Set<Int64> = []

    /// Zero shutter lag hands back a frame from the moment you pressed, which with the flash on
    /// is the frame from before it fired. So with the flash on (or auto) the fast paths go off
    /// and the camera waits for its own flash; with it off, the shot is instant again.
    private func applyCapturePolicy(flash: Bool) {
        let fast = !flash
        if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = fast }
        if photoOutput.isFastCapturePrioritizationSupported { photoOutput.isFastCapturePrioritizationEnabled = fast }
        if photoOutput.isZeroShutterLagSupported { photoOutput.isZeroShutterLagEnabled = fast }
    }

    /// ZERO switched: Apple ProRAW is turned on in the output only while it is wanted.
    func zeroChanged() {
        let on = settings.digiZero
        sessionQueue.async {
            guard self.photoOutput.isAppleProRAWSupported, self.photoOutput.isAppleProRAWEnabled != on else { return }
            self.session.beginConfiguration()
            self.photoOutput.isAppleProRAWEnabled = on
            self.session.commitConfiguration()
        }
        preparePhotos()
    }

    /// The RAW format ZERO shoots: Apple ProRAW where there is one, else the sensor's Bayer RAW.
    private var zeroFormat: OSType? {
        let all = photoOutput.availableRawPhotoPixelFormatTypes
        return all.first(where: { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }) ?? all.first
    }

    /// Called when the flash setting changes.
    func flashChanged() {
        let on = settings.flash != .off
        sessionQueue.async {
            self.session.beginConfiguration()
            self.applyCapturePolicy(flash: on)
            self.session.commitConfiguration()
        }
        preparePhotos()
    }

    private struct Shot { let mode: CaptureMode; let develop: DevelopSettings; let crunch: Double; let date: Date; var zero = false; var pressed: Double = 0; var booth: (session: Int, index: Int)? = nil; var front = false }
    private var pending: [Int64: Shot] = [:]
    /// Shots whose system click was dropped, so XA plays its own when the picture is really taken.
    private var quietShots: Set<Int64> = []

    private func develop(_ data: Data, _ shot: Shot) {
        developQueue.async {
            defer { DispatchQueue.main.async { self.developing = max(0, self.developing - 1) } }
            // DIGI expands the photo's HDR gain map, so a lamp is brighter than white paper and
            // only real light sources bloom. PRO keeps the file untouched anyway.
            let opts: [CIImageOption: Any] = shot.mode == .pro ? [.applyOrientationProperty: true] : [.applyOrientationProperty: true, .expandToHDR: true]
            guard var src = CIImage(data: data, options: opts) ?? CIImage(data: data, options: [.applyOrientationProperty: true]) else { return }
            // ZERO: the RAW developed flat, no boost, no local tone mapping, no HDR: only the
            // film shapes the picture. The metadata still comes from the file.
            let fileProps = src.properties
            var demo: DigicamFX.Conditions? = nil
            if shot.zero, let raw = CIRAWFilter(imageData: data, identifierHint: nil) {
                raw.boostAmount = 0
                raw.localToneMapAmount = 0
                raw.extendedDynamicRangeAmount = 0
                if let o = raw.outputImage { src = o; demo = DigicamFX.Conditions(properties: fileProps) }
            }
            // The selfie camera: upright and mirrored, as the viewfinder showed it.
            if shot.front && shot.mode != .pro { src = Self.upright(src, mirror: true) }
            var out: Data?
            var type: UTType = .jpeg
            var thumbSource = src
            if shot.mode == .pro && !shot.front {
                // Saved exactly as the camera made it.
                out = data
                type = self.settings.proFormat == .heif ? .heic : .jpeg
            } else if shot.mode == .pro {
                // The selfie camera in PRO: turned upright and mirrored, nothing else.
                type = self.settings.proFormat == .heif ? .heic : .jpeg
                if let cg = Encoder.render(src, reference: nil) {
                    var props = fileProps
                    props[kCGImagePropertyOrientation as String] = 1
                    if var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                        tiff[kCGImagePropertyTIFFOrientation as String] = 1
                        props[kCGImagePropertyTIFFDictionary as String] = tiff
                    }
                    out = Encoder.encode(cg, type: type, quality: 0.95, properties: props)
                }
            } else {
                let (developed, alpha) = Darkroom.develop(src, shot.develop, date: shot.date, preview: false, demo: demo)
                let recipe = shot.develop.booth.map { "XA BOOTH · \($0.title)" } ?? Recipe.describe(shot.develop.stack, megapixels: shot.develop.megapixels, film: shot.develop.film)
                thumbSource = developed
                // The thumbnail first: it is the reference the full render is checked against,
                // cell by cell, so a render that came back with black tiles is redone on the CPU.
                let e0 = developed.extent
                let k0: CGFloat = 200 / max(e0.width, 1)
                let small = developed.transformed(by: CGAffineTransform(scaleX: k0, y: k0))
                let reference = Encoder.gpu.createCGImage(small, from: small.extent.integral)
                guard let cg = Encoder.render(developed, reference: reference) else { return }
                let props = Recipe.properties(from: fileProps, recipe: recipe)
                // FILM keeps everything: HEIC at a high quality. DIGI saves the crunch you chose.
                let full = shot.develop.film || shot.develop.booth != nil
                type = full ? .heic : (alpha ? .png : .jpeg)
                out = Encoder.encode(cg, type: type, quality: full ? 0.95 : CGFloat(shot.crunch), properties: props)
                if let b = shot.booth {
                    let small = Self.downsized(cg, longEdge: 1400)
                    DispatchQueue.main.async { self.boothCollect(b.session, b.index, small, date: shot.date) }
                }
                if out == nil && type == .heic {
                    type = .jpeg
                    out = Encoder.encode(cg, type: .jpeg, quality: 0.95, properties: props)
                }
            }
            guard let out else { return }
            let e = thumbSource.extent
            let k: CGFloat = 200 / max(e.width, 1)
            let small = thumbSource.transformed(by: CGAffineTransform(scaleX: k, y: k))
            let thumb = Looks.context.createCGImage(small, from: small.extent)
            let done = CACurrentMediaTime() - shot.pressed
            DispatchQueue.main.async {
                func ms(_ t: Double) -> String { t < 1 ? "\(Int(t * 1000)) ms" : String(format: "%.1f s", t) }
                self.lastTiming = "taken \(ms(self.timing.taken)) · photo \(ms(self.timing.photo)) · saved \(ms(done))"
                if let thumb { self.lastShot = UIImage(cgImage: thumb) }
                if let lib = self.library {
                    lib.save(data: out, type: type) { ok in
                        if !ok { self.writeFallback(out, type) }
                    }
                } else {
                    self.writeFallback(out, type)
                }
            }
        }
    }

    private func save(_ out: Data, _ type: UTType) {
        if let lib = library {
            lib.save(data: out, type: type) { ok in if !ok { self.writeFallback(out, type) } }
        } else {
            writeFallback(out, type)
        }
    }

    private func writeFallback(_ data: Data, _ type: UTType) {
        guard let dir = fallbackFolder else { return }
        let ext = type.preferredFilenameExtension ?? "jpg"
        let url = dir.appendingPathComponent("XA-\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)")
        try? data.write(to: url)
    }

    // MARK: instant review

    private func startReview() {
        let n = UserDefaults.standard.integer(forKey: "fileNumber") + 1
        UserDefaults.standard.set(n, forKey: "fileNumber")
        reviewFile = String(format: "100-%04d", n % 10000)
        reviewToken += 1
        let token = reviewToken
        lock.lock(); _reviewUntil = CACurrentMediaTime() + Self.reviewSeconds; _reviewDrawn = false; lock.unlock()
        reviewing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reviewSeconds) {
            if self.reviewToken == token { self.reviewing = false }
        }
    }

    /// Back to live view now: a half-press, a new shot or a mode change skips the review.
    func skipReview() {
        guard reviewing else { return }
        reviewToken += 1
        lock.lock(); _reviewUntil = 0; lock.unlock()
        reviewing = false
    }

    // MARK: histogram

    private func updateHistogram(_ img: CIImage) {
        let f = CIFilter.areaHistogram()
        f.inputImage = img
        f.extent = img.extent
        f.count = 48
        f.scale = 1
        guard let out = f.outputImage else { return }
        var px = [Float](repeating: 0, count: 48 * 4)
        Looks.context.render(out, toBitmap: &px, rowBytes: 48 * 4 * MemoryLayout<Float>.size, bounds: CGRect(x: 0, y: 0, width: 48, height: 1), format: .RGBAf, colorSpace: nil)
        var bins = [Float](repeating: 0, count: 48)
        for i in 0..<48 { bins[i] = max(px[i * 4], px[i * 4 + 1], px[i * 4 + 2]) }
        let mx = max(bins.max() ?? 1, 0.0001)
        let norm = bins.map { $0 / mx }
        DispatchQueue.main.async { self.histogram = norm }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            lock.lock(); let r = _recorder; lock.unlock()
            r?.append(audio: sampleBuffer)
            return
        }
        if output === uwOutput {
            // Every other ultra-wide frame, small and copied out so the camera gets its buffer back.
            uwCount += 1
            guard uwCount % 2 == 0, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let raw = CIImage(cvPixelBuffer: pb)
            let k: CGFloat = 640 / max(raw.extent.width, raw.extent.height, 1)
            let small = raw.transformed(by: CGAffineTransform(scaleX: k, y: k))
            if let cg = Looks.context.createCGImage(small, from: small.extent.integral) {
                let img = CIImage(cgImage: cg)
                lock.lock(); _uw = img; lock.unlock()
            }
            return
        }
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Cleaned at the door: a sensor pixel below the legal video range decodes to NaN, and every
        // blur and resize downstream would spread it into a black square.
        let raw = Self.upright(Sanitize.apply(CIImage(cvPixelBuffer: pb), floor: 0), mirror: frontFlag)
        let e = raw.extent
        let k: CGFloat = min(1, 1080 / max(e.width, 1))
        let src = raw.transformed(by: CGAffineTransform(scaleX: k, y: k))
        let (m, dev) = frameState()
        frameCount += 1
        if m != .video && frameCount % 6 == 3 && settings.afArea == .eye { trackEye(pb) }
        if frameCount % 10 == 0 {
            let s: CGFloat = 640 / max(src.extent.width, 1)
            let small = src.transformed(by: CGAffineTransform(scaleX: s, y: s))
            lock.lock(); _latest = small; lock.unlock()
        }
        lock.lock()
        if _switchPending { _switchPending = false; _switchStart = CACurrentMediaTime() }
        let vlook = frameVideoLook
        lock.unlock()
        if m == .video {
            lock.lock(); let t = _lockedTurn ?? _turn; lock.unlock()
            let upright = Self.rotated(src, clockwise: t)
            var base = upright
            if let sim = FilmCatalog.sim(dev.stack.simID), !sim.isNeutral { base = SimEngine.apply(sim, to: base, preview: true, push: dev.stack.push) }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let frame = fx.apply(vlook, to: base, time: pts.seconds, date: Date())
            lock.lock()
            if _wantRecord && _recorder == nil { _recorder = VideoRecorder(size: frame.extent.size, audio: audioInput != nil) }
            let r = _recorder
            if let r {
                // A new segment whenever the tape changes mid-take.
                let at = r.duration
                if frameSegments.last?.look != vlook { frameSegments.append(TakeSegment(look: vlook, start: at)) }
            }
            lock.unlock()
            r?.append(frame, at: pts)
            let shown = t == 0 ? frame : Self.rotated(frame, clockwise: 360 - t)
            preview?.show(shown, pixelated: vlook == .pocket)
            return
        }
        let img: CIImage
        let amount = digiAmount()
        if amount <= 0 {
            img = src
            if m == .pro && frameCount % 6 == 0 {
                let s: CGFloat = 160 / max(src.extent.width, 1)
                updateHistogram(src.transformed(by: CGAffineTransform(scaleX: s, y: s)))
            }
            if m == .pro && frameCount % 15 == 0, let dev = device {
                let d = dev.exposureDuration.seconds, iso = dev.iso
                DispatchQueue.main.async { self.meterShutter = d; self.meterISO = iso }
            }
        } else {
            // Develop the frame the way the photograph will be turned, so the date back and the
            // shape sit where they will on the print, then turn it back for the viewfinder.
            if frameCount % 15 == 0, let dev = device {
                let d = dev.exposureDuration.seconds, iso = dev.iso
                DispatchQueue.main.async { self.meterShutter = d; self.meterISO = iso }
            }
            let t = turn
            let upright = Self.rotated(src, clockwise: t)
            var dev = dev
            if dev.booth != nil {
                lock.lock(); dev.eyes = _boothEyes; let busy = eyesBusy; if !busy { eyesBusy = true }; lock.unlock()
                if !busy { findEyes(upright) }
            }
            var developed = Darkroom.develop(upright, dev, date: Date(), preview: true, dateShift: 1 - amount).0
            if amount < 1 {
                // Switching modes: the film fades in or out and the date slides with it.
                let f = CIFilter.dissolveTransition()
                f.inputImage = upright
                f.targetImage = developed
                f.time = Float(amount)
                developed = (f.outputImage ?? developed).cropped(to: developed.extent.union(upright.extent))
            }
            var shown = t == 0 ? developed : Self.rotated(developed, clockwise: 360 - t)
            if m == .film && dev.filmRecipe.xaFinder {
                // The rangefinder patch: its second image slips off when the camera moves or the
                // distance changes, then comes back the way a hand turns a focus ring: a big change
                // swings back slowly and overshoots, a small one snaps, and no two are the same.
                var motionDrive: CGFloat = 0
                if let r = motion.deviceMotion?.rotationRate {
                    motionDrive = CGFloat(min(1, (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot() * 0.5))
                }
                var depth: CGFloat = 0
                var hunting = false
                if let d = device {
                    let lp = d.lensPosition
                    if lastLens >= 0 { depth = CGFloat(lp - lastLens) * 30 }
                    lastLens = lp
                    hunting = d.isAdjustingFocus
                }
                let kick = min(1, max(motionDrive, abs(depth)))
                if kick > 0.12 && kick > abs(patch.pos) * 0.9 {
                    let sign: CGFloat = depth != 0 ? (depth > 0 ? 1 : -1) : (Bool.random() ? 1 : -1)
                    patch.pos = sign * kick
                    patch.vel = 0
                    // further to turn: a slower, looser hand; a nudge: quick and tight
                    patch.k = 95 - 60 * kick + CGFloat.random(in: -10...10)
                    patch.zeta = CGFloat.random(in: 0.28...0.75) + (kick < 0.3 ? 0.15 : 0)
                }
                if hunting {
                    // still turning the ring: the image wanders a little instead of settling
                    patch.vel += CGFloat.random(in: -0.6...0.6)
                }
                patch.step(1.0 / 30)
                patchShift = patch.pos
                // The markings sit on glass nearer the eye: they lag the camera's turn a little.
                if let r = motion.deviceMotion?.rotationRate {
                    sway = CGSize(width: sway.width * 0.84 + CGFloat(r.y) * 2.2, height: sway.height * 0.84 + CGFloat(r.x) * 2.2)
                } else {
                    sway = CGSize(width: sway.width * 0.84, height: sway.height * 0.84)
                }
                let sw = CGSize(width: max(-14, min(14, sway.width)), height: max(-14, min(14, sway.height)))
                DispatchQueue.main.async { self.finderSway = sw }
                lock.lock(); let uw = _uw; let ratio = _uwRatio; var gain = _uwGain; let flong = _finderLong; lock.unlock()
                if let uw, frameCount % 12 == 0, let g = XAFinder.matchGain(main: shown, wide: uw, ratio: ratio) {
                    // The ultra-wide sees colour and exposure its own way: matched to the main camera, slowly.
                    gain = CIVector(x: gain.x * 0.75 + g.x * 0.25, y: gain.y * 0.75 + g.y * 0.25, z: gain.z * 0.75 + g.z * 0.25)
                    lock.lock(); _uwGain = gain; lock.unlock()
                }
                shown = XAFinder.compose(shown, format: dev.filmRecipe.format, shift: patchShift, long: flong, wide: uw, ratio: ratio, gain: gain)
            }
            img = shown
        }
        let pixel = m == .digi && dev.stack.look.pixelWidth != nil
        lock.lock()
        let holding = CACurrentMediaTime() < _reviewUntil
        let drawHeld = holding && !_reviewDrawn
        if drawHeld { _reviewDrawn = true }
        let held = _lastShown
        if !holding { _lastShown = img }
        lock.unlock()
        if holding {
            // The shot stays up on the viewfinder, as it was, until the review is over.
            if drawHeld, let held { preview?.show(held, pixelated: pixel) }
            return
        }
        // Drawn right here on the frame queue: the main thread can be busy without the viewfinder stuttering.
        preview?.show(img, pixelated: pixel)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    /// The moment the sensor actually exposes, after any pre-flash: that is when the shutter sounds
    /// and the screen blinks, so neither happens before the flash.
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        let id = resolvedSettings.uniqueID
        let now = CACurrentMediaTime()
        DispatchQueue.main.async {
            if let p = self.pending[id]?.pressed { self.timing.taken = now - p }
            if self.answered.remove(id) != nil { return }
            if self.quietShots.remove(id) != nil { CameraSounds.shared.play(.shutter) }
            if self.pending[id]?.mode.usesFilm == true && self.settings.instantReview { self.startReview() }
            self.flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { self.flash = false }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let data = photo.fileDataRepresentation()
        let now = CACurrentMediaTime()
        DispatchQueue.main.async {
            guard let shot = self.pending.removeValue(forKey: id) else { return }
            self.timing.photo = now - shot.pressed
            self.preparePhotos()
            guard error == nil, let data else { self.developing = max(0, self.developing - 1); return }
            self.develop(data, shot)
        }
    }
}

extension CameraModel: AVCaptureSessionControlsDelegate {
    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {}
    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {}
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {}
}


// MARK: BOOTH

extension CameraModel {
    /// One press runs the booth: a countdown, a shot, four times. A press while it runs stops it.
    func boothPress() {
        if boothShot != nil { cancelBooth(); return }
        boothSession += 1
        boothFrames[boothSession] = [:]
        boothStep(boothSession, 0)
    }

    func cancelBooth() {
        guard boothShot != nil else { return }
        boothFrames[boothSession] = nil
        boothSession += 1
        boothShot = nil
        boothCount = nil
    }

    private func boothStep(_ session: Int, _ index: Int) {
        guard session == boothSession, mode == .booth else { return }
        boothShot = index + 1
        count(session, from: index == 0 ? 3 : 2) {
            self.boothCount = nil
            self.fire(booth: (session, index))
            if index + 1 < Booth.shots {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.boothStep(session, index + 1) }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { if session == self.boothSession { self.boothShot = nil } }
            }
        }
    }

    private func count(_ session: Int, from n: Int, then: @escaping () -> Void) {
        guard session == boothSession else { return }
        if n == 0 { then(); return }
        boothCount = n
        if settings.sounds { CameraSounds.shared.play(.beep) }
        UISelectionFeedbackGenerator().selectionChanged()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { self.count(session, from: n - 1, then: then) }
    }

    /// A developed shot arrives; with all four in, the sheet is laid out and saved.
    fileprivate func boothCollect(_ session: Int, _ index: Int, _ img: UIImage?, date: Date) {
        guard let img, boothFrames[session] != nil else { return }
        boothFrames[session]?[index] = img
        guard let got = boothFrames[session], got.count == Booth.shots else { return }
        boothFrames[session] = nil
        let shots = (0..<Booth.shots).compactMap { got[$0] }
        let layout = settings.boothLayout
        let n = UserDefaults.standard.integer(forKey: "boothNumber") + 1
        UserDefaults.standard.set(n, forKey: "boothNumber")
        developing += 1
        developQueue.async {
            defer { DispatchQueue.main.async { self.developing = max(0, self.developing - 1) } }
            guard let sheet = Booth.sheet(shots, layout: layout, date: date, number: n), let cg = sheet.cgImage,
                  let out = Encoder.encode(cg, type: .jpeg, quality: 0.93, properties: [:]) else { return }
            let thumb = Self.downsized(cg, longEdge: 200)
            DispatchQueue.main.async {
                if let thumb { self.lastShot = thumb }
                self.save(out, .jpeg)
            }
        }
    }

    /// BOOTH's face warp in the viewfinder: the faces are looked for off the frame queue, a few times a second.
    fileprivate func findEyes(_ frame: CIImage) {
        // Big enough that the faces at the back of a group are still found.
        let k: CGFloat = min(1, 720 / max(frame.extent.width, 1))
        let small = frame.transformed(by: CGAffineTransform(scaleX: k, y: k))
        eyeQueue.async {
            let found = Booth.scaled(Booth.eyes(in: small), 1 / k)
            self.lock.lock(); self._boothEyes = found; self.eyesBusy = false; self.lock.unlock()
        }
    }

    static func downsized(_ cg: CGImage, longEdge: CGFloat) -> UIImage? {
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let k = min(1, longEdge / max(w, h))
        let size = CGSize(width: (w * k).rounded(), height: (h * k).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: FILM's finder

extension CameraModel {
    /// The phone's motion is read only while FILM's finder needs it.
    func updateMotion() {
        if mode == .film {
            guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
            motion.deviceMotionUpdateInterval = 1.0 / 30
            motion.startDeviceMotionUpdates()
        } else if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
    }
}

// MARK: FILM's ultra-wide

extension CameraModel {
    /// Whether FILM should run the ultra-wide behind its finder now.
    private var wantsUltraWide: Bool {
        mode == .film && settings.filmRecipe.xaFinder && !front && AVCaptureMultiCamSession.isMultiCamSupported
            && AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
    }

    /// Bring the ultra-wide in or out to match the mode and the finder setting.
    func updateUltraWide() {
        let want = wantsUltraWide
        sessionQueue.async {
            guard self.authorized == true || self.input != nil else { return }
            if want != self.multiCam { self.rebuildSession(multi: want) }
        }
    }

    /// On the session queue: take everything off the current session and build the other kind.
    private func rebuildSession(multi: Bool) {
        session.stopRunning()
        detach(session)
        input = nil; device = nil; uwInput = nil; audioInput = nil
        lock.lock(); _uw = nil; lock.unlock()
        multiCam = false
        if multi && configureMulti() {
            multiCam = true
        } else {
            session = AVCaptureSession()
            configure()
        }
    }

    private func detach(_ s: AVCaptureSession) {
        s.beginConfiguration()
        if let ms = s as? AVCaptureMultiCamSession { for c in ms.connections { ms.removeConnection(c) } }
        for i in s.inputs { s.removeInput(i) }
        for o in s.outputs { s.removeOutput(o) }
        if s.supportsControls { for c in s.controls { s.removeControl(c) } }
        s.commitConfiguration()
    }

    /// The main camera (photos and the viewfinder) and the ultra-wide (the finder's surround)
    /// together. False if the phone can't run both at full photo quality; the caller then goes
    /// back to the plain session.
    private func configureMulti() -> Bool {
        guard let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let uw = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back),
              let wIn = try? AVCaptureDeviceInput(device: wide), let uIn = try? AVCaptureDeviceInput(device: uw) else { return false }
        let ms = AVCaptureMultiCamSession()
        session = ms
        ms.beginConfiguration()
        func fail() -> Bool { ms.commitConfiguration(); detach(ms); return false }
        guard ms.canAddInput(wIn), ms.canAddInput(uIn) else { return fail() }
        ms.addInputWithNoConnections(wIn)
        ms.addInputWithNoConnections(uIn)
        guard Self.pickMultiFormat(wide, photo: true), Self.pickMultiFormat(uw, photo: false) else { return fail() }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        uwOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        uwOutput.alwaysDiscardsLateVideoFrames = true
        uwOutput.setSampleBufferDelegate(self, queue: frameQueue)
        guard ms.canAddOutput(photoOutput), ms.canAddOutput(videoOutput), ms.canAddOutput(uwOutput) else { return fail() }
        ms.addOutputWithNoConnections(photoOutput)
        ms.addOutputWithNoConnections(videoOutput)
        ms.addOutputWithNoConnections(uwOutput)
        guard let wPort = wIn.ports(for: .video, sourceDeviceType: wide.deviceType, sourceDevicePosition: .back).first,
              let uPort = uIn.ports(for: .video, sourceDeviceType: uw.deviceType, sourceDevicePosition: .back).first else { return fail() }
        let links = [AVCaptureConnection(inputPorts: [wPort], output: videoOutput),
                     AVCaptureConnection(inputPorts: [wPort], output: photoOutput),
                     AVCaptureConnection(inputPorts: [uPort], output: uwOutput)]
        for c in links {
            guard ms.canAddConnection(c) else { return fail() }
            ms.addConnection(c)
        }
        photoOutput.maxPhotoQualityPrioritization = .quality
        applyCapturePolicy(flash: settings.flash != .off)
        device = wide; input = wIn; uwInput = uIn
        let m = mode
        setupPhotoOutput(wide, m)
        ms.commitConfiguration()
        // Too much for this phone at this quality: drop the ultra-wide rather than the photo.
        guard ms.hardwareCost <= 1, ms.systemPressureCost <= 1 else { detach(ms); return false }
        let fovW = Double(wide.activeFormat.videoFieldOfView), fovU = Double(uw.activeFormat.videoFieldOfView)
        let ratio = tan(fovU / 2 * .pi / 180) / tan(fovW / 2 * .pi / 180)
        lock.lock(); _uwRatio = CGFloat(ratio.isFinite && ratio > 1 ? ratio : 2); _uwGain = CIVector(x: 1, y: 1, z: 1); lock.unlock()
        setupLenses(wide)
        applyRotation()
        ms.startRunning()
        applyProOnQueue(m)
        DispatchQueue.main.async { self.preparePhotos() }
        return true
    }

    /// A multi-camera format: for the main camera the one with the biggest photos (a 4:3 picture,
    /// the viewfinder no wider than 1920); for the ultra-wide the smallest 4:3 one, to keep the cost low.
    private static func pickMultiFormat(_ d: AVCaptureDevice, photo: Bool) -> Bool {
        func px(_ x: CMVideoDimensions) -> Int { Int(x.width) * Int(x.height) }
        let ok = d.formats.filter { f in
            let v = f.formatDescription.dimensions
            return f.isMultiCamSupported && abs(Double(v.width) * 3 - Double(v.height) * 4) < 8 && v.width <= 1920
        }
        let pick: AVCaptureDevice.Format?
        if photo {
            pick = ok.max { a, b in
                let pa = a.supportedMaxPhotoDimensions.map(px).max() ?? 0, pb = b.supportedMaxPhotoDimensions.map(px).max() ?? 0
                return pa != pb ? pa < pb : a.formatDescription.dimensions.width < b.formatDescription.dimensions.width
            }
        } else {
            pick = ok.filter { $0.formatDescription.dimensions.width >= 640 }.min { $0.formatDescription.dimensions.width < $1.formatDescription.dimensions.width } ?? ok.first
        }
        // Never at the photo's expense: the main camera must still take full-size (12MP) pictures.
        if photo, (pick?.supportedMaxPhotoDimensions.map(px).max() ?? 0) < 11_900_000 { return false }
        guard let pick, (try? d.lockForConfiguration()) != nil else { return false }
        d.activeFormat = pick
        d.unlockForConfiguration()
        return true
    }
}

extension CameraModel {
    /// The FILM finder's shape, from the view: its height over its width.
    func setFinderShape(_ hOverW: CGFloat) {
        let l = XAFinder.long(hOverW)
        lock.lock(); _finderLong = l; lock.unlock()
    }

    /// A point on the XA finder (normalised to the finder) → the same point on the camera's
    /// picture (normalised), or nil when it falls outside the frame.
    func finderToPicture(_ p: CGPoint) -> CGPoint? {
        lock.lock(); let l = _finderLong; lock.unlock()
        let f = settings.filmRecipe.format
        let n = XAFinder.frame(f, long: l)
        guard n.contains(p) else { return nil }
        let local = CGPoint(x: (p.x - n.minX) / n.width, y: (p.y - n.minY) / n.height)
        // the format's crop inside the picture (3:4 portrait), normalised
        let c = f.frame(in: CGRect(x: 0, y: 0, width: 3, height: 4))
        return CGPoint(x: (c.minX + local.x * c.width) / 3, y: (c.minY + local.y * c.height) / 4)
    }
}
