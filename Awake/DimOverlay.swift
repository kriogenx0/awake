import AppKit

final class DimOverlayController {
    private var windows: [NSWindow] = []

    var isVisible: Bool { !windows.isEmpty }

    func show(opacity: Double) {
        hide()
        guard windows.isEmpty else {
            windows.forEach { $0.backgroundColor = NSColor.black.withAlphaComponent(opacity) }
            return
        }

        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            // window.level = .screenSaver
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelKey.maximumWindow.rawValue))
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.orderFrontRegardless()
            windows.append(win)
            return window
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
