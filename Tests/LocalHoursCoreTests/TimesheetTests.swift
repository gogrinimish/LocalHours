import XCTest
@testable import LocalHoursCore

final class TimesheetTests: XCTestCase {
    
    // MARK: - Creation Tests
    
    func testTimesheetCreation() {
        let now = Date()
        let timesheet = Timesheet(
            periodStart: now,
            periodEnd: now.addingTimeInterval(86400 * 7)
        )
        
        XCTAssertFalse(timesheet.id.uuidString.isEmpty)
        XCTAssertEqual(timesheet.status, .draft)
        XCTAssertTrue(timesheet.entries.isEmpty)
        XCTAssertNil(timesheet.submittedAt)
        XCTAssertNil(timesheet.approvedAt)
    }
    
    func testTimesheetCurrentWeek() {
        let timesheet = Timesheet.currentWeek()
        let calendar = Calendar.current
        
        // Period should be 7 days
        let days = calendar.dateComponents([.day], from: timesheet.periodStart, to: timesheet.periodEnd).day!
        XCTAssertEqual(days, 6) // End is inclusive, so 6 days difference
        
        // Should start on a Sunday or Monday depending on locale
        let weekday = calendar.component(.weekday, from: timesheet.periodStart)
        XCTAssertTrue(weekday == 1 || weekday == 2) // Sunday or Monday
    }
    
    func testTimesheetCurrentMonth() {
        let timesheet = Timesheet.currentMonth()
        let calendar = Calendar.current
        
        // Period start should be first of the month
        let startDay = calendar.component(.day, from: timesheet.periodStart)
        XCTAssertEqual(startDay, 1)
        
        // Period end should be last day of the month
        let endMonth = calendar.component(.month, from: timesheet.periodEnd)
        let startMonth = calendar.component(.month, from: timesheet.periodStart)
        XCTAssertEqual(endMonth, startMonth)
    }
    
    // MARK: - Total Hours Tests
    
    func testTimesheetTotalHoursEmpty() {
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: []
        )
        
        XCTAssertEqual(timesheet.totalHours, 0)
    }
    
    func testTimesheetTotalHours() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-7200),
                endTime: now.addingTimeInterval(-3600),
                description: "Task 1"
            ),
            TimeEntry(
                startTime: now.addingTimeInterval(-3600),
                endTime: now,
                description: "Task 2"
            )
        ]
        
        let timesheet = Timesheet(
            periodStart: now.addingTimeInterval(-86400),
            periodEnd: now,
            entries: entries
        )
        
        XCTAssertEqual(timesheet.totalHours, 2.0, accuracy: 0.01)
    }
    
    func testTimesheetFormattedTotalHours() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-5400), // 1.5 hours
                endTime: now,
                description: "Task"
            )
        ]
        
        let timesheet = Timesheet(
            periodStart: now.addingTimeInterval(-86400),
            periodEnd: now,
            entries: entries
        )
        
        XCTAssertEqual(timesheet.formattedTotalHours, "1.5 hours")
    }
    
    // MARK: - Period Description Tests
    
    func testTimesheetPeriodDescription() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let start = Date()
        let end = start.addingTimeInterval(86400 * 7)
        
        let timesheet = Timesheet(periodStart: start, periodEnd: end)
        
        let expectedDescription = "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        XCTAssertEqual(timesheet.periodDescription, expectedDescription)
    }
    
    // MARK: - Status Tests
    
    func testTimesheetStatusValues() {
        XCTAssertEqual(TimesheetStatus.draft.displayName, "Draft")
        XCTAssertEqual(TimesheetStatus.submitted.displayName, "Submitted")
        XCTAssertEqual(TimesheetStatus.approved.displayName, "Approved")
        XCTAssertEqual(TimesheetStatus.rejected.displayName, "Rejected")
    }
    
    func testTimesheetStatusIcons() {
        XCTAssertEqual(TimesheetStatus.draft.iconName, "doc.text")
        XCTAssertEqual(TimesheetStatus.submitted.iconName, "paperplane.fill")
        XCTAssertEqual(TimesheetStatus.approved.iconName, "checkmark.circle.fill")
        XCTAssertEqual(TimesheetStatus.rejected.iconName, "xmark.circle.fill")
    }
    
    // MARK: - Email Generation Tests
    
    func testTimesheetEmailGeneration() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-3600),
                endTime: now,
                description: "Test task"
            )
        ]
        
        let timesheet = Timesheet(
            periodStart: now.addingTimeInterval(-86400),
            periodEnd: now,
            entries: entries
        )
        
        let template = "Hours: {{totalHours}}, User: {{userName}}"
        let body = timesheet.generateEmailBody(template: template, userName: "John Doe")
        
        XCTAssertTrue(body.contains("1.0 hours"))
        XCTAssertTrue(body.contains("John Doe"))
    }
    
    func testTimesheetEmailGenerationWithPlaceholders() {
        let now = Date()
        let timesheet = Timesheet(
            periodStart: now,
            periodEnd: now.addingTimeInterval(86400 * 7),
            entries: []
        )
        
        let template = "Period: {{periodStart}} to {{periodEnd}}"
        let body = timesheet.generateEmailBody(template: template, userName: "Test")
        
        // Should not contain raw placeholders
        XCTAssertFalse(body.contains("{{periodStart}}"))
        XCTAssertFalse(body.contains("{{periodEnd}}"))
    }
    
    /// README: Timesheet generation compiles entries into formatted email body with entriesSummary
    func testTimesheetGenerateEmailBodyIncludesEntriesSummary() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-3600),
                endTime: now,
                description: "Worked on README"
            )
        ]
        let timesheet = Timesheet(
            periodStart: now.addingTimeInterval(-86400 * 7),
            periodEnd: now,
            entries: entries
        )
        let template = "Summary: {{entriesSummary}}"
        let body = timesheet.generateEmailBody(template: template, userName: "Test User")
        
        XCTAssertTrue(body.contains("Worked on README"), "entriesSummary should include entry descriptions")
        XCTAssertFalse(body.contains("{{entriesSummary}}"), "entriesSummary placeholder should be replaced")
    }
    
    // MARK: - Codable Tests
    
    func testTimesheetCodable() throws {
        let timesheet = Timesheet(
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(86400 * 7),
            entries: [
                TimeEntry(
                    startTime: Date(),
                    endTime: Date().addingTimeInterval(3600),
                    description: "Task"
                )
            ],
            status: .submitted,
            submittedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(timesheet)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Timesheet.self, from: data)
        
        XCTAssertEqual(decoded.id, timesheet.id)
        XCTAssertEqual(decoded.status, timesheet.status)
        XCTAssertEqual(decoded.entries.count, 1)
    }
}
