import SwiftUI
import AppKit

/// Main menu bar popover content
struct MenuBarView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var showStopDialog = false
    @State private var entryDescription = ""
    @State private var projectName = ""
    @State private var showTimesheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if showTimesheet {
                timesheetView
            } else {
                mainView
            }
        }
        .frame(width: 340)
    }
    
    // MARK: - Main View
    
    private var mainView: some View {
        VStack(spacing: 0) {
            // Timer section or inline stop form (avoids sheet so menu bar window stays open)
            if showStopDialog {
                stopFormInline
            } else {
                timerSection
            }
            
            Divider()
            
            // Today's entries
            todaySection
            
            Divider()
            
            // Actions
            actionsSection
        }
    }
    
    /// Inline stop-timer form so Save doesn’t dismiss a sheet and close the menu bar window.
    private var stopFormInline: some View {
        StopTimerInline(
            viewModel: viewModel,
            description: $entryDescription,
            projectName: $projectName,
            isPresented: $showStopDialog
        )
        .padding()
    }
    
    // MARK: - Timesheet View (Inline)
    
    private var timesheetView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    showTimesheet = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Timesheet")
                    .font(.headline)
                
                Spacer()
                
                // Spacer to balance the back button
                Text("Back")
                    .opacity(0)
            }
            .padding()
            
            Divider()
            
            // Timesheet content
            TimesheetInlineView(viewModel: viewModel)
        }
    }
    
    // MARK: - Timer Section
    
    private var timerSection: some View {
        VStack(spacing: 12) {
            // Status indicator
            HStack {
                Circle()
                    .fill(viewModel.isTracking ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.isTracking ? "Tracking" : "Not tracking")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // Timer display
            Text(viewModel.currentElapsedFormatted)
                .font(.system(size: 42, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.isTracking ? .primary : .secondary)
            
            // Start/Stop button
            Button(action: handleTimerButton) {
                HStack {
                    Image(systemName: viewModel.isTracking ? "stop.fill" : "play.fill")
                    Text(viewModel.isTracking ? "Stop" : "Start")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isTracking ? .red : .green)
            .controlSize(.large)
            
            // Today's total
            HStack {
                Text("Today:")
                    .foregroundStyle(.secondary)
                Text(viewModel.todayTotalFormatted)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("Week:")
                    .foregroundStyle(.secondary)
                Text(viewModel.thisWeekTotalFormatted)
                    .fontWeight(.medium)
            }
            .font(.caption)
        }
        .padding()
    }
    
    // MARK: - Today Section
    
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Entries")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(viewModel.todayEntries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if viewModel.todayEntries.isEmpty {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.todayEntries.prefix(5)) { entry in
                            MenuBarEntryRow(entry: entry)
                        }
                        
                        if viewModel.todayEntries.count > 5 {
                            Text("+ \(viewModel.todayEntries.count - 5) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding()
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 4) {
            // Preview Timesheet button
            Button {
                showTimesheet = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Preview Timesheet")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Email with Embedded Timesheet
            Button {
                sendEmailEmbedded()
            } label: {
                HStack {
                    Image(systemName: "doc.plaintext")
                    Text("Email with Embedded Timesheet")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Email with CSV Attachment
            Button {
                sendEmailWithAttachment()
            } label: {
                HStack {
                    Image(systemName: "paperclip")
                    Text("Email with CSV Attachment")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit SimpleTimesheet")
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Email Actions
    
    private func sendEmailEmbedded() {
        let timesheet = viewModel.generateTimesheet()
        let config = viewModel.configuration
        let userName = config.userName.isEmpty ? "Team Member" : config.userName
        let subject = "\(userName) - Timesheet for \(timesheet.periodDescription)"
        let body = generateEmailBodyDetailed(timesheet, userName: userName)
        
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = config.approverEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func sendEmailWithAttachment() {
        let timesheet = viewModel.generateTimesheet()
        let config = viewModel.configuration
        let userName = config.userName.isEmpty ? "Team Member" : config.userName
        
        // Generate CSV
        let csv = generateCSV(timesheet)
        let fileName = "Timesheet_\(formatFileDate(timesheet.periodStart))_to_\(formatFileDate(timesheet.periodEnd)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            
            let subject = "\(userName) - Timesheet for \(timesheet.periodDescription)"
            let body = generateEmailBodyShort(timesheet, userName: userName)
            
            // Use NSSharingService for email with attachment
            if let service = NSSharingService(named: .composeEmail) {
                service.recipients = config.approverEmail.isEmpty ? [] : [config.approverEmail]
                service.subject = subject
                service.perform(withItems: [body, tempURL])
            }
        } catch {
            viewModel.errorMessage = "Failed to create CSV file: \(error.localizedDescription)"
        }
    }
    
    private func generateEmailBodyDetailed(_ timesheet: Timesheet, userName: String) -> String {
        var body = "Hi,\n\n"
        body += "Please find my timesheet for \(timesheet.periodDescription).\n\n"
        
        body += "SUMMARY\n"
        body += "═══════════════════════════════════════════\n"
        body += "Period:       \(timesheet.periodDescription)\n"
        body += "Total Hours:  \(timesheet.formattedTotalHours)\n"
        let daysCount = Set(timesheet.entries.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        body += "Total Days:   \(daysCount)\n"
        body += "═══════════════════════════════════════════\n\n"
        
        body += "DETAILED TIME ENTRIES\n"
        body += "───────────────────────────────────────────\n"
        
        let grouped = timesheet.entries.groupedByDate()
        let sortedDates = grouped.keys.sorted()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"
        
        for date in sortedDates {
            guard let dayEntries = grouped[date] else { continue }
            let dayTotal = dayEntries.totalDuration / 3600.0
            
            body += "\n\(dayFormatter.string(from: date))                    Total: \(String(format: "%.1fh", dayTotal))\n"
            body += "───────────────────────────────────────────\n"
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            for entry in dayEntries {
                let desc = entry.description.isEmpty ? "(No description)" : entry.description
                let start = timeFormatter.string(from: entry.startTime)
                let end = entry.endTime.map { timeFormatter.string(from: $0) } ?? "now"
                let timeRange = "\(start)-\(end)"
                body += "\(timeRange.padding(toLength: 18, withPad: " ", startingAt: 0)) \(entry.formattedDuration.padding(toLength: 8, withPad: " ", startingAt: 0)) \(desc)\n"
            }
        }
        
        body += "\n═══════════════════════════════════════════\n"
        body += "GRAND TOTAL: \(timesheet.formattedTotalHours)\n"
        body += "═══════════════════════════════════════════\n"
        
        body += "\nPlease let me know if you have any questions.\n\n"
        body += "Best regards,\n\(userName)"
        
        return body
    }
    
    private func generateEmailBodyShort(_ timesheet: Timesheet, userName: String) -> String {
        var body = "Hi,\n\n"
        body += "Please find my timesheet attached for the period \(timesheet.periodDescription).\n\n"
        body += "Summary:\n"
        body += "• Total Hours: \(timesheet.formattedTotalHours)\n"
        body += "• Entries: \(timesheet.entries.count)\n"
        let daysCount = Set(timesheet.entries.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        body += "• Days Worked: \(daysCount)\n\n"
        body += "Please let me know if you have any questions.\n\n"
        body += "Best regards,\n\(userName)"
        return body
    }
    
    private func generateCSV(_ timesheet: Timesheet) -> String {
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
            // Escape quotes by doubling them (CSV standard)
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
    
    private func formatFileDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    
    private func handleTimerButton() {
        if viewModel.isTracking {
            showStopDialog = true
        } else {
            viewModel.startClock()
        }
    }
}

// MARK: - Timesheet Inline View

struct TimesheetInlineView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @State private var timesheet: Timesheet?
    
    var body: some View {
        ScrollView {
            if let timesheet = timesheet {
                VStack(alignment: .leading, spacing: 16) {
                    // Summary
                    HStack {
                        Image(systemName: "calendar")
                        Text(timesheet.periodDescription)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                    
                    // Stats
                    HStack(spacing: 12) {
                        StatBox(title: "Hours", value: timesheet.formattedTotalHours)
                        StatBox(title: "Entries", value: "\(timesheet.entries.count)")
                        StatBox(title: "Days", value: "\(uniqueDaysCount(timesheet))")
                    }
                    
                    Divider()
                    
                    // Entries
                    Text("Entries")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    if timesheet.entries.isEmpty {
                        Text("No entries for this period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        let grouped = timesheet.entries.groupedByDate()
                        ForEach(grouped.keys.sorted(), id: \.self) { date in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(formatDate(date))
                                        .font(.caption.weight(.medium))
                                    Spacer()
                                    Text(dayTotal(for: date, grouped: grouped))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                ForEach(grouped[date] ?? []) { entry in
                                    HStack {
                                        Text(entry.description.isEmpty ? "No description" : entry.description)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundStyle(entry.description.isEmpty ? .secondary : .primary)
                                        Spacer()
                                        Text(entry.formattedDuration)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
                    .padding()
            }
        }
        .frame(maxHeight: 400)
        .onAppear {
            timesheet = viewModel.generateTimesheet()
        }
    }
    
    private func uniqueDaysCount(_ timesheet: Timesheet) -> Int {
        Set(timesheet.entries.map { Calendar.current.startOfDay(for: $0.startTime) }).count
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func dayTotal(for date: Date, grouped: [Date: [TimeEntry]]) -> String {
        let entries = grouped[date] ?? []
        let hours = entries.totalDuration / 3600.0
        return String(format: "%.1fh", hours)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Entry Row

struct MenuBarEntryRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description.isEmpty ? "No description" : entry.description)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(entry.description.isEmpty ? .secondary : .primary)
                
                Text(formatTimeRange())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(entry.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: entry.startTime)
        let end = entry.endTime.map { formatter.string(from: $0) } ?? "now"
        
        return "\(start) - \(end)"
    }
}

// MARK: - Stop Timer (inline, no sheet — keeps menu bar window open on Save)

struct StopTimerInline: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @Binding var description: String
    @Binding var projectName: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Stop Timer")
                .font(.headline)
            
            Text("Duration: \(viewModel.currentElapsedFormatted)")
                .font(.title2.monospacedDigit())
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("What did you work on?", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Project (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Project name", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Button("Cancel") {
                    description = ""
                    projectName = ""
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Discard") {
                    viewModel.cancelTracking()
                    description = ""
                    projectName = ""
                    isPresented = false
                }
                .foregroundStyle(.red)
                
                Button("Save") {
                    viewModel.stopClock(
                        description: description,
                        projectName: projectName.isEmpty ? nil : projectName
                    )
                    description = ""
                    projectName = ""
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView(viewModel: .preview)
    }
}
#endif
