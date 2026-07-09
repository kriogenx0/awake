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
}
