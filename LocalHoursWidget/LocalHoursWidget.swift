import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Bundle

@main
struct LocalHoursWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        SummaryWidget()
    }
}

// MARK: - Shared Data Provider

struct TimesheetEntry: TimelineEntry {
    let date: Date
    let isTracking: Bool
    let elapsedTime: TimeInterval
    let todayTotal: TimeInterval
    let weekTotal: TimeInterval
    let entryCount: Int
    let trackingStartTime: Date?  // For live timer display
}

struct TimesheetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimesheetEntry {
        TimesheetEntry(
            date: Date(),
            isTracking: false,
            elapsedTime: 0,
            todayTotal: 3600 * 4.5,
            weekTotal: 3600 * 32,
            entryCount: 5,
            trackingStartTime: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TimesheetEntry) -> Void) {
        let entry = loadCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimesheetEntry>) -> Void) {
        let entry = loadCurrentEntry()
        
        // Update more frequently if tracking
        let nextUpdate: Date
        if entry.isTracking {
            nextUpdate = Date().addingTimeInterval(60) // Update every minute when tracking
        } else {
            nextUpdate = Date().addingTimeInterval(300) // Update every 5 minutes when idle
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> TimesheetEntry {
        // Load from shared UserDefaults/App Group
        let defaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
        
        let isTracking = defaults.bool(forKey: "isTracking")
        let startTime = defaults.object(forKey: "trackingStartTime") as? Date
        let todayTotal = defaults.double(forKey: "todayTotal")
        let weekTotal = defaults.double(forKey: "weekTotal")
        let entryCount = defaults.integer(forKey: "todayEntryCount")
        
        var elapsedTime: TimeInterval = 0
        if isTracking, let start = startTime {
            elapsedTime = Date().timeIntervalSince(start)
        }
        
        return TimesheetEntry(
            date: Date(),
            isTracking: isTracking,
            elapsedTime: elapsedTime,
            todayTotal: todayTotal,
            weekTotal: weekTotal,
            entryCount: entryCount,
            trackingStartTime: isTracking ? startTime : nil
        )
    }
}

// MARK: - Helper Extensions

extension TimeInterval {
    var widgetFormatted: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var hoursFormatted: String {
        let hours = self / 3600
        return String(format: "%.1fh", hours)
    }
}
