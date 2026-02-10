import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// NotificationService uses UserNotifications APIs not available in Skip
#if !SKIP

/// Protocol for notification operations
public protocol NotificationServiceProtocol {
    func requestAuthorization() async -> Bool
    func scheduleTimesheetReminder(at time: DateComponents, days: [Int]) async
    func cancelAllNotifications()
}

/// Service for managing local notifications
public class NotificationService: NotificationServiceProtocol {
    
    public static let shared = NotificationService()
    
    #if canImport(UserNotifications)
    private let notificationCenter = UNUserNotificationCenter.current()
    #endif
    
    public init() {}
    
    /// Request notification authorization
    public func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            return try await notificationCenter.requestAuthorization(options: options)
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
        #else
        return false
        #endif
    }
    
    /// Schedule timesheet reminder notifications
    public func scheduleTimesheetReminder(at time: DateComponents, days: [Int]) async {
        #if canImport(UserNotifications)
        // Cancel existing reminders first
        cancelTimesheetReminders()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Submit Timesheet"
        content.body = "Don't forget to submit your timesheet for this week."
        content.sound = .default
        content.categoryIdentifier = "TIMESHEET_REMINDER"
        
        // Schedule for each configured day
        for day in days {
            var dateComponents = time
            dateComponents.weekday = day
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )
            
            let request = UNNotificationRequest(
                identifier: "timesheet-reminder-\(day)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
            } catch {
                print("Failed to schedule notification: \(error)")
            }
        }
        
        // Register notification actions
        await registerNotificationActions()
        #endif
    }
    
    /// Register notification action categories
    private func registerNotificationActions() async {
        #if canImport(UserNotifications)
        let sendAction = UNNotificationAction(
            identifier: "SEND_TIMESHEET",
            title: "Send Timesheet",
            options: [.foreground]
        )
        
        let remindLaterAction = UNNotificationAction(
            identifier: "REMIND_LATER",
            title: "Remind in 1 Hour",
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "TIMESHEET_REMINDER",
            actions: [sendAction, remindLaterAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([category])
        #endif
    }
    
    /// Cancel all timesheet reminder notifications
    private func cancelTimesheetReminders() {
        #if canImport(UserNotifications)
        let identifiers = (1...7).map { "timesheet-reminder-\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        #endif
    }
    
    /// Cancel all notifications
    public func cancelAllNotifications() {
        #if canImport(UserNotifications)
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        #endif
    }
    
    /// Schedule a one-time reminder
    public func scheduleOneTimeReminder(in seconds: TimeInterval, title: String, body: String) async {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "one-time-reminder-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to schedule one-time notification: \(error)")
        }
        #endif
    }
    
    /// Get pending notification requests
    public func getPendingNotifications() async -> [String] {
        #if canImport(UserNotifications)
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.map { $0.identifier }
        #else
        return []
        #endif
    }
}

/// Notification action identifiers
public enum NotificationAction: String {
    case sendTimesheet = "SEND_TIMESHEET"
    case remindLater = "REMIND_LATER"
    case dismiss = "DISMISS"
}

#endif // !SKIP
