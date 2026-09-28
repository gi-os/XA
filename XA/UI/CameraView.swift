import SwiftUI

/// The viewfinder with its controls floating on glass above it.
struct CameraView: View {
    @ObservedObject var camera: CameraModel
    var onRoll: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.authorized == false {
                VStack(spacing: 12) {
                    Text("XA needs the camera.").font(.headline)
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        .buttonStyle(.borderedProminent).tint(.orange)
                }.foregroundStyle(.white)
            } else {
                Viewfinder(camera: camera)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(alignment: .bottomTrailing) {
                        if camera.dateBack {
                            Text(DateBack.string(Date()))
                                .font(Font(DateBack.font(22) as CTFont))
                                .foregroundStyle(Color(red: 1, green: 0.54, blue: 0.17))
                                .shadow(color: .orange.opacity(0.9), radius: 5)
                                .padding(14)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay { if camera.flash { Color.white.opacity(0.7).clipShape(RoundedRectangle(cornerRadius: 18)) } }
            }
            VStack {
                topBar
                Spacer()
                bottom
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button { camera.dateBack.toggle() } label: {
                Label(camera.dateBack ? "DATE" : "NO DATE", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 7)
            }
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            if camera.developing > 0 {
                Text("DEVELOPING \(camera.developing)").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 7).background(.ultraThinMaterial, in: Capsule())
            } else if camera.hasCameraControl {
                Text("SLIDE CAMERA CONTROL → FILTER").font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 7).background(.ultraThinMaterial, in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.top, 8)
    }

    private var bottom: some View {
        VStack(spacing: 16) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Look.allCases) { l in
                            Button { withAnimation(.snappy) { camera.setLook(l) } } label: {
                                Text(l.title).font(.system(size: 11, weight: .bold)).tracking(0.4)
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .foregroundStyle(camera.look == l ? .black : .white.opacity(0.85))
                                    .background(camera.look == l ? Color.white : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .id(l)
                        }
                    }
                    .padding(4)
                }
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 16)
                .onChange(of: camera.look) { _, l in withAnimation { proxy.scrollTo(l, anchor: .center) } }
            }
            HStack {
                Button(action: onRoll) {
                    Group {
                        if let img = camera.lastShot { Image(uiImage: img).resizable().scaledToFill() }
                        else { LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing) }
                    }
                    .frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white, lineWidth: 2))
                }
                .accessibilityLabel("Open the roll")
                Spacer()
                Button { camera.shoot() } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                        Circle().fill(.white).frame(width: 62, height: 62)
                    }
                }
                .accessibilityLabel("Take picture")
                Spacer()
                Button { camera.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 18, weight: .semibold))
                        .frame(width: 46, height: 46).background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Switch camera")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 36)
        }
        .padding(.bottom, 18)
    }
}
