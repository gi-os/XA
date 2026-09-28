import SwiftUI
import WidgetKit
import AppIntents

@main
struct XAControls: WidgetBundle {
    var body: some Widget {
        XACameraControl()
    }
}

/// The Control Center / Lock Screen button. It is also what makes XA selectable as the
/// camera button's launch app in Settings › Camera › Camera Control.
struct XACameraControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.gios.xa.control.camera") {
            ControlWidgetButton(action: XACaptureIntent()) {
                Label("XA", systemImage: "camera.aperture")
            }
        }
        .displayName("XA")
        .description("Open XA, even when the phone is locked.")
    }
}
