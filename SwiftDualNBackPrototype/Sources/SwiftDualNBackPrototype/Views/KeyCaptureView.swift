import AppKit
import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    let onF: () -> Void
    let onJ: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.start(onF: onF, onJ: onJ)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var monitor: Any?

        func start(onF: @escaping () -> Void, onJ: @escaping () -> Void) {
            stop()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                    return event
                }
                if chars == "f" {
                    onF()
                    return nil
                }
                if chars == "j" {
                    onJ()
                    return nil
                }
                return event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        deinit {
            stop()
        }
    }
}
