import CoreImage

/// Keeps impossible pixel values out of the chain. A single NaN or infinite pixel (a hot
/// sensor pixel, an extended-range highlight) passes through the colour matrices untouched,
/// then every blur spreads it over the blur's whole footprint, and the glow works at a quarter
/// size, so it came back as a black square that sat still on the sensor and turned with the
/// phone. Here NaN becomes 0 and anything past 64 is held at 64 before it can spread.
enum Sanitize {
    private static let kernel: CIColorKernel? = {
        // NaN is the only value that isn't equal to itself.
        let src = """
        kernel vec4 xaSanitize(__sample s, float lo) {
            vec4 c = s;
            c.r = (c.r == c.r) ? clamp(c.r, lo, 64.0) : 0.0;
            c.g = (c.g == c.g) ? clamp(c.g, lo, 64.0) : 0.0;
            c.b = (c.b == c.b) ? clamp(c.b, lo, 64.0) : 0.0;
            c.a = (c.a == c.a) ? clamp(c.a, 0.0, 1.0) : 1.0;
            return c;
        }
        """
        return CIColorKernel(source: src)
    }()

    static func apply(_ img: CIImage, floor: Float = -1) -> CIImage {
        let e = img.extent
        if let k = kernel, let out = k.apply(extent: e, arguments: [img, floor]) { return out }
        let c = CIFilter(name: "CIColorClamp")
        c?.setValue(img, forKey: kCIInputImageKey)
        c?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputMinComponents")
        c?.setValue(CIVector(x: 64, y: 64, z: 64, w: 1), forKey: "inputMaxComponents")
        return c?.outputImage?.cropped(to: e) ?? img
    }
}
