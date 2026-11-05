import XCTest
import AppKit
@testable import Awake

final class DisplayWakeTriggerTests: XCTestCase {
    func testClickOnlyAcceptsMouseButtonsInMonitorAndPolling() {
        let trigger = DisplayWakeTrigger.click
        XCTAssertEqual(trigger.eventMask, [.leftMouseDown, .rightMouseDown, .otherMouseDown])
        XCTAssertEqual(trigger.activityEventTypes, [.leftMouseDown, .rightMouseDown, .otherMouseDown])
    }

    func testAnyActivityIncludesMotionTypingAndScrollingInMonitorAndPolling() {
        let trigger = DisplayWakeTrigger.anyEvent
        XCTAssertTrue(trigger.eventMask.contains([.mouseMoved, .keyDown, .flagsChanged, .scrollWheel]))
        for event: CGEventType in [.mouseMoved, .keyDown, .flagsChanged, .scrollWheel] {
            XCTAssertTrue(trigger.activityEventTypes.contains(event))
            XCTAssertFalse(DisplayWakeTrigger.click.activityEventTypes.contains(event))
        }
    }
}

final class DisplayDelayTests: XCTestCase {
    func testDimDelaySecondsConversion() {
        XCTAssertEqual(DisplayDimDelay.never.seconds, 0)
        XCTAssertEqual(DisplayDimDelay.oneMinute.seconds, 60)
        XCTAssertEqual(DisplayDimDelay.oneHour.seconds, 3600)
    }

    func testBlackDelayLabels() {
        XCTAssertEqual(DisplayBlackDelay.never.label, "Never")
        XCTAssertEqual(DisplayBlackDelay.fiveMinutes.label, "5 minutes later")
    }
}

final class ScheduleWindowTests: XCTestCase {
    private let weekdays = Set(2...6) // Mon-Fri

    func testWithinActiveDayAndHour() {
        XCTAssertTrue(AppState.isWithinSchedule(weekday: 3, hour: 10, activeDays: weekdays, startHour: 9, endHour: 18))
    }

    func testBeforeStartHour() {
        XCTAssertFalse(AppState.isWithinSchedule(weekday: 3, hour: 8, activeDays: weekdays, startHour: 9, endHour: 18))
    }

    func testEndHourIsExclusive() {
        XCTAssertFalse(AppState.isWithinSchedule(weekday: 3, hour: 18, activeDays: weekdays, startHour: 9, endHour: 18))
    }

    func testInactiveDay() {
        XCTAssertFalse(AppState.isWithinSchedule(weekday: 1, hour: 10, activeDays: weekdays, startHour: 9, endHour: 18))
    }

    func testEndHourBeforeStartHourDoesNotCrash() {
        XCTAssertFalse(AppState.isWithinSchedule(weekday: 3, hour: 23, activeDays: weekdays, startHour: 22, endHour: 6))
    }

    func testEndHourEqualToStartHourIsNeverActive() {
        XCTAssertFalse(AppState.isWithinSchedule(weekday: 3, hour: 9, activeDays: weekdays, startHour: 9, endHour: 9))
    }
}

final class NightDimWindowTests: XCTestCase {
    func testWrappedWindowAtStartHour() {
        XCTAssertTrue(AppState.isWithinHourWindow(hour: 23, startHour: 23, endHour: 6))
    }

    func testWrappedWindowAfterMidnight() {
        XCTAssertTrue(AppState.isWithinHourWindow(hour: 2, startHour: 23, endHour: 6))
    }

    func testWrappedWindowEndHourIsExclusive() {
        XCTAssertFalse(AppState.isWithinHourWindow(hour: 6, startHour: 23, endHour: 6))
    }

    func testWrappedWindowOutsideRange() {
        XCTAssertFalse(AppState.isWithinHourWindow(hour: 12, startHour: 23, endHour: 6))
    }

    func testNonWrappedWindowStillWorks() {
        XCTAssertTrue(AppState.isWithinHourWindow(hour: 10, startHour: 9, endHour: 18))
        XCTAssertFalse(AppState.isWithinHourWindow(hour: 20, startHour: 9, endHour: 18))
    }

    func testEqualStartAndEndIsAlwaysFalse() {
        XCTAssertFalse(AppState.isWithinHourWindow(hour: 5, startHour: 9, endHour: 9))
    }

