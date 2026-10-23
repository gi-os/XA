import Foundation
import MetricKit

/// iOS's own reports of XA's crashes and hangs (MetricKit), kept in Files > On My iPhone > XA >
/// Diagnostics as JSON with the stack of the thread that died. They come whatever TestFlight's
/// crash sharing is set to, including for a launch the system killed for hanging, which leaves
/// TestFlight nothing to send. Delivered on a later launch, off the main thread.
final class Diagnostics: NSObject, MXMetricManagerSubscriber {
    static let shared = Diagnostics()

    func start() { MXMetricManager.shared.add(self) }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            let stamp = Int(p.timeStampEnd.timeIntervalSince1970)
            let kinds = [(p.crashDiagnostics?.count ?? 0, "crash"), (p.hangDiagnostics?.count ?? 0, "hang")]
                .filter { $0.0 > 0 }.map { $0.1 }.joined(separator: "-")
            LaunchLog.save(p.jsonRepresentation(), named: "diagnostic-\(stamp)\(kinds.isEmpty ? "" : "-" + kinds).json")
        }
    }
}
