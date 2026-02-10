import XCTest
@testable import LocalHoursCore

final class StorageServiceTests: XCTestCase {
    
    var storageService: StorageService!
    var testDirectory: URL!
    
    override func setUp() {
        super.setUp()
        storageService = StorageService()
        
        // Create a temporary directory for tests
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalHoursTests")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }
    
    // MARK: - Storage Setup Tests
    
    func testSetStorageFolder() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        XCTAssertEqual(storageService.getStorageFolderURL()?.path, testDirectory.path)
    }
    
    func testSetStorageFolderCreatesSubfolders() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let timesheetsFolder = testDirectory.appendingPathComponent("timesheets")
        let entriesFolder = testDirectory.appendingPathComponent("time-entries")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: timesheetsFolder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: entriesFolder.path))
    }
    
    /// README: Verifies folder structure (config.json, timesheets/, time-entries/entries.json)
    func testStorageFolderStructureMatchesReadme() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let configFile = testDirectory.appendingPathComponent("config.json")
        let timesheetsFolder = testDirectory.appendingPathComponent("timesheets")
        let entriesFile = testDirectory.appendingPathComponent("time-entries").appendingPathComponent("entries.json")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: timesheetsFolder.path),
                      "timesheets/ folder should exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: testDirectory.appendingPathComponent("time-entries").path),
                      "time-entries/ folder should exist")
        
        var config = AppConfiguration(storageFolder: testDirectory.path)
        config.userName = "Test"
        config.approverEmail = "test@example.com"
        try storageService.saveConfiguration(config)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configFile.path),
                      "config.json should exist at storage root")
        
        try storageService.saveTimeEntries([TimeEntry(startTime: Date(), description: "Test")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: entriesFile.path),
                      "time-entries/entries.json should exist after saving entries")
    }
    
    func testIsValidStorageFolder() {
        XCTAssertTrue(storageService.isValidStorageFolder(testDirectory.path))
    }
    
    func testIsValidStorageFolderCreatesIfNeeded() {
        let newFolder = testDirectory.appendingPathComponent("newFolder")
        XCTAssertFalse(FileManager.default.fileExists(atPath: newFolder.path))
        
        let isValid = storageService.isValidStorageFolder(newFolder.path)
        
        XCTAssertTrue(isValid)
        XCTAssertTrue(FileManager.default.fileExists(atPath: newFolder.path))
    }
    
    // MARK: - Configuration Tests
    
    func testSaveAndLoadConfiguration() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        var config = AppConfiguration()
        config.userName = "Test User"
        config.approverEmail = "test@example.com"
        config.storageFolder = testDirectory.path
        
        try storageService.saveConfiguration(config)
        
        let loaded = try storageService.loadConfiguration()
        
        XCTAssertEqual(loaded.userName, "Test User")
        XCTAssertEqual(loaded.approverEmail, "test@example.com")
    }
    
    func testLoadConfigurationDefaultsWhenMissing() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let config = try storageService.loadConfiguration()
        
        XCTAssertEqual(config.storageFolder, testDirectory.path)
    }
    
    func testSaveConfigurationWithoutStorageFolder() {
        let config = AppConfiguration()
        
        XCTAssertThrowsError(try storageService.saveConfiguration(config)) { error in
            XCTAssertTrue(error is StorageError)
            XCTAssertEqual(error as? StorageError, .noStorageFolder)
        }
    }
    
    // MARK: - Time Entries Tests
    
    func testSaveAndLoadTimeEntries() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let entries = [
            TimeEntry(startTime: Date(), endTime: Date().addingTimeInterval(3600), description: "Task 1"),
            TimeEntry(startTime: Date(), endTime: Date().addingTimeInterval(1800), description: "Task 2")
        ]
        
        try storageService.saveTimeEntries(entries)
        
        let loaded = try storageService.loadTimeEntries()
        
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].description, "Task 1")
        XCTAssertEqual(loaded[1].description, "Task 2")
    }
    
    func testLoadTimeEntriesEmptyWhenMissing() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let entries = try storageService.loadTimeEntries()
        
        XCTAssertTrue(entries.isEmpty)
    }
    
    func testSaveTimeEntriesWithoutStorageFolder() {
        let entries = [TimeEntry(startTime: Date(), description: "Task")]
        
        XCTAssertThrowsError(try storageService.saveTimeEntries(entries)) { error in
            XCTAssertEqual(error as? StorageError, .noStorageFolder)
        }
    }
    
    // MARK: - Timesheet Tests
    
    func testSaveAndLoadTimesheets() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [
                TimeEntry(startTime: Date(), endTime: Date().addingTimeInterval(3600), description: "Task")
            ],
            status: .submitted
        )
        
        try storageService.saveTimesheet(timesheet)
        
        let loaded = try storageService.loadTimesheets()
        
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, timesheet.id)
        XCTAssertEqual(loaded[0].status, .submitted)
    }
    
    func testLoadTimesheetsEmpty() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let timesheets = try storageService.loadTimesheets()
        
        XCTAssertTrue(timesheets.isEmpty)
    }
    
    func testDeleteTimesheet() throws {
        try storageService.setStorageFolder(testDirectory.path)
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7)
        )
        
        try storageService.saveTimesheet(timesheet)
        XCTAssertEqual(try storageService.loadTimesheets().count, 1)
        
        try storageService.deleteTimesheet(timesheet)
        XCTAssertEqual(try storageService.loadTimesheets().count, 0)
    }
    
    // MARK: - Default Path Tests
    
    func testDefaultStoragePath() {
        let path = StorageService.defaultStoragePath()
        
        XCTAssertTrue(path.contains("LocalHours"))
        XCTAssertTrue(path.contains("Documents") || path.contains("Library"))
    }
    
    // MARK: - Error Tests
    
    func testStorageErrorDescriptions() {
        XCTAssertFalse(StorageError.noStorageFolder.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(StorageError.invalidPath.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(StorageError.fileNotFound.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(StorageError.encodingError.errorDescription?.isEmpty ?? true)
        XCTAssertFalse(StorageError.decodingError.errorDescription?.isEmpty ?? true)
    }
}
