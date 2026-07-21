import AppKit

final class DimOverlayController {
    private var windows: [NSWindow] = []
    private var currentOpacity: Double = 0
    private var screenObserver: Any?

    var isVisible: Bool { !windows.isEmpty }

    func show(opacity: Double) {
        currentOpacity = opacity
        if !windows.isEmpty {
            windows.forEach { $0.backgroundColor = NSColor.black.withAlphaComponent(opacity) }
            return
        }
        rebuildWindows(animated: true)
        observeScreenChanges()
    }

    func hide() {
        stopObservingScreenChanges()
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }

    private func rebuildWindows(animated: Bool) {
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: nil
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.backgroundColor = NSColor.black.withAlphaComponent(currentOpacity)
            window.alphaValue = animated ? 0 : 1
            window.orderFrontRegardless()
            return window
        }
        guard animated else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    private func observeScreenChanges() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isVisible else { return }
            let closing = self.windows
            self.rebuildWindows(animated: false)
            closing.forEach { $0.orderOut(nil) }
        }
    }

    private func stopObservingScreenChanges() {
        if let o = screenObserver { NotificationCenter.default.removeObserver(o); screenObserver = nil }
    }
}
