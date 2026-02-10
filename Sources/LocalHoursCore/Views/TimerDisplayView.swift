import SwiftUI
#if canImport(SkipUI)
import SkipUI
#endif

/// Displays the current timer with start/stop functionality
public struct TimerDisplayView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    
    @State private var showStopDialog = false
    @State private var entryDescription = ""
    @State private var projectName = ""
    
    public init(viewModel: TimeTrackingViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Timer display
            timerDisplay
            
            // Start/Stop button
            controlButton
            
            // Today's summary
            todaySummary
        }
        .padding()
        .alert("Stop Timer", isPresented: $showStopDialog) {
            TextField("What did you work on?", text: $entryDescription)
            TextField("Project (optional)", text: $projectName)
            
            Button("Cancel", role: .cancel) {
                entryDescription = ""
                projectName = ""
            }
            
            Button("Save") {
                viewModel.stopClock(
                    description: entryDescription,
                    projectName: projectName.isEmpty ? nil : projectName
                )
                entryDescription = ""
                projectName = ""
            }
        } message: {
            Text("Add a description for this time entry")
        }
    }
    
    // MARK: - Subviews
    
    private var timerDisplay: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentElapsedFormatted)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(viewModel.isTracking ? .primary : .secondary)
            
            if viewModel.isTracking {
                Text("Tracking time...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready to start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var controlButton: some View {
        Button(action: handleButtonTap) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isTracking ? "stop.fill" : "play.fill")
                Text(viewModel.isTracking ? "Stop" : "Start")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.isTracking ? Color.red : Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private var todaySummary: some View {
        VStack(spacing: 4) {
            Divider()
                .padding(.vertical, 8)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.todayTotalFormatted)
                        .font(.title3.weight(.medium))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.thisWeekTotalFormatted)
                        .font(.title3.weight(.medium))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleButtonTap() {
        if viewModel.isTracking {
            showStopDialog = true
        } else {
            viewModel.startClock()
        }
    }
}

/// Compact timer display for menu bar or widget
public struct CompactTimerView: View {
    @ObservedObject var viewModel: TimeTrackingViewModel
    let showControls: Bool
    
    public init(viewModel: TimeTrackingViewModel, showControls: Bool = true) {
        self.viewModel = viewModel
        self.showControls = showControls
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(viewModel.isTracking ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            
            // Time
            Text(viewModel.currentElapsedFormatted)
                .font(.system(.body, design: .monospaced))
                .monospacedDigit()
            
            if showControls {
                Spacer()
                
                // Control button
                Button(action: {}) {
                    Image(systemName: viewModel.isTracking ? "stop.fill" : "play.fill")
                        .foregroundStyle(viewModel.isTracking ? .red : .green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#if DEBUG
struct TimerDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        TimerDisplayView(viewModel: .preview)
            .frame(width: 300)
    }
}
#endif
