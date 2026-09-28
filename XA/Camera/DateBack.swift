import UIKit
import CoreImage

/// A quartz date back, stamped into the corner the way a 1990s compact did it: '26 9 26.
enum DateBack {
    static func string(_ date: Date, tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "'%02d %d %d", (c.year ?? 0) % 100, c.month ?? 0, c.day ?? 0)
    }

    static var font: (CGFloat) -> UIFont = { size in
        UIFont(name: "DBLCDTempBlack", size: size) ?? .monospacedDigitSystemFont(ofSize: size, weight: .bold)
    }

    /// Stamps the date into the lower right of the image.
    static func stamp(_ image: CIImage, date: Date = Date()) -> CIImage {
        let e = image.extent
        let size = max(18, e.width / 22)
        let text = string(date)
        let attrs: [NSAttributedString.Key: Any] = [.font: font(size), .foregroundColor: UIColor(red: 1, green: 0.54, blue: 0.17, alpha: 1)]
        let ts = (text as NSString).size(withAttributes: attrs)
        let pad = size * 0.8
        let canvas = CGSize(width: ceil(ts.width + pad * 2), height: ceil(ts.height + pad * 2))
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: canvas, format: fmt).image { ctx in
            let c = ctx.cgContext
            c.setShadow(offset: .zero, blur: size * 0.45, color: UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 0.9).cgColor)
            (text as NSString).draw(at: CGPoint(x: pad, y: pad), withAttributes: attrs)
        }
        guard let cg = img.cgImage else { return image }
        let stamp = CIImage(cgImage: cg).transformed(by: CGAffineTransform(translationX: e.maxX - canvas.width - e.width * 0.04, y: e.minY + e.height * 0.04))
        return stamp.composited(over: image).cropped(to: e)
    }
}
