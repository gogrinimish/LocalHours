import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// History tab showing all time entries
struct HistoryTab: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var searchText = ""
    @State private var selectedFilter = HistoryFilter.all
    @State private var selectedEntry: TimeEntry?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                filterPicker
                
                // Entry list
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search entries")
            .sheet(item: $selectedEntry) { entry in
                EntryDetailView(entry: entry, viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No entries found")
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try a different search term"
        }
        
        switch selectedFilter {
        case .all:
            return "Start tracking time to see your history"
        case .today:
            return "No entries recorded today"
        case .thisWeek:
            return "No entries recorded this week"
        case .thisMonth:
            return "No entries recorded this month"
        }
    }
    
    private var entryList: some View {
        List {
            // Summary header
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(filteredEntries.count) entries")
                            .font(.headline)
                        Text(filteredEntries.formattedTotalDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(String(format: "%.1f hrs", filteredEntries.totalDuration / 3600))
                            .font(.title2.weight(.semibold))
                        Text("total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Grouped entries
            ForEach(groupedEntries.keys.sorted().reversed(), id: \.self) { date in
                Section {
                    ForEach(groupedEntries[date] ?? []) { entry in
                        HistoryEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Text(formatSectionDate(date))
                        Spacer()
                        Text(formatDayTotal(groupedEntries[date] ?? []))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [TimeEntry] {
        var entries = viewModel.allEntries
        
        // Apply filter
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedFilter {
        case .all:
            break
        case .today:
            entries = entries.filter { calendar.isDateInToday($0.startTime) }
        case .thisWeek:
            if let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
                entries = entries.filter { $0.startTime >= weekStart }
            }
        case .thisMonth:
            if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) {
                entries = entries.filter { $0.startTime >= monthStart }
            }
        }
        
        // Apply search
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.description.localizedCaseInsensitiveContains(searchText) ||
                (entry.projectName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return entries
    }
    
    private var groupedEntries: [Date: [TimeEntry]] {
        filteredEntries.groupedByDate()
    }
    
    // MARK: - Helpers
    
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
    
    private func formatDayTotal(_ entries: [TimeEntry]) -> String {
        let total = entries.totalDuration / 3600.0
        return String(format: "%.1f hrs", total)
    }
}

// MARK: - Filter Enum

enum HistoryFilter: CaseIterable {
    case all
    case today
    case thisWeek
    case thisMonth
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .thisWeek: return "Week"
        case .thisMonth: return "Month"
        }
    }
}

// MARK: - Entry Row

struct HistoryEntryRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time indicator
            Circle()
                .fill(entry.isActive ? Color.green : Color.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayDescription ?? "No description")
                    .font(.body)
                    .foregroundStyle(entry.displayDescription == nil ? .secondary : .primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text(formatTimeRange())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let project = entry.projectName {
                        Text(project)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    if entry.isActive {
                        Text("In Progress")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            Text(entry.formattedDuration)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
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
struct HistoryTab_Previews: PreviewProvider {
    static var previews: some View {
        HistoryTab(viewModel: .preview)
    }
}
#endif
