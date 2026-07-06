import AppKit

final class DimOverlayController {
    private var windows: [NSWindow] = []

    func show(opacity: Double) {
        hide()
        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.backgroundColor = NSColor.black.withAlphaComponent(opacity)
            win.level = NSWindow.Level(rawValue: Int(CGWindowLevelKey.maximumWindow.rawValue))
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.isOpaque = false
            win.hasShadow = false
            win.orderFrontRegardless()
            windows.append(win)
        }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
