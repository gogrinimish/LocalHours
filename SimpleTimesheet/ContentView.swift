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
            if newPhase == .active {
                viewModel.syncFromWidget()
                viewModel.saveTimesheetForCurrentPeriodIfDue()
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
            VStack(spacing: 32) {
                // Welcome header
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 72))
                        .foregroundStyle(.blue)
                    
                    Text("Welcome to SimpleTimesheet")
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
                
                Spacer()
                
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
                .padding(.bottom, 32)
            }
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
            if let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                
                Task {
                    try? await viewModel.setupStorage(path: url.path)
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
