import SwiftUI
import MessageUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Timesheet tab for viewing and sending timesheets
struct TimesheetTab: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var showTimesheetPreview = false
    @State private var showMailComposer = false
    @State private var currentTimesheet: Timesheet?
    @State private var csvFileURL: URL?
    @State private var emailSubject: String = ""
    @State private var emailBody: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current period summary
                    currentPeriodSection
                    
                    // Quick actions
                    actionsSection
                    
                    // Past timesheets
                    pastTimesheetsSection
                }
                .padding()
            }
            .navigationTitle("Timesheet")
            .onAppear {
                currentTimesheet = viewModel.generateTimesheet()
            }
            .onChange(of: viewModel.allEntries.count) { _, _ in
                currentTimesheet = viewModel.generateTimesheet()
            }
            .sheet(isPresented: $showTimesheetPreview) {
                TimesheetPreviewView(viewModel: viewModel)
            }
            .sheet(isPresented: $showMailComposer) {
                if let url = csvFileURL {
                    MailComposerView(
                        subject: emailSubject,
                        body: emailBody,
                        attachmentURL: url,
                        recipients: viewModel.configuration.approverEmail.isEmpty ? [] : [viewModel.configuration.approverEmail]
                    )
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var currentPeriodSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Period")
                    .font(.headline)
                Spacer()
                Text(viewModel.configuration.timesheetPeriod.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            // Period stats - use cached timesheet
            if let timesheet = currentTimesheet {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(timesheet.periodDescription)
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack(spacing: 24) {
                        VStack(alignment: .leading) {
                            Text(timesheet.formattedTotalHours)
                                .font(.title.weight(.bold))
                            Text("Total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack(alignment: .leading) {
                            Text("\(timesheet.entries.count)")
                                .font(.title.weight(.bold))
                            Text("Entries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack(alignment: .leading) {
                            let uniqueDays = Set(timesheet.entries.map { Calendar.current.startOfDay(for: $0.startTime) }).count
                            Text("\(uniqueDays)")
                                .font(.title.weight(.bold))
                            Text("Days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ProgressView()
                    .padding()
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Preview button
            Button {
                _ = viewModel.generateTimesheet()
                showTimesheetPreview = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Preview Timesheet")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            // Send options header
            Text("Send Options")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            
            // Option 1: Email with embedded timesheet (text in body)
            Button(action: { sendEmailEmbedded() }) {
                HStack {
                    Image(systemName: "doc.plaintext")
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email with Embedded Timesheet")
                            .font(.subheadline.weight(.medium))
                        Text("Timesheet details in email body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            // Option 2: Email with CSV attachment
            Button(action: { sendEmailWithAttachment() }) {
                HStack {
                    Image(systemName: "paperclip")
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email with CSV Attachment")
                            .font(.subheadline.weight(.medium))
                        Text("Timesheet as attached spreadsheet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Email Actions
    
    private func sendEmailEmbedded() {
        guard let timesheet = currentTimesheet ?? viewModel.generateTimesheet() as Timesheet? else { return }
        
        let subject = generateEmailSubject(timesheet)
        let body = generateEmailBodyDetailed(timesheet)
        let recipient = viewModel.configuration.approverEmail
        
        // Create mailto URL
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendEmailWithAttachment() {
        guard let timesheet = currentTimesheet ?? viewModel.generateTimesheet() as Timesheet? else { return }
        
        // Generate CSV content and save to temp file
        let csv = generateCSV(timesheet)
        let fileName = "Timesheet_\(formatFileDate(timesheet.periodStart))_to_\(formatFileDate(timesheet.periodEnd)).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvFileURL = tempURL
            emailSubject = generateEmailSubject(timesheet)
            emailBody = generateEmailBodyShort(timesheet)
            showMailComposer = true
        } catch {
            viewModel.errorMessage = "Failed to create CSV file: \(error.localizedDescription)"
        }
    }
    
    private func generateEmailSubject(_ timesheet: Timesheet) -> String {
        let userName = viewModel.configuration.userName
        if userName.isEmpty {
            return "Timesheet for \(timesheet.periodDescription)"
        } else {
            return "\(userName) - Timesheet for \(timesheet.periodDescription)"
        }
    }
    
    private func generateEmailBodyDetailed(_ timesheet: Timesheet) -> String {
        let userName = viewModel.configuration.userName
        var body = "Hi,\n\n"
        body += "Please find my timesheet for the period \(timesheet.periodDescription).\n\n"
        body += "Total Hours: \(timesheet.formattedTotalHours)\n\n"
        body += "--- Details ---\n"
        
        let grouped = timesheet.entries.groupedByDate()
        let sortedDates = grouped.keys.sorted()
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE, MMM d"
        
        for date in sortedDates {
            guard let dayEntries = grouped[date] else { continue }
            body += "\n\(dayFormatter.string(from: date)):\n"
            
            for entry in dayEntries {
                let desc = entry.displayDescription ?? "No description"
                body += "  • \(entry.formattedDuration): \(desc)\n"
            }
            
            let dayTotal = dayEntries.totalDuration / 3600.0
            body += "  Day Total: \(String(format: "%.1f", dayTotal)) hours\n"
        }
        
        body += "\n---\n\n"
        body += "Please let me know if you have any questions.\n\n"
        body += "Best regards"
        if !userName.isEmpty {
            body += ",\n\(userName)"
        }
        
        return body
    }
    
    private func generateEmailBodyShort(_ timesheet: Timesheet) -> String {
        let userName = viewModel.configuration.userName
        var body = "Hi,\n\n"
        body += "Please find my timesheet attached for the period \(timesheet.periodDescription).\n\n"
        body += "Summary:\n"
        body += "• Total Hours: \(timesheet.formattedTotalHours)\n"
        body += "• Entries: \(timesheet.entries.count)\n"
        body += "• Days Worked: \(Set(timesheet.entries.map { Calendar.current.startOfDay(for: $0.startTime) }).count)\n\n"
        body += "Please let me know if you have any questions.\n\n"
        body += "Best regards"
        if !userName.isEmpty {
            body += ",\n\(userName)"
        }
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
    
    private var pastTimesheetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Timesheets")
                .font(.headline)
            
            // Load past timesheets
            if let timesheets = try? StorageService.shared.loadTimesheets(), !timesheets.isEmpty {
                VStack(spacing: 8) {
                    ForEach(timesheets.prefix(5)) { timesheet in
                        PastTimesheetRow(timesheet: timesheet)
                    }
                }
            } else {
                Text("No timesheets sent yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }
}

// MARK: - Past Timesheet Row

struct PastTimesheetRow: View {
    let timesheet: Timesheet
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(timesheet.periodDescription)
                    .font(.subheadline)
                
                HStack(spacing: 8) {
                    StatusBadge(status: timesheet.status)
                    
                    if let submittedAt = timesheet.submittedAt {
                        Text("Sent \(formatDate(submittedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(timesheet.formattedTotalHours)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Mail Composer

struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let attachmentURL: URL
    let recipients: [String]
    
    @Environment(\.dismiss) private var dismiss
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        composer.setToRecipients(recipients.isEmpty ? nil : recipients)
        
        // Attach CSV file
        if let data = try? Data(contentsOf: attachmentURL) {
            let fileName = attachmentURL.lastPathComponent
            composer.addAttachmentData(data, mimeType: "text/csv", fileName: fileName)
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

// MARK: - Previews

#if DEBUG
struct TimesheetTab_Previews: PreviewProvider {
    static var previews: some View {
        TimesheetTab(viewModel: .preview)
    }
}
#endif
