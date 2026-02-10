import XCTest
@testable import LocalHoursCore

/// Tests for the in-progress timer sync scenario: start timer on one device (e.g. macOS),
/// open app on another (e.g. iOS) — the second device should show the active timer
/// with correct elapsed time and a forward-moving counter.
final class InProgressTimerSyncTests: XCTestCase {

    var tempDir: URL!
    var storage: StorageService!
    fileprivate var mockNotification: MockNotificationService!
    fileprivate var mockEmail: MockEmailService!

    /// Mocks to avoid UNUserNotificationCenter / app bundle in xctest.
    private func makeViewModel(storageService: StorageServiceProtocol? = nil) -> TimeTrackingViewModel {
        TimeTrackingViewModel(
            storageService: storageService ?? storage,
            notificationService: mockNotification,
            emailService: mockEmail
        )
    }

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("InProgressTimerSync-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        storage = StorageService()
        mockNotification = MockNotificationService()
        mockEmail = MockEmailService()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Storage round-trip for in-progress entry

    func testStorageRoundTripPreservesInProgressEntry() throws {
        try storage.setStorageFolder(tempDir.path)

        let startTime = Date().addingTimeInterval(-300) // 5 min ago
        let inProgress = TimeEntry(
            id: UUID(),
            startTime: startTime,
            endTime: nil,
            description: ""
        )
        let completed = TimeEntry(
            startTime: startTime.addingTimeInterval(-3600),
            endTime: startTime,
            description: "Earlier task"
        )
        let entriesToSave = [inProgress, completed]

        try storage.saveTimeEntries(entriesToSave)
        let loaded = try storage.loadTimeEntries()

        XCTAssertEqual(loaded.count, 2)
        let active = loaded.first { $0.endTime == nil }
        XCTAssertNotNil(active, "In-progress entry should be in storage")
        XCTAssertEqual(active?.id, inProgress.id)
        XCTAssertEqual(active!.startTime.timeIntervalSince1970, inProgress.startTime.timeIntervalSince1970, accuracy: 2.0)
    }

    // MARK: - ViewModel restores in-progress when loading (second device opens)

    func testViewModelRestoresInProgressEntryFromStorage() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)

        let startTime = Date().addingTimeInterval(-120) // 2 min ago
        let inProgressId = UUID()
        let inProgress = TimeEntry(
            id: inProgressId,
            startTime: startTime,
            endTime: nil,
            description: ""
        )
        let completed = TimeEntry(
            startTime: startTime.addingTimeInterval(-3600),
            endTime: startTime.addingTimeInterval(-3500),
            description: "Done earlier"
        )
        try storage.saveTimeEntries([inProgress, completed])

        let viewModel = makeViewModel()
        try await viewModel.setupStorage(path: tempDir.path)

        XCTAssertTrue(viewModel.isTracking, "Second device should show tracking when in-progress entry exists in storage")
        XCTAssertNotNil(viewModel.currentEntry)
        XCTAssertEqual(viewModel.currentEntry?.id, inProgressId)
        XCTAssertEqual(viewModel.currentEntry!.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 2.0)
        XCTAssertNil(viewModel.currentEntry?.endTime)

