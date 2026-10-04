import SwiftUI

/// FILM's finder markings, after the Olympus XA: split bright-frame bars, the hatched
/// over-exposure block and the shutter-speed scale with its needle, the solid under-exposure
/// block, all drawn in the finder's landscape space and turned a quarter with the body. They
/// sit at about two-thirds strength so they blend into the picture, and the eyepiece falls off
/// into black around them. The picture itself (the photo in the frame, the scene around it and
/// the rangefinder patch) is composed by XAFinder.compose on the viewfinder frames.
struct XAFinderView: View {
    @ObservedObject var camera: CameraModel
    let format: FilmFormat
    private let cream = Color(red: 0.957, green: 0.925, blue: 0.835)

    var body: some View {
        GeometryReader { g in
            ZStack {
                // the finder, in its own landscape space, turned with the body
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in draw(&ctx, size) }
                    needle(CGSize(width: g.size.height, height: g.size.width))
                }
                .frame(width: g.size.height, height: g.size.width)
                .rotationEffect(.degrees(90))
                .opacity(0.68)
                .position(x: g.size.width / 2, y: g.size.height / 2)
                // the eyepiece: everything falls off into black at the edges, most in the corners
                RadialGradient(stops: [.init(color: .clear, location: 0.62),
                                       .init(color: .black.opacity(0.5), location: 0.84),
                                       .init(color: .black.opacity(0.95), location: 1)],
                               center: .center, startRadius: 0, endRadius: hypot(g.size.width, g.size.height) / 2)
                Rectangle().stroke(Color.black, lineWidth: min(g.size.width, g.size.height) * 0.1)
                    .blur(radius: min(g.size.width, g.size.height) * 0.05)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: geometry, in the landscape space (width = the viewfinder's height)

    private struct Geo {
        let S, t, off, gap, R: CGFloat
        let fr: CGRect
        let top, bot, right, midx, midy: CGFloat
        let sx, sw, ox, ix, hh, ty, tb, oy, iy, Ro, Ri, xe: CGFloat
        func Y(_ r: CGFloat) -> CGFloat { top + (bot - top) * r }
    }

    private func geo(_ size: CGSize) -> Geo {
        let u = size.width / XAFinder.LW
        let lf = XAFinder.landscapeFrame(format)
        let fr = CGRect(x: lf.minX * u, y: lf.minY * u, width: lf.width * u, height: lf.height * u)
        let S = size.height
        let t = S * 0.022, off = t * 1.3, gap = S * 0.075, R = S * 0.075
        let top = fr.minY - off, bot = fr.maxY + off, right = fr.maxX + off
        let sx = fr.minX - off - S * 0.085, sw = S * 0.07
        let sh = bot - top
        return Geo(S: S, t: t, off: off, gap: gap, R: R, fr: fr, top: top, bot: bot, right: right,
                   midx: fr.midX, midy: fr.midY, sx: sx, sw: sw, ox: sx, ix: sx + sw, hh: sh * 0.175,
                   ty: top - t / 2, tb: top + t / 2, oy: bot + t / 2, iy: bot - t / 2,
                   Ro: sw * 0.95, Ri: R * 0.45, xe: fr.midX - gap / 2 - t / 2)
    }

    // MARK: drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let g = geo(size)
        let k: CGFloat = 0.45
        // right side: two strokes with round ends, pulled back half a bar so every gap is equal
        var right = Path()
        right.move(to: CGPoint(x: g.midx + g.gap / 2 + g.t / 2, y: g.top))
        right.addLine(to: CGPoint(x: g.right - g.R, y: g.top))
        right.addCurve(to: CGPoint(x: g.right, y: g.top + g.R),
                       control1: CGPoint(x: g.right - g.R * k, y: g.top), control2: CGPoint(x: g.right, y: g.top + g.R * k))
        right.addLine(to: CGPoint(x: g.right, y: g.midy - g.gap / 2 - g.t / 2))
        right.move(to: CGPoint(x: g.right, y: g.midy + g.gap / 2 + g.t / 2))
        right.addLine(to: CGPoint(x: g.right, y: g.bot - g.R))
        right.addCurve(to: CGPoint(x: g.right - g.R, y: g.bot),
                       control1: CGPoint(x: g.right, y: g.bot - g.R * k), control2: CGPoint(x: g.right - g.R * k, y: g.bot))
        right.addLine(to: CGPoint(x: g.midx + g.gap / 2 + g.t / 2, y: g.bot))
        let stroke = StrokeStyle(lineWidth: g.t, lineCap: .round, lineJoin: .round)

        // top left: one outline, the bar turning into the hatched block
        var tl = Path()
        tl.move(to: CGPoint(x: g.xe, y: g.ty))
        tl.addLine(to: CGPoint(x: g.ox + g.Ro, y: g.ty))
        tl.addCurve(to: CGPoint(x: g.ox, y: g.ty + g.Ro),
                    control1: CGPoint(x: g.ox + g.Ro * k, y: g.ty), control2: CGPoint(x: g.ox, y: g.ty + g.Ro * k))
        tl.addLine(to: CGPoint(x: g.ox, y: g.ty + g.hh * 0.72))
        tl.addLine(to: CGPoint(x: g.ox + g.sw * 0.3, y: g.ty + g.hh))
        tl.addLine(to: CGPoint(x: g.ix, y: g.ty + g.hh))
        tl.addLine(to: CGPoint(x: g.ix, y: g.tb))
        tl.addLine(to: CGPoint(x: g.xe, y: g.tb))
        // the half-round end at the gap
        tl.addCurve(to: CGPoint(x: g.xe, y: g.ty), control1: CGPoint(x: g.xe + g.t * 0.667, y: g.tb), control2: CGPoint(x: g.xe + g.t * 0.667, y: g.ty))
        tl.closeSubpath()
        // where the stripes go: the column, up to a diagonal through the inside corner
        var stripes = Path()
        stripes.move(to: CGPoint(x: g.ox - 6, y: g.ty - 6))
        stripes.addLine(to: CGPoint(x: g.ix - g.t - 6, y: g.ty - 6))
        stripes.addLine(to: CGPoint(x: g.ix, y: g.tb))
        stripes.addLine(to: CGPoint(x: g.ix, y: g.ty + g.hh + 2))
        stripes.addLine(to: CGPoint(x: g.ox - 6, y: g.ty + g.hh + 2))
        stripes.closeSubpath()

        // bottom left: its mirror, solid, rising to the block under the "1"
        var bl = Path()
        let y82 = g.Y(0.82), r82 = g.t * 0.4
        bl.move(to: CGPoint(x: g.xe, y: g.oy))
        bl.addLine(to: CGPoint(x: g.ox + g.Ro, y: g.oy))
        bl.addCurve(to: CGPoint(x: g.ox, y: g.oy - g.Ro),
                    control1: CGPoint(x: g.ox + g.Ro * k, y: g.oy), control2: CGPoint(x: g.ox, y: g.oy - g.Ro * k))
        bl.addLine(to: CGPoint(x: g.ox, y: y82 + r82))
        bl.addQuadCurve(to: CGPoint(x: g.ox + r82, y: y82), control: CGPoint(x: g.ox, y: y82))
        bl.addLine(to: CGPoint(x: g.ix - r82, y: y82))
        bl.addQuadCurve(to: CGPoint(x: g.ix, y: y82 + r82), control: CGPoint(x: g.ix, y: y82))
        bl.addLine(to: CGPoint(x: g.ix, y: g.iy - g.Ri))
        bl.addCurve(to: CGPoint(x: g.ix + g.Ri, y: g.iy),
                    control1: CGPoint(x: g.ix, y: g.iy - g.Ri * k), control2: CGPoint(x: g.ix + g.Ri * k, y: g.iy))
        bl.addLine(to: CGPoint(x: g.xe, y: g.iy))
        bl.addCurve(to: CGPoint(x: g.xe, y: g.oy), control1: CGPoint(x: g.xe + g.t * 0.667, y: g.iy), control2: CGPoint(x: g.xe + g.t * 0.667, y: g.oy))
        bl.closeSubpath()

        // glow under everything
        ctx.drawLayer { c in
            c.addFilter(.blur(radius: g.S * 0.012))
            c.opacity = 0.3
            c.stroke(right, with: .color(cream), style: stroke)
            c.fill(tl, with: .color(cream))
            c.fill(bl, with: .color(cream))
        }
        // the markings, softened once as a whole
        ctx.drawLayer { c in
            c.addFilter(.blur(radius: max(0.4, g.S * 0.0016)))
            c.stroke(right, with: .color(cream), style: stroke)
            c.fill(bl, with: .color(cream))
            c.drawLayer { h in
                h.clip(to: tl)
                // solid everywhere in the outline except the striped column
                var solid = Path(CGRect(x: g.ox - 8, y: g.ty - 8, width: g.midx - g.ox + 16, height: g.hh + 16))
                solid.addPath(stripes)
                h.fill(solid, with: .color(cream), style: FillStyle(eoFill: true))
                h.clip(to: stripes)
                h.fill(hatch(g), with: .color(cream))
            }
            // the speed scale, in a stencilled serif
            let fs = g.S * 0.05
            for m in XAFinder.marks {
                c.draw(Text(m.label).font(.custom("StardosStencil-Bold", size: fs)).foregroundColor(cream),
                       at: CGPoint(x: g.sx + g.sw / 2, y: g.Y(m.at)), anchor: .center)
            }
        }
    }

    /// Stripes running top-left to bottom-right, as thick as the gaps between them, phased so a
    /// dark gap sits against the bar's diagonal cut.
    private func hatch(_ g: Geo) -> Path {
        var p = Path()
        let P = g.t * 1.24
        let step = P * 2.squareRoot()               // spacing of x − y between stripes
        let c0 = g.ix - g.tb                         // the cut: x − y = c0
        let x0 = g.ox - 20, x1 = g.ix + 20
        var c = c0 - step / 2
        while c > (g.ox - (g.ty + g.hh)) - step {
            // the band between x − y = c − step/2 and x − y = c
            let a = c - step / 2, b = c
            p.move(to: CGPoint(x: x0, y: x0 - b))
            p.addLine(to: CGPoint(x: x1, y: x1 - b))
            p.addLine(to: CGPoint(x: x1, y: x1 - a))
            p.addLine(to: CGPoint(x: x0, y: x0 - a))
            p.closeSubpath()
            c -= step
        }
        return p
    }

    /// The meter needle: points at the speed the camera is using, swinging and settling like the XA's.
    private func needle(_ size: CGSize) -> some View {
        let g = geo(size)
        let at = XAFinder.needle(camera.meterShutter)
        return Capsule()
            .fill(Color(white: 0.05))
            .shadow(color: .black.opacity(0.7), radius: g.S * 0.012)
            .frame(width: g.sw * 0.95, height: g.S * 0.012)
            .rotationEffect(.degrees(-9), anchor: .leading)
            .position(x: g.sx - g.sw * 0.55 + g.sw * 0.475, y: g.Y(at))
            .animation(.interpolatingSpring(stiffness: 120, damping: 9), value: at)
    }
}
