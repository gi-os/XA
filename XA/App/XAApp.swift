import SwiftUI

@main
struct XAApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Camera alone on a regular iPhone and on the iPhone Duo's outer display. On a wide window
/// (the Duo's inner display, or landscape) the roll sits beside the viewfinder.
struct RootView: View {
    @StateObject private var camera = CameraModel()
    @StateObject private var library = Library()
    @State private var showRoll = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height * 0.8
            Group {
                if wide {
                    HStack(spacing: 0) {
                        CameraView(camera: camera, onRoll: {}).frame(width: geo.size.width * 0.55)
                        ContactSheet(library: library)
                    }
                } else {
                    CameraView(camera: camera, onRoll: { showRoll = true })
                        .fullScreenCover(isPresented: $showRoll) { ContactSheet(library: library, onClose: { showRoll = false }) }
                }
            }
        }
        .statusBarHidden()
        .onAppear { camera.library = library; camera.start() }
        .onChange(of: phase) { _, p in if p == .active { camera.resume() } else if p == .background { camera.stop() } }
    }
}
