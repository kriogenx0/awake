import Foundation
import IOKit.pwr_mgt
import ServiceManagement
import AppKit
import CoreGraphics

enum DisplayDimDelay: Int, CaseIterable {
    case never = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case twentyMinutes = 20
    case thirtyMinutes = 30
    case oneHour = 60

    var label: String {
        switch self {
        case .never:          return "Never"
        case .fiveMinutes:    return "5 minutes"
        case .tenMinutes:     return "10 minutes"
        case .twentyMinutes:  return "20 minutes"
        case .thirtyMinutes:  return "30 minutes"
        case .oneHour:        return "1 hour"
        }
    }

    var seconds: TimeInterval { TimeInterval(rawValue) * 60 }
}

enum DisplayInactiveAction: Int, CaseIterable {
    case dim = 0
    case turnOff = 1

    var label: String {
        switch self {
        case .dim:     return "Dim the display"
        case .turnOff: return "Turn off the display"
        }
    }
}

let defaultDimOpacity: Double = 0.8

class AppState: ObservableObject {
    @Published private(set) var caffeineActive = false
    @Published private(set) var scheduleEnabled: Bool

    @Published var startHour: Int {
        didSet { UserDefaults.standard.set(startHour, forKey: "startHour"); updateSchedule() }
    }
    @Published var endHour: Int {
        didSet { UserDefaults.standard.set(endHour, forKey: "endHour"); updateSchedule() }
    }
    @Published var activeDays: Set<Int> {
        didSet { UserDefaults.standard.set(Array(activeDays), forKey: "activeDays"); updateSchedule() }
    }
    @Published var displayDimDelay: DisplayDimDelay {
        didSet {
            UserDefaults.standard.set(displayDimDelay.rawValue, forKey: "displayDimDelay")
            updateDisplayAssertion()
        }
    }
    @Published var displayInactiveAction: DisplayInactiveAction {
        didSet {
            UserDefaults.standard.set(displayInactiveAction.rawValue, forKey: "displayInactiveAction")
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
    @Published var preventScreenLock: Bool {
        didSet {
            UserDefaults.standard.set(preventScreenLock, forKey: "preventScreenLock")
            if preventScreenLock { enableScreenLockPrevention() } else { disableScreenLockPrevention() }
        }
    }
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
    private var jiggleTimer: Timer?
    private var displayDidTrigger = false
    private let dimOverlay = DimOverlayController()

    init() {
        let d = UserDefaults.standard
        scheduleEnabled       = d.object(forKey: "scheduleEnabled")  as? Bool ?? true
        startHour             = d.object(forKey: "startHour")        as? Int  ?? 9
        endHour               = d.object(forKey: "endHour")          as? Int  ?? 18
        activeDays            = Set(d.array(forKey: "activeDays")    as? [Int] ?? [2, 3, 4, 5, 6])
        displayDimDelay       = DisplayDimDelay(rawValue: d.object(forKey: "displayDimDelay") as? Int ?? 0) ?? .never
        displayInactiveAction = DisplayInactiveAction(rawValue: d.object(forKey: "displayInactiveAction") as? Int ?? 0) ?? .dim
        dimOpacity            = d.object(forKey: "dimOpacity")       as? Double ?? defaultDimOpacity
        preventScreenLock     = d.object(forKey: "preventScreenLock") as? Bool ?? false

        let service = SMAppService.mainApp
        if service.status == .notRegistered { try? service.register() }
        launchAtLogin = service.status == .enabled

        jiggleMouse = d.object(forKey: "jiggleMouse") as? Bool ?? false
        setupScheduleTimer()
        if jiggleMouse { startJiggleTimer() }
        updateSchedule()
    }

    // MARK: - Public

    func toggleManual() {
        if caffeineActive { disableCaffeine() } else { enableCaffeine() }
    }

    func setScheduleEnabled(_ enabled: Bool) {
        scheduleEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "scheduleEnabled")
        if enabled { updateSchedule() } else { disableCaffeine() }
    }

    func toggleDay(_ day: Int) {
        var days = activeDays
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
        activeDays = days
    }

    func previewDim() {
        previewDimActive = true
        dimOverlay.show(opacity: dimOpacity)
    }

    func stopPreviewDim() {
        previewDimActive = false
        guard !(caffeineActive && displayDidTrigger && displayInactiveAction == .dim) else { return }
        dimOverlay.hide()
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
        dimOverlay.hide()
        caffeineActive = false
    }

    // MARK: - Display / overlay

    private func updateDisplayAssertion() {
        dimCheckTimer?.invalidate()
        dimCheckTimer = nil
        if !previewDimActive { dimOverlay.hide() }
        guard caffeineActive else { return }
        displayDidTrigger = false

        holdDisplayAssertion()

        if displayDimDelay != .never {
            applyDisplayPolicy()
            let t = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                self?.applyDisplayPolicy()
            }
            RunLoop.main.add(t, forMode: .common)
            dimCheckTimer = t
        }
    }

    private func applyDisplayPolicy() {
        let idle = [CGEventType.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0

        if idle >= displayDimDelay.seconds {
            if !displayDidTrigger {
                displayDidTrigger = true
                releaseDisplayAssertion()
                switch displayInactiveAction {
                case .dim:     dimOverlay.show(opacity: dimOpacity)
                case .turnOff: sleepDisplay()
                }
            }
        } else {
            displayDidTrigger = false
            if !previewDimActive { dimOverlay.hide() }
            holdDisplayAssertion()
        }
    }

    private func sleepDisplay() {
        let r = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IODisplayWrangler")
        if r != MACH_PORT_NULL {
            IORegistryEntrySetCFProperty(r, "IORequestIdle" as CFString, true as CFTypeRef)
            IOObjectRelease(r)
        }
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
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateSchedule()
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
    }

    func updateSchedule() {
        guard scheduleEnabled else { return }
        if isWithinSchedule() { enableCaffeine() } else { disableCaffeine() }
    }

    private func isWithinSchedule() -> Bool {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let hour    = cal.component(.hour, from: now)
        return activeDays.contains(weekday) && (startHour..<endHour).contains(hour)
    }

    // MARK: - Mouse jiggle

    private func startJiggleTimer() {
        guard jiggleTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performJiggle()
        }
        RunLoop.main.add(t, forMode: .common)
        jiggleTimer = t
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

    deinit {
        scheduleTimer?.invalidate()
        dimCheckTimer?.invalidate()
        jiggleTimer?.invalidate()
        dimOverlay.hide()
        if systemAssertionID != 0 { IOPMAssertionRelease(systemAssertionID) }
        releaseDisplayAssertion()
    }
}
