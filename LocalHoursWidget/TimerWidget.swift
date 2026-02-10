import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Group Identifier

private let appGroupIdentifier = "group.com.localhours.shared"

// MARK: - Timer Widget

struct TimerWidget: Widget {
    let kind: String = "TimerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimesheetProvider()) { entry in
            TimerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Timer")
        .description("Quick access to start and stop time tracking")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timer Widget View

struct TimerWidgetView: View {
    var entry: TimesheetEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }
    
    // MARK: - Small Widget
    
    private var smallWidget: some View {
        VStack(spacing: 8) {
            // Status indicator
            HStack {
                Circle()
                    .fill(entry.isTracking ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(entry.isTracking ? "Tracking" : "Ready")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            Spacer()
            
            // Timer display - use live updating timer when tracking
            if entry.isTracking, let startTime = entry.trackingStartTime {
                Text(startTime, style: .timer)
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            } else {
                Text("00:00")
                    .font(.system(size: 28, weight: .light, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Interactive action button
            if entry.isTracking {
                // Use Link to open app with stop action
                Link(destination: URL(string: "localhours://stop")!) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Button(intent: StartTimerWidgetIntent()) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
    
    // MARK: - Medium Widget
    
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left side - Timer
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(entry.isTracking ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    Text(entry.isTracking ? "Tracking" : "Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                // Timer display - use live updating timer when tracking
                if entry.isTracking, let startTime = entry.trackingStartTime {
                    Text(startTime, style: .timer)
                        .font(.system(size: 36, weight: .light, design: .monospaced))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("00:00")
                        .font(.system(size: 36, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                // Interactive action button
                if entry.isTracking {
                    // Use Link to open app with stop action
                    Link(destination: URL(string: "localhours://stop")!) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Button(intent: StartTimerWidgetIntent()) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Right side - Stats
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.todayTotal.hoursFormatted)
                        .font(.title3.weight(.semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.weekTotal.hoursFormatted)
                        .font(.title3.weight(.semibold))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

// MARK: - App Intents for Widget Interaction

struct StartTimerWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Timer"
    static var description = IntentDescription("Start time tracking")
    
    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return .result()
        }
        
        // Only start if not already tracking
        guard !defaults.bool(forKey: "isTracking") else {
            return .result()
        }
        
        // Set tracking state
        defaults.set(true, forKey: "isTracking")
        defaults.set(Date(), forKey: "trackingStartTime")
        
        // Reload widget timelines
        WidgetCenter.shared.reloadAllTimelines()
        
        return .result()
    }
}

// MARK: - Previews

#if DEBUG
struct TimerWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TimerWidgetView(entry: TimesheetEntry(
                date: Date(),
                isTracking: true,
                elapsedTime: 3723,
                todayTotal: 3600 * 4.5,
                weekTotal: 3600 * 32,
                entryCount: 5,
                trackingStartTime: Date().addingTimeInterval(-3723)
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Tracking")
            
            TimerWidgetView(entry: TimesheetEntry(
                date: Date(),
                isTracking: false,
                elapsedTime: 0,
                todayTotal: 3600 * 4.5,
                weekTotal: 3600 * 32,
                entryCount: 5,
                trackingStartTime: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small - Idle")
            
            TimerWidgetView(entry: TimesheetEntry(
                date: Date(),
                isTracking: true,
                elapsedTime: 3723,
                todayTotal: 3600 * 4.5,
                weekTotal: 3600 * 32,
                entryCount: 5,
                trackingStartTime: Date().addingTimeInterval(-3723)
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium - Tracking")
        }
    }
}
#endif
