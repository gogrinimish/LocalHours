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
    /// Set by app when opened via widget "stop" URL to show the stop-timer sheet (iOS).
    @Published public var showStopDialogFromWidget: Bool = false
    
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
    
    /// True when storage folder is set (iOS setup flow).
    public var isSetupComplete: Bool {
        storageService.getStorageFolderURL() != nil
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
            let loaded = try storageService.loadTimeEntries()
            applyLoadedEntries(loaded)
            saveTimesheetForCurrentPeriodIfDue()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Splits loaded entries into completed (allEntries) and in-progress (currentEntry).
    /// When another device started the timer, the in-progress entry is in storage with endTime == nil.
    private func applyLoadedEntries(_ entries: [TimeEntry]) {
        let inProgressList = entries.filter { $0.endTime == nil }
        let completed = entries.filter { $0.endTime != nil }
        // At most one in-progress; use the most recent by startTime (e.g. from macOS).
        let active = inProgressList.max(by: { $0.startTime < $1.startTime })
        // Any other in-progress entries are stale; treat as 0-duration so they don't inflate totals.
        let staleInProgress = inProgressList.filter { $0.id != active?.id }
        let fixedStale = staleInProgress.map { entry -> TimeEntry in
            var e = entry
            e.endTime = e.startTime
            return e
        }
        allEntries = (completed + fixedStale).sorted { $0.startTime > $1.startTime }
        currentEntry = active
        if active != nil {
            startTimerUpdates()
        }
    }
    
    public func setupStorage(path: String) async throws {
        try storageService.setStorageFolder(path)
        let config = try storageService.loadConfiguration()
        let entries = try storageService.loadTimeEntries()
        await MainActor.run {
            configuration = config
            configuration.storageFolder = path
            applyLoadedEntries(entries)
            saveTimesheetForCurrentPeriodIfDue()
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
        saveEntries()
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
            // Persist in-progress entry so other devices (e.g. iOS) see the active timer and show live elapsed time.
            var toSave = allEntries
            if let cur = currentEntry {
                toSave.insert(cur, at: 0)
            }
            try storageService.saveTimeEntries(toSave)
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
        let (periodStart, periodEnd) = currentPeriodBounds(now: Date())
        let entries = allEntries.entries(from: periodStart, to: periodEnd)
        return Timesheet(
            periodStart: periodStart,
            periodEnd: periodEnd,
            entries: entries,
            status: .draft
        )
    }
    
    /// Current period (start/end) in config timezone for the given date.
    private func currentPeriodBounds(now: Date) -> (Date, Date) {
        var cal = Calendar.current
        cal.timeZone = configuration.timezone
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
        return (periodStart, periodEnd)
    }
    
    /// Notification due date/time for a period: latest occurrence of (notification day + time) within [periodStart, periodEnd].
    private func notificationDueDate(periodStart: Date, periodEnd: Date) -> Date? {
        guard let timeComps = configuration.notificationTimeComponents,
              !configuration.notificationDays.isEmpty else { return nil }
        var cal = Calendar.current
        cal.timeZone = configuration.timezone
        var date = periodEnd
        while date >= periodStart {
            let weekday = cal.component(.weekday, from: date)
            if configuration.notificationDays.contains(weekday) {
                return cal.date(bySettingHour: timeComps.hour ?? 0, minute: timeComps.minute ?? 0, second: 0, of: date)
            }
            date = cal.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return nil
    }
    
    /// If the notification due time for the current (or previous) period has passed, save that period's timesheet to the timesheets folder as a backup.
    /// Uses a deterministic filename per period so macOS and iOS write the same file and don't both create a backup.
    public func saveTimesheetForCurrentPeriodIfDue() {
        guard storageService.getStorageFolderURL() != nil else { return }
        guard configuration.notificationTimeComponents != nil,
              !configuration.notificationDays.isEmpty else { return }
        var cal = Calendar.current
        cal.timeZone = configuration.timezone
        let now = Date()
        let tz = configuration.timezone
        do {
            func saveIfDue(periodStart: Date, periodEnd: Date) {
                guard let due = notificationDueDate(periodStart: periodStart, periodEnd: periodEnd), now >= due else { return }
                guard !storageService.timesheetFileExistsForPeriod(periodStart: periodStart, periodEnd: periodEnd, timeZone: tz) else { return }
                let entries = allEntries.entries(from: periodStart, to: periodEnd)
                let timesheet = Timesheet(periodStart: periodStart, periodEnd: periodEnd, entries: entries, status: .draft)
                try? storageService.saveTimesheetForPeriod(timesheet, timeZone: tz)
            }
            let (curStart, curEnd) = currentPeriodBounds(now: now)
            saveIfDue(periodStart: curStart, periodEnd: curEnd)
            let prevEnd = cal.date(byAdding: .day, value: -1, to: curStart)!
            let prevStart: Date
            switch configuration.timesheetPeriod {
            case .weekly:
                prevStart = cal.date(byAdding: .day, value: -7, to: curStart)!
            case .biweekly:
                prevStart = cal.date(byAdding: .day, value: -14, to: curStart)!
            case .monthly:
                prevStart = cal.date(byAdding: DateComponents(month: -1), to: curStart)!
            }
            saveIfDue(periodStart: prevStart, periodEnd: prevEnd)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Notifications
    
    public func requestNotificationPermissions() async -> Bool {
        await notificationService.requestAuthorization()
    }
    
    // MARK: - iOS helpers
    
    public func clearError() {
        errorMessage = nil
    }
    
    /// Sync state from app group (e.g. after returning from widget).
    public func syncFromWidget() {
        loadFromStorageIfAvailable()
    }
}

#endif
