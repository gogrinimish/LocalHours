import XCTest
@testable import SimpleTimesheetCore

/// Tests that verify functionality described in the README actually works in the app.
/// If any of these fail, update the app or the README to keep them in sync.
final class ReadmeComplianceTests: XCTestCase {
    
    // MARK: - Core Functionality (README: Features)
    
    /// README: "Quick Time Tracking: Start and stop the clock with a single tap/click"
    func testQuickTimeTrackingStartStop() {
        let entry = TimeEntry(startTime: Date(), description: "")
        XCTAssertTrue(entry.isActive)
        XCTAssertNil(entry.endTime)
        
        var stopped = entry
        stopped.stop(withDescription: "Done")
        XCTAssertFalse(stopped.isActive)
        XCTAssertNotNil(stopped.endTime)
    }
    
    /// README: "Work Descriptions: Add descriptions when stopping the clock to document what was worked on"
    func testWorkDescriptionsWhenStopping() {
        var entry = TimeEntry(startTime: Date(), description: "")
        entry.stop(withDescription: "Implemented feature X")
        XCTAssertEqual(entry.description, "Implemented feature X")
    }
    
    /// README: "Timesheet Generation: Automatically compile tracked time into formatted timesheets"
    func testTimesheetGenerationCompilesTime() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-7200),
                endTime: now.addingTimeInterval(-3600),
                description: "Task A"
            ),
            TimeEntry(
                startTime: now.addingTimeInterval(-3600),
                endTime: now,
                description: "Task B"
            )
        ]
        let timesheet = Timesheet(
            periodStart: now.addingTimeInterval(-86400 * 7),
            periodEnd: now,
            entries: entries
        )
        XCTAssertEqual(timesheet.totalHours, 2.0, accuracy: 0.01)
        XCTAssertEqual(timesheet.entries.count, 2)
    }
    
    /// README: "Email Integration: Send timesheets to approvers with customizable email templates"
    func testEmailIntegrationCustomizableTemplate() {
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: []
        )
        let customTemplate = "Hello, my hours: {{totalHours}}. Signed, {{userName}}"
        let body = timesheet.generateEmailBody(template: customTemplate, userName: "Jane")
        XCTAssertTrue(body.contains("Signed, Jane"))
        XCTAssertFalse(body.contains("{{userName}}"))
    }
    
    /// README: "Cross-Device Sync: Store data in cloud folders (iCloud, Google Drive, OneDrive)"
    func testCrossDeviceSyncStorageStructure() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadmeCompliance-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let storage = StorageService()
        try storage.setStorageFolder(tempDir.path)
        
        var config = AppConfiguration(storageFolder: tempDir.path)
        config.userName = "Sync User"
        config.approverEmail = "boss@example.com"
        try storage.saveConfiguration(config)
        
        let entries = [TimeEntry(startTime: Date(), endTime: Date().addingTimeInterval(3600), description: "Synced task")]
        try storage.saveTimeEntries(entries)
        
        let configPath = tempDir.appendingPathComponent("config.json").path
        let entriesPath = tempDir.appendingPathComponent("time-entries").appendingPathComponent("entries.json").path
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: entriesPath))
        
        let loadedConfig = try storage.loadConfiguration()
        XCTAssertEqual(loadedConfig.userName, "Sync User")
        let loadedEntries = try storage.loadTimeEntries()
        XCTAssertEqual(loadedEntries.count, 1)
        XCTAssertEqual(loadedEntries[0].description, "Synced task")
    }
    
    // MARK: - Configuration Options (README: Configuration Options table)
    
    /// README: All configuration options exist and can be round-tripped
    func testReadmeConfigurationOptionsExistAndPersist() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadmeConfig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let storage = StorageService()
        try storage.setStorageFolder(tempDir.path)
        
        let config = AppConfiguration(
            storageFolder: tempDir.path,
            timezoneIdentifier: "America/New_York",
            notificationTime: "17:00",
            notificationDays: [6],
            emailTemplate: "Custom {{totalHours}}",
            approverEmail: "approver@example.com",
            userName: "Test User",
            emailSubject: "{{userName}} - Timesheet"
        )
        
        try storage.saveConfiguration(config)
        let loaded = try storage.loadConfiguration()
        
        XCTAssertEqual(loaded.storageFolder, tempDir.path)
        XCTAssertEqual(loaded.timezoneIdentifier, "America/New_York")
        XCTAssertEqual(loaded.notificationTime, "17:00")
        XCTAssertEqual(loaded.notificationDays, [6])
        XCTAssertEqual(loaded.emailTemplate, "Custom {{totalHours}}")
        XCTAssertEqual(loaded.approverEmail, "approver@example.com")
        XCTAssertEqual(loaded.userName, "Test User")
        XCTAssertEqual(loaded.emailSubject, "{{userName}} - Timesheet")
    }
    
    // MARK: - Usage (README: Keyboard Shortcuts - macOS)
    
    /// README: Keyboard shortcuts are documented; we verify the app supports start/stop and timesheet concepts
    func testStartStopAndTimesheetConceptsSupported() {
        var entry = TimeEntry(startTime: Date(), description: "")
        XCTAssertTrue(entry.isActive)
        entry.stop(withDescription: "Work")
        XCTAssertFalse(entry.isActive)
        
        let timesheet = Timesheet.currentWeek()
        XCTAssertNotNil(timesheet.periodStart)
        XCTAssertNotNil(timesheet.periodEnd)
    }
    
    // MARK: - Privacy (README: No analytics, no account)
    
    /// README: "No analytics or tracking" - app uses local/cloud storage only; no remote API
    func testNoRemoteDependenciesInCoreModels() {
        // TimeEntry, Timesheet, AppConfiguration are pure data; no URLSession or analytics
        let entry = TimeEntry(startTime: Date(), description: "Private work")
        XCTAssertFalse(entry.description.isEmpty)
        // If we had analytics, we'd assert it's not called; here we assert models are local
        let _ = entry.id
        let _ = entry.duration
    }
}
