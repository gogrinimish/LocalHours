#if canImport(XCTest)
import XCTest
#if canImport(LocalHours)
@testable import LocalHours   // iOS app target name
#elseif canImport(Local_Hours)
@testable import Local_Hours // macOS app module name
#endif

final class TimeTrackingTripleTrackTests: XCTestCase {
    // MARK: - Mocks
    final class InMemoryStorage: StorageServiceProtocol {
        var config: AppConfiguration = AppConfiguration()
        var entries: [TimeEntry] = []
        var timesheets: [Timesheet] = []
        var folderURL: URL? = URL(fileURLWithPath: "/tmp")

        func loadConfiguration() throws -> AppConfiguration { config }
        func saveConfiguration(_ config: AppConfiguration) throws { self.config = config }
        func loadTimeEntries() throws -> [TimeEntry] { entries }
        func saveTimeEntries(_ entries: [TimeEntry]) throws { self.entries = entries }
        func loadTimesheets() throws -> [Timesheet] { timesheets }
        func saveTimesheet(_ timesheet: Timesheet) throws { timesheets.append(timesheet) }
        func timesheetFileExistsForPeriod(periodStart: Date, periodEnd: Date, timeZone: TimeZone) -> Bool { false }
        func saveTimesheetForPeriod(_ timesheet: Timesheet, timeZone: TimeZone) throws { timesheets.append(timesheet) }
        func getStorageFolderURL() -> URL? { folderURL }
        func isValidStorageFolder(_ path: String) -> Bool { true }
        func setStorageFolder(_ path: String) throws { folderURL = URL(fileURLWithPath: path) }
        func setStorageFolder(url: URL) throws { folderURL = url }
    }

    final class NoopNotifications: NotificationServiceProtocol {
        func requestAuthorization() async -> Bool { true }
        func scheduleTimesheetReminder(at time: DateComponents, days: [Int]) async {}
        func cancelAllNotifications() {}
    }

    final class NoopEmail: EmailServiceProtocol {
        func sendTimesheet(_ timesheet: Timesheet, config: AppConfiguration) -> Bool { true }
        func canSendEmail() -> Bool { true }
        func exportAsCSV(_ timesheet: Timesheet) -> String { "" }
    }

    private func makeViewModel(tz: TimeZone) -> TimeTrackingViewModel {
        let storage = InMemoryStorage()
        var cfg = AppConfiguration()
        cfg.timezoneIdentifier = tz.identifier
        storage.config = cfg
        return TimeTrackingViewModel(
            storageService: storage,
            notificationService: NoopNotifications(),
            emailService: NoopEmail()
        )
    }

    // MARK: - Tests

    func testStartCapturesTripleTrack() throws {
        let tz = TimeZone(identifier: "America/New_York")!
        let vm = makeViewModel(tz: tz)

        vm.startClock()
        guard let entry = vm.currentEntry else { return XCTFail("No current entry") }

        XCTAssertGreaterThan(entry.startTime.timeIntervalSince1970, 0)
        let clockIn = try XCTUnwrap(entry.clockIn)
        XCTAssertEqual(clockIn.timezone, tz.identifier)
        XCTAssertTrue(clockIn.timestamp.contains("-") || clockIn.timestamp.contains("+"))
    }

    func testStopCapturesTripleTrackAndDuration() throws {
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        let vm = makeViewModel(tz: tz)

        vm.startClock()
        Thread.sleep(forTimeInterval: 0.5)
        vm.stopClock(description: "Test")

        let last = try XCTUnwrap(vm.allEntries.first)
        XCTAssertNotNil(last.endTime)
        let clockOut = try XCTUnwrap(last.clockOut)
        XCTAssertEqual(clockOut.timezone, tz.identifier)
        XCTAssertGreaterThan(last.duration, 0)
    }

    func testBackfillLegacy() throws {
        let tz = TimeZone(identifier: "Europe/London")!
        let storage = InMemoryStorage()
        var cfg = AppConfiguration()
        cfg.timezoneIdentifier = tz.identifier
        storage.config = cfg

        let start = Date().addingTimeInterval(-3600)
        let end = Date()
        storage.entries = [TimeEntry(startTime: start, endTime: end, description: "Legacy")]

        let vm = TimeTrackingViewModel(
            storageService: storage,
            notificationService: NoopNotifications(),
            emailService: NoopEmail()
        )

        let e = try XCTUnwrap(vm.allEntries.first)
        XCTAssertNotNil(e.clockIn)
        XCTAssertNotNil(e.clockOut)
        XCTAssertEqual(e.clockIn?.timezone, tz.identifier)
        XCTAssertEqual(e.clockOut?.timezone, tz.identifier)
    }

    func testCrossTimezone() throws {
        let ny = TimeZone(identifier: "America/New_York")!
        let la = TimeZone(identifier: "America/Los_Angeles")!

        let storage = InMemoryStorage()
        var cfg = AppConfiguration()
        cfg.timezoneIdentifier = ny.identifier
        storage.config = cfg
        let vm = TimeTrackingViewModel(
            storageService: storage,
            notificationService: NoopNotifications(),
            emailService: NoopEmail()
        )

        vm.startClock()
        let cur = try XCTUnwrap(vm.currentEntry)
        let clockIn = try XCTUnwrap(cur.clockIn)
        XCTAssertEqual(clockIn.timezone, ny.identifier)

        var newCfg = vm.configuration
        newCfg.timezoneIdentifier = la.identifier
        vm.updateConfiguration(newCfg)
        Thread.sleep(forTimeInterval: 0.25)
        vm.stopClock(description: "Travel shift")

        let saved = try XCTUnwrap(vm.allEntries.first)
        let out = try XCTUnwrap(saved.clockOut)
        XCTAssertEqual(out.timezone, la.identifier)
    }
}
#endif
