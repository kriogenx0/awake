import Foundation
import IOKit.pwr_mgt
import ServiceManagement
import AppKit
import CoreGraphics

enum DisplayDimDelay: Int, CaseIterable {
    case never = 0
    case oneMinute = 1
    case fiveMinutes = 5
    case tenMinutes = 10
    case twentyMinutes = 20
    case thirtyMinutes = 30
    case oneHour = 60

    var label: String {
        switch self {
        case .never:          return "Never"
        case .oneMinute:      return "1 minute"
        case .fiveMinutes:    return "5 minutes"
        case .tenMinutes:     return "10 minutes"
        case .twentyMinutes:  return "20 minutes"
        case .thirtyMinutes:  return "30 minutes"
        case .oneHour:        return "1 hour"
        }
    }

    var seconds: TimeInterval { TimeInterval(rawValue) * 60 }
}

enum DisplayBlackDelay: Int, CaseIterable {
    case never = 0
    case oneMinute = 1
    case fiveMinutes = 5
    case tenMinutes = 10
    case thirtyMinutes = 30

    var label: String {
        switch self {
        case .never:          return "Never"
        case .oneMinute:      return "1 minute later"
        case .fiveMinutes:    return "5 minutes later"
        case .tenMinutes:     return "10 minutes later"
        case .thirtyMinutes:  return "30 minutes later"
        }
    }

    var seconds: TimeInterval { TimeInterval(rawValue) * 60 }
}

enum DisplayWakeTrigger: String, CaseIterable {
    case click
    case anyEvent

    var label: String {
        switch self {
        case .click: return "A click"
        case .anyEvent: return "Any activity"
        }
    }

    var activityEventTypes: [CGEventType] {
        let clicks: [CGEventType] = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        switch self {
        case .click: return clicks
        case .anyEvent:
            return clicks + [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                             .otherMouseDragged, .keyDown, .keyUp, .flagsChanged, .scrollWheel,
                             .leftMouseUp, .rightMouseUp, .otherMouseUp,
                             .tabletPointer, .tabletProximity, CGEventType(rawValue: 14)!]
        }
    }

    var eventMask: NSEvent.EventTypeMask {
        switch self {
        case .click:
            return [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        case .anyEvent:
            return [.leftMouseDown, .rightMouseDown, .otherMouseDown,
                    .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                    .keyDown, .keyUp, .flagsChanged, .scrollWheel, .tabletPoint, .tabletProximity,
                    .leftMouseUp, .rightMouseUp, .otherMouseUp, .systemDefined,
                    .magnify, .swipe, .rotate, .smartMagnify, .gesture]
        }
    }
}

enum StayAwakeDuration: Int, CaseIterable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case fourHours = 240
    case eightHours = 480

    var label: String {
        switch self {
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes:  return "30 minutes"
        case .oneHour:        return "1 hour"
        case .twoHours:       return "2 hours"
        case .fourHours:      return "4 hours"
        case .eightHours:     return "8 hours"
        }
    }

    var seconds: TimeInterval { TimeInterval(rawValue) * 60 }
}

let defaultDimOpacity: Double = 0.8

final class CountdownModel: ObservableObject {
    @Published var text: String?
}

class AppState: ObservableObject {
    @Published private(set) var caffeineActive = false
    @Published private(set) var activeDuration: StayAwakeDuration?
    let countdown = CountdownModel()
    @Published private(set) var scheduleEnabled: Bool
    @Published private(set) var scheduleActiveNow = false

