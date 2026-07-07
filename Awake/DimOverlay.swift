import AppKit

final class DimOverlayController {
    private var windows: [NSWindow] = []

    var isVisible: Bool { !windows.isEmpty }

    func show(opacity: Double) {
        guard windows.isEmpty else {
            windows.forEach { $0.backgroundColor = NSColor.black.withAlphaComponent(opacity) }
            return
        }
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            window.orderFrontRegardless()
            return window
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
