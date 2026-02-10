import SwiftUI

/// Settings window for macOS
struct SettingsView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var selectedTab = SettingsTab.general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)
            
            EmailSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Email", systemImage: "envelope")
                }
                .tag(SettingsTab.email)
            
            NotificationSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .tag(SettingsTab.notifications)
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 500, height: 480)
    }
}

enum SettingsTab: Hashable {
    case general
    case email
    case notifications
    case about
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var showFolderPicker = false
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Storage Folder")
                                .fontWeight(.medium)
                            
                            Text(viewModel.configuration.storageFolder.isEmpty ? "Not configured" : viewModel.configuration.storageFolder)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button("Choose...") {
                            selectFolder()
                        }
                    }
                    
                    Text("Select a folder synced with iCloud, Google Drive, or OneDrive to share data across devices.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                TextField("Your Name", text: binding(\.userName))
                
                Picker("Timesheet Period", selection: binding(\.timesheetPeriod)) {
                    ForEach(TimesheetPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                
                Picker("Timezone", selection: binding(\.timezoneIdentifier)) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                        Text(identifier).tag(identifier)
                    }
                }
            }
            
            Section {
                Toggle("Start tracking on app launch", isOn: binding(\.autoStartOnLaunch))
                Toggle("Confirm before sending timesheet", isOn: binding(\.confirmBeforeSending))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder for storing timesheets"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                do {
                    try await viewModel.setupStorage(path: url.path)
                } catch {
                    viewModel.errorMessage = "Failed to set storage folder: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<AppConfiguration, T>) -> Binding<T> {
        Binding(
            get: { viewModel.configuration[keyPath: keyPath] },
            set: { newValue in
                var config = viewModel.configuration
                config[keyPath: keyPath] = newValue
                viewModel.updateConfiguration(config)
            }
        )
    }
}

// MARK: - Email Settings

struct EmailSettingsView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    var body: some View {
        Form {
            Section {
                TextField("Approver Email", text: binding(\.approverEmail))
                TextField("Email Subject", text: binding(\.emailSubject))
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Template")
                        .fontWeight(.medium)
                    
                    TextEditor(text: binding(\.emailTemplate))
                        .font(.body.monospaced())
                        .frame(height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text("Placeholders: {{userName}}, {{periodStart}}, {{periodEnd}}, {{totalHours}}, {{entriesSummary}}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Toggle("Include detailed entries in email", isOn: binding(\.includeEntriesInEmail))
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<AppConfiguration, T>) -> Binding<T> {
        Binding(
            get: { viewModel.configuration[keyPath: keyPath] },
            set: { newValue in
                var config = viewModel.configuration
                config[keyPath: keyPath] = newValue
                viewModel.updateConfiguration(config)
            }
        )
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var notificationsEnabled = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Notifications")
                    Spacer()
                    if notificationsEnabled {
                        Text("Enabled")
                            .foregroundStyle(.green)
                    } else {
                        Button("Enable") {
                            Task {
                                notificationsEnabled = await viewModel.requestNotificationPermissions()
                            }
                        }
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Reminder Time")
                    Spacer()
                    TextField("HH:mm", text: binding(\.notificationTime))
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder Days")
                        .fontWeight(.medium)
                    
                    HStack {
                        ForEach([(1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")], id: \.0) { day, label in
                            DayToggle(
                                day: day,
                                label: label,
                                isSelected: viewModel.configuration.notificationDays.contains(day)
                            ) { selected in
                                var config = viewModel.configuration
                                if selected {
                                    if !config.notificationDays.contains(day) {
                                        config.notificationDays.append(day)
                                        config.notificationDays.sort()
                                    }
                                } else {
                                    config.notificationDays.removeAll { $0 == day }
                                }
                                viewModel.updateConfiguration(config)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Check notification status
            Task {
                notificationsEnabled = await viewModel.requestNotificationPermissions()
            }
        }
    }
    
    private func binding<T>(_ keyPath: WritableKeyPath<AppConfiguration, T>) -> Binding<T> {
        Binding(
            get: { viewModel.configuration[keyPath: keyPath] },
            set: { newValue in
                var config = viewModel.configuration
                config[keyPath: keyPath] = newValue
                viewModel.updateConfiguration(config)
            }
        )
    }
}

struct DayToggle: View {
    let day: Int
    let label: String
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text("Local Hours")
                .font(.title.weight(.bold))
            
            Text("Version 1.0.0")
                .foregroundStyle(.secondary)
            
            Text("A simple, local-first time tracking app that works across macOS, iOS, and Android — with your data stored in files you control.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 8) {
                Link("View on GitHub", destination: URL(string: "https://github.com/gogrinimish/LocalHours")!)
                Link("Buy Me a Coffee", destination: URL(string: "https://buymeacoffee.com/hwrxt65o5i")!)
                
                Text("Open Source • MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: .preview)
    }
}
#endif
