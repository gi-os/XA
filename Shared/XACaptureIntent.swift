import AppIntents
import Foundation

/// What the app hands the Lock Screen camera: the capture extension cannot read the app's
/// settings, so the few that shape a picture travel in the intent's app context (4 KB max).
struct XAContext: Codable, Sendable {
    var mode: String = "digi"
    var simID: String? = "nocturne"
    var look: Int = 0
    var shape: Int = 0
    var digiMegapixels: Int = 2
    var crunch: Double = 0.6
    var dateStyle: String = "quartz"
    var datePlacement: String = "follow"
    var dateFormat: String = "own"
    var dateTime: Bool = false
    var front: Bool = false
}

/// Launches XA from the camera button, the Lock Screen, Control Center and the Action button.
struct XACaptureIntent: CameraCaptureIntent {
    typealias AppContext = XAContext
    static let title: LocalizedStringResource = "Open XA"
    static let description = IntentDescription("Take a picture with XA.")

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}
