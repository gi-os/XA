import Photos
import UIKit

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

    func save(jpeg: Data, completion: ((Bool) -> Void)? = nil) {
        let write = {
            let existing = self.album()
            PHPhotoLibrary.shared().performChanges({
                let req = PHAssetCreationRequest.forAsset()
                req.addResource(with: .photo, data: jpeg, options: nil)
                guard let ph = req.placeholderForCreatedAsset else { return }
                if let existing {
                    PHAssetCollectionChangeRequest(for: existing)?.addAssets([ph] as NSArray)
                } else {
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Self.title).addAssets([ph] as NSArray)
                }
            }, completionHandler: { ok, _ in DispatchQueue.main.async { completion?(ok) } })
        }
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in DispatchQueue.main.async { self.authorized = true; PHPhotoLibrary.shared().register(self); write() } }
        } else { write() }
    }

    func thumbnail(_ asset: PHAsset, side: CGFloat, _ done: @escaping (UIImage?) -> Void) {
        let o = PHImageRequestOptions(); o.deliveryMode = .opportunistic; o.isNetworkAccessAllowed = true
        images.requestImage(for: asset, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill, options: o) { img, _ in done(img) }
    }

    func full(_ asset: PHAsset, _ done: @escaping (UIImage?) -> Void) {
        let o = PHImageRequestOptions(); o.deliveryMode = .highQualityFormat; o.isNetworkAccessAllowed = true
        images.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: o) { img, _ in done(img) }
    }
}
