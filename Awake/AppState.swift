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
    @Published var dimOpacity: Double {
        didSet {
            UserDefaults.standard.set(dimOpacity, forKey: "dimOpacity")
            if dimOverlay.isVisible { dimOverlay.show(opacity: dimOpacity) }
        }
    }
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
            if jiggleMouse { startJiggleTimer() } else { stopJiggleTimer() }
        }
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
    private var displayDidTrigger = false
    private var wakeMonitor: Any?
    private var menuTrackingObserver: Any?
    private var systemWakeObserver: Any?
    private var screenUnlockObserver: Any?
    private let dimOverlay = DimOverlayController()

    init() {
        let d = UserDefaults.standard
        scheduleEnabled       = d.object(forKey: "scheduleEnabled")  as? Bool ?? true
        startHour             = d.object(forKey: "startHour")        as? Int  ?? 9
        endHour               = d.object(forKey: "endHour")          as? Int  ?? 18
        activeDays            = Set(d.array(forKey: "activeDays")    as? [Int] ?? [2, 3, 4, 5, 6])
        displayDimDelay       = DisplayDimDelay(rawValue: d.object(forKey: "displayDimDelay") as? Int ?? 0) ?? .never
        displayBlackDelay     = DisplayBlackDelay(rawValue: d.object(forKey: "displayBlackDelay") as? Int ?? 0) ?? .never
        dimOpacity            = d.object(forKey: "dimOpacity")       as? Double ?? defaultDimOpacity

        let service = SMAppService.mainApp
        if service.status == .notRegistered { try? service.register() }
        launchAtLogin = service.status == .enabled

        jiggleMouse = d.object(forKey: "jiggleMouse") as? Bool ?? false
        setupScheduleTimer()
        setupMenuTrackingObserver()
        setupWakeObservers()
        if jiggleMouse { startJiggleTimer() }
        updateSchedule()
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
        dimOverlay.hide()
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
    }

    private func reassertOnWake() {
        guard caffeineActive else { return }
        IOPMAssertionRelease(systemAssertionID)
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
            dimOverlay.hide()
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
        dimOverlay.show(opacity: dimOpacity)
    }

    func stopPreviewDim() {
        previewDimActive = false
        guard !(caffeineActive && displayDidTrigger) else { return }
        dimOverlay.hide()
    }

    private func updateDisplayAssertion() {
        dimCheckTimer?.invalidate()
        dimCheckTimer = nil
        blackTimer?.invalidate(); blackTimer = nil
        removeWakeMonitor()
        if !previewDimActive { dimOverlay.hide() }
        guard caffeineActive else { return }
        displayDidTrigger = false

        holdDisplayAssertion()

        if displayDimDelay != .never {
            applyDisplayPolicy()
            dimCheckTimer = scheduledTimer(interval: 10, repeats: true) { [weak self] _ in
                self?.applyDisplayPolicy()
            }
        }
    }

    private static let activityEventTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .keyDown, .flagsChanged, .scrollWheel, .tabletPointer, .tabletProximity
    ]

    private static let wakeEventMask: NSEvent.EventTypeMask = [
        .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .keyDown, .flagsChanged, .scrollWheel,
        .magnify, .swipe, .rotate, .smartMagnify, .gesture
    ]

    private static func idleSeconds() -> TimeInterval {
        activityEventTypes
            .map { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) }
            .min()!
    }

    private func applyDisplayPolicy() {
        let idle = Self.idleSeconds()

        if idle >= displayDimDelay.seconds {
            if !displayDidTrigger {
                displayDidTrigger = true
                dimOverlay.show(opacity: dimOpacity)
                if displayBlackDelay != .never {
                    blackTimer = scheduledTimer(interval: displayBlackDelay.seconds, repeats: false) { [weak self] _ in
                        guard let self, self.displayDidTrigger else { return }
                        self.dimOverlay.show(opacity: 1.0)
                    }
                }
                wakeMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.wakeEventMask) { [weak self] _ in
                    self?.wakeFromDim()
                }
                wakeCheckTimer = scheduledTimer(interval: 0.25, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    if Self.idleSeconds() < 0.25 {
                        self.wakeFromDim()
                    }
                }
            }
        } else {
            displayDidTrigger = false
            removeWakeMonitor()
            if !previewDimActive { dimOverlay.hide() }
            holdDisplayAssertion()
        }
    }

    private func wakeFromDim() {
        removeWakeMonitor()
        blackTimer?.invalidate(); blackTimer = nil
        displayDidTrigger = false
        if !previewDimActive { dimOverlay.hide() }
        holdDisplayAssertion()
    }

    private func removeWakeMonitor() {
        if let m = wakeMonitor { NSEvent.removeMonitor(m); wakeMonitor = nil }
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
            self?.updateSchedule()
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

    private func performJiggle() {
        let nsLoc = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 800
        let pos = CGPoint(x: nsLoc.x, y: screenHeight - nsLoc.y)
        let nudge = CGPoint(x: pos.x + 1, y: pos.y)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: nudge, mouseButton: .left)?
            .post(tap: .cgSessionEventTap)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: pos, mouseButton: .left)?
            .post(tap: .cgSessionEventTap)
    }

    // MARK: - Shared helpers

    private func scheduledTimer(interval: TimeInterval, repeats: Bool, _ block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    deinit {
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
        dimOverlay.hide()
        if systemAssertionID != 0 { IOPMAssertionRelease(systemAssertionID) }
        releaseDisplayAssertion()
    }
}
