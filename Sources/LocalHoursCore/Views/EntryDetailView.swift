import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Detail view for editing a time entry
public struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let entry: TimeEntry
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var description: String
    @State private var projectName: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var hasChanges = false
    
    public init(entry: TimeEntry, viewModel: TimeTrackingViewModel) {
        self.entry = entry
        self.viewModel = viewModel
        _description = State(initialValue: entry.description)
        _projectName = State(initialValue: entry.projectName ?? "")
        _startTime = State(initialValue: entry.startTime)
        _endTime = State(initialValue: entry.endTime ?? Date())
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Description") {
                    TextField("What did you work on?", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: description) { _, _ in hasChanges = true }
                }
                
                Section("Project") {
                    TextField("Project name (optional)", text: $projectName)
                        .onChange(of: projectName) { _, _ in hasChanges = true }
                }
                
                Section("Time") {
                    DatePicker("Start", selection: $startTime)
                        .onChange(of: startTime) { _, _ in hasChanges = true }
                    
                    if !entry.isActive {
                        DatePicker("End", selection: $endTime)
                            .onChange(of: endTime) { _, _ in hasChanges = true }
                    }
                }
                
                Section {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formattedDuration)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if entry.isActive {
                    Section {
                        Button("Stop Timer", role: .destructive) {
                            viewModel.stopClock(
                                description: description,
                                projectName: projectName.isEmpty ? nil : projectName
                            )
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDuration: String {
        let end = entry.isActive ? Date() : endTime
        let duration = end.timeIntervalSince(startTime)
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        var updatedEntry = entry
        updatedEntry.description = description
        updatedEntry.projectName = projectName.isEmpty ? nil : projectName
        updatedEntry.startTime = startTime
        
        if !entry.isActive {
            updatedEntry.endTime = endTime
        }
        
        viewModel.updateEntry(updatedEntry)
        dismiss()
    }
}

// MARK: - Previews

#if DEBUG
struct EntryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let entry = TimeEntry(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            description: "Working on feature",
            projectName: "Project Alpha"
        )
        
        EntryDetailView(entry: entry, viewModel: .preview)
    }
}
#endif
