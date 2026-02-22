import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Main content view with tab navigation
struct ContentView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @State private var selectedTab = Tab.timer
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if viewModel.isSetupComplete {
                mainContent
            } else {
                SetupView(viewModel: viewModel)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.syncFromWidget()
                viewModel.saveTimesheetForCurrentPeriodIfDue()
                viewModel.startPeriodicFileSync()
            case .background, .inactive:
                viewModel.stopPeriodicFileSync()
            @unknown default:
                break
            }
        }
        .onChange(of: viewModel.showStopDialogFromWidget) { _, shouldShow in
            if shouldShow {
                // Switch to Timer tab so the stop dialog appears there
                selectedTab = .timer
            }
        }
    }
    
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            TimerTab(viewModel: viewModel)
                .tabItem {
                    Label("Timer", systemImage: "clock")
                }
                .tag(Tab.timer)
            
            HistoryTab(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
                .tag(Tab.history)
            
            TimesheetTab(viewModel: viewModel)
                .tabItem {
                    Label("Timesheet", systemImage: "doc.text")
                }
                .tag(Tab.timesheet)
            
            SettingsTab(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }
}

enum Tab: Hashable {
    case timer
    case history
    case timesheet
    case settings
}

// MARK: - Setup View

struct SetupView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    @State private var showFolderPicker = false
    @State private var userName = ""
    @State private var approverEmail = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Welcome header
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)
                        
                        Text("Welcome to Local Hours")
                            .font(.title.weight(.bold))
                        
                        Text("Track your hours, generate timesheets, and email approvers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Setup form
                    VStack(spacing: 20) {
                        // Storage folder
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Storage Location")
                                .font(.headline)
                            
                            Text("Optionally choose a folder synced with iCloud, Google Drive, or OneDrive to enable cross-device sync. You can always change this later in Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                showFolderPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text(viewModel.configuration.storageFolder.isEmpty ? "Select Folder (Optional)" : "Folder Selected")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // User info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Information (Optional)")
                                .font(.headline)
                            
                            Text("You can fill these in later from Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("Your Name", text: $userName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                            
                            TextField("Approver Email", text: $approverEmail)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        // Continue button
                        Button {
                            completeSetup()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Skip button
                        Button {
                            skipSetup()
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarHidden(true)
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                viewModel.errorMessage = "No folder was selected."
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                viewModel.errorMessage = "Access to the selected folder was denied."
                return
            }
            let sharedDefaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                sharedDefaults.set(bookmarkData, forKey: "storageFolderBookmark")
                sharedDefaults.set(url.path, forKey: "storageFolderPath")
            } catch {
                viewModel.errorMessage = "Failed to save folder access: \(error.localizedDescription)"
                url.stopAccessingSecurityScopedResource()
                return
            }
            Task {
                do {
                    try await viewModel.setupStorage(url: url)
                } catch {
                    await MainActor.run {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
    
    private func completeSetup() {
        setupWithDefaults()
        if !userName.isEmpty || !approverEmail.isEmpty {
            var config = viewModel.configuration
            if !userName.isEmpty { config.userName = userName }
            if !approverEmail.isEmpty { config.approverEmail = approverEmail }
            viewModel.updateConfiguration(config)
        }
    }
    
    private func skipSetup() {
        setupWithDefaults()
    }
    
    private func setupWithDefaults() {
        if viewModel.configuration.storageFolder.isEmpty {
            let defaultPath = StorageService.defaultStoragePath()
            Task {
                do {
                    try await viewModel.setupStorage(path: defaultPath)
                } catch {
                    await MainActor.run {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: .preview)
    }
}
#endif
