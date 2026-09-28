import Photos
import UIKit
import UniformTypeIdentifiers
import ImageIO

/// Everything XA takes goes into an "XA" album in Photos. iOS won't let a camera replace
/// Photos, so the contact sheet is a view onto that album.
final class Library: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let title = "XA"
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var authorized = false
    private let images = PHCachingImageManager()

    override init() {
        super.init()
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorized = s == .authorized || s == .limited
        if authorized { PHPhotoLibrary.shared().register(self); reload() }
    }

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
            DispatchQueue.main.async {
                self.authorized = s == .authorized || s == .limited
                if self.authorized { PHPhotoLibrary.shared().register(self); self.reload() }
            }
        }
    }

    private func album() -> PHAssetCollection? {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "title = %@", Self.title)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: o).firstObject
    }

    func reload() {
        guard let a = album() else { assets = []; return }
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let r = PHAsset.fetchAssets(in: a, options: o)
        var list: [PHAsset] = []
        r.enumerateObjects { asset, _, _ in list.append(asset) }
        assets = list
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { self.reload() }
    }

    /// Days, newest first, for the roll.
    var days: [(title: String, assets: [PHAsset])] {
        let cal = Calendar.current
        var out: [(title: String, assets: [PHAsset])] = []
        var current: Date?
        var bucket: [PHAsset] = []
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE d MMM"
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

    func save(data: Data, type: UTType, completion: ((Bool) -> Void)? = nil) {
        let write = {
            let existing = self.album()
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                let o = PHAssetResourceCreationOptions()
                o.uniformTypeIdentifier = type.identifier
                req.addResource(with: .photo, data: data, options: o)
                guard let ph = req.placeholderForCreatedAsset else { return }
                if let existing {
                    PHAssetCollectionChangeRequest(for: existing)?.addAssets([ph] as NSArray)
                } else {
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Self.title).addAssets([ph] as NSArray)
                }
            }, completionHandler: { ok, _ in DispatchQueue.main.async { completion?(ok) } })
        }
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                DispatchQueue.main.async { self.authorized = true; PHPhotoLibrary.shared().register(self); write() }
            }
        } else { write() }
    }

    /// Shaped pictures are PNGs with empty pixels; Photos' own thumbnails flatten them, so they
    /// are decoded from the file to keep the transparency.
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
        if isTransparent(asset) {
            data(asset) { d, _ in
                let img = d.flatMap { self.decode($0, maxSide: side * 2) }
                DispatchQueue.main.async { done(img) }
            }
            return
        }
        let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.isNetworkAccessAllowed = true
        images.requestImage(for: asset, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill, options: o) { img, _ in done(img) }
    }

    func full(_ asset: PHAsset, _ done: @escaping (UIImage?) -> Void) {
        if isTransparent(asset) {
            data(asset) { d, _ in
                let img = d.flatMap { self.decode($0, maxSide: nil) }
                DispatchQueue.main.async { done(img) }
            }
            return
        }
        let o = PHImageRequestOptions(); o.deliveryMode = .highQualityFormat; o.isNetworkAccessAllowed = true
        images.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: o) { img, _ in done(img) }
    }

    /// The original file, for sharing a shaped PNG with its transparency intact.
    func data(_ asset: PHAsset, _ done: @escaping (Data?, String?) -> Void) {
        let o = PHImageRequestOptions(); o.isNetworkAccessAllowed = true; o.version = .current
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: o) { d, uti, _, _ in done(d, uti) }
    }
}
