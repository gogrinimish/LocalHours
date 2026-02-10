import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
import MessageUI
#endif

/// Preview timesheet view (read-only)
public struct TimesheetPreviewView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var timesheet: Timesheet?
    
    public init(viewModel: TimeTrackingViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Timesheet")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    closeWindow()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                if let timesheet = timesheet {
                    timesheetContent(timesheet)
                } else {
                    ProgressView("Generating timesheet...")
                        .padding()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        #endif
        .onAppear {
            self.timesheet = viewModel.generateTimesheet()
        }
    }
    
    // MARK: - Close Window
    
    private func closeWindow() {
        #if os(macOS)
        // Find and close the window containing this view
        NSApplication.shared.keyWindow?.close()
        #else
        dismiss()
        #endif
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func timesheetContent(_ timesheet: Timesheet) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection(timesheet)
            
            Divider()
            
            // Summary
            summarySection(timesheet)
            
            Divider()
            
            // Entries by day
            entriesSection(timesheet)
        }
        .padding()
    }
    
    private func headerSection(_ timesheet: Timesheet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timesheet")
                .font(.title.weight(.bold))
            
            HStack {
                Image(systemName: "calendar")
                Text(timesheet.periodDescription)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            StatusBadge(status: timesheet.status)
        }
    }
    
    private func summarySection(_ timesheet: Timesheet) -> some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Total Hours",
                value: timesheet.formattedTotalHours,
                icon: "clock"
            )
            
            SummaryCard(
                title: "Entries",
                value: "\(timesheet.entries.count)",
                icon: "list.bullet"
            )
            
            SummaryCard(
                title: "Days",
                value: "\(Set(timesheet.entries.map { Calendar.current.startOfDay(for: $0.startTime) }).count)",
                icon: "calendar"
            )
        }
    }
    
    private func entriesSection(_ timesheet: Timesheet) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Entries")
                .font(.headline)
            
            let grouped = timesheet.entries.groupedByDate()
            let sortedDates = grouped.keys.sorted()
            
            if sortedDates.isEmpty {
                Text("No entries for this period")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(sortedDates, id: \.self) { date in
                    VStack(alignment: .leading, spacing: 8) {
                        // Day header
                        HStack {
                            Text(formatDayHeader(date))
                                .font(.subheadline.weight(.semibold))
                            
                            Spacer()
                            
                            Text(formatDayTotal(grouped[date] ?? []))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Entries for this day
                        ForEach(grouped[date] ?? []) { entry in
                            TimesheetEntryRow(entry: entry)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDayHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func formatDayTotal(_ entries: [TimeEntry]) -> String {
        let total = entries.totalDuration
        let hours = total / 3600.0
        return String(format: "%.1f hrs", hours)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title2.weight(.bold))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusBadge: View {
    let status: TimesheetStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
            Text(status.displayName)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .draft: return Color.gray.opacity(0.2)
        case .submitted: return Color.blue.opacity(0.2)
        case .approved: return Color.green.opacity(0.2)
        case .rejected: return Color.red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .draft: return .gray
        case .submitted: return .blue
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

struct TimesheetEntryRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayDescription ?? "No description")
                    .font(.subheadline)
                    .foregroundStyle(entry.displayDescription == nil ? .secondary : .primary)
                
                Text(formatTimeRange())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(entry.formattedDuration)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: entry.startTime)
        let end = entry.endTime.map { formatter.string(from: $0) } ?? "now"
        
        return "\(start) - \(end)"
    }
}

// MARK: - Previews

#if DEBUG
struct TimesheetPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        TimesheetPreviewView(viewModel: .preview)
    }
}
#endif
