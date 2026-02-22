import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Configuration/Settings view for the app
public struct ConfigurationView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var config: AppConfiguration
    @State private var showFolderPicker = false
    @State private var validationErrors: [String] = []
    @State private var showValidationAlert = false
    
    public init(viewModel: TimeTrackingViewModel) {
        self.viewModel = viewModel
        _config = State(initialValue: viewModel.configuration)
    }
    
    public var body: some View {
        Form {
            // Storage Section
            storageSection
            
            // User Section
            userSection
            
            // Email Section
            emailSection
            
            // Notification Section
            notificationSection
            
            // Timesheet Section
            timesheetSection
            
            // Advanced Section
            advancedSection
            
            // About & Support Section
            aboutSection
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Configuration Errors", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationErrors.joined(separator: "\n"))
        }
        #if os(macOS)
        .frame(minWidth: 450, minHeight: 500)
        #endif
        .onDisappear {
            saveConfigurationSilent()
        }
        .onChange(of: config) { _, newConfig in
            saveConfigurationSilent()
        }
    }
    
    // MARK: - Sections
    
    private var storageSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.storageFolder.isEmpty ? "Not configured" : config.storageFolder)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text("Synced folder for cross-device access")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Choose...") {
                    showFolderPicker = true
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Label("Storage", systemImage: "folder")
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    private var userSection: some View {
        Section {
            TextField("Your Name", text: $config.userName)
                .textContentType(.name)
        } header: {
            Label("User", systemImage: "person")
        } footer: {
            Text("Used in email signatures")
        }
    }
    
    private var emailSection: some View {
        Section {
            TextField("Approver Email", text: $config.approverEmail)
                .textContentType(.emailAddress)
                #if os(iOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
            
            TextField("Email Subject", text: $config.emailSubject)
            
            NavigationLink {
                EmailTemplateEditorView(template: $config.emailTemplate)
            } label: {
                HStack {
                    Text("Email Template")
                    Spacer()
                    Text("Edit")
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle("Include detailed entries in email", isOn: $config.includeEntriesInEmail)
        } header: {
            Label("Email", systemImage: "envelope")
        }
    }
    
    private var notificationSection: some View {
        Section {
            HStack {
                Text("Reminder Time")
                Spacer()
                TextField("HH:mm", text: $config.notificationTime)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                    #endif
            }
            
            NavigationLink {
                NotificationDaysView(selectedDays: $config.notificationDays)
            } label: {
                HStack {
                    Text("Reminder Days")
                    Spacer()
                    Text(formatSelectedDays())
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Notifications", systemImage: "bell")
        } footer: {
            Text("Get reminded to submit your timesheet")
        }
    }
    
    private var timesheetSection: some View {
        Section {
            Picker("Period", selection: $config.timesheetPeriod) {
                ForEach(TimesheetPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            
            Picker("Timezone", selection: $config.timezoneIdentifier) {
                ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                    Text(identifier).tag(identifier)
                }
            }
        } header: {
            Label("Timesheet", systemImage: "doc.text")
        }
    }
    
    private var advancedSection: some View {
        Section {
            Toggle("Auto-start on app launch", isOn: $config.autoStartOnLaunch)
            Toggle("Confirm before sending", isOn: $config.confirmBeforeSending)
        } header: {
            Label("Advanced", systemImage: "gearshape.2")
        }
    }
    
    private var aboutSection: some View {
        Section {
            Link("View on GitHub", destination: URL(string: "https://github.com/gogrinimish/LocalHours")!)
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }
    
    // MARK: - Helpers
    
    private func formatSelectedDays() -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selected = config.notificationDays.compactMap { day -> String? in
            guard day >= 1 && day <= 7 else { return nil }
            return dayNames[day - 1]
        }
        return selected.isEmpty ? "None" : selected.joined(separator: ", ")
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else { return }
                // Don't stop access - keep it for the session
                
                config.storageFolder = url.path
                
                // Save bookmark for future access to shared app group
                let sharedDefaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
                #if os(macOS)
                if let bookmarkData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    sharedDefaults.set(bookmarkData, forKey: "storageFolderBookmark")
                    sharedDefaults.set(url.path, forKey: "storageFolderPath")
                }
                #else
                // iOS uses different file access patterns via document picker
                if let bookmarkData = try? url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    sharedDefaults.set(bookmarkData, forKey: "storageFolderBookmark")
                    sharedDefaults.set(url.path, forKey: "storageFolderPath")
                }
                #endif
            }
        case .failure(let error):
            viewModel.errorMessage = "Failed to select folder: \(error.localizedDescription)"
        }
    }
    
    private func saveConfiguration() {
        validationErrors = config.validate()
        
        if !validationErrors.isEmpty {
            showValidationAlert = true
            return
        }
        
        viewModel.updateConfiguration(config)
        
        // Update storage if path changed
        if config.storageFolder != viewModel.configuration.storageFolder {
            Task {
                try? await viewModel.setupStorage(path: config.storageFolder)
            }
        }
    }
    
    /// Save configuration silently (for auto-save)
    private func saveConfigurationSilent() {
        // Only save if validation passes
        let errors = config.validate()
        guard errors.isEmpty else { return }
        
        viewModel.updateConfiguration(config)
        
        // Update storage if path changed
        if config.storageFolder != viewModel.configuration.storageFolder {
            Task {
                try? await viewModel.setupStorage(path: config.storageFolder)
            }
        }
    }
}

/// View for editing email template
public struct EmailTemplateEditorView: View {
    @Binding var template: String
    
    public var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $template)
                .font(.body.monospaced())
                .padding(4)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Available placeholders:")
                    .font(.caption.weight(.semibold))
                Text("{{userName}}, {{periodStart}}, {{periodEnd}}, {{totalHours}}, {{entriesSummary}}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            #if os(iOS)
            .background(Color(.systemGray6))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
        }
        .navigationTitle("Email Template")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// View for selecting notification days
public struct NotificationDaysView: View {
    @Binding var selectedDays: [Int]
    
    private let days = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    public var body: some View {
        List {
            ForEach(days, id: \.0) { day, name in
                HStack {
                    Text(name)
                    Spacer()
                    if selectedDays.contains(day) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleDay(day)
                }
            }
        }
        .navigationTitle("Reminder Days")
    }
    
    private func toggleDay(_ day: Int) {
        if let index = selectedDays.firstIndex(of: day) {
            selectedDays.remove(at: index)
        } else {
            selectedDays.append(day)
            selectedDays.sort()
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ConfigurationView(viewModel: .preview)
        }
    }
}
#endif
