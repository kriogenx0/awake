import XCTest
@testable import Awake

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
