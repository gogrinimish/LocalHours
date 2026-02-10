import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Settings tab for iOS app
struct SettingsTab: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    var body: some View {
        NavigationStack {
            ConfigurationView(viewModel: viewModel)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct SettingsTab_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTab(viewModel: .preview)
    }
}
#endif
