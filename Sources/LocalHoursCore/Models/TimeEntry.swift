import Foundation
#if canImport(SkipFoundation)
import SkipFoundation
#endif

/// Represents a single time entry with start/end times and description
public struct TimeEntry: Codable, Identifiable, Hashable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var description: String
    public var projectName: String?
    public var tags: [String]
    
    /// Duration in seconds
    public var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Duration formatted as hours and minutes
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    /// Whether this entry is currently active (no end time)
    public var isActive: Bool {
        endTime == nil
    }
    
    /// Returns the best available description for display purposes.
    /// Prefers `description`, falls back to `projectName`, or returns nil if both are empty.
    public var displayDescription: String? {
        if !description.isEmpty {
            return description
        }
        if let project = projectName, !project.isEmpty {
            return project
        }
        return nil
    }
    
    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        description: String = "",
        projectName: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.description = description
        self.projectName = projectName
        self.tags = tags
    }
    
    /// Stop this time entry
    public mutating func stop(withDescription description: String) {
        self.endTime = Date()
        self.description = description
    }
}

// MARK: - Time Entry Collection Extensions

public extension Array where Element == TimeEntry {
    /// Total duration of all entries in seconds
    var totalDuration: TimeInterval {
        reduce(0) { $0 + $1.duration }
    }
    
    /// Formatted total duration
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    /// Filter entries for a specific date
    func entries(for date: Date, in calendar: Calendar = .current) -> [TimeEntry] {
        filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
    /// Filter entries for a date range
    func entries(from startDate: Date, to endDate: Date) -> [TimeEntry] {
        filter { entry in
            entry.startTime >= startDate && entry.startTime <= endDate
        }
    }
    
    /// Group entries by date
    func groupedByDate(calendar: Calendar = .current) -> [Date: [TimeEntry]] {
        var result: [Date: [TimeEntry]] = [:]
        for entry in self {
            let day = calendar.startOfDay(for: entry.startTime)
            if result[day] != nil {
                result[day]?.append(entry)
            } else {
                result[day] = [entry]
            }
        }
        return result
    }
}
