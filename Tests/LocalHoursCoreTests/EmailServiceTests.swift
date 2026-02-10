import XCTest
@testable import LocalHoursCore

final class EmailServiceTests: XCTestCase {
    
    var emailService: EmailService!
    
    override func setUp() {
        emailService = EmailService()
    }
    
    override func tearDown() {
        emailService = nil
    }
    
    // MARK: - CSV Export Tests
    
    func testExportAsCSVHeader() {
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: []
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        XCTAssertTrue(csv.hasPrefix("Date,Start Time,End Time,Duration (hours),Description,Project"))
    }
    
    func testExportAsCSVWithEntries() {
        let entry = TimeEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600), // 1 hour
            description: "Test work",
            projectName: "Test Project"
        )
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [entry]
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        XCTAssertTrue(csv.contains("Test work"))
        XCTAssertTrue(csv.contains("Test Project"))
        XCTAssertTrue(csv.contains("1.00")) // 1 hour duration
    }
    
    func testExportAsCSVTotalHours() {
        let entry1 = TimeEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600), // 1 hour
            description: "Work 1"
        )
        let entry2 = TimeEntry(
            startTime: Date().addingTimeInterval(7200),
            endTime: Date().addingTimeInterval(10800), // 1 hour
            description: "Work 2"
        )
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [entry1, entry2]
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        XCTAssertTrue(csv.contains("Total Hours:"))
        XCTAssertTrue(csv.contains("2.00"))
    }
    
    func testExportAsCSVHandlesCommasInDescription() {
        let entry = TimeEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            description: "Work with, comma",
            projectName: "Project, Inc"
        )
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [entry]
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        // Commas are preserved inside quoted fields (proper CSV format)
        XCTAssertTrue(csv.contains("\"Work with, comma\""))
        XCTAssertTrue(csv.contains("\"Project, Inc\""))
    }
    
    func testExportAsCSVEscapesQuotesInDescription() {
        let entry = TimeEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            description: "Work with \"quotes\"",
            projectName: nil
        )
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [entry]
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        // Quotes should be escaped by doubling them (CSV standard)
        XCTAssertTrue(csv.contains("\"\"quotes\"\""))
    }
    
    func testExportAsCSVUsesISO8601DateFormat() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2026, month: 1, day: 15, hour: 14, minute: 30)
        let startTime = calendar.date(from: components)!
        
        let entry = TimeEntry(
            startTime: startTime,
            endTime: startTime.addingTimeInterval(3600),
            description: "Test"
        )
        
        let timesheet = Timesheet(
            periodStart: startTime,
            periodEnd: startTime.addingTimeInterval(86400 * 7),
            entries: [entry]
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        // Should use yyyy-MM-dd format and 24-hour time
        XCTAssertTrue(csv.contains("2026-01-15"))
        XCTAssertTrue(csv.contains("14:30"))
    }
    
    func testExportAsCSVHandlesInProgressEntry() {
        let entry = TimeEntry(
            startTime: Date(),
            description: "Work in progress"
        )
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [entry]
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        XCTAssertTrue(csv.contains("In Progress"))
    }
    
    func testExportAsCSVEmptyEntries() {
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: []
        )
        
        let csv = emailService.exportAsCSV(timesheet)
        
        // Should still have header and total
        XCTAssertTrue(csv.contains("Date,Start Time"))
        XCTAssertTrue(csv.contains("Total Hours:"))
        XCTAssertTrue(csv.contains("0.00"))
    }
    
    /// README: CSV export includes period description for timesheet context
    func testExportAsCSVContainsPeriodLine() {
        let start = Date()
        let end = start.addingTimeInterval(86400 * 7)
        let timesheet = Timesheet(
            periodStart: start,
            periodEnd: end,
            entries: []
        )
        let csv = emailService.exportAsCSV(timesheet)
        
        XCTAssertTrue(csv.contains("Period:"), "CSV should include Period line per README")
        XCTAssertTrue(csv.contains(timesheet.periodDescription), "Period line should contain period description")
    }
    
    // MARK: - Text Export Tests
    
    func testExportAsText() {
        let entry = TimeEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            description: "Test work"
        )
        
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [entry]
        )
        
        let config = AppConfiguration(
            storageFolder: "/tmp",
            userName: "Test User"
        )
        
        let text = emailService.exportAsText(timesheet, config: config)
        
        XCTAssertFalse(text.isEmpty)
    }
    
    // MARK: - Send Timesheet Tests
    
    func testSendTimesheetFailsWithEmptyApproverEmail() {
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: []
        )
        
        let config = AppConfiguration(
            storageFolder: "/tmp",
            approverEmail: "" // Empty email
        )
        
        let result = emailService.sendTimesheet(timesheet, config: config)
        
        XCTAssertFalse(result)
    }
    
    func testCanSendEmail() {
        // Should always return true since we use mailto: URLs
        XCTAssertTrue(emailService.canSendEmail())
    }
    
    // MARK: - Email Error Tests
    
    func testEmailErrorDescriptions() {
        XCTAssertEqual(
            EmailError.noRecipient.errorDescription,
            "No recipient email address configured."
        )
        XCTAssertEqual(
            EmailError.invalidEmail.errorDescription,
            "The email address is invalid."
        )
        XCTAssertEqual(
            EmailError.emailClientNotAvailable.errorDescription,
            "No email client is available on this device."
        )
        XCTAssertEqual(
            EmailError.failedToOpen.errorDescription,
            "Failed to open email client."
        )
    }
}
