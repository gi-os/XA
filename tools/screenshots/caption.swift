// A caption as a transparent PNG, drawn with Core Text so any system font can be used by its
// PostScript name (ImageMagick can't pick one face out of a .ttc, which is how the Japanese,
// Korean and Chinese system fonts come). The text shrinks until it fits the box.
//
//   swiftc -O tools/screenshots/caption.swift -o caption
//   ./caption <font PostScript name or .ttf path> <size> <box width> <box height> <#RRGGBB> <out.png> <text>
import AppKit
import CoreText

let a = CommandLine.arguments
guard a.count == 8, let start = Double(a[2]), let bw = Double(a[3]), let bh = Double(a[4]) else {
    FileHandle.standardError.write("usage: caption font size width height #RRGGBB out.png text\n".data(using: .utf8)!)
    exit(2)
}
let fontArg = a[1], hex = a[5], out = a[6], text = a[7]

if fontArg.hasSuffix(".ttf") || fontArg.hasSuffix(".otf") {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: fontArg) as CFURL, .process, nil)
}
func fontName() -> String {
    guard fontArg.hasSuffix(".ttf") || fontArg.hasSuffix(".otf"),
          let ds = CTFontManagerCreateFontDescriptorsFromURL(URL(fileURLWithPath: fontArg) as CFURL) as? [CTFontDescriptor],
          let d = ds.first, let n = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String else { return fontArg }
    return n
}
let name = fontName()

func color(_ h: String) -> CGColor {
    var v: UInt64 = 0
    Scanner(string: h.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
    return CGColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
}

func attributed(_ size: CGFloat) -> NSAttributedString {
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    p.lineBreakMode = .byWordWrapping
    p.lineHeightMultiple = 0.95
    return NSAttributedString(string: text, attributes: [
        .font: CTFontCreateWithName(name as CFString, size, nil),
        .foregroundColor: color(hex),
        .paragraphStyle: p,
    ])
}

// the biggest size up to `start` at which the text fits the box (lines broken at words; CJK at characters)
var size = CGFloat(start)
var frameSize = CGSize.zero
while size > 8 {
    let fs = CTFramesetterCreateWithAttributedString(attributed(size))
    frameSize = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(location: 0, length: 0), nil, CGSize(width: bw, height: .greatestFiniteMagnitude), nil)
    if frameSize.height <= bh && frameSize.width <= bw { break }
    size -= 2
}

let w = Int(bw), h = Int(bh)
guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
let fs = CTFramesetterCreateWithAttributedString(attributed(size))
// centred vertically in the box
let y = (bh - frameSize.height) / 2
let path = CGPath(rect: CGRect(x: 0, y: y, width: bw, height: frameSize.height + 1), transform: nil)
CTFrameDraw(CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), path, nil), ctx)
guard let img = ctx.makeImage(), let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
exit(CGImageDestinationFinalize(dest) ? 0 : 1)
