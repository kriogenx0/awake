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
            window.alphaValue = 0
            window.orderFrontRegardless()
            return window
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func hide() {
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }
}
