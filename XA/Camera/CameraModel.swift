import AVFoundation
import CoreImage
import UIKit

/// The camera. A shutter that never waits: the press takes the picture and everything slow
/// (the filter at full size, the date back, the encode, the save) drains through a queue
/// behind the live viewfinder.
final class CameraModel: NSObject, ObservableObject {
    @Published var look: Look = .film { didSet { UserDefaults.standard.set(look.rawValue, forKey: "look") } }
    @Published var dateBack = true { didSet { UserDefaults.standard.set(dateBack, forKey: "dateBack") } }
    @Published private(set) var authorized: Bool?
    @Published private(set) var front = false
    @Published private(set) var developing = 0
    @Published private(set) var flash = false
    @Published private(set) var hasCameraControl = false
    @Published private(set) var lastShot: UIImage?

    let session = AVCaptureSession()
    weak var preview: PreviewView?
    var library: Library?

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "xa.session")
    private let frameQueue = DispatchQueue(label: "xa.frames")
    private let developQueue = DispatchQueue(label: "xa.develop")
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var picker: AVCaptureIndexPicker?
    private var currentLook: Look = .film

    override init() {
        super.init()
        if let l = Look(rawValue: UserDefaults.standard.integer(forKey: "look")), UserDefaults.standard.object(forKey: "look") != nil { look = l }
        if UserDefaults.standard.object(forKey: "dateBack") != nil { dateBack = UserDefaults.standard.bool(forKey: "dateBack") }
        currentLook = look
    }

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

    func setLook(_ l: Look) {
        look = l
        frameQueue.async { self.currentLook = l }
        picker?.selectedIndex = l.rawValue
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let inp = try? AVCaptureDeviceInput(device: dev), session.canAddInput(inp) else { session.commitConfiguration(); return }
        session.addInput(inp)
        device = dev; input = inp
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        setupPhotoOutput(dev)
        addControls(dev)
        session.commitConfiguration()
        applyRotation()
        session.startRunning()
    }

    private func setupPhotoOutput(_ dev: AVCaptureDevice) {
        // 12MP: the full-sensor readout is what makes a phone camera feel slow.
        let dims = dev.activeFormat.supportedMaxPhotoDimensions
        if let d = dims.filter({ Int($0.width) * Int($0.height) <= 12_600_000 }).max(by: { $0.width * $0.height < $1.width * $1.height }) ?? dims.first {
            photoOutput.maxPhotoDimensions = d
        }
        photoOutput.maxPhotoQualityPrioritization = .balanced
        if photoOutput.isResponsiveCaptureSupported { photoOutput.isResponsiveCaptureEnabled = true }
        if photoOutput.isFastCapturePrioritizationSupported { photoOutput.isFastCapturePrioritizationEnabled = true }
        if photoOutput.isZeroShutterLagSupported { photoOutput.isZeroShutterLagEnabled = true }
    }

    /// Camera Control: slide to change filter, the way the LP3 wheel did.
    private func addControls(_ dev: AVCaptureDevice) {
        guard session.supportsControls else { return }
        for c in session.controls { session.removeControl(c) }
        let p = AVCaptureIndexPicker("Filter", symbolName: "camera.filters", localizedIndexTitles: Look.allCases.map { $0.title.capitalized })
        p.selectedIndex = look.rawValue
        p.setActionQueue(.main) { [weak self] i in
            guard let self, let l = Look(rawValue: i) else { return }
            self.look = l
            self.frameQueue.async { self.currentLook = l }
        }
        if session.canAddControl(p) { session.addControl(p); picker = p }
        let zoom = AVCaptureSystemZoomSlider(device: dev)
        if session.canAddControl(zoom) { session.addControl(zoom) }
        session.setControlsDelegate(self, queue: sessionQueue)
        DispatchQueue.main.async { self.hasCameraControl = true }
    }

    private func applyRotation() {
        guard let dev = device else { return }
        let rc = AVCaptureDevice.RotationCoordinator(device: dev, previewLayer: nil)
        rotation = rc
        if let c = videoOutput.connection(with: .video) {
            let a = rc.videoRotationAngleForHorizonLevelCapture
            if c.isVideoRotationAngleSupported(a) { c.videoRotationAngle = a }
            if c.isVideoMirroringSupported { c.automaticallyAdjustsVideoMirroring = false; c.isVideoMirrored = frontFlag }
        }
    }

    func flip() {
        sessionQueue.async {
            guard let old = self.input else { return }
            let pos: AVCaptureDevice.Position = self.front ? .back : .front
            guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos),
                  let inp = try? AVCaptureDeviceInput(device: dev) else { return }
            self.session.beginConfiguration()
            self.session.removeInput(old)
            if self.session.canAddInput(inp) { self.session.addInput(inp); self.input = inp; self.device = dev } else { self.session.addInput(old) }
            self.setupPhotoOutput(self.device!)
            self.addControls(self.device!)
            self.session.commitConfiguration()
            DispatchQueue.main.async { self.front = pos == .front }
            self.frontFlag = pos == .front
            self.applyRotation()
        }
    }
    private var frontFlag = false

    func shoot() {
        guard authorized == true else { return }
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .speed
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        if let c = photoOutput.connection(with: .video), let rc = rotation {
            let a = rc.videoRotationAngleForHorizonLevelCapture
            if c.isVideoRotationAngleSupported(a) { c.videoRotationAngle = a }
        }
        let meta = Shot(look: look, dateBack: dateBack, date: Date())
        pending[settings.uniqueID] = meta
        photoOutput.capturePhoto(with: settings, delegate: self)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { self.flash = false }
        developing += 1
    }

    private struct Shot { let look: Look; let dateBack: Bool; let date: Date }
    private var pending: [Int64: Shot] = [:]

    private func develop(_ data: Data, _ shot: Shot) {
        developQueue.async {
            defer { DispatchQueue.main.async { self.developing = max(0, self.developing - 1) } }
            guard var img = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return }
            img = Looks.apply(shot.look, to: img, outputWidth: shot.look.pixelWidth != nil ? 1600 : nil)
            if shot.dateBack { img = DateBack.stamp(img, date: shot.date) }
            guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
                  let jpeg = Looks.context.jpegRepresentation(of: img, colorSpace: cs, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.92]) else { return }
            let thumb = Looks.context.createCGImage(img.transformed(by: CGAffineTransform(scaleX: 160 / img.extent.width, y: 160 / img.extent.width)), from: CGRect(x: 0, y: 0, width: 160, height: 160 * img.extent.height / img.extent.width))
            DispatchQueue.main.async {
                if let thumb { self.lastShot = UIImage(cgImage: thumb) }
                self.library?.save(jpeg: jpeg)
            }
        }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let img = Looks.apply(currentLook, to: CIImage(cvPixelBuffer: pb))
        let pixel = currentLook.pixelWidth != nil
        DispatchQueue.main.async { [weak self] in self?.preview?.show(img, pixelated: pixel) }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        DispatchQueue.main.async {
            guard let shot = self.pending.removeValue(forKey: id) else { return }
            guard error == nil, let data = photo.fileDataRepresentation() else { self.developing = max(0, self.developing - 1); return }
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
