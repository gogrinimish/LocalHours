import Foundation
#if canImport(SkipFoundation)
import SkipFoundation
#endif

/// Application configuration that persists to the storage folder
public struct AppConfiguration: Codable, Equatable {
    /// Path to the folder where timesheets and data are stored
    public var storageFolder: String
    
    /// Timezone identifier for timesheet calculations
    public var timezoneIdentifier: String
    
    /// Time of day to send notification reminder (in HH:mm format)
    public var notificationTime: String
    
    /// Days of week to send notifications (1 = Sunday, 7 = Saturday)
    public var notificationDays: [Int]
    
    /// Email template for timesheet submission
    public var emailTemplate: String
    
    /// Email address of the timesheet approver
    public var approverEmail: String
    
    /// User's name for email signatures
    public var userName: String
    
    /// Email subject template (supports {{userName}}, {{periodStart}}, {{periodEnd}})
    public var emailSubject: String
    
    /// Whether to include detailed entries in email
    public var includeEntriesInEmail: Bool
    
    /// Timesheet period type
    public var timesheetPeriod: TimesheetPeriod
    
    /// Auto-start tracking on app launch
    public var autoStartOnLaunch: Bool
    
    /// Show confirmation dialog before sending timesheet
    public var confirmBeforeSending: Bool
    
    /// The timezone object
    public var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }
    
    /// Notification time as Date components
    public var notificationTimeComponents: DateComponents? {
        let parts = notificationTime.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return DateComponents(hour: hour, minute: minute)
    }
    
    public init(
        storageFolder: String = "",
        timezoneIdentifier: String = TimeZone.current.identifier,
        notificationTime: String = "17:00",
        notificationDays: [Int] = [6], // Friday
        emailTemplate: String = AppConfiguration.defaultEmailTemplate,
        approverEmail: String = "",
        userName: String = "",
        emailSubject: String = "{{userName}} - Timesheet for {{periodStart}} - {{periodEnd}}",
        includeEntriesInEmail: Bool = true,
        timesheetPeriod: TimesheetPeriod = .weekly,
        autoStartOnLaunch: Bool = false,
        confirmBeforeSending: Bool = true
    ) {
        self.storageFolder = storageFolder
        self.timezoneIdentifier = timezoneIdentifier
        self.notificationTime = notificationTime
        self.notificationDays = notificationDays
        self.emailTemplate = emailTemplate
        self.approverEmail = approverEmail
        self.userName = userName
        self.emailSubject = emailSubject
        self.includeEntriesInEmail = includeEntriesInEmail
        self.timesheetPeriod = timesheetPeriod
        self.autoStartOnLaunch = autoStartOnLaunch
        self.confirmBeforeSending = confirmBeforeSending
    }
    
    /// Default email template with placeholders
    public static let defaultEmailTemplate = """
    Hi,
    
    Please find my timesheet for the period {{periodStart}} to {{periodEnd}}.
    
    Total Hours: {{totalHours}}
    
    {{entriesSummary}}
    
    Please let me know if you have any questions.
    
    Best regards,
    {{userName}}
    """
    
    /// Validate the configuration
    public func validate() -> [String] {
        var errors: [String] = []
        
        if storageFolder.isEmpty {
            errors.append("Storage folder is not configured")
        }
        
        if approverEmail.isEmpty {
            errors.append("Approver email is not configured")
        } else if !isValidEmail(approverEmail) {
            errors.append("Approver email is not valid")
        }
        
        if userName.isEmpty {
            errors.append("User name is not configured")
        }
        
        if notificationTimeComponents == nil {
            errors.append("Notification time format is invalid (use HH:mm)")
        }
        
        return errors
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

/// Timesheet period options
public enum TimesheetPeriod: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-Weekly"
    case monthly = "Monthly"
    
    public var displayName: String {
        rawValue
    }
}
