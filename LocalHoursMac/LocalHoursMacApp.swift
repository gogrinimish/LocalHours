import SwiftUI
import AppKit

@main
struct LocalHoursMacApp: App {
    @StateObject private var viewModel = TimeTrackingViewModel()
    @Environment(\.openSettings) private var openSettings
    
    init() {
        // Restore security-scoped bookmark on app launch
        restoreStorageFolderAccess()
    }
    
    var body: some Scene {
        // Settings window
        Settings {
            SettingsView(viewModel: viewModel)
        }
        
        // Menu bar extra
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            MenuBarLabel(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
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
                options: .withSecurityScope,
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
                    options: .withSecurityScope,
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

/// Menu bar label showing status
struct MenuBarLabel: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.isTracking ? "clock.fill" : "clock")
            
            if viewModel.isTracking {
                Text(viewModel.currentElapsedFormatted)
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }
}
