import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// EmailService uses UIKit/AppKit APIs not available in Skip
#if !SKIP

/// Protocol for email operations
public protocol EmailServiceProtocol {
    func sendTimesheet(_ timesheet: Timesheet, config: AppConfiguration) -> Bool
    func canSendEmail() -> Bool
    func exportAsCSV(_ timesheet: Timesheet) -> String
}

/// Service for sending emails
public class EmailService: EmailServiceProtocol {
    
    public static let shared = EmailService()
    
    public init() {}
    
    /// Check if the device can send emails
    public func canSendEmail() -> Bool {
        // On macOS/iOS, we'll use mailto: URLs which should always be available
        return true
    }
    
    /// Send a timesheet via email
    public func sendTimesheet(_ timesheet: Timesheet, config: AppConfiguration) -> Bool {
        guard !config.approverEmail.isEmpty else {
            return false
        }
        
        // Generate email content
        let subject = generateSubject(timesheet: timesheet, config: config)
        let body = timesheet.generateEmailBody(template: config.emailTemplate, userName: config.userName)
        
        // Create mailto URL
        guard let mailtoURL = createMailtoURL(
            to: config.approverEmail,
            subject: subject,
            body: body
        ) else {
            return false
        }
        
        // Open email client
        return openURL(mailtoURL)
    }
    
    /// Generate email subject from template
    private func generateSubject(timesheet: Timesheet, config: AppConfiguration) -> String {
        var subject = config.emailSubject
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        subject = subject.replacingOccurrences(of: "{{periodStart}}", with: formatter.string(from: timesheet.periodStart))
        subject = subject.replacingOccurrences(of: "{{periodEnd}}", with: formatter.string(from: timesheet.periodEnd))
        subject = subject.replacingOccurrences(of: "{{userName}}", with: config.userName)
        
        return subject
    }
    
    /// Create a mailto URL
    private func createMailtoURL(to recipient: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        
        return components.url
    }
    
    /// Open a URL using the appropriate platform method
    private func openURL(_ url: URL) -> Bool {
        #if canImport(UIKit)
        // iOS
        guard UIApplication.shared.canOpenURL(url) else {
            return false
        }
        UIApplication.shared.open(url)
        return true
        #elseif canImport(AppKit)
        // macOS
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }
    
    /// Export timesheet as CSV
    public func exportAsCSV(_ timesheet: Timesheet) -> String {
        var csv = "Date,Start Time,End Time,Duration (hours),Description,Project\n"
        
        // Use explicit formats to avoid encoding issues with AM/PM
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"  // 24-hour format
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        for entry in timesheet.entries {
            let date = dateFormatter.string(from: entry.startTime)
            let startTime = timeFormatter.string(from: entry.startTime)
            let endTime = entry.endTime.map { timeFormatter.string(from: $0) } ?? "In Progress"
            let duration = String(format: "%.2f", entry.duration / 3600.0)
            // Escape quotes and handle commas in description
            let description = entry.description
                .replacingOccurrences(of: "\"", with: "\"\"")
            let project = (entry.projectName ?? "")
                .replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\(date),\(startTime),\(endTime),\(duration),\"\(description)\",\"\(project)\"\n"
        }
        
        csv += "\nTotal Hours:,\(String(format: "%.2f", timesheet.totalHours))\n"
        csv += "Period:,\"\(timesheet.periodDescription)\"\n"
        
        return csv
    }
    
    /// Export timesheet as plain text
    public func exportAsText(_ timesheet: Timesheet, config: AppConfiguration) -> String {
        return timesheet.generateEmailBody(template: config.emailTemplate, userName: config.userName)
    }
}

/// Email-related errors
public enum EmailError: LocalizedError {
    case noRecipient
    case invalidEmail
    case emailClientNotAvailable
    case failedToOpen
    
    public var errorDescription: String? {
        switch self {
        case .noRecipient:
            return "No recipient email address configured."
        case .invalidEmail:
            return "The email address is invalid."
        case .emailClientNotAvailable:
            return "No email client is available on this device."
        case .failedToOpen:
            return "Failed to open email client."
        }
    }
}

#endif // !SKIP
