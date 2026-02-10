import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Displays a list of time entries
public struct EntryListView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var selectedEntry: TimeEntry?
    @State private var showDeleteConfirmation = false
    @State private var entryToDelete: TimeEntry?
    
    public init(viewModel: TimeTrackingViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if viewModel.allEntries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .alert("Delete Entry", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    viewModel.deleteEntry(entry)
                }
                entryToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this entry? This action cannot be undone.")
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailView(entry: entry, viewModel: viewModel)
        }
    }
    
    // MARK: - Subviews
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No time entries yet")
                .font(.headline)
            
            Text("Start tracking time to see your entries here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var entryList: some View {
        List {
            ForEach(groupedEntries.keys.sorted().reversed(), id: \.self) { date in
                Section {
                    ForEach(groupedEntries[date] ?? []) { entry in
                        EntryRowView(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    entryToDelete = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(formatSectionDate(date))
                        Spacer()
                        Text(formatDayTotal(for: date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }
    
    // MARK: - Helpers
    
    private var groupedEntries: [Date: [TimeEntry]] {
        viewModel.allEntries.groupedByDate()
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func formatDayTotal(for date: Date) -> String {
        let entries = groupedEntries[date] ?? []
        let total = entries.totalDuration
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

/// Row view for a single time entry
public struct EntryRowView: View {
    let entry: TimeEntry
    
    public init(entry: TimeEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(entry.isActive ? Color.green : Color.blue)
                    .frame(width: 10, height: 10)
                
                if !entry.isActive {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                }
            }
            .frame(width: 10)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.displayDescription ?? "No description")
                        .font(.body)
                        .foregroundStyle(entry.displayDescription == nil ? .secondary : .primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(entry.formattedDuration)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 8) {
                    // Time range
                    Text(formatTimeRange())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Project badge
                    if let project = entry.projectName {
                        Text(project)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    // Active indicator
                    if entry.isActive {
                        Text("In Progress")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: entry.startTime)
        
        if let endTime = entry.endTime {
            let end = formatter.string(from: endTime)
            return "\(start) - \(end)"
        }
        
        return "\(start) - now"
    }
}

// MARK: - Previews

#if DEBUG
struct EntryListView_Previews: PreviewProvider {
    static var previews: some View {
        EntryListView(viewModel: .preview)
    }
}
#endif
