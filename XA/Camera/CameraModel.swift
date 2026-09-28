import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
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
    @Published var mode: CaptureMode = .digi { didSet { modeChanged(oldValue) } }
    @Published var stack = Stack(simID: "nocturne") { didSet { stackChanged() } }
    @Published private(set) var authorized: Bool?
    @Published private(set) var front = false
    @Published private(set) var developing = 0
    @Published private(set) var flash = false
    @Published private(set) var hasCameraControl = false
    @Published private(set) var lastShot: UIImage?
    @Published private(set) var lenses: [Lens] = []
    @Published private(set) var zoom: CGFloat = 1
    @Published private(set) var photoSize: CGSize = .zero
    @Published private(set) var histogram: [Float] = []
    /// Photo sizes PRO can ask the sensor for, in megapixels, smallest first.
    @Published private(set) var proOptions: [Int] = []

    // PRO dials. nil means auto.
    @Published var proControl: ProControl = .ev
    @Published var ev: Float = 0 { didSet { if ev != oldValue { applyPro() } } }
    @Published var shutterIndex: Int? { didSet { if shutterIndex != oldValue { applyPro() } } }
    @Published var isoIndex: Int? { didSet { if isoIndex != oldValue { applyPro() } } }
    @Published var wbIndex: Int = 0 { didSet { if wbIndex != oldValue { applyPro() } } }
    @Published var focusIndex: Int? { didSet { if focusIndex != oldValue { applyPro() } } }

    let session = AVCaptureSession()
    let settings: AppSettings
    weak var preview: PreviewView?
    var library: Library?
    /// Where the Lock Screen camera saves when Photos is not available to it.
    var fallbackFolder: URL?

    private let photoOutput = AVCapturePhotoOutput()
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
    // Mode switch: DIGI's processing fades in or out over half a second.
    private var _switchStart: CFTimeInterval = 0
    private var _toDigi = true
    /// The fade starts on the first frame after the switch, not on the tap, so a slow frame
    /// never eats the start of it.
    private var _switchPending = false
    // Per-shot photo sizes: the output is set to the largest once, so switching modes never
    // reconfigures the session.
    private var digiDims = CMVideoDimensions(width: 4032, height: 3024)
    private var proDims = CMVideoDimensions(width: 4032, height: 3024)

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
        if let s: Stack = AppSettings.load("stack") { stack = s }
        let last = CaptureMode(rawValue: UserDefaults.standard.string(forKey: "mode") ?? "") ?? .digi
        switch settings.openIn {
        case .last: mode = last
        case .digi: mode = .digi
        case .pro: mode = .pro
        }
        _toDigi = mode == .digi
        syncFrameSettings()
    }

    /// The last viewfinder frame, small, for the editors' previews.
    var latestFrame: CIImage? { lock.lock(); defer { lock.unlock() }; return _latest }

    func syncFrameSettings() {
        var d = DevelopSettings()
        d.stack = stack
        d.megapixels = settings.digiMegapixels
        d.noise = settings.noise
        d.date = settings.date
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
        if let data = try? JSONEncoder().encode(stack) { UserDefaults.standard.set(data, forKey: "stack") }
        syncFrameSettings()
        onStackChange?()
    }
    var onStackChange: (() -> Void)?

    private func modeChanged(_ old: CaptureMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: "mode")
        if old != mode {
            lock.lock(); _switchPending = true; _switchStart = CACurrentMediaTime(); _toDigi = mode == .digi; lock.unlock()
        }
        syncFrameSettings()
        guard old != mode, input != nil else { return }
        let m = mode
        publishPhotoSize(m)
        sessionQueue.async { self.applyProOnQueue(m) }
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
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true; sessionQueue.async { self.configure() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { self.authorized = ok }
                if ok { self.sessionQueue.async { self.configure() } }
            }
        default: authorized = false
        }
    }

    func stop() { sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } } }
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
        if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = true }
        if photoOutput.isFastCapturePrioritizationSupported { photoOutput.isFastCapturePrioritizationEnabled = true }
        if photoOutput.isZeroShutterLagSupported { photoOutput.isZeroShutterLagEnabled = true }
        let m = mode
        setupPhotoOutput(dev, m)
        addControls(dev, m)
        session.commitConfiguration()
        setupLenses(dev)
        applyRotation()
        session.startRunning()
        applyProOnQueue(m)
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
        return m == .digi ? digiDims : proDims
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
        DispatchQueue.main.async { self.lenses = stops; self.zoom = main }
    }

    /// Camera Control. DIGI: slide through sims or looks. PRO: exposure or zoom.
    private func addControls(_ dev: AVCaptureDevice, _ m: CaptureMode) {
        guard session.supportsControls else { return }
        for c in session.controls { session.removeControl(c) }
        let zoom = AVCaptureSystemZoomSlider(device: dev) { [weak self] z in
            DispatchQueue.main.async { self?.zoom = z }
        }
        if m == .digi {
            let sims = FilmCatalog.sims
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
            let first: AVCaptureControl = settings.digiSlide == .sim ? simPicker : lookPicker
            let second: AVCaptureControl = settings.digiSlide == .sim ? lookPicker : simPicker
            for c in [first, second] where session.canAddControl(c) { session.addControl(c) }
        } else {
            let bias = AVCaptureSystemExposureBiasSlider(device: dev) { [weak self] b in
                DispatchQueue.main.async { if self?.ev != b { self?.ev = b } }
            }
            let order: [AVCaptureControl] = settings.proSlide == .exposure ? [bias, zoom] : [zoom, bias]
            for c in order where session.canAddControl(c) { session.addControl(c) }
        }
        if m == .digi, session.canAddControl(zoom) { session.addControl(zoom) }
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
        if let c = videoOutput.connection(with: .video) {
            let a = c.isVideoRotationAngleSupported(portrait) ? portrait : rc.videoRotationAngleForHorizonLevelCapture
            if c.isVideoRotationAngleSupported(a) { c.videoRotationAngle = a }
            previewAngle = a
            if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = frontFlag }
        }
        angleObservation = rc.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] rc, _ in
            guard let self else { return }
            var t = rc.videoRotationAngleForHorizonLevelCapture - self.previewAngle
            while t < 0 { t += 360 }
            while t >= 360 { t -= 360 }
            self.lock.lock(); self._turn = t; self.lock.unlock()
        }
    }

    private var turn: CGFloat { lock.lock(); defer { lock.unlock() }; return _turn }

    /// Turn a frame clockwise by a multiple of 90°, keeping it at the origin.
    static func rotated(_ img: CIImage, clockwise deg: CGFloat) -> CIImage {
        guard deg != 0 else { return img }
        let r = img.transformed(by: CGAffineTransform(rotationAngle: -deg * .pi / 180))
        return r.transformed(by: CGAffineTransform(translationX: -r.extent.minX, y: -r.extent.minY))
    }

    func flip() {
        sessionQueue.async {
            guard let old = self.input else { return }
            let toFront = !self.frontFlag
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

    func setZoom(_ f: CGFloat) {
        sessionQueue.async {
            guard let dev = self.device, (try? dev.lockForConfiguration()) != nil else { return }
            let z = min(max(f, dev.minAvailableVideoZoomFactor), dev.maxAvailableVideoZoomFactor)
            dev.ramp(toVideoZoomFactor: z, withRate: 14)
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

    // MARK: swiping through films

    func stepSim(_ by: Int) {
        let ids: [String] = FilmCatalog.sims.map { $0.id }
        let loaded = FilmCatalog.sim(stack.simID)?.id
        let i = ids.firstIndex(where: { $0 == loaded }) ?? 0
        let n = ids.count
        stack.simID = ids[((i + by) % n + n) % n]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func stepLook(_ by: Int) {
        let all = Look.allCases
        let i = all.firstIndex(of: stack.look) ?? 0
        let n = all.count
        stack.look = all[((i + by) % n + n) % n]
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: shooting

    func shoot() {
        guard authorized == true, input != nil else { return }
        let m = mode
        let settingsP: AVCapturePhotoSettings
        if m == .pro && settings.proFormat == .heif && photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settingsP = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settingsP = AVCapturePhotoSettings()
        }
        let want = m.prioritization
        settingsP.photoQualityPrioritization = want.rawValue <= photoOutput.maxPhotoQualityPrioritization.rawValue ? want : photoOutput.maxPhotoQualityPrioritization
        settingsP.maxPhotoDimensions = shotDims(m)
        if let c = photoOutput.connection(with: .video), let rc = rotation {
            let a = rc.videoRotationAngleForHorizonLevelCapture
            if c.isVideoRotationAngleSupported(a) { c.videoRotationAngle = a }
        }
        syncFrameSettings()
        let (_, dev) = frameState()
        pending[settingsP.uniqueID] = Shot(mode: m, develop: dev, crunch: settings.crunch, date: Date())
        photoOutput.capturePhoto(with: settingsP, delegate: self)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { self.flash = false }
        developing += 1
    }

    private struct Shot { let mode: CaptureMode; let develop: DevelopSettings; let crunch: Double; let date: Date }
    private var pending: [Int64: Shot] = [:]

    private func develop(_ data: Data, _ shot: Shot) {
        developQueue.async {
            defer { DispatchQueue.main.async { self.developing = max(0, self.developing - 1) } }
            guard let src = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return }
            var out: Data?
            var type: UTType = .jpeg
            var thumbSource = src
            if shot.mode == .pro {
                // Saved exactly as the camera made it.
                out = data
                type = self.settings.proFormat == .heif ? .heic : .jpeg
            } else {
                let (developed, alpha) = Darkroom.develop(src, shot.develop, date: shot.date, preview: false)
                let recipe = Recipe.describe(shot.develop.stack, megapixels: shot.develop.megapixels)
                let img = developed.settingProperties(Recipe.properties(from: src.properties, recipe: recipe))
                thumbSource = img
                guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return }
                if alpha {
                    out = Looks.context.pngRepresentation(of: img, format: .RGBA8, colorSpace: cs)
                    type = .png
                } else {
                    let q = CGFloat(shot.crunch)
                    out = Looks.context.jpegRepresentation(of: img, colorSpace: cs, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: q])
                }
            }
            guard let out else { return }
            let e = thumbSource.extent
            let k: CGFloat = 200 / max(e.width, 1)
            let small = thumbSource.transformed(by: CGAffineTransform(scaleX: k, y: k))
            let thumb = Looks.context.createCGImage(small, from: small.extent)
            DispatchQueue.main.async {
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

    private func writeFallback(_ data: Data, _ type: UTType) {
        guard let dir = fallbackFolder else { return }
        let ext = type.preferredFilenameExtension ?? "jpg"
        let url = dir.appendingPathComponent("XA-\(Int(Date().timeIntervalSince1970 * 1000)).\(ext)")
        try? data.write(to: url)
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

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let raw = CIImage(cvPixelBuffer: pb)
        let e = raw.extent
        let k: CGFloat = min(1, 1080 / max(e.width, 1))
        let src = raw.transformed(by: CGAffineTransform(scaleX: k, y: k))
        let (m, dev) = frameState()
        frameCount += 1
        if frameCount % 10 == 0 {
            let s: CGFloat = 640 / max(src.extent.width, 1)
            let small = src.transformed(by: CGAffineTransform(scaleX: s, y: s))
            lock.lock(); _latest = small; lock.unlock()
        }
        lock.lock()
        if _switchPending { _switchPending = false; _switchStart = CACurrentMediaTime() }
        lock.unlock()
        let img: CIImage
        let amount = digiAmount()
        if amount <= 0 {
            img = src
            if m == .pro && frameCount % 6 == 0 {
                let s: CGFloat = 160 / max(src.extent.width, 1)
                updateHistogram(src.transformed(by: CGAffineTransform(scaleX: s, y: s)))
            }
        } else {
            // Develop the frame the way the photograph will be turned, so the date back and the
            // shape sit where they will on the print, then turn it back for the viewfinder.
            let t = turn
            let upright = Self.rotated(src, clockwise: t)
            var developed = Darkroom.develop(upright, dev, date: Date(), preview: true, dateShift: 1 - amount).0
            if amount < 1 {
                // Switching modes: the film fades in or out and the date slides with it.
                let f = CIFilter.dissolveTransition()
                f.inputImage = upright
                f.targetImage = developed
                f.time = Float(amount)
                developed = (f.outputImage ?? developed).cropped(to: developed.extent.union(upright.extent))
            }
            img = t == 0 ? developed : Self.rotated(developed, clockwise: 360 - t)
        }
        let pixel = m == .digi && dev.stack.look.pixelWidth != nil
        // Drawn right here on the frame queue: the main thread can be busy without the viewfinder stuttering.
        preview?.show(img, pixelated: pixel)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let data = photo.fileDataRepresentation()
        DispatchQueue.main.async {
            guard let shot = self.pending.removeValue(forKey: id) else { return }
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
