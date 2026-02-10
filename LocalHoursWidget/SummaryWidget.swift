import WidgetKit
import SwiftUI

// MARK: - Summary Widget

struct SummaryWidget: Widget {
    let kind: String = "SummaryWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimesheetProvider()) { entry in
            SummaryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Summary")
        .description("View your time tracking summary at a glance")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Summary Widget View

struct SummaryWidgetView: View {
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundStyle(.blue)
                Text("Today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Spacer()
            
            // Main stat
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.todayTotal.hoursFormatted)
                    .font(.system(size: 32, weight: .bold))
                
                Text("\(entry.entryCount) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Status
            if entry.isTracking {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Tracking: \(entry.elapsedTime.widgetFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Medium Widget
    
    private var mediumWidget: some View {
        HStack(spacing: 20) {
            // Today section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundStyle(.orange)
                    Text("Today")
                        .font(.subheadline.weight(.medium))
                }
                
                Text(entry.todayTotal.hoursFormatted)
                    .font(.system(size: 36, weight: .bold))
                
                Text("\(entry.entryCount) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if entry.isTracking {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Active: \(entry.elapsedTime.widgetFormatted)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // Week section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                    Text("This Week")
                        .font(.subheadline.weight(.medium))
                }
                
                Text(entry.weekTotal.hoursFormatted)
                    .font(.system(size: 36, weight: .bold))
                
                // Progress bar (assuming 40hr work week)
                let progress = min(entry.weekTotal / (40 * 3600), 1.0)
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(Int(progress * 100))% of 40h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

// MARK: - Previews

#if DEBUG
struct SummaryWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SummaryWidgetView(entry: TimesheetEntry(
                date: Date(),
                isTracking: true,
                elapsedTime: 1823,
                todayTotal: 3600 * 4.5,
                weekTotal: 3600 * 32,
                entryCount: 5,
                trackingStartTime: Date().addingTimeInterval(-1823)
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small")
            
            SummaryWidgetView(entry: TimesheetEntry(
                date: Date(),
                isTracking: false,
                elapsedTime: 0,
                todayTotal: 3600 * 6.5,
                weekTotal: 3600 * 28,
                entryCount: 8,
                trackingStartTime: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")
        }
    }
}
#endif
