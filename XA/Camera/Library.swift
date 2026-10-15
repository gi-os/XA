import Photos
import UIKit
import UniformTypeIdentifiers
import ImageIO
import AVFoundation

/// Everything XA takes goes into an "XA" album in Photos. iOS won't let a camera replace
/// Photos, so the contact sheet is a view onto that album.
final class Library: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let title = "XA"
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var authorized = false
    /// Photos access was refused: XA can still add pictures, but not show them.
    @Published private(set) var denied = false
    private let images = PHCachingImageManager()
    private var registered = false

    /// Empty until `refresh`: the app reads Photos once the camera has started.
    override init() {
        super.init()
    }

    /// Full and limited access both show the roll: with limited access iOS still lets XA see
    /// every picture it made itself.
    private func apply(_ s: PHAuthorizationStatus) {
        authorized = s == .authorized || s == .limited
        denied = s == .denied || s == .restricted
        if authorized && !registered { registered = true; PHPhotoLibrary.shared().register(self) }
        if authorized { reload() }
    }

    /// Pictures that couldn't be saved yet (no Photos access at the time), kept in the app.
    static var pendingFolder: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// How many pictures and videos are waiting in the pending folder.
    static var pendingCount: Int {
        guard let dir = pendingFolder else { return 0 }
        return ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { !$0.hasPrefix(".") }.count
    }

    private var flushing: Set<URL> = []

    /// Saves whatever is waiting, oldest first, and removes each once Photos has it. Add-only
    /// access is enough; files go in by URL (never all loaded into memory at once).
    /// `done` once every file it started on has been tried (on the main thread).
    func flushPending(done: (() -> Void)? = nil) {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard s == .authorized || s == .limited || PHPhotoLibrary.authorizationStatus(for: .addOnly) == .authorized,
              let dir = Self.pendingFolder,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            if let done { DispatchQueue.main.async(execute: done) }
            return
        }
        let group = DispatchGroup()
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where !flushing.contains(url) {
            let type = UTType(filenameExtension: url.pathExtension.lowercased()) ?? .jpeg
            flushing.insert(url)
            group.enter()
            if type.conforms(to: .movie) {
                save(video: url) { _ in self.flushing.remove(url); group.leave() }   // moved into Photos on success
            } else {
                save(file: url, type: type) { ok in
                    if ok { try? FileManager.default.removeItem(at: url) }
                    self.flushing.remove(url)
                    group.leave()
                }
            }
        }
        if let done { group.notify(queue: .main, execute: done) }
    }

    func refresh() { apply(PHPhotoLibrary.authorizationStatus(for: .readWrite)) }

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
            DispatchQueue.main.async { self.apply(s) }
        }
    }

    /// Every picture XA has saved, by its Photos id: the roll finds them even when the album
    /// can't be made or seen (limited access).
    private static let idsKey = "xaAssetIDs"
    private var savedIDs: [String] { UserDefaults.standard.stringArray(forKey: Self.idsKey) ?? [] }
    private func remember(_ id: String) {
        var ids = savedIDs
        guard !ids.contains(id) else { return }
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: Self.idsKey)
    }

    /// A picture the Lock Screen camera put in Photos itself: onto the roll and into the album.
    func adopt(_ id: String) {
        remember(id); file(id); scheduleReload()
    }

    /// The XA album: by the id XA made it with, else by its title.
    private static let albumKey = "xaAlbumID"
    private func album() -> PHAssetCollection? {
        if let id = UserDefaults.standard.string(forKey: Self.albumKey),
           let a = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject { return a }
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "title = %@", Self.title)
        let a = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: o).firstObject
        if let a { UserDefaults.standard.set(a.localIdentifier, forKey: Self.albumKey) }
        return a
    }
    /// Album filing one at a time: a burst of first saves made several "XA" albums.
    private let albumQueue = DispatchQueue(label: "xa.album")

    private var reloadQueued = false
    /// Many changes in a row (a save, its album filing, iCloud) reload once.
    func scheduleReload() {
        guard !reloadQueued else { return }
        reloadQueued = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.reloadQueued = false; self.reload() }
    }

    func reload() {
        guard authorized else { if !assets.isEmpty { assets = [] }; return }
        var seen = Set<String>()
        var list: [PHAsset] = []
        func take(_ r: PHFetchResult<PHAsset>) {
            r.enumerateObjects { asset, _, _ in
                if seen.insert(asset.localIdentifier).inserted { list.append(asset) }
            }
        }
        if let a = album() { take(PHAsset.fetchAssets(in: a, options: nil)) }
        let ids = savedIDs
        if !ids.isEmpty { take(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)) }
        list.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        // published only when the roll really changed: every publish redraws the whole app
        if list.map(\.localIdentifier) != assets.map(\.localIdentifier)
            || zip(list, assets).contains(where: { $0.modificationDate != $1.modificationDate }) {
            assets = list
        }
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { self.scheduleReload() }
    }

    static func clock(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private static let dayFormat: DateFormatter = { let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEEEMMMd"); return f }()

    /// Days, newest first, for the roll.
    var days: [(title: String, assets: [PHAsset])] {
        let cal = Calendar.current
        var out: [(title: String, assets: [PHAsset])] = []
        var current: Date?
        var bucket: [PHAsset] = []
        let fmt = Self.dayFormat
        func title(_ d: Date) -> String {
            if cal.isDateInToday(d) { return "TODAY" }
            if cal.isDateInYesterday(d) { return "YESTERDAY" }
            return fmt.string(from: d).uppercased()
        }
        for a in assets {
            let d = cal.startOfDay(for: a.creationDate ?? Date())
            if let c = current, c != d { out.append((title: title(c), assets: bucket)); bucket = [] }
            current = d
            bucket.append(a)
        }
        if let c = current, !bucket.isEmpty { out.append((title: title(c), assets: bucket)) }
        return out
    }

    /// Saves in two steps: first the picture itself, which works with any access (full, limited
    /// or add-only), then into the XA album, which needs full access. A failed album step never
    /// loses the picture.
    func save(data: Data, type: UTType, completion: ((Bool) -> Void)? = nil) {
        save(add: { req in
            let o = PHAssetResourceCreationOptions()
            o.uniformTypeIdentifier = type.identifier
            req.addResource(with: .photo, data: data, options: o)
        }, completion: completion)
    }

    /// The same from a file (nothing loaded into memory).
    func save(file url: URL, type: UTType, completion: ((Bool) -> Void)? = nil) {
        save(add: { req in
            let o = PHAssetResourceCreationOptions()
            o.uniformTypeIdentifier = type.identifier
            req.addResource(with: .photo, fileURL: url, options: o)
        }, completion: completion)
    }

    private func save(add: @escaping (PHAssetCreationRequest) -> Void, completion: ((Bool) -> Void)?) {
        let write = { (addOnly: Bool) in
            var id: String?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                add(req)
                id = req.placeholderForCreatedAsset?.localIdentifier
            }, completionHandler: { ok, _ in
                DispatchQueue.main.async {
                    guard ok else { completion?(false); return }
                    // remembered even without read access, so the roll shows it once it has access
                    if let id { self.remember(id); if !addOnly { self.file(id) } }
                    self.scheduleReload()
                    completion?(true)
                }
            })
        }
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                DispatchQueue.main.async {
                    self.apply(s)
                    if s == .authorized || s == .limited { write(false) } else { self.addOnly(write, completion) }
                }
            }
        case .denied, .restricted:
            addOnly(write, completion)
        default:
            write(false)
        }
    }

    /// Without read access, XA can still add the picture to Photos (it just can't show it yet).
    private func addOnly(_ write: @escaping (Bool) -> Void, _ completion: ((Bool) -> Void)?) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in
            DispatchQueue.main.async {
                guard s == .authorized || s == .limited else { completion?(false); return }
                write(true)
            }
        }
    }

    /// Into the XA album, when Photos lets XA see albums. One at a time, so the album is made once.
    private func file(_ id: String) {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else { return }
        albumQueue.async {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
            let existing = self.album()
            var made: String?
            try? PHPhotoLibrary.shared().performChangesAndWait {
                if let existing {
                    PHAssetCollectionChangeRequest(for: existing)?.addAssets([asset] as NSArray)
                } else {
                    let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Self.title)
                    req.addAssets([asset] as NSArray)
                    made = req.placeholderForCreatedAssetCollection.localIdentifier
                }
            }
            if let made { UserDefaults.standard.set(made, forKey: Self.albumKey) }
        }
    }

    /// Shaped pictures are PNGs with empty pixels; Photos' own thumbnails flatten them, so they
    /// are decoded from the file to keep the transparency.
    private var transparent: [String: Bool] = [:]
    /// isTransparent, remembered: the roll asks for every print as it lays the table out.
    func isTransparentCached(_ asset: PHAsset) -> Bool {
        if let v = transparent[asset.localIdentifier] { return v }
        let v = isTransparent(asset); transparent[asset.localIdentifier] = v; return v
    }

    func isTransparent(_ asset: PHAsset) -> Bool {
        PHAssetResource.assetResources(for: asset).contains { $0.uniformTypeIdentifier == UTType.png.identifier }
    }

    private func decode(_ data: Data, maxSide: CGFloat?) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        if let maxSide {
            let o: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceThumbnailMaxPixelSize: maxSide,
                                      kCGImageSourceCreateThumbnailWithTransform: true]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, o as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }
        guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return UIImage(cgImage: cg)
    }

    func thumbnail(_ asset: PHAsset, side: CGFloat, _ done: @escaping (UIImage?) -> Void) {
        if isTransparentCached(asset) {
            data(asset) { d, _ in
                // decoded off the main thread
                DispatchQueue.global(qos: .userInitiated).async {
                    let img = d.flatMap { self.decode($0, maxSide: side * 2) }
                    DispatchQueue.main.async { done(img) }
                }
            }
            return
        }
        let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.isNetworkAccessAllowed = true
        images.requestImage(for: asset, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill, options: o) { img, _ in done(img) }
    }

    /// For the viewer: never bigger than 4096 on the long side (a 48MP photo decoded whole is
    /// 190 MB, and the viewer keeps its neighbours too).
    func full(_ asset: PHAsset, _ done: @escaping (UIImage?) -> Void) {
        let cap: CGFloat = 4096
        let long = CGFloat(max(asset.pixelWidth, asset.pixelHeight))
        let k = long > cap ? cap / long : 1
        if isTransparentCached(asset) {
            data(asset) { d, _ in
                DispatchQueue.global(qos: .userInitiated).async {
                    let img = d.flatMap { self.decode($0, maxSide: cap) }
                    DispatchQueue.main.async { done(img) }
                }
            }
            return
        }
        let o = PHImageRequestOptions(); o.deliveryMode = .highQualityFormat; o.resizeMode = .exact; o.isNetworkAccessAllowed = true
        let size = CGSize(width: max(1, CGFloat(asset.pixelWidth) * k), height: max(1, CGFloat(asset.pixelHeight) * k))
        images.requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: o) { img, _ in done(img) }
    }

    /// A movie, with any access: Limited and add-only access can't touch albums, so the movie
    /// goes in first and into the album only with full access (in one change it failed whole).
    func save(video url: URL, completion: ((String?) -> Void)? = nil) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                DispatchQueue.main.async { self.apply(s); self.save(video: url, completion: completion) }
            }
            return
        }
        let write = { (canRead: Bool) in
            var id: String?
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                let o = PHAssetResourceCreationOptions(); o.shouldMoveFile = true
                req.addResource(with: .video, fileURL: url, options: o)
                id = req.placeholderForCreatedAsset?.localIdentifier
            }, completionHandler: { ok, _ in
                DispatchQueue.main.async {
                    if ok, let id { self.remember(id); if canRead { self.file(id) }; self.scheduleReload() }
                    completion?(ok ? id : nil)
                }
            })
        }
        if status == .authorized || status == .limited {
            write(true)
        } else {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in
                DispatchQueue.main.async {
                    guard s == .authorized || s == .limited else { completion?(nil); return }
                    write(false)
                }
            }
        }
    }

    func playerItem(_ asset: PHAsset, _ done: @escaping (AVPlayerItem?) -> Void) {
        let o = PHVideoRequestOptions(); o.isNetworkAccessAllowed = true; o.deliveryMode = .automatic
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: o) { item, _ in DispatchQueue.main.async { done(item) } }
    }

    /// A video's file, for sending.
    func exportVideo(_ asset: PHAsset, _ done: @escaping (URL?) -> Void) {
        guard let res = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else { done(nil); return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(res.originalFilename)
        try? FileManager.default.removeItem(at: url)
        let o = PHAssetResourceRequestOptions(); o.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: res, toFile: url, options: o) { err in
            DispatchQueue.main.async { done(err == nil ? url : nil) }
        }
    }

    /// Straight to Recently Deleted; iOS asks first.
    /// Several at once, so Photos asks once.
    func delete(_ assets: [PHAsset], _ done: ((Bool) -> Void)? = nil) {
        guard !assets.isEmpty else { done?(true); return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }, completionHandler: { ok, _ in DispatchQueue.main.async { done?(ok) } })
    }

    func delete(_ asset: PHAsset, _ done: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }, completionHandler: { ok, _ in DispatchQueue.main.async { done?(ok) } })
    }

    /// What the file says about itself, as label/value rows.
    func metadata(_ asset: PHAsset, _ done: @escaping ([(String, String)]) -> Void) {
        if asset.mediaType == .video {
            let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
            var rows: [(String, String)] = []
            if let date = asset.creationDate { rows.append(("Taken", df.string(from: date))) }
            rows.append(("Length", Library.clock(asset.duration)))
            rows.append(("Size", "\(asset.pixelWidth) × \(asset.pixelHeight)"))
            done(rows)
            return
        }
        data(asset) { d, uti in
            var rows: [(String, String)] = []
            let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
            if let date = asset.creationDate { rows.append(("Taken", df.string(from: date))) }
            if let d, let src = CGImageSourceCreateWithData(d as CFData, nil),
               let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] {
                let exif = p[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
                let tiff = p[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
                let recipe = (exif[kCGImagePropertyExifUserComment as String] as? String) ?? (tiff[kCGImagePropertyTIFFImageDescription as String] as? String)
                if let recipe, recipe.hasPrefix("XA") { rows.append(("Film", recipe)) }
                if let w = p[kCGImagePropertyPixelWidth as String] as? Int, let h = p[kCGImagePropertyPixelHeight as String] as? Int {
                    rows.append(("Size", "\(w) × \(h) · \(CaptureMode.megapixels(CGSize(width: w, height: h)))MP"))
                }
                if let t = exif[kCGImagePropertyExifExposureTime as String] as? Double, t > 0 {
                    rows.append(("Shutter", Exposure.shutterLabel(Int64(t * 1e9))))
                }
                if let f = exif[kCGImagePropertyExifFNumber as String] as? Double { rows.append(("Aperture", String(format: "ƒ/%.1f", f))) }
                if let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int])?.first { rows.append(("ISO", "\(iso)")) }
                if let fl = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Int { rows.append(("Focal length", "\(fl) mm")) }
                if let lens = exif[kCGImagePropertyExifLensModel as String] as? String { rows.append(("Lens", lens)) }
                if let model = tiff[kCGImagePropertyTIFFModel as String] as? String { rows.append(("Camera", model)) }
            }
            if let uti, let t = UTType(uti) { rows.append(("Format", (t.preferredFilenameExtension ?? uti).uppercased())) }
            if let d { rows.append(("File", ByteCountFormatter.string(fromByteCount: Int64(d.count), countStyle: .file))) }
            if let loc = asset.location { rows.append(("Place", String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))) }
            DispatchQueue.main.async { done(rows) }
        }
    }

    /// The original file, for sharing a shaped PNG with its transparency intact.
    func data(_ asset: PHAsset, _ done: @escaping (Data?, String?) -> Void) {
        let o = PHImageRequestOptions(); o.isNetworkAccessAllowed = true; o.version = .current
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: o) { d, uti, _, _ in done(d, uti) }
    }
}
