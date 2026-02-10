import XCTest
@testable import LocalHoursCore

final class AppConfigurationTests: XCTestCase {
    
    // MARK: - Default Values Tests
    
    func testDefaultConfiguration() {
        let config = AppConfiguration()
        
        XCTAssertTrue(config.storageFolder.isEmpty)
        XCTAssertEqual(config.timezoneIdentifier, TimeZone.current.identifier)
        XCTAssertEqual(config.notificationTime, "17:00")
        XCTAssertEqual(config.notificationDays, [6]) // Friday (1=Sun … 7=Sat per README)
        XCTAssertFalse(config.emailTemplate.isEmpty)
        XCTAssertTrue(config.approverEmail.isEmpty)
        XCTAssertTrue(config.userName.isEmpty)
        XCTAssertTrue(config.emailSubject.contains("{{userName}}"))
        XCTAssertTrue(config.includeEntriesInEmail)
        XCTAssertEqual(config.timesheetPeriod, .weekly)
        XCTAssertFalse(config.autoStartOnLaunch)
        XCTAssertTrue(config.confirmBeforeSending)
    }
    
    func testCustomConfiguration() {
        let config = AppConfiguration(
            storageFolder: "/path/to/storage",
            timezoneIdentifier: "America/New_York",
            notificationTime: "09:00",
            notificationDays: [2, 6], // Monday and Friday
            emailTemplate: "Custom template",
            approverEmail: "boss@example.com",
            userName: "Test User",
            emailSubject: "Custom Subject",
            includeEntriesInEmail: false,
            timesheetPeriod: .monthly,
            autoStartOnLaunch: true,
            confirmBeforeSending: false
        )
        
        XCTAssertEqual(config.storageFolder, "/path/to/storage")
        XCTAssertEqual(config.timezoneIdentifier, "America/New_York")
        XCTAssertEqual(config.notificationTime, "09:00")
        XCTAssertEqual(config.notificationDays, [2, 6])
        XCTAssertEqual(config.emailTemplate, "Custom template")
        XCTAssertEqual(config.approverEmail, "boss@example.com")
        XCTAssertEqual(config.userName, "Test User")
        XCTAssertEqual(config.emailSubject, "Custom Subject")
        XCTAssertFalse(config.includeEntriesInEmail)
        XCTAssertEqual(config.timesheetPeriod, .monthly)
        XCTAssertTrue(config.autoStartOnLaunch)
        XCTAssertFalse(config.confirmBeforeSending)
    }
    
    // MARK: - Timezone Tests
    
    func testTimezoneProperty() {
        var config = AppConfiguration()
        config.timezoneIdentifier = "America/Los_Angeles"
        
        XCTAssertEqual(config.timezone.identifier, "America/Los_Angeles")
    }
    
    func testInvalidTimezoneDefaultsToCurrent() {
        var config = AppConfiguration()
        config.timezoneIdentifier = "Invalid/Timezone"
        
        XCTAssertEqual(config.timezone, .current)
    }
    
    // MARK: - Notification Time Tests
    
