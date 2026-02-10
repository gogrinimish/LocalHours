import AppIntents
import Foundation

// MARK: - App Shortcuts

struct LocalHoursShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTrackingIntent(),
            phrases: [
                "Start tracking time in \(.applicationName)",
                "Start \(.applicationName)",
                "Begin tracking with \(.applicationName)"
            ],
            shortTitle: "Start Tracking",
            systemImageName: "play.fill"
        )
        
        AppShortcut(
            intent: StopTrackingIntent(),
            phrases: [
                "Stop tracking time in \(.applicationName)",
                "Stop \(.applicationName)",
                "End tracking with \(.applicationName)"
            ],
            shortTitle: "Stop Tracking",
            systemImageName: "stop.fill"
        )
        
        AppShortcut(
            intent: ShowTimesheetIntent(),
            phrases: [
                "Show my timesheet in \(.applicationName)",
                "View timesheet in \(.applicationName)",
                "Show hours in \(.applicationName)"
            ],
            shortTitle: "Show Timesheet",
            systemImageName: "doc.text"
        )
    }
}

// MARK: - Start Tracking Intent

struct StartTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Time Tracking"
    static var description = IntentDescription("Start tracking your work time")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Access shared data
        let defaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
        
        // Check if already tracking
        if defaults.bool(forKey: "isTracking") {
            return .result(dialog: "You're already tracking time.")
        }
        
        // Start tracking
        defaults.set(true, forKey: "isTracking")
        defaults.set(Date(), forKey: "trackingStartTime")
        
        return .result(dialog: "Started tracking time. Good luck with your work!")
    }
}

// MARK: - Stop Tracking Intent

struct StopTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Time Tracking"
    static var description = IntentDescription("Stop tracking and save your time entry")
    static var openAppWhenRun: Bool = true // Open app to add description
    
    @Parameter(title: "Description")
    var description: String?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
        
        // Check if tracking
        guard defaults.bool(forKey: "isTracking"),
              let startTime = defaults.object(forKey: "trackingStartTime") as? Date else {
            return .result(dialog: "You're not currently tracking time.")
        }
        
        // Calculate duration
        let duration = Date().timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        // Stop tracking
        defaults.set(false, forKey: "isTracking")
        defaults.removeObject(forKey: "trackingStartTime")
        
        // Update totals
        let todayTotal = defaults.double(forKey: "todayTotal") + duration
        defaults.set(todayTotal, forKey: "todayTotal")
        
        let weekTotal = defaults.double(forKey: "weekTotal") + duration
        defaults.set(weekTotal, forKey: "weekTotal")
        
        let entryCount = defaults.integer(forKey: "todayEntryCount") + 1
        defaults.set(entryCount, forKey: "todayEntryCount")
        
        return .result(dialog: "Stopped tracking. You worked for \(hours)h \(minutes)m.")
    }
}

// MARK: - Show Timesheet Intent

struct ShowTimesheetIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Timesheet"
    static var description = IntentDescription("View your current timesheet")
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
        
        let todayTotal = defaults.double(forKey: "todayTotal")
        let weekTotal = defaults.double(forKey: "weekTotal")
        
        let todayHours = todayTotal / 3600
        let weekHours = weekTotal / 3600
        
        return .result(dialog: "Today: \(String(format: "%.1f", todayHours)) hours. This week: \(String(format: "%.1f", weekHours)) hours.")
    }
}

// MARK: - Get Status Intent

struct GetTrackingStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Tracking Status"
    static var description = IntentDescription("Check if you're currently tracking time")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
        
        if defaults.bool(forKey: "isTracking"),
           let startTime = defaults.object(forKey: "trackingStartTime") as? Date {
            let duration = Date().timeIntervalSince(startTime)
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            
            return .result(dialog: "You've been tracking for \(hours)h \(minutes)m.")
        } else {
            return .result(dialog: "You're not currently tracking time.")
        }
    }
}
