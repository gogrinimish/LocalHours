import Foundation
import Combine
#if canImport(SkipFoundation)
import SkipFoundation
#endif

#if !SKIP

/// View model for time tracking: start/stop clock, entries, timesheet generation, and configuration.
public final class TimeTrackingViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    private let storageService: StorageServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let emailService: EmailServiceProtocol
    
    // MARK: - Published State
    
    @Published public private(set) var configuration: AppConfiguration
    @Published public private(set) var allEntries: [TimeEntry] = []
    @Published public private(set) var currentEntry: TimeEntry?
    @Published public var errorMessage: String?
    
    private var timerCancellable: AnyCancellable?
    private let calendar: Calendar
    
    // MARK: - Computed Properties
    
    public var isTracking: Bool { currentEntry != nil }
    
    public var currentElapsedFormatted: String {
        guard let entry = currentEntry else { return "0:00" }
        let seconds = Int(entry.duration)
        let mins = seconds / 60
        let hrs = mins / 60
        let m = mins % 60
        if hrs > 0 {
            return String(format: "%d:%02d", hrs, m)
        }
        return String(format: "%d:%02d", mins, seconds % 60)
    }
    
    public var todayEntries: [TimeEntry] {
        allEntries.entries(for: Date(), in: calendar)
    }
    
    public var todayTotalFormatted: String {
        let total = todayEntries.totalDuration
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
    
    public var thisWeekTotalFormatted: String {
        let calendar = self.calendar
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return "0m"
        }
        let weekEntries = allEntries.entries(from: weekStart, to: weekEnd)
        let total = weekEntries.totalDuration
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }
    
    // MARK: - Init
    
    public init(
        storageService: StorageServiceProtocol? = nil,
        notificationService: NotificationServiceProtocol? = nil,
        emailService: EmailServiceProtocol? = nil
    ) {
        self.storageService = storageService ?? StorageService.shared
        self.notificationService = notificationService ?? NotificationService.shared
        self.emailService = emailService ?? EmailService.shared
        self.configuration = AppConfiguration()
        self.calendar = Calendar.current
        loadFromStorageIfAvailable()
    }
    
    /// Preview instance for SwiftUI previews
    public static var preview: TimeTrackingViewModel {
        let vm = TimeTrackingViewModel()
        vm.loadPreviewData()
        return vm
    }
    
    private func loadPreviewData() {
        let now = Date()
        allEntries = [
            TimeEntry(startTime: now.addingTimeInterval(-3600), endTime: now, description: "Preview task 1"),
            TimeEntry(startTime: now.addingTimeInterval(-7200), endTime: now.addingTimeInterval(-3600), description: "Preview task 2")
        ]
        configuration = AppConfiguration(
            storageFolder: "/tmp/preview",
            approverEmail: "preview@example.com",
            userName: "Preview User"
        )
    }
    
    // MARK: - Storage
    
    private func loadFromStorageIfAvailable() {
        guard let url = storageService.getStorageFolderURL() else { return }
        let path = url.path
        guard storageService.isValidStorageFolder(path) else { return }
        do {
            try storageService.setStorageFolder(path)
            configuration = try storageService.loadConfiguration()
            configuration.storageFolder = path
            allEntries = try storageService.loadTimeEntries()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func setupStorage(path: String) async throws {
        try storageService.setStorageFolder(path)
        let config = try storageService.loadConfiguration()
        let entries = try storageService.loadTimeEntries()
        await MainActor.run {
            configuration = config
            configuration.storageFolder = path
            allEntries = entries
            errorMessage = nil
        }
    }
    
    // MARK: - Timer Updates
    
    private func startTimerUpdates() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
    
    private func stopTimerUpdates() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    // MARK: - Actions
    
    public func startClock() {
        guard currentEntry == nil else { return }
        let entry = TimeEntry(startTime: Date(), description: "")
        currentEntry = entry
        startTimerUpdates()
        saveEntries()
    }
    
    public func stopClock(description: String, projectName: String? = nil) {
        guard var entry = currentEntry else { return }
        entry.endTime = Date()
        entry.description = description
        entry.projectName = projectName
        currentEntry = nil
        stopTimerUpdates()
        allEntries.append(entry)
        allEntries.sort { $0.startTime > $1.startTime }
        saveEntries()
    }
    
    public func cancelTracking() {
        currentEntry = nil
        stopTimerUpdates()
        objectWillChange.send()
    }
    
    public func deleteEntry(_ entry: TimeEntry) {
        allEntries.removeAll { $0.id == entry.id }
        saveEntries()
    }
    
    public func updateEntry(_ entry: TimeEntry) {
        if let index = allEntries.firstIndex(where: { $0.id == entry.id }) {
            allEntries[index] = entry
            allEntries.sort { $0.startTime > $1.startTime }
            saveEntries()
        }
    }
    
    private func saveEntries() {
        guard storageService.getStorageFolderURL() != nil else { return }
        do {
            try storageService.saveTimeEntries(allEntries)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Configuration
    
    public func updateConfiguration(_ config: AppConfiguration) {
        configuration = config
        guard storageService.getStorageFolderURL() != nil else { return }
        do {
            try storageService.saveConfiguration(configuration)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Timesheet
    
    public func generateTimesheet() -> Timesheet {
        var cal = Calendar.current
        cal.timeZone = configuration.timezone
        let now = Date()
        let periodStart: Date
        let periodEnd: Date
        switch configuration.timesheetPeriod {
        case .weekly:
            periodStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            periodEnd = cal.date(byAdding: .day, value: 6, to: periodStart) ?? now
        case .biweekly:
            periodStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            periodEnd = cal.date(byAdding: .day, value: 13, to: periodStart) ?? now
        case .monthly:
            periodStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            periodEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: periodStart) ?? now
        }
        let entries = allEntries.entries(from: periodStart, to: periodEnd)
        return Timesheet(
            periodStart: periodStart,
            periodEnd: periodEnd,
            entries: entries,
            status: .draft
        )
    }
    
    // MARK: - Notifications
    
    public func requestNotificationPermissions() async -> Bool {
        await notificationService.requestAuthorization()
    }
}

#endif