    func testNotificationTimeComponents() {
        var config = AppConfiguration()
        config.notificationTime = "17:30"
        
        let components = config.notificationTimeComponents
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.hour, 17)
        XCTAssertEqual(components?.minute, 30)
    }
    
    func testNotificationTimeComponentsMorning() {
        var config = AppConfiguration()
        config.notificationTime = "09:00"
        
        let components = config.notificationTimeComponents
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.hour, 9)
        XCTAssertEqual(components?.minute, 0)
    }
    
    func testInvalidNotificationTimeComponents() {
        var config = AppConfiguration()
        config.notificationTime = "invalid"
        
        XCTAssertNil(config.notificationTimeComponents)
    }
    
    func testNotificationTimeComponentsPartiallyInvalid() {
        var config = AppConfiguration()
        config.notificationTime = "25:00" // Invalid hour
        
        // Should still parse but hour will be 25
        let components = config.notificationTimeComponents
        XCTAssertNotNil(components)
        XCTAssertEqual(components?.hour, 25)
    }
    
    // MARK: - Validation Tests
    
    func testValidationEmptyConfig() {
        let config = AppConfiguration()
        let errors = config.validate()
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("Storage folder") })
        XCTAssertTrue(errors.contains { $0.contains("Approver email") })
        XCTAssertTrue(errors.contains { $0.contains("User name") })
    }
    
    func testValidationValidConfig() {
        var config = AppConfiguration()
        config.storageFolder = "/tmp/test"
        config.userName = "Test User"
        config.approverEmail = "approver@example.com"
        
        let errors = config.validate()
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testValidationInvalidEmail() {
        var config = AppConfiguration()
        config.storageFolder = "/tmp/test"
        config.userName = "Test User"
        config.approverEmail = "invalid-email"
        
        let errors = config.validate()
        XCTAssertTrue(errors.contains { $0.contains("email") && $0.contains("not valid") })
    }
    
    func testValidationInvalidEmailFormats() {
        var config = AppConfiguration()
        config.storageFolder = "/tmp/test"
        config.userName = "Test User"
        
        let invalidEmails = [
            "plaintext",
            "@nodomain.com",
            "missing@.com",
            "spaces in@email.com",
            "double@@at.com"
        ]
        
        for email in invalidEmails {
            config.approverEmail = email
            let errors = config.validate()
            XCTAssertTrue(errors.contains { $0.contains("email") }, "Expected invalid: \(email)")
        }
    }
    
    func testValidationValidEmailFormats() {
        var config = AppConfiguration()
        config.storageFolder = "/tmp/test"
        config.userName = "Test User"
        
        let validEmails = [
            "simple@example.com",
            "user.name@example.com",
            "user+tag@example.com",
            "user@subdomain.example.com"
        ]
        
        for email in validEmails {
            config.approverEmail = email
            let errors = config.validate()
            XCTAssertFalse(errors.contains { $0.contains("email") && $0.contains("not valid") }, "Expected valid: \(email)")
        }
    }
    
    func testValidationInvalidNotificationTime() {
        var config = AppConfiguration()
        config.storageFolder = "/tmp/test"
        config.userName = "Test User"
        config.approverEmail = "test@example.com"
        config.notificationTime = "invalid"
        
        let errors = config.validate()
        XCTAssertTrue(errors.contains { $0.contains("Notification time") })
    }
    
    // MARK: - Timesheet Period Tests
    
    func testTimesheetPeriodValues() {
        XCTAssertEqual(TimesheetPeriod.weekly.displayName, "Weekly")
        XCTAssertEqual(TimesheetPeriod.biweekly.displayName, "Bi-Weekly")
        XCTAssertEqual(TimesheetPeriod.monthly.displayName, "Monthly")
    }
    
    func testTimesheetPeriodAllCases() {
        XCTAssertEqual(TimesheetPeriod.allCases.count, 3)
        XCTAssertTrue(TimesheetPeriod.allCases.contains(.weekly))
        XCTAssertTrue(TimesheetPeriod.allCases.contains(.biweekly))
        XCTAssertTrue(TimesheetPeriod.allCases.contains(.monthly))
    }
    
    /// README: notificationDays uses 1=Sunday … 7=Saturday; [6] = Friday
    func testNotificationDaysFridayIsSix() {
        let config = AppConfiguration()
        XCTAssertEqual(config.notificationDays, [6], "Default reminder day should be Friday (6)")
    }
    
    // MARK: - Default Email Template Tests
    
    func testDefaultEmailTemplateContainsPlaceholders() {
        let template = AppConfiguration.defaultEmailTemplate
        
        XCTAssertTrue(template.contains("{{userName}}"))
        XCTAssertTrue(template.contains("{{periodStart}}"))
        XCTAssertTrue(template.contains("{{periodEnd}}"))
        XCTAssertTrue(template.contains("{{totalHours}}"))
        XCTAssertTrue(template.contains("{{entriesSummary}}"))
    }
    
    // MARK: - Codable Tests
    
    func testConfigurationCodable() throws {
        let config = AppConfiguration(
            storageFolder: "/test/path",
            timezoneIdentifier: "UTC",
            notificationTime: "18:00",
            notificationDays: [1, 5],
            emailTemplate: "Test template",
            approverEmail: "test@test.com",
            userName: "Coder",
            emailSubject: "Test Subject",
            includeEntriesInEmail: true,
            timesheetPeriod: .biweekly,
            autoStartOnLaunch: false,
            confirmBeforeSending: true
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppConfiguration.self, from: data)
        
        XCTAssertEqual(decoded.storageFolder, config.storageFolder)
        XCTAssertEqual(decoded.timezoneIdentifier, config.timezoneIdentifier)
        XCTAssertEqual(decoded.notificationTime, config.notificationTime)
        XCTAssertEqual(decoded.notificationDays, config.notificationDays)
        XCTAssertEqual(decoded.approverEmail, config.approverEmail)
        XCTAssertEqual(decoded.userName, config.userName)
        XCTAssertEqual(decoded.timesheetPeriod, config.timesheetPeriod)
    }
}
