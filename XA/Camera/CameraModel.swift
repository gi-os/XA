import AVFoundation
import CoreMotion
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UIKit
import UniformTypeIdentifiers
import Vision
import Photos

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
    /// Whether the phone can shoot Apple ProRAW (Customize hides Develop from RAW otherwise).
    @Published private(set) var rawSupported = UserDefaults.standard.bool(forKey: "rawSupported")
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
    /// Starred films for this mode (FILM's stocks and DIGI's sims are kept apart), in the order starred.
    @Published private(set) var favorites: [String] = []
    /// A QR code PRO is looking at (its text), while it is in view.
    @Published var qrCode: String?
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
    /// The live histogram, in its own object: its five updates a second redraw only the
    /// histograms, not every view that watches the camera.
    let meters = LiveMeters()
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
    /// The dials as the session queue reads them (no waiting on the main thread from there).
    private func snapshotDials() {
        lock.lock(); _dials = (shutterIndex, isoIndex, wbIndex, focusIndex, ev); lock.unlock()
    }

    /// A plain session, or in FILM (with the XA finder) a multi-camera one that also streams the ultra-wide.
    private(set) var session: AVCaptureSession = AVCaptureSession()
    let settings: AppSettings
    weak var preview: PreviewView?
    var library: Library?
    /// Where the Lock Screen camera saves when Photos is not available to it.
    var fallbackFolder: URL?
    /// The hardware buttons (volume, Camera Control) take pictures only while the camera is on
    /// screen: not under the roll, a sheet or the photo viewer.
    @Published var captureButtonsEnabled = true

    private let photoOutput = AVCapturePhotoOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let audioQueue = DispatchQueue(label: "xa.audio")
    private var audioInput: AVCaptureDeviceInput?
    private var frameVideoLook: VideoLook = .clean
    private var _wantRecord = false
    private var _lockedTurn: CGFloat?
    private var frameSegments: [TakeSegment] = []
    private var _recorder: VideoRecorder?
    /// VIDEO's tapes, made the first time VIDEO draws a frame (they bring their own Metal
    /// context, which the other modes and the Lock Screen camera never need). The frame queue's.
    private var fx: VideoFX {
        if let f = _fx { return f }
        let f = VideoFX(); _fx = f; return f
    }
    private var _fx: VideoFX?
    /// POCKET 3D's sound (the 3DS's microphone and its 4-bit, 16 kHz code). The audio queue's.
    private let pocketAudio = Pocket3DAudio()
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
    private var _boothMask: CIImage?
    private var eyesBusy = false
    private var lastEyesAt: CFTimeInterval = 0
    private var eyeAFBusy = false
    /// Kept between frames, on the eye queue: Vision smooths a person's mask over time.
    private lazy var segmentation = VNGeneratePersonSegmentationRequest()
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
    private var lastKick: CFTimeInterval = 0
    private var lastFrameAt: CFTimeInterval = 0
    private let qrOutput = AVCaptureMetadataOutput()
    private var qrClear: DispatchWorkItem?
    /// The mic is on the session (read on the frame queue, so kept under the lock).
    private var _hasMic = false
    /// What Camera Control's pickers show, read on the session queue (kept under the lock).
    private var _ctlSim: String?
    private var _ctlLook: Look = .none
    /// Configure tries left when the camera can't be opened yet (another app still has it).
    private var configureTries = 0
    /// The ultra-wide couldn't run alongside the main camera on this phone: not tried again.
    private var multiCamFailed = false
    /// Frames aren't shown yet (see holdViewfinder). Read on the frame queue, under the lock.
    private var _holdFrames = false
    /// The first configure opens FILM's two-camera session directly (set on the main thread).
    private var _launchMulti = false
    /// The PRO dials, read on the session queue (kept under the lock).
    private var _dials: (shutter: Int?, iso: Int?, wb: Int, focus: Int?, ev: Float) = (nil, nil, 0, nil, 0)
    #if CAPTURE_EXTENSION
    /// The Lock Screen camera writes each shot's files in order on this queue.
    private let ioQueue = DispatchQueue(label: "xa.lock.io", qos: .userInitiated)
    private let run = Int(Date().timeIntervalSince1970 * 1000)
    private var shotCount = 0
    /// Each pending shot's file name and recipe, read on the photo callback's queue.
    private var _lockShots: [Int64: (name: String, recipe: LockShot)] = [:]
    #endif
    private var lowPower = false
    private var finderLight: CGFloat = 1
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
    /// How far the finder's markings have swung with the camera's motion. Its own object, so the
    /// 30 updates a second move only the finder, not every view that watches the camera.
    let finderMotion = FinderMotion()
    private var sway: CGSize = .zero
    private var lastSway: CGSize = .zero
    private var lastLight: CGFloat = 1
    /// When FILM's finder started arriving (it steps back into place over 0.75 s), and whether
    /// the patch has dropped in yet.
    private var _introStart: CFTimeInterval = 0
    private var _outroStart: CFTimeInterval = -10
    private var _peekStart: CFTimeInterval = -100
    private var _filmAlwaysOn = false
    static let peekHold: Double = 2.6, peekFade: Double = 0.7
    static let outroLength: Double = 0.45
    /// Leaving FILM: the XA finder stays up a moment to step back out.
    @Published var leavingFilm = false
    private var introPatchDone = true
    private let eyeQueue = DispatchQueue(label: "xa.eyes", qos: .userInitiated)
    private var proDims = CMVideoDimensions(width: 4032, height: 3024)
    /// FILM's drum and full scans: the biggest photo the sensor makes.
    private var filmDims = CMVideoDimensions(width: 4032, height: 3024)

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
        lock.lock(); _ctlSim = stack.simID; _ctlLook = stack.look; lock.unlock()
        // The camera can stop under us (a call, another app, the media server restarting): start
        // it again when it can, and never leave a take running into a dead session.
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: nil, queue: nil) { [weak self] n in
            guard let self else { return }
            self.sessionQueue.async {
                guard (n.object as? AVCaptureSession) === self.session else { return }
                if self.input == nil { self.configure(); return }
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
        nc.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: nil, queue: .main) { [weak self] _ in
            if self?.recording == true { self?.stopRecording() }
        }
    }

    /// The Lock Screen camera takes on the app's settings (already applied to `settings` and to
    /// its own defaults by LockSettings.apply): the mode, the film for it, the favourites.
    func adopt(_ l: LockSettings) {
        let m = LockSettings.modes.contains(l.mode) ? l.mode : .digi
        if mode != m { mode = m }
        stack = m == .film ? l.filmStack : l.digiStack
        loadFavorites()
        syncFrameSettings()
        // on the session queue, after the camera has opened (it may still be opening)
        applyResolution(); flashChanged()
    }

    /// The Lock Screen camera holds the viewfinder while the app's settings come in, so the
    /// camera can open at the same time instead of after them. Let go, it opens already in its
    /// mode: no fade from the mode it started in.
    func holdViewfinder(_ hold: Bool) {
        lock.lock()
        _holdFrames = hold
        if !hold { _switchPending = false; _switchStart = 0 }
        lock.unlock()
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
        d.screenDate = mode == .digi && settings.digiOSD
        if mode == .booth {
            d.booth = settings.boothSkin
            d.deco = settings.boothDeco.step((boothShot ?? 1) - 1)
        }
        lock.lock()
        // FILM's finder is plain, like a real viewfinder; a change of film (stock, push, the
        // camera or lab settings, or arriving in FILM) shows it accurately for a moment.
        if mode == .film && (_frameMode != .film || _develop.stack != d.stack || _develop.filmRecipe != d.filmRecipe) {
            _peekStart = CACurrentMediaTime()
        }
        _develop = d; _frameMode = mode; _filmAlwaysOn = settings.filmAlwaysOn
        lock.unlock()
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
        lock.lock(); _ctlSim = stack.simID; _ctlLook = stack.look; lock.unlock()
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
            if old == .video { frameQueue.async { self._fx?.release() } }
            if (old == .film) != (mode == .film) { stack = Self.loadStack(for: mode) }
            // BOOTH turns the camera round to face you, and back when you leave.
            if old == .booth { cancelBooth(); setFront(false) }
            updateMotion()
            loadFavorites()
            updateUltraWide()
            if mode == .film { beginFinderIntro() }
            if old == .film && settings.filmRecipe.xaFinder {
                lock.lock(); _outroStart = CACurrentMediaTime(); lock.unlock()
                leavingFilm = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.outroLength) { [weak self] in
                    if self?.mode != .film { self?.leavingFilm = false }
                }
            } else if mode == .film { leavingFilm = false }
            if mode == .booth { setFront(true) }
        }
        syncFrameSettings()
        guard old != mode else { return }
        let m = mode
        publishPhotoSize(m)
        snapshotDials()
        // Checked on the session queue, not here: a mode that changes while the camera is still
        // opening (the Lock Screen camera taking the app's settings) waits behind configure()
        // instead of being skipped.
        sessionQueue.async {
            guard self.input != nil else { return }
            // the microphone only while in VIDEO: elsewhere it kept the orange dot on, stopped the
            // user's music and made XA's sounds ignore the silent switch
            if m == .video { self.addAudioIfNeeded() } else { self.removeAudio() }
            self.applyProOnQueue(m)
            self.updateQR(m)
        }
        preparePhotos()
        // Camera Control is rebuilt once the fade is over, so it cannot stall the feed during it.
        sessionQueue.asyncAfter(deadline: .now() + 0.7) {
            guard self.frameState().0 == m, let dev = self.device else { return }
            self.session.beginConfiguration()
            self.addControls(dev, m)
            self.session.commitConfiguration()
        }
        onStackChange?()
    }

    // MARK: session

    /// The app opens the camera the moment it makes this model, while its first screen is still
    /// being built, if it already may (otherwise `start` asks). `start` does the rest.
    func openEarly() {
        #if DEBUG && targetEnvironment(simulator) && !CAPTURE_EXTENSION
        if Self.demo.active { return }
        #endif
        guard !openedEarly, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        openedEarly = true
        let multi = wantsUltraWide
        lock.lock(); _launchMulti = multi; lock.unlock()
        warmViewfinder()
        sessionQueue.async { self.configure() }
    }
    private var openedEarly = false

    /// The camera is open (in a debug simulator build the demo feed stands in for it).
    private var cameraReady: Bool {
        #if DEBUG && targetEnvironment(simulator) && !CAPTURE_EXTENSION
        if Self.demo.active { return true }
        #endif
        return input != nil
    }

    func start() {
        updateMotion()
        loadFavorites()
        #if DEBUG && targetEnvironment(simulator) && !CAPTURE_EXTENSION
        if Self.demo.active { startDemo(); return }
        #endif
        if !openedEarly {
            let multi = wantsUltraWide
            lock.lock(); _launchMulti = multi; lock.unlock()
            warmViewfinder()
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        #if CAPTURE_EXTENSION
        // The Lock Screen camera has the app's camera permission and cannot ask for it: unless
        // it was refused outright, start the camera.
        if status != .denied && status != .restricted {
            authorized = true
            sessionQueue.async { self.configure() }
            if mode == .film { beginFinderIntro() }
            return
        }
        #endif
        switch status {
        case .authorized:
            authorized = true
            if !openedEarly { sessionQueue.async { self.configure() } }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { self.authorized = ok }
                if ok { self.sessionQueue.async { self.configure() } }
            }
        default: authorized = false
        }
        updateUltraWide()
        if mode == .film { beginFinderIntro() }
    }

    func stop() {
        // a take is finished and saved before the camera goes, never left open
        if recording { stopRecording() }
        cancelBooth()
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }
    func resume() {
        sessionQueue.async {
            // a camera that couldn't be opened before (another app had it) is tried again
            if self.input == nil {
                let s = AVCaptureDevice.authorizationStatus(for: .video)
                if s == .authorized { self.configureTries = 0; self.configure() }
                return
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private static func backCamera() -> AVCaptureDevice? {
        let kinds: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        for k in kinds { if let d = AVCaptureDevice.default(k, for: .video, position: .back) { return d } }
        return nil
    }

    private func configure() {
        // FILM with the ultra-wide behind its finder opens straight into the two-camera session
        // (it used to start the plain one, stop it and build this one: two camera starts). Read
        // once, by the first configure only.
        lock.lock(); let multi = _launchMulti; _launchMulti = false; lock.unlock()
        guard input == nil else { return }
        if multi && !multiCamFailed && !multiCam {
            if configureMulti() { multiCam = true; return }
            // Not marked as failed: the camera may only have been busy a moment. The plain
            // session opens, and updateUltraWide tries the two cameras again as it always did.
            input = nil; device = nil; uwInput = nil
            session = AVCaptureSession()
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let dev = Self.backCamera(), let inp = try? AVCaptureDeviceInput(device: dev), session.canAddInput(inp) else {
            session.commitConfiguration()
            // The camera can still be held a moment (the Lock Screen handing over, another app
            // closing): try again shortly instead of leaving a black finder.
            configureTries += 1
            if configureTries < 8 { sessionQueue.asyncAfter(deadline: .now() + 0.3) { self.configure() } }
            return
        }
        configureTries = 0
        session.addInput(inp)
        device = dev; input = inp
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .quality
        if photoOutput.isAppleProRAWSupported { photoOutput.isAppleProRAWEnabled = settings.digiZero }
        let raw = photoOutput.isAppleProRAWSupported
        applyCapturePolicy(flash: settings.flash != .off)
        let m = frameState().0
        setupPhotoOutput(dev, m)
        addControls(dev, m)
        session.commitConfiguration()
        setupLenses(dev)
        applyRotation()
        // Everything the mode needs goes on before the camera starts: added to a running session,
        // the QR reader, the microphone or BOOTH's selfie camera each rebuilt the camera's whole
        // pipeline a moment after it opened, holding up the first frames.
        updateQR(m)
        if m == .video { addAudioIfNeeded() }
        if m == .booth { switchCamera(toFront: true) }
        session.startRunning()
        applyProOnQueue(m)
        DispatchQueue.main.async {
            // remembered: a launch straight into FILM's two cameras never asks the plain session
            if self.rawSupported != raw { self.rawSupported = raw; UserDefaults.standard.set(raw, forKey: "rawSupported") }
            self.preparePhotos()
        }
    }

    private func setupPhotoOutput(_ dev: AVCaptureDevice, _ m: CaptureMode) {
        func px(_ d: CMVideoDimensions) -> Int { Int(d.width) * Int(d.height) }
        func mp(_ d: CMVideoDimensions) -> Int { CaptureMode.megapixels(CGSize(width: CGFloat(d.width), height: CGFloat(d.height))) }
        // 5712×4284 is only ever delivered as 24MP through deferred delivery, which XA doesn't use:
        // asked for, it comes back 12MP.
        var dims = dev.activeFormat.supportedMaxPhotoDimensions.filter { !($0.width == 5712 && $0.height == 4284) }
        #if CAPTURE_EXTENSION
        // The Lock Screen camera has a small memory budget: 12MP at most.
        dims = dims.filter { px($0) <= CaptureMode.digi.maxSensorPixels }
        #endif
        if dims.isEmpty { dims = dev.activeFormat.supportedMaxPhotoDimensions }
        guard let largest = dims.max(by: { px($0) < px($1) }) else { return }
        let options = Array(Set(dims.map(mp))).sorted()
        if px(photoOutput.maxPhotoDimensions) != px(largest) { photoOutput.maxPhotoDimensions = largest }
        let digi = dims.filter { px($0) <= CaptureMode.digi.maxSensorPixels }.max(by: { px($0) < px($1) }) ?? largest
        var pro = largest
        let want = settings.proMegapixels
        if want > 0, let chosen = dims.filter({ mp($0) <= want }).max(by: { px($0) < px($1) }) { pro = chosen }
        lock.lock(); digiDims = digi; proDims = pro; filmDims = largest; lock.unlock()
        // the mode as it is by now (it can change while the camera is still opening)
        DispatchQueue.main.async { self.proOptions = options; self.publishPhotoSize(self.mode) }
    }

    /// On the main thread (it reads the settings).
    private func shotDims(_ m: CaptureMode) -> CMVideoDimensions {
        let big = m == .film && filmTakesFullSensor
        lock.lock(); defer { lock.unlock() }
        return m == .pro ? proDims : (big ? filmDims : digiDims)
    }

    /// FILM's drum and full scans take the biggest photo the sensor makes, for real detail under
    /// the grain (a 48 MP sensor's whole picture). A lab scan, ZERO's RAW and the Lock Screen
    /// camera's small memory keep to 12 MP.
    private var filmTakesFullSensor: Bool {
        #if CAPTURE_EXTENSION
        return false
        #else
        return settings.filmRecipe.scan != .lab && !settings.digiZero
        #endif
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
        // the next shot's buffers, at the size and quality it will now be taken at
        preparePhotos()
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
        lock.lock(); let ctlSim = _ctlSim, ctlLook = _ctlLook; lock.unlock()
        if m.usesFilm {
            let sims = FilmCatalog.sims(for: m)
            let simTitles = sims.map { Self.controlTitle($0.title) }
            let simPicker = AVCaptureIndexPicker("Sim", symbolName: "film", localizedIndexTitles: simTitles)
            let loaded = FilmCatalog.sim(ctlSim)?.id
            simPicker.selectedIndex = sims.firstIndex { $0.id == loaded } ?? 0
            simPicker.setActionQueue(.main) { [weak self] i in
                guard let self else { return }
                self.stack.simID = sims[min(sims.count - 1, max(0, i))].id
            }
            let lookPicker = AVCaptureIndexPicker("Look", symbolName: "camera.filters", localizedIndexTitles: Look.allCases.map { Self.controlTitle($0.title) })
            lookPicker.selectedIndex = ctlLook.rawValue
            lookPicker.setActionQueue(.main) { [weak self] i in
                self?.stack.look = Look(rawValue: i) ?? .none
            }
            let first: AVCaptureControl = settings.digiSlide == .sim || m == .film ? simPicker : lookPicker
            let second: AVCaptureControl = settings.digiSlide == .sim || m == .film ? lookPicker : simPicker
            for c in [first, second] where session.canAddControl(c) && (m == .digi || c === simPicker) { session.addControl(c) }
        } else if m == .booth {
            if session.canAddControl(zoom) { session.addControl(zoom) }
        } else if m == .video {
            lock.lock(); let vlook = frameVideoLook; lock.unlock()
            let shelf = VideoLook.shelf
            let looks = AVCaptureIndexPicker("Look", symbolName: "film", localizedIndexTitles: shelf.map { Self.controlTitle($0.title) })
            looks.selectedIndex = shelf.firstIndex(of: vlook) ?? 0
            looks.setActionQueue(.main) { [weak self] i in self?.videoLook = shelf[min(shelf.count - 1, max(0, i))] }
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

    /// A box title as Camera Control shows it: words in title case, speeds and initials kept
    /// ("NOCTURNE 800T" → "Nocturne 800T", "VHS" stays "VHS").
    static func controlTitle(_ t: String) -> String {
        let initials: Set<String> = ["VHS", "CCTV", "LCD", "XA"]
        return t.split(separator: " ").map { w -> String in
            let s = String(w)
            if initials.contains(s) || s.contains(where: { $0.isNumber }) { return s }
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }.joined(separator: " ")
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
    /// How dark the scene is for POCKET 3D's little sensor, from the brightness the camera
    /// measured for this frame (APEX Bv, in the frame's Exif). Not there: bright.
    static func sceneDarkness(_ sb: CMSampleBuffer) -> Double {
        guard let all = CMCopyDictionaryOfAttachments(allocator: nil, target: sb, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [String: Any],
              let exif = all[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let bv = (exif[kCGImagePropertyExifBrightnessValue as String] as? NSNumber)?.doubleValue, bv.isFinite
        else { return 0 }
        return Pocket3DLook.darkness(brightness: bv)
    }

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
        guard !recording else { return }   // never mid-take: the take would change camera halfway
        sessionQueue.async {
            // the selfie camera has no ultra-wide: back to the plain session first
            if self.multiCam { self.rebuildSession(multi: false) }
            self.switchCamera(toFront: !self.frontFlag)
            // and back on the rear camera in FILM, the ultra-wide returns
            DispatchQueue.main.async { self.updateUltraWide() }
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
            var switched = false
            if self.session.canAddInput(inp) { self.session.addInput(inp); self.input = inp; self.device = dev; switched = true } else { self.session.addInput(old) }
            let m = self.frameState().0
            if let d = self.device { self.setupPhotoOutput(d, m); self.addControls(d, m) }
            self.session.commitConfiguration()
            // only a camera that really changed changes the flags
            guard switched else { return }
            self.lock.lock(); self.frontFlag = toFront; self.lock.unlock()
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
        snapshotDials()
        sessionQueue.async { self.applyProOnQueue(m) }
    }

    private func applyProOnQueue(_ m: CaptureMode) {
        guard let dev = device, (try? dev.lockForConfiguration()) != nil else { return }
        defer { dev.unlockForConfiguration() }
        let pro = m == .pro
        lock.lock(); let (sIdx, iIdx, wb, fIdx, bias) = _dials; lock.unlock()
        // Exposure. The metered values and the format's limits are checked and rounded inward:
        // setExposureModeCustom throws for anything a hair outside its range.
        let es = dev.exposureDuration.seconds, ei = dev.iso
        if pro && (sIdx != nil || iIdx != nil) && dev.isExposureModeSupported(.custom) && es.isFinite && es > 0 && ei.isFinite && ei > 0 {
            // In custom mode the device reports XA's own last values: fold in how far off the
            // meter says they are, so S and ISO priority keep metering the scene.
            let off = Double(dev.exposureTargetOffset)
            let metered = es * pow(2, (off.isFinite ? -off : 0))
            let fmt = dev.activeFormat
            let lo = Int64((fmt.minExposureDuration.seconds * 1e9).rounded(.up))
            let hi = Int64((min(fmt.maxExposureDuration.seconds, 1) * 1e9).rounded(.down))
            let iLo = Int(fmt.minISO.rounded(.up)), iHi = max(Int(fmt.minISO.rounded(.up)), Int(fmt.maxISO.rounded(.down)))
            let r = Exposure.rebalance(meteredShutter: max(Int64(min(metered, 30) * 1e9), 1), meteredIso: max(Int(ei), 1),
                                       heldShutter: sIdx.map { Exposure.shutterAt($0) }, heldIso: iIdx.map { Exposure.isoAt($0) },
                                       shutterRange: max(lo, 1)...max(hi, max(lo, 1)), isoRange: iLo...iHi)
            let maxD = CMTimeMinimum(fmt.maxExposureDuration, CMTime(value: 1, timescale: 1))
            let duration = CMTimeMaximum(fmt.minExposureDuration, CMTimeMinimum(CMTime(value: r.shutter, timescale: 1_000_000_000), maxD))
            dev.setExposureModeCustom(duration: duration, iso: min(max(Float(r.iso), fmt.minISO), fmt.maxISO), completionHandler: nil)
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
    func showThumb(_ img: UIImage?) { lastShot = img }

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
        if mode == .video {
            guard authorized == true, cameraReady else { return }
            toggleRecording(); return
        }
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
    private func trackEye(_ frame: CIImage) {
        lock.lock(); let busy = eyeAFBusy; if !busy { eyeAFBusy = true }; lock.unlock()
        guard !busy else { return }
        // small: a face to focus on is never tiny in the frame
        let k: CGFloat = min(1, 480 / max(frame.extent.width, 1))
        let small = frame.transformed(by: CGAffineTransform(scaleX: k, y: k))
        eyeQueue.async {
            let found = EyeFinder.nearerEye(in: small)
            self.lock.lock(); self.eyeAFBusy = false; self.lock.unlock()
            guard let eye = found else { return }
            self.aimAtEye(eye)
        }
    }

    private func aimAtEye(_ eye: CGPoint) {
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
        let all = VideoLook.shelf, n = all.count
        let i = all.firstIndex(of: videoLook) ?? 0
        videoLook = all[((i + by) % n + n) % n]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private var favoritesKey: String { mode == .film ? "favorites.film" : "favorites.digi" }
    func loadFavorites() {
        let valid = Set(FilmCatalog.sims(for: mode).map { $0.id })
        favorites = (UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []).filter { valid.contains($0) }
    }
    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }
    /// Star or unstar a film (long-press its box).
    func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.append(id) }
        UserDefaults.standard.set(favorites, forKey: favoritesKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Swiping the corner box: through the favorites when there are any, else every film.
    func stepSim(_ by: Int) {
        let all: [String] = FilmCatalog.sims(for: mode).map { $0.id }
        let ids = favorites.count >= 2 ? favorites : all
        let loaded = FilmCatalog.sim(stack.simID)?.id
        let i = ids.firstIndex(where: { $0 == loaded }) ?? 0
        let n = ids.count
        guard n > 0 else { return }
        // a new film starts at box speed (one change, so the finder redraws once)
        var next = stack
        next.push = 0
        next.simID = ids[((i + by) % n + n) % n]
        stack = next
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
            if self.session.canAddInput(inp) {
                self.session.addInput(inp); self.audioInput = inp
                self.lock.lock(); self._hasMic = true; self.lock.unlock()
            }
            if self.session.canAddOutput(self.audioOutput) {
                self.session.addOutput(self.audioOutput)
                self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
            }
            self.session.commitConfiguration()
        }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: add()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                // still in VIDEO by the time the answer comes?
                if ok { self.sessionQueue.async { if self.frameState().0 == .video { add() } } }
            }
        default: break
        }
    }

    /// The microphone leaves the session when VIDEO does. On the session queue.
    private func removeAudio() {
        guard let inp = audioInput else { return }
        lock.lock(); _hasMic = false; lock.unlock()
        session.beginConfiguration()
        session.removeInput(inp)
        if session.outputs.contains(audioOutput) { session.removeOutput(audioOutput) }
        session.commitConfiguration()
        audioInput = nil
        // back to sounds that mix with the user's music and respect the silent switch
        CameraSounds.shared.ambient()
    }

    func toggleRecording() { recording ? stopRecording() : startRecording() }

    private func startRecording() {
        guard !recording else { return }
        frameQueue.async { self.fx.reset() }   // the frame queue owns the looks' state
        audioQueue.async { self.pocketAudio.reset() }
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
        // The take is finished and saved even if the app goes to the background right now.
        #if !CAPTURE_EXTENSION
        var bg = UIBackgroundTaskIdentifier.invalid
        bg = UIApplication.shared.beginBackgroundTask(withName: "xa.take") {
            if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
        }
        #endif
        let end = {
            #if !CAPTURE_EXTENSION
            if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
            #endif
        }
        r.finish { url in
            DispatchQueue.main.async {
                self.developing = max(0, self.developing - 1)
                guard let url else { end(); return }
                let keep = {
                    // Photos wouldn't take it now: it waits in the app and goes in later
                    if let dir = self.fallbackFolder {
                        try? FileManager.default.moveItem(at: url, to: dir.appendingPathComponent(url.lastPathComponent))
                    }
                }
                if let lib = self.library {
                    lib.save(video: url) { id in
                        if let id { TakeSegment.store(segs, for: id) } else { keep() }
                        end()
                    }
                } else {
                    keep(); end()
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
        // PRO's held shutter or ISO is only honoured at .speed (the camera may override it otherwise).
        let manual = m == .pro && (shutterIndex != nil || isoIndex != nil)
        // FILM at the whole sensor is asked for the way PRO asks for it (quality), the combination
        // the biggest photos are known to come back from.
        let fullSensor = m == .film && filmTakesFullSensor && !zero
        let want: AVCapturePhotoOutput.QualityPrioritization = manual ? .speed
            : (fullSensor ? .quality : (settings.flash != .off && m != .pro ? .balanced : m.prioritization))
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
        guard authorized == true, cameraReady else { return }
        // not before the viewfinder shows what the picture will be (see holdViewfinder)
        lock.lock(); let held = _holdFrames; lock.unlock()
        guard !held else { return }
        if mode == .video { toggleRecording(); return }
        if mode == .booth { boothPress(); return }
        // Shots still developing hold their whole file in memory: past a handful, wait.
        guard developing < 6 else { UINotificationFeedbackGenerator().notificationOccurred(.warning); return }
        fire(booth: nil)
    }

    private func fire(booth: (session: Int, index: Int)?) {
        guard authorized == true, cameraReady else { return }
        let pressed = CACurrentMediaTime()
        skipReview()
        let m = mode
        let (settingsP, zero) = photoSettings(m)
        syncFrameSettings()
        var (_, dev) = frameState()
        if let booth { dev.deco = settings.boothDeco.step(booth.index) }
        let id = settingsP.uniqueID
        var shot = Shot(mode: m, develop: dev, crunch: settings.crunch, date: Date(), zero: zero, pressed: pressed, booth: booth, front: front)
        #if CAPTURE_EXTENSION
        shotCount += 1
        shot.name = String(format: "XA-%ld-%04d", run, shotCount)
        lock.lock(); _lockShots[id] = (shot.name, shot.lock); lock.unlock()
        #endif
        pending[id] = shot
        // Manual exposure (PRO's held shutter or ISO) has no zero shutter lag: the picture is
        // taken when the camera says so, and the click waits for it.
        let manual = m == .pro && (shutterIndex != nil || isoIndex != nil)
        let instant = settings.flash == .off && !zero && !manual && photoOutput.isZeroShutterLagEnabled
        if instant {
            answered.insert(id)
            // XA's click only where the system's own is dropped, never both
            if settings.sounds && settingsP.isShutterSoundSuppressionEnabled { CameraSounds.shared.play(.shutter) }
            if m.usesFilm && settings.instantReview { startReview() }
            flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (m == .booth ? 0.22 : 0.08)) { self.flash = false }
        } else if settings.sounds && settingsP.isShutterSoundSuppressionEnabled {
            quietShots.insert(id)
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        developing += 1
        #if DEBUG && targetEnvironment(simulator) && !CAPTURE_EXTENSION
        if Self.demo.active { demoFire(id, settingsP); return }
        #endif
        // Off the main thread: whatever the screen is busy drawing can't hold the shot up. The
        // settings were made on the main thread a moment ago; what the camera can do is checked
        // here, against the session as it is now (a flip or a rebuild may have come between).
        sessionQueue.async {
            guard self.session.isRunning, let c = self.photoOutput.connection(with: .video), c.isEnabled, c.isActive else {
                DispatchQueue.main.async { self.abandon(id) }; return
            }
            let maxD = self.photoOutput.maxPhotoDimensions
            if Int(settingsP.maxPhotoDimensions.width) * Int(settingsP.maxPhotoDimensions.height) > Int(maxD.width) * Int(maxD.height) {
                settingsP.maxPhotoDimensions = maxD
            }
            if settingsP.rawPhotoPixelFormatType != 0, !self.photoOutput.availableRawPhotoPixelFormatTypes.contains(settingsP.rawPhotoPixelFormatType) {
                DispatchQueue.main.async { self.abandon(id) }; return
            }
            if !self.photoOutput.supportedFlashModes.contains(settingsP.flashMode) { settingsP.flashMode = .off }
            self.lock.lock(); let selfie = self.frontFlag; self.lock.unlock()
            if selfie {
                // The selfie camera is shot exactly as the viewfinder shows it: upright and
                // mirrored, the same turn and the same mirror as the frames. Its horizon
                // angle came out upside down once mirrored.
                if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = false }
                if c.isVideoRotationAngleSupported(0) { c.videoRotationAngle = 0 }
            } else {
                if let rc = self.rotation {
                    let a = rc.videoRotationAngleForHorizonLevelCapture
                    if c.isVideoRotationAngleSupported(a) { c.videoRotationAngle = a }
                }
                if c.isVideoMirroringSupported && !c.automaticallyAdjustsVideoMirroring { c.automaticallyAdjustsVideoMirroring = true }
            }
            self.photoOutput.capturePhoto(with: settingsP, delegate: self)
        }
    }

    /// A shot the camera couldn't take (or that ended without a picture): forget it, so the
    /// roll button's spinner never sticks. On the main thread.
    private func abandon(_ id: Int64) {
        guard let shot = pending.removeValue(forKey: id) else { return }
        answered.remove(id); quietShots.remove(id)
        developing = max(0, developing - 1)
        if let b = shot.booth { boothCollect(b.session, b.index, nil, date: shot.date) }
    }

    /// How long the last shot took: press → taken → photo → developed. Kept for debugging, not
    /// published (a change re-draws everything watching the camera).
    private(set) var lastTiming = ""
    private var timing: (taken: Double, photo: Double) = (0, 0)
    /// Shots that already clicked and blinked at the press.
    private var answered: Set<Int64> = []

    /// Zero shutter lag hands back a frame from the moment you pressed, which with the flash on
    /// is the frame from before it fired. So with the flash on (or auto) the fast paths go off
    /// and the camera waits for its own flash; with it off, the shot is instant again.
    private func applyCapturePolicy(flash: Bool) {
        // Responsive capture needs zero shutter lag on, and fast capture needs responsive capture:
        // on in that order, off in the reverse (the other way round they stayed off for good).
        if !flash {
            if photoOutput.isZeroShutterLagSupported { photoOutput.isZeroShutterLagEnabled = true }
            if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = true }
            if photoOutput.isFastCapturePrioritizationSupported { photoOutput.isFastCapturePrioritizationEnabled = true }
        } else {
            if photoOutput.isFastCapturePrioritizationSupported { photoOutput.isFastCapturePrioritizationEnabled = false }
            if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = false }
            if photoOutput.isZeroShutterLagSupported { photoOutput.isZeroShutterLagEnabled = false }
        }
    }

    /// ZERO switched: Apple ProRAW is turned on in the output only while it is wanted.
    func zeroChanged() {
        updateUltraWide()   // never the ultra-wide with RAW
        let on = settings.digiZero
        sessionQueue.async {
            guard self.photoOutput.isAppleProRAWSupported, self.photoOutput.isAppleProRAWEnabled != on else { return }
            self.session.beginConfiguration()
            self.photoOutput.isAppleProRAWEnabled = on
            self.session.commitConfiguration()
        }
        preparePhotos()
    }

    /// The RAW format ZERO shoots: Apple ProRAW only. (A sensor's Bayer RAW needs zoom 1× and the
    /// fastest capture, and threw otherwise; without ProRAW the setting is hidden.)
    private var zeroFormat: OSType? {
        photoOutput.availableRawPhotoPixelFormatTypes.first(where: { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) })
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

    private struct Shot {
        let mode: CaptureMode; let develop: DevelopSettings; let crunch: Double; let date: Date
        var zero = false; var pressed: Double = 0; var booth: (session: Int, index: Int)? = nil; var front = false
        /// The Lock Screen camera's file name for this shot (its camera file, recipe and result).
        var name = ""

        var lock: LockShot {
            LockShot(mode: mode, stack: develop.stack, megapixels: develop.megapixels, noise: develop.noise, date: develop.date,
                     recipe: develop.recipe, film: develop.film, filmRecipe: develop.filmRecipe, crunch: crunch, taken: date, front: front)
        }

        init(mode: CaptureMode, develop: DevelopSettings, crunch: Double, date: Date, zero: Bool = false, pressed: Double = 0,
             booth: (session: Int, index: Int)? = nil, front: Bool = false) {
            self.mode = mode; self.develop = develop; self.crunch = crunch; self.date = date
            self.zero = zero; self.pressed = pressed; self.booth = booth; self.front = front
        }

        init(_ l: LockShot) {
            var d = DevelopSettings()
            d.stack = l.stack; d.megapixels = l.megapixels; d.noise = l.noise; d.date = l.date
            d.recipe = l.recipe; d.film = l.film; d.filmRecipe = l.filmRecipe
            self.init(mode: l.mode, develop: d, crunch: l.crunch, date: l.taken, front: l.front)
        }
    }
    private var pending: [Int64: Shot] = [:]
    /// Shots whose system click was dropped, so XA plays its own when the picture is really taken.
    private var quietShots: Set<Int64> = []

    /// What a shot's develop hands back: the file, its type, a small picture for the roll
    /// button, and BOOTH's copy for its sheet.
    fileprivate struct Developed { let out: Data; let type: UTType; let thumb: CGImage?; let booth: UIImage? }

    /// The camera's file, developed into the picture that is saved. Any queue.
    private func produce(_ data: Data, _ shot: Shot) -> Developed? {
        // DIGI and FILM expand the photo's HDR gain map, so a lamp is brighter than white paper and
        // only real light sources bloom and halate. PRO keeps the file untouched anyway.
        #if CAPTURE_EXTENSION
        let opts: [CIImageOption: Any] = [.applyOrientationProperty: true]
        #else
        let opts: [CIImageOption: Any] = shot.mode == .pro ? [.applyOrientationProperty: true] : [.applyOrientationProperty: true, .expandToHDR: true]
        #endif
        guard var src = CIImage(data: data, options: opts) ?? CIImage(data: data, options: [.applyOrientationProperty: true]) else { return nil }
        #if CAPTURE_EXTENSION
        // The Lock Screen camera develops at a lab scan's size, well inside its memory.
        if shot.mode != .pro { src = Darkroom.scaled(src, longEdge: shot.develop.film ? 3088 : 2600) }
        #endif
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
        // The selfie camera: upright and mirrored, as the viewfinder showed it (PRO too: its
        // picture is shot at the sensor's angle, so it needs the same turn).
        if shot.front { src = Self.upright(src, mirror: true) }
        // What the camera wrote, for PRO: HEIF or JPEG as it came out.
        var fileType: UTType = .jpeg
        if let s = CGImageSourceCreateWithData(data as CFData, nil), let t = CGImageSourceGetType(s), let u = UTType(t as String) { fileType = u }
        if shot.mode == .pro && !shot.front {
            // Saved exactly as the camera made it.
            return Developed(out: data, type: fileType, thumb: Self.quickThumb(data), booth: nil)
        }
        if shot.mode == .pro {
            // The selfie camera in PRO: turned upright and mirrored, nothing else.
            guard let cg = Encoder.render(src, reference: nil) else { return nil }
            var props = fileProps
            props[kCGImagePropertyOrientation as String] = 1
            if var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                tiff[kCGImagePropertyTIFFOrientation as String] = 1
                props[kCGImagePropertyTIFFDictionary as String] = tiff
            }
            var type = fileType
            var out = Encoder.encode(cg, type: type, quality: 0.95, properties: props)
            if out == nil { type = .jpeg; out = Encoder.encode(cg, type: .jpeg, quality: 0.95, properties: props) }
            guard let out else { return nil }
            return Developed(out: out, type: type, thumb: Self.downsizedCG(cg, longEdge: 200), booth: nil)
        }
        let (developed, alpha) = Darkroom.develop(src, shot.develop, date: shot.date, preview: false, demo: demo)
        let recipe = shot.develop.booth.map { "XA BOOTH · \($0.title)" } ?? Recipe.describe(shot.develop.stack, megapixels: shot.develop.megapixels, film: shot.develop.film)
        // The thumbnail first: it is the reference the full render is checked against, cell by
        // cell, so a render that came back with black tiles is redone on the CPU. It is also the
        // roll button's picture.
        let e0 = developed.extent
        var reference: CGImage?
        if shot.develop.film && e0.width * e0.height > 16_000_000, let meter = Darkroom.reduced(src, longEdge: 1024) {
            // A drum scan can't be shrunk to a thumbnail in one go (it would be read whole): the
            // same recipe on the meter's small copy, at its own size, stands in.
            var d = shot.develop
            d.filmRecipe.scan = .full
            let sm = Darkroom.develop(meter, d, date: shot.date, preview: false, demo: demo).0
            let k = 200 / max(sm.extent.width, 1)
            let s = sm.transformed(by: CGAffineTransform(scaleX: k, y: k))
            reference = Encoder.gpu.createCGImage(s, from: s.extent.integral)
        } else {
            let k0: CGFloat = 200 / max(e0.width, 1)
            let small = developed.transformed(by: CGAffineTransform(scaleX: k0, y: k0))
            reference = Encoder.gpu.createCGImage(small, from: small.extent.integral)
        }
        guard let cg = Encoder.render(developed, reference: reference) else { return nil }
        let props = Recipe.properties(from: fileProps, recipe: recipe)
        // FILM keeps everything: HEIC at a high quality. DIGI saves the crunch you chose.
        let full = shot.develop.film || shot.develop.booth != nil
        var type: UTType = full ? .heic : (alpha ? .png : .jpeg)
        var out = Encoder.encode(cg, type: type, quality: full ? 0.95 : CGFloat(shot.crunch), properties: props)
        if out == nil && type == .heic {
            type = .jpeg
            out = Encoder.encode(cg, type: .jpeg, quality: 0.95, properties: props)
        }
        guard let out else { return nil }
        let booth = shot.booth != nil ? Self.downsized(cg, longEdge: 1400) : nil
        return Developed(out: out, type: type, thumb: reference, booth: booth)
    }

    private func develop(_ data: Data, _ shot: Shot) {
        developQueue.async {
            defer { DispatchQueue.main.async { self.developing = max(0, self.developing - 1) } }
            let made = self.produce(data, shot)
            if let b = shot.booth {
                let small = made?.booth
                DispatchQueue.main.async { self.boothCollect(b.session, b.index, small, date: shot.date) }
            }
            guard let made else { return }
            #if CAPTURE_EXTENSION
            self.lockSave(made, name: shot.name)
            #endif
            let done = CACurrentMediaTime() - shot.pressed
            DispatchQueue.main.async {
                func ms(_ t: Double) -> String { t < 1 ? "\(Int(t * 1000)) ms" : String(format: "%.1f s", t) }
                self.lastTiming = "taken \(ms(self.timing.taken)) · photo \(ms(self.timing.photo)) · saved \(ms(done))"
                if let thumb = made.thumb { self.lastShot = UIImage(cgImage: thumb) }
                #if !CAPTURE_EXTENSION
                self.save(made.out, made.type)
                #endif
            }
        }
    }

    /// The app develops a shot the Lock Screen camera didn't get to (its recipe and camera file
    /// were left in the session folder). Any queue; nil if it can't be developed.
    func developLeftover(_ data: Data, recipe: LockShot) -> (Data, UTType)? {
        guard let made = produce(data, Shot(recipe)) else { return nil }
        return (made.out, made.type)
    }

    /// Into Photos, or into the pending folder for later when Photos won't take it now.
    private func save(_ out: Data, _ type: UTType) {
        if let lib = library {
            lib.save(data: out, type: type) { ok in if !ok { self.writeFallback(out, type) } }
        } else {
            writeFallback(out, type)
        }
    }

    @discardableResult
    private func writeFallback(_ data: Data, _ type: UTType, name: String? = nil) -> URL? {
        guard let dir = fallbackFolder else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = type.preferredFilenameExtension ?? "jpg"
        let stem = name ?? "XA-\(Int(Date().timeIntervalSince1970 * 1000))-\(Int.random(in: 0..<10000))"
        let url = dir.appendingPathComponent("\(stem).\(ext)")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    /// A small picture straight from the camera's file (the full one isn't decoded for it).
    static func quickThumb(_ data: Data, side: Int = 200) -> CGImage? {
        guard let s = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                  kCGImageSourceThumbnailMaxPixelSize: side,
                                  kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(s, 0, o as CFDictionary)
    }

    static func downsizedCG(_ cg: CGImage, longEdge: CGFloat) -> CGImage? { downsized(cg, longEdge: longEdge)?.cgImage }

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

    /// The meter, for the PRO panel, DIGI's screen and FILM's needle: published only when it
    /// moves (every publish redraws every view that watches the camera).
    private func publishMeter() {
        sessionQueue.async {
            guard let dev = self.device else { return }
            let d = dev.exposureDuration.seconds, iso = dev.iso
            guard d.isFinite, d > 0, iso.isFinite, iso > 0 else { return }
            DispatchQueue.main.async {
                if abs(log2(d / max(self.meterShutter, 1e-6))) > 0.1 { self.meterShutter = d }
                if abs(self.meterISO - iso) > 1 { self.meterISO = iso }
            }
        }
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
        DispatchQueue.main.async { self.meters.histogram = norm }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            lock.lock(); let r = _recorder; let look = frameVideoLook; lock.unlock()
            guard let r else { return }
            // the tape playing now decides the sound too: POCKET 3D records the way a 3DS hears
            if look == .pocket3D, let heard = pocketAudio.process(sampleBuffer) { r.append(audio: heard) }
            else { r.append(audio: sampleBuffer) }
            return
        }
        if output === uwOutput {
            // Every other ultra-wide frame, small and copied out so the camera gets its buffer back.
            uwCount += 1
            guard uwCount % 3 == 0, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let raw = CIImage(cvPixelBuffer: pb)
            let k: CGFloat = 480 / max(raw.extent.width, raw.extent.height, 1)
            let small = raw.transformed(by: CGAffineTransform(scaleX: k, y: k))
            if let cg = Looks.context.createCGImage(small, from: small.extent.integral) {
                let img = CIImage(cgImage: cg)
                lock.lock(); _uw = img; lock.unlock()
            }
            return
        }
        viewfinderFrame(sampleBuffer)
    }

    /// One frame of the viewfinder (and of a VIDEO take). On the frame queue.
    private func viewfinderFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock(); let hold = _holdFrames; lock.unlock()
        if hold { return }
        // Power: the developed modes run at a lighter size, at the camera's 30 frames a second
        // (FILM's finder is one baked colour cube per frame, see FilmPreview); on Low Power Mode
        // or a hot phone, 20 and lighter still.
        let mNow = frameState().0
        if frameCount % 60 == 0 {
            let p = ProcessInfo.processInfo
            lowPower = p.isLowPowerModeEnabled || p.thermalState == .serious || p.thermalState == .critical
            #if CAPTURE_EXTENSION
            lowPower = true   // the Lock Screen camera runs in a small memory budget
            #endif
        }
        if mNow.developed && mNow != .video {
            let now = CACurrentMediaTime()
            let gap = lowPower ? 1.0 / 20.5 : 1.0 / 31
            if now - lastFrameAt < gap { frameCount += 1; return }
            lastFrameAt = now
        }
        // Cleaned at the door: a sensor pixel below the legal video range decodes to NaN, and every
        // blur and resize downstream would spread it into a black square.
        lock.lock(); let mirror = frontFlag; lock.unlock()
        let raw = Self.upright(Sanitize.apply(CIImage(cvPixelBuffer: pb), floor: 0), mirror: mirror)
        let e = raw.extent
        let width: CGFloat = !mNow.developed || mNow == .video ? 1080 : (lowPower ? 640 : 810)
        let k: CGFloat = min(1, width / max(e.width, 1))
        let src = raw.transformed(by: CGAffineTransform(scaleX: k, y: k))
        let (m, dev) = frameState()
        frameCount += 1
        // Eye AF on the rear camera, off this queue (Vision here stalled the viewfinder).
        if m != .video && !mirror && frameCount % 6 == 3 && settings.afArea == .eye { trackEye(src) }
        if frameCount % 10 == 0 {
            // a small copy for the editors' previews, baked so it doesn't hold the camera's buffer
            let s: CGFloat = 640 / max(src.extent.width, 1)
            let small = src.transformed(by: CGAffineTransform(scaleX: s, y: s))
            if let cg = Looks.context.createCGImage(small, from: small.extent.integral) {
                let img = CIImage(cgImage: cg)
                lock.lock(); _latest = img; lock.unlock()
            }
        }
        lock.lock()
        if _switchPending { _switchPending = false; _switchStart = CACurrentMediaTime() }
        let vlook = frameVideoLook
        lock.unlock()
        if m == .video {
            lock.lock(); let t = _lockedTurn ?? _turn; lock.unlock()
            let upright = Self.rotated(src, clockwise: t)
            var base = upright
            // (POCKET 3D is the console's camera straight: no film on it)
            if vlook != .pocket3D, let sim = FilmCatalog.sim(dev.stack.simID), !sim.isNeutral {
                base = SimEngine.apply(sim, to: base, preview: true, push: dev.stack.push)
            }
            if vlook == .pocket3D { fx.pocket3D.dark += (Self.sceneDarkness(sampleBuffer) - fx.pocket3D.dark) * 0.05 }
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let frame = fx.apply(vlook, to: base, time: pts.seconds, date: Date())
            // A look that holds frames writes only its new ones, on its own clock: POCKET 3D's
            // file is 20 even frames a second, like the 3DS's own.
            let fresh = fx.lastWasNew
            let at = fx.fps(vlook) == nil ? pts : CMTime(seconds: fx.lastStamp, preferredTimescale: max(pts.timescale, 600))
            lock.lock()
            var failed = false
            if _wantRecord && _recorder == nil {
                _recorder = VideoRecorder(size: frame.extent.size, audio: _hasMic)
                if _recorder == nil { _wantRecord = false; failed = true }
            }
            let r = _recorder
            if let r {
                // A new segment whenever the tape changes mid-take.
                let at = r.duration
                if frameSegments.last?.look != vlook { frameSegments.append(TakeSegment(look: vlook, start: at)) }
            }
            lock.unlock()
            if failed { DispatchQueue.main.async { self.stopRecording() } }
            if fresh { r?.append(frame, at: at) }
            let shown = t == 0 ? frame : Self.rotated(frame, clockwise: 360 - t)
            preview?.show(shown, pixelated: vlook.pixelated)
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
            if m == .pro && frameCount % 15 == 0 { publishMeter() }
        } else {
            // Develop the frame the way the photograph will be turned, so the date back and the
            // shape sit where they will on the print, then turn it back for the viewfinder.
            if frameCount % 15 == 0 { publishMeter() }
            // DIGI's screen shows a histogram too (a few times a second is plenty), only when it's on.
            if m == .digi && dev.screenDate && frameCount % 10 == 0 {
                let s: CGFloat = 160 / max(src.extent.width, 1)
                updateHistogram(src.transformed(by: CGAffineTransform(scaleX: s, y: s)))
            }
            let t = turn
            let upright = Self.rotated(src, clockwise: t)
            var dev = dev
            if dev.booth != nil {
                // faces and the person are looked for about ten times a second, off this queue
                let now = CACurrentMediaTime()
                lock.lock()
                dev.eyes = _boothEyes; dev.boothMask = _boothMask
                let go = !eyesBusy && now - lastEyesAt > 0.1
                if go { eyesBusy = true; lastEyesAt = now }
                lock.unlock()
                if go { findEyes(upright) }
            }
            // FILM: plain finder, with a peek at the film after each change (see syncFrameSettings).
            var peek: CGFloat = 1
            if m == .film {
                lock.lock(); let since = CACurrentMediaTime() - _peekStart; let always = _filmAlwaysOn; lock.unlock()
                if !always {
                    peek = since < Self.peekHold ? 1 : CGFloat(max(0, 1 - (since - Self.peekHold) / Self.peekFade))
                    dev.accurate = true
                }
            }
            var developed = peek > 0 ? Darkroom.develop(upright, dev, date: Date(), preview: true, dateShift: 1 - amount).0 : upright
            if peek > 0 && peek < 1 {
                let f = CIFilter.dissolveTransition()
                f.inputImage = upright; f.targetImage = developed; f.time = Float(peek * peek * (3 - 2 * peek))
                developed = (f.outputImage ?? developed).cropped(to: upright.extent)
            }
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
                let now = CACurrentMediaTime()
                if kick > 0.12 && kick > abs(patch.pos) * 0.9 && now - lastKick > 0.35 {
                    // Pushed, not teleported: the image slides off. While the camera keeps moving it
                    // keeps going the same way rather than flipping sides every frame.
                    lastKick = now
                    let settled = abs(patch.pos) < 0.05 && abs(patch.vel) < 0.3
                    let sign: CGFloat = depth != 0 ? (depth > 0 ? 1 : -1)
                        : (settled ? (Bool.random() ? 1 : -1) : (patch.pos + patch.vel * 0.1 >= 0 ? 1 : -1))
                    patch.vel += sign * kick * 12
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
                if abs(sw.width - lastSway.width) > 0.25 || abs(sw.height - lastSway.height) > 0.25 {
                    lastSway = sw
                    DispatchQueue.main.async { self.finderMotion.sway = sw }
                }
                // The bright frame is lit by the scene, through its window: dim in the dark.
                if frameCount % 6 == 0, let y = XAFinder.brightness(shown) {
                    let target = max(0.14, min(1, 0.1 + y * 2.4))
                    finderLight = finderLight * 0.6 + target * 0.4
                    let lit = finderLight
                    if abs(lit - lastLight) > 0.02 {
                        lastLight = lit
                        DispatchQueue.main.async { self.finderMotion.light = lit }
                    }
                }
                lock.lock(); let uw = _uw; let ratio = _uwRatio; var gain = _uwGain; let flong = _finderLong; lock.unlock()
                if let uw, frameCount % 12 == 0, let g = XAFinder.matchGain(main: shown, wide: uw, ratio: ratio) {
                    // The ultra-wide sees colour and exposure its own way: matched to the main camera, slowly.
                    gain = CIVector(x: gain.x * 0.75 + g.x * 0.25, y: gain.y * 0.75 + g.y * 0.25, z: gain.z * 0.75 + g.z * 0.25)
                    lock.lock(); _uwGain = gain; lock.unlock()
                }
                lock.lock(); let introStart = _introStart; lock.unlock()
                let raw = CGFloat((CACurrentMediaTime() - introStart) / 0.75)
                let q = max(0, min(1, raw))
                let intro = 1 - (1 - q) * (1 - q) * (1 - q)
                if intro >= 0.6 && !introPatchDone {
                    // the patch drops in and bounces into line
                    introPatchDone = true
                    patch.pos = 0.9; patch.vel = 0; patch.k = 55; patch.zeta = 0.3
                }
                shown = XAFinder.compose(shown, format: dev.filmRecipe.format, shift: patchShift, long: flong, wide: uw, ratio: ratio, gain: gain, intro: intro)
            }
            img = shown
        }
        // Leaving FILM: the XA finder plays its arrival backwards, the frame growing back out to the
        // whole picture as the surround fades, before the next mode's finder takes over.
        // (The picture itself goes straight to the next mode's shape: changing the canvas
        // mid-switch made the screen flicker. Only the markings step back out, in the view.)
        let outFrame = img
        let pixel = m == .digi && dev.stack.look.pixelWidth != nil
        lock.lock()
        let holding = CACurrentMediaTime() < _reviewUntil
        let drawHeld = holding && !_reviewDrawn
        if drawHeld { _reviewDrawn = true }
        let held = _lastShown
        if !holding { _lastShown = outFrame }
        lock.unlock()
        if holding {
            // The shot stays up on the viewfinder, as it was, until the review is over.
            if drawHeld, let held { preview?.show(held, pixelated: pixel) }
            return
        }
        // Drawn right here on the frame queue: the main thread can be busy without the viewfinder stuttering.
        preview?.show(outFrame, pixelated: pixel)
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
        #if CAPTURE_EXTENSION
        // On the Lock Screen the camera's file is kept right away, before anything else.
        if error == nil, let data { lockKeep(data, id: id) }
        #endif
        DispatchQueue.main.async {
            guard let shot = self.pending.removeValue(forKey: id) else { return }
            self.timing.photo = now - shot.pressed
            self.preparePhotos()
            guard error == nil, let data else { self.developing = max(0, self.developing - 1); return }
            self.develop(data, shot)
        }
    }

    /// The capture is over. A shot that never got its picture is let go here (otherwise it
    /// stayed pending and the roll button's spinner never stopped).
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let id = resolvedSettings.uniqueID
        DispatchQueue.main.async { self.abandon(id) }
    }
}

#if CAPTURE_EXTENSION
/// The Lock Screen camera's saving. Apple's design: the extension adds pictures straight to
/// Photos (it may, even while locked, with the app's permission), and anything it can't finish
/// waits in the session folder, which the system hands to the app when the camera is put away.
/// Per shot, in that folder:
/// - `<name>.camera.<ext>` + `<name>.json`: the camera's file and the recipe, the moment the photo arrives
/// - `<name>.asset`: the picture went into Photos (its id, for the app's roll and album)
/// - `<name>.<ext>`: developed, but Photos wouldn't take it here
/// The app (XAApp.ingest) finishes whatever is left.
extension CameraModel {
    fileprivate func lockKeep(_ data: Data, id: Int64) {
        lock.lock(); let entry = _lockShots.removeValue(forKey: id); lock.unlock()
        guard let entry, let dir = fallbackFolder else { return }
        let ext = Self.fileExtension(of: data)
        ioQueue.async {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: dir.appendingPathComponent("\(entry.name).camera.\(ext)"), options: .atomic)
            if let j = try? JSONEncoder().encode(entry.recipe) {
                try? j.write(to: dir.appendingPathComponent("\(entry.name).json"), options: .atomic)
            }
        }
    }

    fileprivate func lockSave(_ made: Developed, name: String) {
        guard let dir = fallbackFolder, !name.isEmpty else { return }
        let marker = dir.appendingPathComponent("\(name).asset")
        let finish: (Bool) -> Void = { inPhotos in
            self.ioQueue.async {
                let fm = FileManager.default
                if !inPhotos {
                    try? fm.removeItem(at: marker)
                    let ext = made.type.preferredFilenameExtension ?? "jpg"
                    guard (try? made.out.write(to: dir.appendingPathComponent("\(name).\(ext)"), options: .atomic)) != nil else { return }
                }
                // the camera's copy and the recipe are done with
                for u in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
                where u.lastPathComponent.hasPrefix(name + ".camera.") || u.lastPathComponent == name + ".json" {
                    try? fm.removeItem(at: u)
                }
            }
        }
        let rw = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard rw == .authorized || rw == .limited || PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized else {
            finish(false); return
        }
        PHPhotoLibrary.shared().performChanges({
            let req = PHAssetCreationRequest.forAsset()
            let o = PHAssetResourceCreationOptions()
            o.uniformTypeIdentifier = made.type.identifier
            req.addResource(with: .photo, data: made.out, options: o)
            // written before the change commits: a marker whose picture never arrived is just
            // dropped by the app, a picture with no marker would come in twice
            if let id = req.placeholderForCreatedAsset?.localIdentifier {
                try? Data(id.utf8).write(to: marker, options: .atomic)
            }
        }, completionHandler: { ok, _ in finish(ok) })
    }

    static func fileExtension(of data: Data) -> String {
        guard let s = CGImageSourceCreateWithData(data as CFData, nil), let t = CGImageSourceGetType(s) else { return "jpg" }
        return UTType(t as String)?.preferredFilenameExtension ?? "jpg"
    }
}
#endif

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
        // a shot that couldn't be developed ends its sheet (the other three aren't held forever)
        guard let img else { boothFrames[session] = nil; return }
        guard boothFrames[session] != nil else { return }
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
        let full = frame.extent
        eyeQueue.async {
            let found = Booth.scaled(Booth.eyes(in: small), 1 / k)
            // the person, for the backdrop: on the small frame, scaled back to the frame's own size
            var mask: CIImage?
            if let m = Booth.segment(small, quality: .balanced, request: self.segmentation) {
                mask = m.transformed(by: CGAffineTransform(scaleX: 1 / k, y: 1 / k)).cropped(to: full)
            }
            self.lock.lock(); self._boothEyes = found; self._boothMask = mask; self.eyesBusy = false; self.lock.unlock()
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
            motion.deviceMotionUpdateInterval = 1.0 / 24
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
        #if CAPTURE_EXTENSION
        return false   // one camera on the Lock Screen: less memory, nothing to fall back from
        #else
        return mode == .film && settings.filmRecipe.xaFinder && settings.filmRecipe.ultraWide && !settings.digiZero && !front && AVCaptureMultiCamSession.isMultiCamSupported
            && AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
        #endif
    }

    /// Bring the ultra-wide in or out to match the mode and the finder setting.
    func updateUltraWide() {
        let want = wantsUltraWide
        sessionQueue.async {
            guard self.input != nil else { return }
            // a phone that couldn't run both cameras isn't asked again
            if want != self.multiCam && !(want && self.multiCamFailed) { self.rebuildSession(multi: want) }
        }
    }

    /// On the session queue: take everything off the current session and build the other kind.
    private func rebuildSession(multi: Bool) {
        session.stopRunning()
        detach(session)
        input = nil; device = nil; uwInput = nil; audioInput = nil
        lock.lock(); _hasMic = false; lock.unlock()
        lock.lock(); _uw = nil; lock.unlock()
        multiCam = false
        if multi && configureMulti() {
            multiCam = true
        } else {
            if multi { multiCamFailed = true }
            input = nil; device = nil; uwInput = nil
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
        let m = frameState().0
        setupPhotoOutput(wide, m)
        addControls(wide, m)
        ms.commitConfiguration()
        // Too much for this phone at this quality: drop the ultra-wide rather than the photo.
        // (The cameras are only taken on once the session is known to run: set before this,
        // a failed check left `input` set and the plain session that follows never opened.)
        guard ms.hardwareCost <= 1, ms.systemPressureCost <= 1 else { detach(ms); return false }
        device = wide; input = wIn; uwInput = uIn
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

// MARK: warming up

extension CameraModel {
    /// The first frame used to wait while Core Image made its contexts and compiled this mode's
    /// chain (kernels compile the first time they're drawn). A blank frame goes through the same
    /// steps on the frame queue while the camera is still starting, so the real one doesn't.
    /// VIDEO and BOOTH aren't warmed: their tapes keep state, and BOOTH's faces need Vision.
    func warmViewfinder() {
        var (m, dev) = frameState()
        guard m != .video, m != .booth else { return }
        #if CAPTURE_EXTENSION
        let w = 640
        #else
        let w = m.developed ? 810 : 1080
        #endif
        // FILM opens on an accurate peek at the film (see syncFrameSettings)
        if m == .film && !settings.filmAlwaysOn { dev.accurate = true }
        let finder = m == .film && dev.filmRecipe.xaFinder
        let pixel = m == .digi && dev.stack.look.pixelWidth != nil
        frameQueue.async {
            guard let pb = Self.blankFrame(width: w, height: w * 4 / 3) else { return }
            var img = Sanitize.apply(CIImage(cvPixelBuffer: pb), floor: 0)
            if m.developed { img = Darkroom.develop(img, dev, date: Date(), preview: true).0 }
            if finder {
                self.lock.lock(); let flong = self._finderLong; self.lock.unlock()
                img = XAFinder.compose(img, format: dev.filmRecipe.format, long: flong)
            }
            PreviewView.warm(img, pixelated: pixel)
            _ = Looks.context   // the editors' copy of the frame and the histogram draw with this
        }
    }

    /// A mid-grey camera-shaped frame.
    private static func blankFrame(width: Int, height: Int) -> CVPixelBuffer? {
        var out: CVPixelBuffer?
        let attrs: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                                    kCVPixelBufferMetalCompatibilityKey as String: true]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &out) == kCVReturnSuccess,
              let pb = out else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        if let base = CVPixelBufferGetBaseAddress(pb) { memset(base, 0x80, CVPixelBufferGetDataSize(pb)) }
        CVPixelBufferUnlockBaseAddress(pb, [])
        return pb
    }
}

extension CameraModel {
    /// FILM's finder arrives: it starts too big for the screen and steps back to fit.
    func beginFinderIntro() {
        guard settings.filmRecipe.xaFinder else { return }
        lock.lock(); _introStart = CACurrentMediaTime(); lock.unlock()
        introPatchDone = false
    }
}

/// The live histogram, observed only by the histograms (see `CameraModel.meters`).
final class LiveMeters: ObservableObject {
    @Published var histogram: [Float] = []
}

/// The finder's swing with the camera's motion, observed only by the finder.
final class FinderMotion: ObservableObject {
    @Published var sway: CGSize = .zero
    /// How brightly the scene lights the bright frame, 0.14…1.
    @Published var light: CGFloat = 1
}

/// The photo modes read QR codes, like the system camera: the code shown while it is in view,
/// a tap away from the browser.
extension CameraModel: AVCaptureMetadataOutputObjectsDelegate {
    /// DIGI, FILM and PRO look for codes (on the Lock Screen too); VIDEO and BOOTH don't carry
    /// the reader. Not alongside FILM's ultra-wide (two cameras at once). On the session queue.
    static func readsCodes(_ m: CaptureMode) -> Bool { m == .digi || m == .film || m == .pro }

    func updateQR(_ m: CaptureMode) {
        let want = Self.readsCodes(m)
        let on = session.outputs.contains(qrOutput)
        if want && !on && !(session is AVCaptureMultiCamSession) {
            session.beginConfiguration()
            if session.canAddOutput(qrOutput) {
                session.addOutput(qrOutput)
                qrOutput.setMetadataObjectsDelegate(self, queue: .main)
            }
            session.commitConfiguration()
            if session.outputs.contains(qrOutput), qrOutput.availableMetadataObjectTypes.contains(.qr) {
                qrOutput.metadataObjectTypes = [.qr]
            }
        } else if !want && on {
            session.beginConfiguration()
            session.removeOutput(qrOutput)
            session.commitConfiguration()
        }
        if !want { DispatchQueue.main.async { self.qrCode = nil } }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard Self.readsCodes(mode),
              let code = objects.compactMap({ ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }).first,
              !code.isEmpty else { return }
        if qrCode != code { qrCode = code }
        // gone a couple of seconds after it leaves the frame (one timer, pushed back each sighting)
        qrClear?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.qrCode = nil }
        qrClear = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: w)
    }
}

#if DEBUG && targetEnvironment(simulator) && !CAPTURE_EXTENSION
// MARK: demo (the simulator, for screenshots)

/// The simulator has no camera. With XA_DEMO_PHOTO set (a picture, or a folder of them), the
/// picture is fed through the real viewfinder as the camera's frames, drifting slowly the way a
/// hand-held camera does, and a press develops what is shown through the real lab and saves it.
/// Debug builds in the simulator only: nothing of this is in the app people get.
extension CameraModel {
    final class Demo {
        let photos: [URL]
        var index = 0
        var still: CIImage?
        var timer: DispatchSourceTimer?
        var pool: CVPixelBufferPool?
        var started: CFTimeInterval = 0
        let context = CIContext(options: [.cacheIntermediates: false])
        var active: Bool { !photos.isEmpty }

        init() {
            guard let path = ProcessInfo.processInfo.environment["XA_DEMO_PHOTO"] else { photos = []; return }
            let url = URL(fileURLWithPath: path)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { photos = []; return }
            if isDir.boolValue {
                let kinds: Set<String> = ["jpg", "jpeg", "png", "heic", "tif", "tiff"]
                photos = ((try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
                    .filter { kinds.contains($0.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
            } else {
                photos = [url]
            }
        }

        /// The picture as the camera would hold it: upright, 3:4 portrait, cropped from the middle.
        func load() {
            guard !photos.isEmpty, let img = CIImage(contentsOf: photos[index % photos.count], options: [.applyOrientationProperty: true]) else { still = nil; return }
            let e = img.extent
            let w = min(e.width, e.height * 3 / 4), h = w * 4 / 3
            let crop = CGRect(x: e.midX - w / 2, y: e.midY - h / 2, width: w, height: h).integral
            still = img.cropped(to: crop).transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        }

        /// What the camera sees at time `t`: a 92% window drifting a little, as a hand holds a camera.
        func window(_ t: CFTimeInterval) -> CIImage? {
            guard let s = still else { return nil }
            let e = s.extent
            let k: CGFloat = 0.92
            let dx = CGFloat(sin(t * 0.37)) * e.width * (1 - k) / 2
            let dy = CGFloat(cos(t * 0.29)) * e.height * (1 - k) / 2
            let r = CGRect(x: e.width * (1 - k) / 2 + dx, y: e.height * (1 - k) / 2 + dy, width: e.width * k, height: e.height * k)
            return s.cropped(to: r).transformed(by: CGAffineTransform(translationX: -r.minX, y: -r.minY))
        }
    }

    static let demo = Demo()

    /// Frames at 30 a second on the frame queue, as the camera sends them (1440 × 1920 portrait).
    fileprivate func startDemo() {
        let d = Self.demo
        authorized = true
        lenses = Lenses.stops(switchOvers: [2, 10], maxZoom: 20, multiplier: 0.5)
        zoom = Lenses.main(switchOvers: [2, 10], multiplier: 0.5)
        zoomMultiplier = 0.5
        proOptions = [12, 48]
        publishPhotoSize(mode)
        if mode == .film { beginFinderIntro() }
        frameQueue.async {
            d.load()
            d.started = CACurrentMediaTime()
            let attrs: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                                        kCVPixelBufferWidthKey as String: 1440, kCVPixelBufferHeightKey as String: 1920,
                                        kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()]
            CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &d.pool)
            let t = DispatchSource.makeTimerSource(queue: self.frameQueue)
            t.schedule(deadline: .now(), repeating: 1.0 / 30)
            t.setEventHandler { [weak self] in self?.demoFrame() }
            t.resume()
            d.timer = t
        }
    }

    private func demoFrame() {
        let d = Self.demo
        guard let pool = d.pool, let win = d.window(CACurrentMediaTime() - d.started) else { return }
        var out: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out) == kCVReturnSuccess, let pb = out else { return }
        let s = 1440 / win.extent.width
        d.context.render(win.transformed(by: CGAffineTransform(scaleX: s, y: s)), to: pb,
                         bounds: CGRect(x: 0, y: 0, width: 1440, height: 1920), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        var fmt: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pb, formatDescriptionOut: &fmt)
        guard let fmt else { return }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                        presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pb, formatDescription: fmt, sampleTiming: &timing, sampleBufferOut: &sb)
        if let sb { viewfinderFrame(sb) }
    }

    /// A press: the picture in the window, at the camera's photo size, through the real develop.
    /// With a folder, the next picture comes up after the shot.
    fileprivate func demoFire(_ id: Int64, _ settingsP: AVCapturePhotoSettings) {
        guard let shot = pending.removeValue(forKey: id) else { return }
        answered.remove(id); quietShots.remove(id)
        if settings.sounds { CameraSounds.shared.play(.shutter) }
        if shot.mode.usesFilm && settings.instantReview { startReview() }
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { self.flash = false }
        let dims = settingsP.maxPhotoDimensions
        frameQueue.async {
            let d = Self.demo
            guard let win = d.window(CACurrentMediaTime() - d.started) else {
                DispatchQueue.main.async { self.developing = max(0, self.developing - 1) }; return
            }
            // the photo at the size the camera would have taken (portrait: the short side across)
            let across = CGFloat(min(dims.width, dims.height))
            let s = across / win.extent.width
            let photo = win.transformed(by: CGAffineTransform(scaleX: s, y: s))
            let data = d.context.jpegRepresentation(of: photo, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                    options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95])
            if d.photos.count > 1 { d.index += 1; d.load() }
            DispatchQueue.main.async {
                guard let data else { self.developing = max(0, self.developing - 1); return }
                self.develop(data, shot)
            }
        }
    }
}
#endif
