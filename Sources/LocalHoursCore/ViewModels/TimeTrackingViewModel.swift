import Foundation
import Combine
#if canImport(SkipFoundation)
import SkipFoundation
#endif
#if canImport(WidgetKit)
import WidgetKit
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
    private var fileSyncCancellable: AnyCancellable?
    private let calendar: Calendar
    
    /// Interval for checking if storage files changed (cross-device sync)
    private let fileSyncInterval: TimeInterval = 5.0
    
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
        // Keep widget in sync
        syncStateToWidget()
    }
    
    public func setupStorage(path: String) async throws {
        try storageService.setStorageFolder(path)
        try await finishSetupStorage(path: path)
    }

    /// Set up storage using a URL (e.g. security-scoped URL from document picker on iOS).
    public func setupStorage(url: URL) async throws {
        try storageService.setStorageFolder(url: url)
        try await finishSetupStorage(path: url.path)
    }

    private func finishSetupStorage(path: String) async throws {
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
    
    // MARK: - Periodic File Sync (Cross-Device)
    
    /// Starts periodic polling of storage files to detect changes from other devices.
    /// Call this when the app becomes active or visible.
    public func startPeriodicFileSync() {
        guard fileSyncCancellable == nil else { return }
        fileSyncCancellable = Timer.publish(every: fileSyncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForExternalChanges()
            }
    }
    
    /// Stops periodic file sync polling.
    /// Call this when the app goes to background or is not visible.
    public func stopPeriodicFileSync() {
        fileSyncCancellable?.cancel()
        fileSyncCancellable = nil
    }
    
    /// Checks storage for changes made by other devices and updates state if needed.
    private func checkForExternalChanges() {
        guard storageService.getStorageFolderURL() != nil else { return }
        do {
            let loadedEntries = try storageService.loadTimeEntries()
            let loadedInProgress = loadedEntries.first { $0.endTime == nil }
            
            // Check if timer state changed externally
            if let current = currentEntry {
                // We have a timer running - check if it was stopped externally
                if let loaded = loadedEntries.first(where: { $0.id == current.id }) {
                    if loaded.endTime != nil {
                        // Timer was stopped on another device - update our state
                        applyLoadedEntries(loadedEntries)
                    }
                }
            } else if loadedInProgress != nil {
                // We don't have a timer but one was started externally
                applyLoadedEntries(loadedEntries)
            }
            
            // Also check if completed entries changed (e.g., edits from another device)
            let loadedCompletedCount = loadedEntries.filter { $0.endTime != nil }.count
            if loadedCompletedCount != allEntries.count {
                applyLoadedEntries(loadedEntries)
            }
        } catch {
            // Silently ignore sync errors to avoid spamming the user
        }
    }
    
    // MARK: - Actions
    
    private let sharedDefaults = UserDefaults(suiteName: "group.com.localhours.shared")
    
    public func startClock() {
        guard currentEntry == nil else { return }
        let entry = TimeEntry(startTime: Date(), description: "")
        currentEntry = entry
        startTimerUpdates()
        saveEntries()
        syncStateToWidget()
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
        syncStateToWidget()
    }
    
    public func cancelTracking() {
        currentEntry = nil
        stopTimerUpdates()
        saveEntries()
        syncStateToWidget()
        objectWillChange.send()
    }
    
    /// Syncs timer state to shared UserDefaults so widgets can read it.
    private func syncStateToWidget() {
        guard let defaults = sharedDefaults else { return }
        if let entry = currentEntry {
            defaults.set(true, forKey: "isTracking")
            defaults.set(entry.startTime, forKey: "trackingStartTime")
        } else {
            defaults.set(false, forKey: "isTracking")
            defaults.removeObject(forKey: "trackingStartTime")
        }
        // Update totals for widget display
        let todayTotal = todayEntries.totalDuration
        defaults.set(todayTotal, forKey: "todayTotal")
        defaults.set(todayEntries.count, forKey: "todayEntryCount")
        // Week total
        let cal = calendar
        let now = Date()
        if let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
           let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) {
            let weekTotal = allEntries.entries(from: weekStart, to: weekEnd).totalDuration
            defaults.set(weekTotal, forKey: "weekTotal")
        }
        // Tell iOS widgets to refresh immediately
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
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
        // First check if widget started a timer we don't know about
        if let defaults = sharedDefaults,
           defaults.bool(forKey: "isTracking"),
           currentEntry == nil,
           let startTime = defaults.object(forKey: "trackingStartTime") as? Date {
            // Widget started a timer - create an entry for it
            let entry = TimeEntry(startTime: startTime, description: "")
            currentEntry = entry
            startTimerUpdates()
            saveEntries()
        }
        // Then reload from storage to get any file changes
        loadFromStorageIfAvailable()
        // Update widget with our current state
        syncStateToWidget()
    }
}


#endif
