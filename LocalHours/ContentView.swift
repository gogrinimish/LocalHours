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
                        
                        Text("Let's get you set up")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Setup form
                    VStack(spacing: 20) {
                        // Storage folder
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Storage Location")
                                .font(.headline)
                            
                            Text("Choose a folder synced with iCloud, Google Drive, or OneDrive to enable cross-device sync.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                showFolderPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text(viewModel.configuration.storageFolder.isEmpty ? "Select Folder" : "Folder Selected")
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
                            Text("Your Information")
                                .font(.headline)
                            
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
                    
                    // Continue button
                    Button {
                        completeSetup()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canContinue ? Color.blue : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canContinue)
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
    
    private var canContinue: Bool {
        !viewModel.configuration.storageFolder.isEmpty &&
        !userName.isEmpty &&
        !approverEmail.isEmpty
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                viewModel.errorMessage = "No folder was selected."
                return
            }
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                viewModel.errorMessage = "Access to the selected folder was denied."
                return
            }
            // Save bookmark for future access (keep access across app launches)
            // Use app group so widget can also access
            let sharedDefaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
            do {
                let bookmarkData = try url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                sharedDefaults.set(bookmarkData, forKey: "storageFolderBookmark")
                // Also save the path for widget fallback
                sharedDefaults.set(url.path, forKey: "storageFolderPath")
            } catch {
                viewModel.errorMessage = "Failed to save folder access: \(error.localizedDescription)"
                url.stopAccessingSecurityScopedResource()
                return
            }
            Task {
                // Note: Do NOT call stopAccessingSecurityScopedResource here - we want to keep access
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
        var config = viewModel.configuration
        config.userName = userName
        config.approverEmail = approverEmail
        viewModel.updateConfiguration(config)
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