    func testBigJiggleGoesRightWhenMoreRoomOnRight() {
        let t = AppState.bigJiggleTarget(from: CGPoint(x: 200, y: 300), in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(t, CGPoint(x: 700, y: 300))
    }

    func testBigJiggleGoesLeftNearRightEdge() {
        let t = AppState.bigJiggleTarget(from: CGPoint(x: 1800, y: 300), in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        XCTAssertEqual(t, CGPoint(x: 1300, y: 300))
    }

    func testBigJiggleClampsToNarrowScreen() {
        let t = AppState.bigJiggleTarget(from: CGPoint(x: 100, y: 50), in: CGRect(x: 0, y: 0, width: 400, height: 300))
        XCTAssertEqual(t, CGPoint(x: 399, y: 50))
    }
}

final class BrightnessKeyTests: XCTestCase {
    func testBrightnessPressesAndRepeats() {
        XCTAssertEqual(AppState.brightnessDirection(subtype: 8, data: (3 << 16) | 0x0a00), 1)
        XCTAssertEqual(AppState.brightnessDirection(subtype: 8, data: (2 << 16) | 0x0a01), -1)
    }

    func testBrightnessReleasesAreConsumedButOtherMediaKeysPassThrough() {
        XCTAssertTrue(AppState.isBrightnessKey(subtype: 8, data: (3 << 16) | 0x0b00))
        XCTAssertTrue(AppState.isBrightnessKey(subtype: 8, data: (2 << 16) | 0x0a00))
        XCTAssertFalse(AppState.isBrightnessKey(subtype: 8, data: 0x0a00))
        XCTAssertFalse(AppState.isBrightnessKey(subtype: 7, data: (3 << 16) | 0x0a00))
    }

    func testReleaseAndUnrelatedMediaKeysAreIgnored() {
        XCTAssertNil(AppState.brightnessDirection(subtype: 8, data: (3 << 16) | 0x0b00))
        XCTAssertNil(AppState.brightnessDirection(subtype: 8, data: 0x0a00))
        XCTAssertNil(AppState.brightnessDirection(subtype: 7, data: (3 << 16) | 0x0a00))
    }

    func testDimmingIsBoundedAndReversible() {
        var opacity = 0.0
        for _ in 0..<30 { opacity = AppState.adjustedKeyboardOpacity(opacity, direction: 1) }
        XCTAssertEqual(opacity, 0.9)
        for _ in 0..<18 { opacity = AppState.adjustedKeyboardOpacity(opacity, direction: -1) }
        XCTAssertEqual(opacity, 0)
        XCTAssertEqual(AppState.adjustedKeyboardOpacity(0, direction: -1), 0)
    }
}

final class BacklightFloorTests: XCTestCase {
    func testBrightnessUpRemovesOverlayBeforeRaisingBacklight() {
        XCTAssertTrue(BacklightFloorController.shouldUndoHardwareIncrease(brightness: 0.125, hasExtraDimming: true, interceptingKeys: false))
        XCTAssertFalse(BacklightFloorController.shouldUndoHardwareIncrease(brightness: 0.125, hasExtraDimming: false, interceptingKeys: false))
        XCTAssertFalse(BacklightFloorController.shouldUndoHardwareIncrease(brightness: 0.0625, hasExtraDimming: true, interceptingKeys: false))
        XCTAssertFalse(BacklightFloorController.shouldUndoHardwareIncrease(brightness: 0.125, hasExtraDimming: true, interceptingKeys: true))
    }

    func testCorrectsOnlyValidBrightnessBelowFloor() {
        XCTAssertTrue(BacklightFloorController.needsCorrection(0))
        XCTAssertTrue(BacklightFloorController.needsCorrection(0.01))
        XCTAssertFalse(BacklightFloorController.needsCorrection(0.0625))
        XCTAssertFalse(BacklightFloorController.needsCorrection(0.5))
        XCTAssertFalse(BacklightFloorController.needsCorrection(-1))
        XCTAssertFalse(BacklightFloorController.needsCorrection(.nan))
    }
}

final class WakeActivityTests: XCTestCase {
    func testMouseMovementKeyboardScrollAndMediaKeysWakeDisplay() {
        let events: [NSEvent.EventTypeMask] = [.mouseMoved, .keyDown, .keyUp, .flagsChanged, .scrollWheel, .systemDefined, .tabletPoint, .leftMouseDown, .swipe]
        for event in events { XCTAssertTrue(DisplayWakeTrigger.anyEvent.eventMask.contains(event)) }
    }

    func testClickOnlyModeDoesNotWakeOnMovementOrKeyboard() {
        XCTAssertTrue(DisplayWakeTrigger.click.eventMask.contains(.leftMouseDown))
        XCTAssertFalse(DisplayWakeTrigger.click.eventMask.contains(.mouseMoved))
        XCTAssertFalse(DisplayWakeTrigger.click.eventMask.contains(.keyDown))
        XCTAssertFalse(DisplayWakeTrigger.click.eventMask.contains(.systemDefined))
        XCTAssertEqual(DisplayWakeTrigger.click.activityEventTypes, [.leftMouseDown, .rightMouseDown, .otherMouseDown])
    }

    func testInputIsDetectedEvenAfterDelayedTimer() {
        XCTAssertTrue(AppState.activityOccurredSinceDim(idleSeconds: 0.6, elapsedSinceDim: 2))
        XCTAssertFalse(AppState.activityOccurredSinceDim(idleSeconds: 62, elapsedSinceDim: 2))
        XCTAssertFalse(AppState.activityOccurredSinceDim(idleSeconds: .infinity, elapsedSinceDim: 2))
    }
}
