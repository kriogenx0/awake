import AppKit

final class DimOverlayController {
    private var windows: [NSWindow] = []
    private var currentOpacity: Double = 0
    private var screenObserver: Any?

    var isVisible: Bool { !windows.isEmpty }

    func show(opacity: Double, duration: TimeInterval = 0.1) {
        currentOpacity = opacity
        if !windows.isEmpty {
            windows.forEach { setOpacity(opacity, on: $0, duration: duration) }
            return
        }
        rebuildWindows(animated: true, duration: duration)
        observeScreenChanges()
    }

    func hide(duration: TimeInterval = 0.1) {
        stopObservingScreenChanges()
        let closing = windows
        windows.removeAll()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }

    /// Window background colors don't animate, so the tint lives on the content view's layer.
    private func setOpacity(_ opacity: Double, on window: NSWindow, duration: TimeInterval) {
        guard let layer = window.contentView?.layer else { return }
        let target = NSColor.black.withAlphaComponent(opacity).cgColor
        let anim = CABasicAnimation(keyPath: "backgroundColor")
        anim.fromValue = layer.presentation()?.backgroundColor ?? layer.backgroundColor
        anim.toValue = target
        anim.duration = duration
        layer.backgroundColor = target
        layer.add(anim, forKey: "backgroundColor")
    }

    private func rebuildWindows(animated: Bool, duration: TimeInterval = 0.1) {
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
            window.backgroundColor = .clear
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(currentOpacity).cgColor
            window.alphaValue = animated ? 0 : 1
            window.orderFrontRegardless()
            return window
        }
        guard animated else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
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

/// The system can handle brightness keys outside the event-tap path on some Macs.
/// Keep a nonzero backlight independently of keyboard interception.
final class BacklightFloorController {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private let library: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?
    private var timer: Timer?
    var paused = false
    var onFloorCrossed: (() -> Void)?
    var onBacklightRaisedWhileDimmed: (() -> Void)?
    var hasExtraDimming = false
    var interceptingKeys = false
    static let minimum: Float = 0.0625

    init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        library = handle
        getBrightness = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }
            .map { unsafeBitCast($0, to: GetBrightness.self) }
        setBrightness = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }
            .map { unsafeBitCast($0, to: SetBrightness.self) }
    }

    static func needsCorrection(_ brightness: Float) -> Bool {
        brightness.isFinite && brightness >= 0 && brightness < minimum
    }

    func start() {
        guard timer == nil, getBrightness != nil, setBrightness != nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.enforceFloor() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Return false when at the floor or no supported display can be controlled.
    func stepBacklight(direction: Int) -> Bool {
        guard !paused, let getBrightness, let setBrightness else { return false }
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let display = number.uint32Value
            guard CGDisplayIsBuiltin(display) != 0, CGDisplayIsAsleep(display) == 0 else { continue }
            var brightness: Float = 0
            guard getBrightness(display, &brightness) == 0 else { continue }
            if direction > 0 && brightness <= Self.minimum + 0.001 { return false }
            let target = min(1, max(Self.minimum, brightness - Float(direction) / 16))
            return setBrightness(display, target) == 0
        }
        return false
    }

    static func shouldUndoHardwareIncrease(brightness: Float, hasExtraDimming: Bool, interceptingKeys: Bool) -> Bool {
        hasExtraDimming && !interceptingKeys && brightness.isFinite && brightness > minimum + 0.001
    }

    private func enforceFloor() {
        guard !paused, let getBrightness, let setBrightness else { return }
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let display = number.uint32Value
            // Leave actual display sleep and external monitors alone.
            guard CGDisplayIsBuiltin(display) != 0, CGDisplayIsAsleep(display) == 0 else { continue }
            var brightness: Float = 0
            guard getBrightness(display, &brightness) == 0 else { continue }
            if Self.needsCorrection(brightness) {
                guard setBrightness(display, Self.minimum) == 0 else { continue }
                onFloorCrossed?()
            } else if Self.shouldUndoHardwareIncrease(brightness: brightness, hasExtraDimming: hasExtraDimming, interceptingKeys: interceptingKeys) {
                // Native brightness-up must clear the overlay before leaving the floor.
                guard setBrightness(display, Self.minimum) == 0 else { continue }
                onBacklightRaisedWhileDimmed?()
            }
        }
    }

    deinit {
        timer?.invalidate()
        if let library { dlclose(library) }
    }
}