    @Published var startHour: Int {
        didSet { UserDefaults.standard.set(startHour, forKey: "startHour"); updateSchedule() }
    }
    @Published var endHour: Int {
        didSet { UserDefaults.standard.set(endHour, forKey: "endHour"); updateSchedule() }
    }
    @Published private(set) var activeDays: Set<Int> {
        didSet { UserDefaults.standard.set(Array(activeDays), forKey: "activeDays"); updateSchedule() }
    }
    @Published var displayDimDelay: DisplayDimDelay {
        didSet {
            UserDefaults.standard.set(displayDimDelay.rawValue, forKey: "displayDimDelay")
            updateDisplayAssertion()
        }
    }
    @Published var displayBlackDelay: DisplayBlackDelay {
        didSet {
            UserDefaults.standard.set(displayBlackDelay.rawValue, forKey: "displayBlackDelay")
            updateDisplayAssertion()
        }
    }
    @Published var displayWakeTrigger: DisplayWakeTrigger {
        didSet {
            UserDefaults.standard.set(displayWakeTrigger.rawValue, forKey: "displayWakeTrigger")
            if isDimmed { installWakeMonitor() }
        }
    }
    @Published var dimOpacity: Double {
        didSet {
            UserDefaults.standard.set(dimOpacity, forKey: "dimOpacity")
            if dimOverlay.isVisible { dimOverlay.show(opacity: currentOverlayOpacity()) }
        }
    }
    @Published var nightDimEnabled: Bool {
        didSet { UserDefaults.standard.set(nightDimEnabled, forKey: "nightDimEnabled"); updateNightDim() }
    }
    @Published var nightDimStartHour: Int {
        didSet { UserDefaults.standard.set(nightDimStartHour, forKey: "nightDimStartHour"); updateNightDim() }
    }
    @Published var nightDimEndHour: Int {
        didSet { UserDefaults.standard.set(nightDimEndHour, forKey: "nightDimEndHour"); updateNightDim() }
    }
    @Published var nightDimOpacity: Double {
        didSet {
            UserDefaults.standard.set(nightDimOpacity, forKey: "nightDimOpacity")
            if nightDimActive { dimOverlay.show(opacity: currentOverlayOpacity()) }
        }
    }
    @Published private(set) var nightDimActive = false
    @Published private(set) var previewDimActive = false
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else             { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = !launchAtLogin
            }
        }
    }
    @Published var jiggleMouse: Bool {
        didSet {
            UserDefaults.standard.set(jiggleMouse, forKey: "jiggleMouse")
            if jiggleMouse && caffeineActive { startJiggleTimer() } else { stopJiggleTimer() }
        }
    }
    @Published var jiggleBig: Bool {
        didSet { UserDefaults.standard.set(jiggleBig, forKey: "jiggleBig") }
    }

    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var scheduleTimer: Timer?
    private var dimCheckTimer: Timer?
    private var blackTimer: Timer?
    private var wakeCheckTimer: Timer?
    private var jiggleTimer: Timer?
    private var awakeDurationTimer: Timer?
    private var awakeUntil: Date?
    private var manualOverride = false
    @Published private(set) var isDimmed = false
    private var wakeMonitor: Any?
    private var localWakeMonitor: Any?
    private var menuTrackingObserver: Any?
    private var systemWakeObserver: Any?
    private var screenUnlockObserver: Any?
    private var screenLockObserver: Any?
    private let dimOverlay = DimOverlayController()
    private let backlightFloor = BacklightFloorController()
    private var brightnessKeyTap: CFMachPort?
    private var brightnessKeySource: CFRunLoopSource?
    @Published private(set) var brightnessKeysEnabled = false
    @Published private(set) var keyboardDimOpacity: Double = 0


    init() {
        let d = UserDefaults.standard
        scheduleEnabled       = d.object(forKey: "scheduleEnabled")  as? Bool ?? true
        startHour             = d.object(forKey: "startHour")        as? Int  ?? 9
        endHour               = d.object(forKey: "endHour")          as? Int  ?? 18
        activeDays            = Set(d.array(forKey: "activeDays")    as? [Int] ?? [2, 3, 4, 5, 6])
        displayDimDelay       = DisplayDimDelay(rawValue: d.object(forKey: "displayDimDelay") as? Int ?? 0) ?? .never
        displayBlackDelay     = DisplayBlackDelay(rawValue: d.object(forKey: "displayBlackDelay") as? Int ?? 0) ?? .never
        displayWakeTrigger    = DisplayWakeTrigger(rawValue: d.string(forKey: "displayWakeTrigger") ?? "") ?? .anyEvent
        dimOpacity            = d.object(forKey: "dimOpacity")       as? Double ?? defaultDimOpacity
        nightDimEnabled       = d.object(forKey: "nightDimEnabled")  as? Bool ?? false
        nightDimStartHour     = d.object(forKey: "nightDimStartHour") as? Int ?? 23
        nightDimEndHour       = d.object(forKey: "nightDimEndHour")   as? Int ?? 6
        nightDimOpacity       = min(d.object(forKey: "nightDimOpacity") as? Double ?? defaultDimOpacity, 0.8)

        let service = SMAppService.mainApp
        if service.status == .notRegistered { try? service.register() }
        launchAtLogin = service.status == .enabled

        jiggleMouse = d.object(forKey: "jiggleMouse") as? Bool ?? false
        jiggleBig = d.object(forKey: "jiggleBig") as? Bool ?? false
        backlightFloor.onFloorCrossed = { [weak self] in
            guard let self else { return }
            // If interception is unavailable, a hardware step below the floor
            // becomes an extra overlay step instead of leaving the panel black.
            if !self.brightnessKeysEnabled {
                self.keyboardDimOpacity = Self.adjustedKeyboardOpacity(self.keyboardDimOpacity, direction: 1)
                self.refreshKeyboardDim()
            }
        }
        backlightFloor.onBacklightRaisedWhileDimmed = { [weak self] in
            guard let self else { return }
            self.keyboardDimOpacity = Self.adjustedKeyboardOpacity(self.keyboardDimOpacity, direction: -1)
            self.refreshKeyboardDim()
        }
        backlightFloor.start()
        setupBrightnessKeys()
        setupScheduleTimer()
        setupMenuTrackingObserver()
        setupWakeObservers()
        updateSchedule()
        updateNightDim()
    }

    // Consume media keys before macOS can lower the backlight to zero.
    private func setupBrightnessKeys() {
        guard brightnessKeyTap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(1) << 14 // NX_SYSDEFINED
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let state = Unmanaged<AppState>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = state.brightnessKeyTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                if state.isDimmed && state.displayWakeTrigger == .anyEvent { state.wakeFromDim() }
                guard let mediaEvent = NSEvent(cgEvent: event),
                      AppState.isBrightnessKey(subtype: Int(mediaEvent.subtype.rawValue), data: mediaEvent.data1)
                else { return Unmanaged.passUnretained(event) }
                state.handleBrightnessKey(mediaEvent)
                return nil // Suppress presses, repeats AND releases in the system handler.
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }
        brightnessKeyTap = tap
        brightnessKeySource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        brightnessKeysEnabled = true
        backlightFloor.interceptingKeys = true
    }

    func enableBrightnessKeyControl() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        setupBrightnessKeys()
    }

    static func isBrightnessKey(subtype: Int, data: Int) -> Bool {
        guard subtype == 8 else { return false }
        let key = (data >> 16) & 0xffff
        return key == 2 || key == 3
    }

    static func brightnessDirection(subtype: Int, data: Int) -> Int? {
        guard subtype == 8, (data >> 8) & 0xff == 0x0a else { return nil }
        switch (data >> 16) & 0xffff {
        case 3: return 1 // NX_KEYTYPE_BRIGHTNESS_DOWN
        case 2: return -1 // NX_KEYTYPE_BRIGHTNESS_UP
        default: return nil
        }
    }

    static func adjustedKeyboardOpacity(_ opacity: Double, direction: Int) -> Double {
        min(0.9, max(0, (opacity * 20 + Double(direction)).rounded() / 20))
    }

    private func handleBrightnessKey(_ event: NSEvent) {
        guard let direction = Self.brightnessDirection(subtype: Int(event.subtype.rawValue), data: event.data1) else { return }
        // Use the normal backlight range first when going down. When going up,
        // remove extra dimming completely before raising the hardware backlight.
        if keyboardDimOpacity == 0, backlightFloor.stepBacklight(direction: direction) { return }
        keyboardDimOpacity = Self.adjustedKeyboardOpacity(keyboardDimOpacity, direction: direction)
        refreshKeyboardDim()
    }

    func resetKeyboardDim() {
        keyboardDimOpacity = 0
        refreshKeyboardDim()
    }

    private func refreshKeyboardDim() {
        backlightFloor.hasExtraDimming = keyboardDimOpacity > 0
        let opacity = currentOverlayOpacity()
        if opacity > 0 { dimOverlay.show(opacity: opacity) }
        else { dimOverlay.hide() }
    }

    // MARK: - Public: Stay Awake

    func enableCaffeineIndefinitely() {
        clearAwakeDuration()
        enableCaffeine()
        manualOverride = caffeineActive
    }

    func enableCaffeine(for duration: StayAwakeDuration) {
        clearAwakeDuration()
        enableCaffeine()
        guard caffeineActive else { manualOverride = false; return }
        manualOverride = true
        activeDuration = duration
        let end = Date().addingTimeInterval(duration.seconds)
        awakeUntil = end
        awakeDurationTimer = scheduledTimer(interval: duration.seconds, repeats: false) { [weak self] _ in
            self?.disableCaffeine()
        }
        updateRemainingText()
    }

    func turnOff() {
        disableCaffeine()
    }

    var statusText: String {
        let base = caffeineActive ? "Active" : "Inactive"
        return scheduleEnabled ? "\(base) · Scheduled" : base
    }

    // MARK: - System sleep

    private func enableCaffeine() {
        guard !caffeineActive else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Awake: Preventing system sleep" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { return }
        systemAssertionID = id
        caffeineActive = true
        updateDisplayAssertion()
        if jiggleMouse { startJiggleTimer() }
    }

    private func disableCaffeine() {
        guard caffeineActive else { return }
        IOPMAssertionRelease(systemAssertionID)
        systemAssertionID = 0
        releaseDisplayAssertion()
        dimCheckTimer?.invalidate()
        dimCheckTimer = nil
        blackTimer?.invalidate(); blackTimer = nil
        removeWakeMonitor()
        stopJiggleTimer()
        hideDimOverlayUnlessNeeded()
        clearAwakeDuration()
        manualOverride = false
        caffeineActive = false
    }

    private func clearAwakeDuration() {
        awakeDurationTimer?.invalidate(); awakeDurationTimer = nil
        activeDuration = nil
        awakeUntil = nil
        countdown.text = nil
    }

    private func setupMenuTrackingObserver() {
        menuTrackingObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupBrightnessKeys()
            self?.updateRemainingText()
            self?.updateSchedule()
        }
    }

    private func setupWakeObservers() {
        systemWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reassertOnWake()
        }
        screenUnlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reassertOnWake()
        }
        screenLockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenLocked()
        }
    }

    private func handleScreenLocked() {
        backlightFloor.paused = true
        // At the lock screen, macOS ties display sleep to whether ANY idle-sleep
        // assertion is held, not just the display-specific one. Holding
        // systemAssertionID alone still keeps the display (and the Mac) awake, so
        // release both here; reassertOnWake() recreates them on unlock.
        guard caffeineActive else { return }
        if systemAssertionID != 0 { IOPMAssertionRelease(systemAssertionID) }
        systemAssertionID = 0
        releaseDisplayAssertion()
        dimCheckTimer?.invalidate(); dimCheckTimer = nil
        blackTimer?.invalidate(); blackTimer = nil
        removeWakeMonitor()
        stopJiggleTimer()
        hideDimOverlayUnlessNeeded()
    }

    private func reassertOnWake() {
        backlightFloor.paused = false
        guard caffeineActive else { return }
        if systemAssertionID != 0 { IOPMAssertionRelease(systemAssertionID) }
        systemAssertionID = 0
        releaseDisplayAssertion()
        caffeineActive = false
        enableCaffeine()
        if !caffeineActive {
            // Re-creation failed: fully reset so manualOverride/duration state
            // doesn't stay silently desynced and timers don't leak.
            dimCheckTimer?.invalidate(); dimCheckTimer = nil
            blackTimer?.invalidate(); blackTimer = nil
            removeWakeMonitor()
            stopJiggleTimer()
            hideDimOverlayUnlessNeeded()
            clearAwakeDuration()
            manualOverride = false
            updateSchedule()
        }
    }

    private func updateRemainingText() {
        guard let end = awakeUntil else { countdown.text = nil; return }
        let remaining = Int(end.timeIntervalSinceNow.rounded(.up))
        guard remaining > 0 else { countdown.text = nil; return }
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        let seconds = remaining % 60
        let time: String
        if hours > 0 {
            time = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            time = String(format: "%d:%02d", minutes, seconds)
        } else {
            time = String(seconds)
        }
        countdown.text = "\(time) remaining"
    }

    // MARK: - Display / overlay

    func previewDim() {
        previewDimActive = true
        dimOverlay.show(opacity: currentOverlayOpacity())
    }

    func stopPreviewDim() {
        previewDimActive = false
        guard !(caffeineActive && isDimmed) else { return }
        hideDimOverlayUnlessNeeded()
    }

    private func updateDisplayAssertion() {
        dimCheckTimer?.invalidate()
        dimCheckTimer = nil
        blackTimer?.invalidate(); blackTimer = nil
        removeWakeMonitor()
        hideDimOverlayUnlessNeeded()
        guard caffeineActive else { return }
        isDimmed = false

        holdDisplayAssertion()

        if displayDimDelay != .never {
            applyDisplayPolicy()
            dimCheckTimer = scheduledTimer(interval: 10, repeats: true) { [weak self] _ in
                self?.applyDisplayPolicy()
            }
        }
    }

    static func activityOccurredSinceDim(idleSeconds: TimeInterval, elapsedSinceDim: TimeInterval) -> Bool {
        idleSeconds.isFinite && idleSeconds >= 0 && idleSeconds < elapsedSinceDim
    }

    private static func idleSeconds(for trigger: DisplayWakeTrigger = .anyEvent) -> TimeInterval {
        trigger.activityEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min()!
    }

    private let idleDimFadeDuration: TimeInterval = 5

    private func applyDisplayPolicy() {
        // Once dimmed, only the chosen wake trigger may dismiss the overlay.
        guard !isDimmed else { return }
        let idle = Self.idleSeconds()

        if idle >= displayDimDelay.seconds {
            isDimmed = true
            dimOverlay.show(opacity: currentOverlayOpacity(), duration: idleDimFadeDuration)
            if displayBlackDelay != .never {
                blackTimer = scheduledTimer(interval: displayBlackDelay.seconds, repeats: false) { [weak self] _ in
                    guard let self, self.isDimmed else { return }
                    self.dimOverlay.show(opacity: 1.0, duration: self.idleDimFadeDuration)
                }
            }
            installWakeMonitor()
        } else {
            removeWakeMonitor()
            hideDimOverlayUnlessNeeded()
            holdDisplayAssertion()
        }
    }

    private func installWakeMonitor() {
        removeWakeMonitor()
        wakeMonitor = NSEvent.addGlobalMonitorForEvents(matching: displayWakeTrigger.eventMask) { [weak self] _ in
            self?.wakeFromDim()
        }
        localWakeMonitor = NSEvent.addLocalMonitorForEvents(matching: displayWakeTrigger.eventMask) { [weak self] event in
            self?.wakeFromDim()
            return event
        }
        // Poll the same event types to cover activity within Awake and events
        // unavailable to the global monitor, including keyboard input.
        let monitoringStarted = ProcessInfo.processInfo.systemUptime
        wakeCheckTimer = scheduledTimer(interval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - monitoringStarted
            if Self.activityOccurredSinceDim(idleSeconds: Self.idleSeconds(for: self.displayWakeTrigger), elapsedSinceDim: elapsed) {
                self.wakeFromDim()
            }
        }
    }

    private func wakeFromDim() {
        removeWakeMonitor()
        blackTimer?.invalidate(); blackTimer = nil
        isDimmed = false
        hideDimOverlayUnlessNeeded()
        holdDisplayAssertion()
    }

    private func removeWakeMonitor() {
        if let m = wakeMonitor { NSEvent.removeMonitor(m); wakeMonitor = nil }
        if let m = localWakeMonitor { NSEvent.removeMonitor(m); localWakeMonitor = nil }
        wakeCheckTimer?.invalidate(); wakeCheckTimer = nil
    }

    private func holdDisplayAssertion() {
        guard displayAssertionID == 0 else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Awake: Keeping display on" as CFString,
            &id
        )
        if result == kIOReturnSuccess { displayAssertionID = id }
    }

    private func releaseDisplayAssertion() {
        guard displayAssertionID != 0 else { return }
        IOPMAssertionRelease(displayAssertionID)
        displayAssertionID = 0
    }

    // MARK: - Schedule

    private func setupScheduleTimer() {
        scheduleTimer = scheduledTimer(interval: 60, repeats: true) { [weak self] _ in
            self?.setupBrightnessKeys()
            self?.updateSchedule()
            self?.updateNightDim()
        }
    }

    func setScheduleEnabled(_ enabled: Bool) {
        scheduleEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "scheduleEnabled")
        if enabled {
            updateSchedule()
        } else if !manualOverride {
            disableCaffeine()
        }
    }

    func toggleDay(_ day: Int) {
        var days = activeDays
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
        activeDays = days
    }

    func updateSchedule() {
        scheduleActiveNow = isWithinSchedule()
        guard scheduleEnabled, !manualOverride else { return }
        if scheduleActiveNow { enableCaffeine() } else { disableCaffeine() }
    }

    private func isWithinSchedule() -> Bool {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let hour    = cal.component(.hour, from: now)
        return Self.isWithinSchedule(weekday: weekday, hour: hour, activeDays: activeDays, startHour: startHour, endHour: endHour)
    }

    static func isWithinSchedule(weekday: Int, hour: Int, activeDays: Set<Int>, startHour: Int, endHour: Int) -> Bool {
        guard startHour < endHour else { return false }
        return activeDays.contains(weekday) && (startHour..<endHour).contains(hour)
    }

    // MARK: - Night Dim

    private let nightDimFadeDuration: TimeInterval = 3

    func updateNightDim() {
        guard nightDimEnabled else {
            guard nightDimActive else { return }
            nightDimActive = false
            hideDimOverlayUnlessNeeded(duration: nightDimFadeDuration)
            return
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let within = Self.isWithinHourWindow(hour: hour, startHour: nightDimStartHour, endHour: nightDimEndHour)
        if within {
            guard !nightDimActive else { return }
            nightDimActive = true
            dimOverlay.show(opacity: currentOverlayOpacity(), duration: nightDimFadeDuration)
        } else if nightDimActive {
            nightDimActive = false
            hideDimOverlayUnlessNeeded(duration: nightDimFadeDuration)
        }
    }

    /// Unlike the daytime schedule, a night window is expected to wrap past midnight (e.g. 23 -> 6).
    static func isWithinHourWindow(hour: Int, startHour: Int, endHour: Int) -> Bool {
        guard startHour != endHour else { return false }
        if startHour < endHour {
            return (startHour..<endHour).contains(hour)
        }
        return hour >= startHour || hour < endHour
    }

    /// The strongest opacity requested among whichever dim sources are currently active.
    private func currentOverlayOpacity() -> Double {
        var opacity = 0.0
        if previewDimActive { opacity = max(opacity, dimOpacity) }
        if isDimmed { opacity = max(opacity, dimOpacity) }
        if nightDimActive { opacity = max(opacity, nightDimOpacity) }
        return 1 - (1 - opacity) * (1 - keyboardDimOpacity)
    }

    private func hideDimOverlayUnlessNeeded(duration: TimeInterval = 0.1) {
        if previewDimActive || nightDimActive || keyboardDimOpacity > 0 {
            dimOverlay.show(opacity: currentOverlayOpacity(), duration: duration)
        } else {
            dimOverlay.hide(duration: duration)
        }
    }

    // MARK: - Mouse jiggle

    private func startJiggleTimer() {
        guard jiggleTimer == nil else { return }
        jiggleTimer = scheduledTimer(interval: 60, repeats: true) { [weak self] _ in
            self?.performJiggle()
        }
    }

    private func stopJiggleTimer() {
        jiggleTimer?.invalidate()
        jiggleTimer = nil
    }

    private static let bigJiggleDistance: CGFloat = 500
    private static let shiftKeyCode: CGKeyCode = 56  // Left Shift: does nothing on its own, but counts as keyboard activity

    /// Moves `distance` px horizontally, toward whichever side of `bounds` has more room,
    /// clamped so the target stays on screen.
    static func bigJiggleTarget(from pos: CGPoint, in bounds: CGRect, distance: CGFloat = bigJiggleDistance) -> CGPoint {
        let goRight = bounds.maxX - pos.x >= pos.x - bounds.minX
        let x = goRight ? min(pos.x + distance, bounds.maxX - 1) : max(pos.x - distance, bounds.minX)
        return CGPoint(x: x, y: pos.y)
    }

    private func performJiggle() {
        let nsLoc = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 800
        let pos = CGPoint(x: nsLoc.x, y: screenHeight - nsLoc.y)
        let nudge: CGPoint
        if jiggleBig {
            var display = CGMainDisplayID()
            var count: UInt32 = 0
            CGGetDisplaysWithPoint(pos, 1, &display, &count)
            nudge = Self.bigJiggleTarget(from: pos, in: CGDisplayBounds(display))
            postSafeKeyPress()
        } else {
            nudge = CGPoint(x: pos.x + 3, y: pos.y)
        }
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: nudge, mouseButton: .left)?
            .post(tap: .cgSessionEventTap)
        // Without a real gap the WindowServer never renders the nudged position,
        // so the move-and-revert collapses into a no-op that resets nothing visibly.
        DispatchQueue.main.asyncAfter(deadline: .now() + (jiggleBig ? 0.25 : 0.05)) {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pos, mouseButton: .left)?
                .post(tap: .cgSessionEventTap)
        }
    }

    private func postSafeKeyPress() {
        // Modifier presses arrive as flagsChanged events, not keyDown/keyUp.
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: Self.shiftKeyCode, keyDown: keyDown) else { continue }
            event.type = .flagsChanged
            event.flags = keyDown ? .maskShift : []
            event.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Shared helpers

    private func scheduledTimer(interval: TimeInterval, repeats: Bool, _ block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    deinit {
        if let source = brightnessKeySource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap = brightnessKeyTap { CFMachPortInvalidate(tap) }
        scheduleTimer?.invalidate()
        dimCheckTimer?.invalidate()
        blackTimer?.invalidate()
        wakeCheckTimer?.invalidate()
        jiggleTimer?.invalidate()
        awakeDurationTimer?.invalidate()
        removeWakeMonitor()
        if let observer = menuTrackingObserver { NotificationCenter.default.removeObserver(observer) }
        if let observer = systemWakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        if let observer = screenUnlockObserver { DistributedNotificationCenter.default().removeObserver(observer) }
        if let observer = screenLockObserver { DistributedNotificationCenter.default().removeObserver(observer) }
        dimOverlay.hide()
        if systemAssertionID != 0 { IOPMAssertionRelease(systemAssertionID) }
        releaseDisplayAssertion()
    }
}
