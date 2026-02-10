import Foundation
#if canImport(SkipFoundation)
import SkipFoundation
#endif

/// Represents a timesheet for a specific period (typically a week or month)
public struct Timesheet: Codable, Identifiable, Hashable {
    public var id: UUID
    public var periodStart: Date
    public var periodEnd: Date
    public var entries: [TimeEntry]
    public var status: TimesheetStatus
    public var submittedAt: Date?
    public var approvedAt: Date?
    public var notes: String?
    
    /// Total hours worked in this timesheet
    public var totalHours: Double {
        entries.totalDuration / 3600.0
    }
    
    /// Formatted total hours
    public var formattedTotalHours: String {
        String(format: "%.1f hours", totalHours)
    }
    
    /// Human-readable period description
    public var periodDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: periodStart)) - \(formatter.string(from: periodEnd))"
    }
    
    public init(
        id: UUID = UUID(),
        periodStart: Date,
        periodEnd: Date,
        entries: [TimeEntry] = [],
        status: TimesheetStatus = .draft,
        submittedAt: Date? = nil,
        approvedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.entries = entries
        self.status = status
        self.submittedAt = submittedAt
        self.approvedAt = approvedAt
        self.notes = notes
    }
    
    /// Create a timesheet for the current week
    public static func currentWeek(calendar: Calendar = .current) -> Timesheet {
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        
        return Timesheet(
            periodStart: weekStart,
            periodEnd: weekEnd
        )
    }
    
    /// Create a timesheet for the current month
    public static func currentMonth(calendar: Calendar = .current) -> Timesheet {
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
        
        return Timesheet(
            periodStart: monthStart,
            periodEnd: monthEnd
        )
    }
    
    /// Generate email body for this timesheet
    public func generateEmailBody(template: String, userName: String) -> String {
        var body = template
        body = body.replacingOccurrences(of: "{{userName}}", with: userName)
        body = body.replacingOccurrences(of: "{{periodStart}}", with: formatDate(periodStart))
        body = body.replacingOccurrences(of: "{{periodEnd}}", with: formatDate(periodEnd))
        body = body.replacingOccurrences(of: "{{totalHours}}", with: formattedTotalHours)
        body = body.replacingOccurrences(of: "{{entriesSummary}}", with: generateEntriesSummary())
        return body
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func generateEntriesSummary() -> String {
        let grouped = entries.groupedByDate()
        let sortedDates = grouped.keys.sorted()
        
        var summary = ""
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        
        for date in sortedDates {
            guard let dayEntries = grouped[date] else { continue }
            summary += "\n\(dateFormatter.string(from: date)):\n"
            
            for entry in dayEntries {
                summary += "  - \(entry.formattedDuration): \(entry.displayDescription ?? "No description")\n"
            }
            
            let dayTotal = dayEntries.totalDuration / 3600.0
            summary += "  Total: \(String(format: "%.1f", dayTotal)) hours\n"
        }
        
        return summary
    }
}

/// Status of a timesheet
public enum TimesheetStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case submitted = "Submitted"
    case approved = "Approved"
    case rejected = "Rejected"
    
    public var displayName: String {
        rawValue
    }
    
    public var iconName: String {
        switch self {
        case .draft: return "doc.text"
        case .submitted: return "paperplane.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
}
