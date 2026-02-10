import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Timer tab for starting/stopping time tracking
struct TimerTab: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var showStopSheet = false
    @State private var entryDescription = ""
    @State private var projectName = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Main timer display
                    timerSection
                    
                    // Quick stats
                    statsSection
                    
                    // Recent entries
                    recentEntriesSection
                }
                .padding()
            }
            .navigationTitle("Timer")
            .sheet(isPresented: $showStopSheet) {
                StopTimerSheet(
                    viewModel: viewModel,
                    description: $entryDescription,
                    projectName: $projectName,
                    isPresented: $showStopSheet
                )
                .presentationDetents([.medium])
            }
            .onChange(of: viewModel.showStopDialogFromWidget) { _, shouldShow in
                if shouldShow {
                    showStopSheet = true
                    viewModel.showStopDialogFromWidget = false
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var timerSection: some View {
        VStack(spacing: 24) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isTracking ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.isTracking ? "Tracking" : "Ready")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Timer display
            Text(viewModel.currentElapsedFormatted)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.isTracking ? .primary : .secondary)
            
            // Control buttons
            HStack(spacing: 16) {
                if viewModel.isTracking {
                    // Cancel button
                    Button {
                        viewModel.cancelTracking()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.gray)
                            .clipShape(Circle())
                    }
                    
                    // Stop button
                    Button {
                        showStopSheet = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                } else {
                    // Start button
                    Button {
                        viewModel.startClock()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 24)
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Today",
                value: viewModel.todayTotalFormatted,
                icon: "sun.max.fill",
                color: .orange
            )
            
            StatCard(
                title: "This Week",
                value: viewModel.thisWeekTotalFormatted,
                icon: "calendar",
                color: .blue
            )
        }
    }
    
    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Entries")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink {
                    EntryListView(viewModel: viewModel)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
            }
            
            if viewModel.todayEntries.isEmpty {
                Text("No entries yet today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.todayEntries.prefix(3)) { entry in
                        CompactEntryRow(entry: entry)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3.weight(.semibold))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CompactEntryRow: View {
    let entry: TimeEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayDescription ?? "No description")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(entry.displayDescription == nil ? .secondary : .primary)
                
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
                }
            }
            
            Spacer()
            
            Text(entry.formattedDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: entry.startTime)
        let end = entry.endTime.map { formatter.string(from: $0) } ?? "now"
        
        return "\(start) - \(end)"
    }
}

/// Sheet for stopping timer with description (iOS version)
struct StopTimerSheet: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @Binding var description: String
    @Binding var projectName: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(viewModel.currentElapsedFormatted)
                        .font(.system(size: 36, weight: .light, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                
                Section("Description") {
                    TextField("What did you work on?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Project (optional)") {
                    TextField("Project name", text: $projectName)
                }
            }
            .navigationTitle("Stop Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        description = ""
                        projectName = ""
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.stopClock(
                            description: description,
                            projectName: projectName.isEmpty ? nil : projectName
                        )
                        description = ""
                        projectName = ""
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct TimerTab_Previews: PreviewProvider {
    static var previews: some View {
        TimerTab(viewModel: .preview)
    }
}
#endif