        // In-progress entry should not be in allEntries (only completed ones)
        XCTAssertEqual(viewModel.allEntries.count, 1)
        XCTAssertEqual(viewModel.allEntries.first?.description, "Done earlier")
    }

    /// Elapsed time should reflect time since start (e.g. start 2 min ago → display ~2:00 and counting).
    func testRestoredInProgressShowsCorrectElapsedTime() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)

        let twoMinutesAgo = Date().addingTimeInterval(-120)
        let inProgress = TimeEntry(
            startTime: twoMinutesAgo,
            endTime: nil,
            description: ""
        )
        try storage.saveTimeEntries([inProgress])

        let viewModel = makeViewModel()
        try await viewModel.setupStorage(path: tempDir.path)

        XCTAssertTrue(viewModel.isTracking)
        // Should show ~2:00 (2 min 0 sec) or 1:59/2:01 depending on timing
        let formatted = viewModel.currentElapsedFormatted
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertNotEqual(formatted, "0:00", "Elapsed should not be zero when start was in the past")
        // Format is "M:SS" or "H:MM" — after 2 min we expect something like "2:00" or "1:59"
        XCTAssertTrue(
            formatted.contains(":") && formatted.count >= 4,
            "Elapsed format should be like M:SS (e.g. 2:00), got \(formatted)"
        )
    }

    /// When multiple in-progress entries exist (stale), use the most recent and normalize others.
    func testMultipleInProgressUsesMostRecentAndNormalizesStale() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)

        let oldStart = Date().addingTimeInterval(-3600)
        let newStart = Date().addingTimeInterval(-60)
        let oldInProgress = TimeEntry(startTime: oldStart, endTime: nil, description: "Stale")
        let newInProgress = TimeEntry(startTime: newStart, endTime: nil, description: "Current")
        try storage.saveTimeEntries([oldInProgress, newInProgress])

        let viewModel = makeViewModel()
        try await viewModel.setupStorage(path: tempDir.path)

        XCTAssertTrue(viewModel.isTracking)
        XCTAssertEqual(viewModel.currentEntry!.startTime.timeIntervalSince1970, newStart.timeIntervalSince1970, accuracy: 2.0,
                       "Current entry should be the one with latest startTime")

        // Stale in-progress should be in allEntries with 0 duration (endTime = startTime)
        let staleEntry = viewModel.allEntries.first { $0.id == oldInProgress.id }
        XCTAssertNotNil(staleEntry)
        XCTAssertEqual(staleEntry!.endTime!.timeIntervalSince1970, oldStart.timeIntervalSince1970, accuracy: 2.0)
        XCTAssertEqual(staleEntry?.duration, 0)
    }

    // MARK: - Persist in-progress when starting; clear when stopping/cancelling

    func testStartClockPersistsInProgressToStorage() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)
        try storage.saveTimeEntries([])

        let viewModel = makeViewModel()
        try await viewModel.setupStorage(path: tempDir.path)

        viewModel.startClock()

        let loaded = try storage.loadTimeEntries()
        let inProgress = loaded.first { $0.endTime == nil }
        XCTAssertNotNil(inProgress, "Starting the clock should persist an in-progress entry to storage")
    }

    func testStopClockRemovesInProgressFromStorageAndSavesCompleted() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)

        let viewModel = makeViewModel()
        try await viewModel.setupStorage(path: tempDir.path)
        viewModel.startClock()

        viewModel.stopClock(description: "Done", projectName: nil)

        let loaded = try storage.loadTimeEntries()
        let inProgress = loaded.first { $0.endTime == nil }
        XCTAssertNil(inProgress, "After stop, no in-progress entry should remain in storage")
        let completed = loaded.first { $0.description == "Done" }
        XCTAssertNotNil(completed)
        XCTAssertNotNil(completed?.endTime)
    }

    func testCancelTrackingRemovesInProgressFromStorage() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)

        let viewModel = makeViewModel()
        try await viewModel.setupStorage(path: tempDir.path)
        viewModel.startClock()

        viewModel.cancelTracking()

        let loaded = try storage.loadTimeEntries()
        let inProgress = loaded.first { $0.endTime == nil }
        XCTAssertNil(inProgress, "After cancel, in-progress entry should be removed from storage")
    }

    /// Full scenario: device A starts timer, saves; device B loads and sees active timer with correct elapsed.
    func testCrossDeviceScenarioDeviceBSeesActiveTimerWithElapsedTime() async throws {
        try storage.setStorageFolder(tempDir.path)
        let config = AppConfiguration(storageFolder: tempDir.path)
        try storage.saveConfiguration(config)

        // Device A: start timer (simulate macOS)
        let deviceA = makeViewModel()
        try await deviceA.setupStorage(path: tempDir.path)
        deviceA.startClock()
        // Wait so elapsed time is at least 1 second (display shows "0:01")
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s

        // Device B: open app (simulate iOS) — new ViewModel loading from same storage
        let deviceB = makeViewModel()
        try await deviceB.setupStorage(path: tempDir.path)

        XCTAssertTrue(deviceB.isTracking, "Device B should see active timer started on Device A")
        XCTAssertNotNil(deviceB.currentEntry)
        XCTAssertGreaterThanOrEqual(
            deviceB.currentEntry!.duration,
            1.0,
            "Elapsed time on Device B should be at least 1s"
        )
        XCTAssertNotEqual(deviceB.currentElapsedFormatted, "0:00", "Display should show elapsed time (e.g. 0:01)")
    }
}

// MARK: - Mocks (avoid UNUserNotificationCenter / app bundle in xctest)

private final class MockNotificationService: NotificationServiceProtocol {
    func requestAuthorization() async -> Bool { true }
    func scheduleTimesheetReminder(at time: DateComponents, days: [Int]) async {}
    func cancelAllNotifications() {}
}

private final class MockEmailService: EmailServiceProtocol {
    func sendTimesheet(_ timesheet: Timesheet, config: AppConfiguration) -> Bool { false }
    func canSendEmail() -> Bool { true }
    func exportAsCSV(_ timesheet: Timesheet) -> String { "" }
}
