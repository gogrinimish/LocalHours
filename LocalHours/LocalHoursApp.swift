import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

@main
struct LocalHoursApp: App {
    @StateObject private var viewModel = TimeTrackingViewModel()
    
    init() {
        // Restore security-scoped bookmark on app launch
        restoreStorageFolderAccess()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onAppear {
                    // Request notification permissions on first launch
                    Task {
                        _ = await viewModel.requestNotificationPermissions()
                    }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "localhours" else { return }
        
        switch url.host {
        case "stop":
            // Widget requested to stop timer - show stop dialog
            if viewModel.isTracking {
                viewModel.showStopDialogFromWidget = true
            }
        default:
            break
        }
    }
    
    /// Restores access to the previously selected storage folder using a security-scoped bookmark.
    private func restoreStorageFolderAccess() {
        let sharedDefaults = UserDefaults(suiteName: "group.com.localhours.shared") ?? .standard
        guard let bookmarkData = sharedDefaults.data(forKey: "storageFolderBookmark") else {
            return
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to start accessing security-scoped resource")
                return
            }
            // IMPORTANT: Set the storage folder on the shared StorageService
            // This ensures the ViewModel uses the correct folder when it initializes
            try? StorageService.shared.setStorageFolder(url: url)
            
            // If bookmark is stale, save a fresh one
            if isStale {
                if let newBookmark = try? url.bookmarkData(
                    options: .minimalBookmark,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    sharedDefaults.set(newBookmark, forKey: "storageFolderBookmark")
                }
            }
        } catch {
            print("Failed to resolve bookmark: \(error)")
        }
    }
}
