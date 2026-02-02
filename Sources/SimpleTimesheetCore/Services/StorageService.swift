import Foundation
#if canImport(SkipFoundation)
import SkipFoundation
#endif

// StorageService uses FileManager APIs not available in Skip
// For Android, a Skip-specific implementation would be needed
#if !SKIP

/// Protocol for storage operations
public protocol StorageServiceProtocol {
    func loadConfiguration() throws -> AppConfiguration
    func saveConfiguration(_ config: AppConfiguration) throws
    func loadTimeEntries() throws -> [TimeEntry]
    func saveTimeEntries(_ entries: [TimeEntry]) throws
    func loadTimesheets() throws -> [Timesheet]
    func saveTimesheet(_ timesheet: Timesheet) throws
    /// Returns true if the deterministic period file exists (so macOS and iOS don't both create a backup).
    func timesheetFileExistsForPeriod(periodStart: Date, periodEnd: Date, timeZone: TimeZone) -> Bool
    /// Saves a timesheet to the deterministic path for that period (same path on all devices).
    func saveTimesheetForPeriod(_ timesheet: Timesheet, timeZone: TimeZone) throws
    func getStorageFolderURL() -> URL?
    func isValidStorageFolder(_ path: String) -> Bool
    func setStorageFolder(_ path: String) throws
}

/// Service for managing file-based storage
public class StorageService: StorageServiceProtocol {
    
    public static let shared = StorageService()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // File names
    private let configFileName = "config.json"
    private let entriesFileName = "entries.json"
    private let timesheetsFolder = "timesheets"
    
    private var storageFolderURL: URL?
    
    public init() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
    }
    
    /// Set the storage folder path
    public func setStorageFolder(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        
        // Create folder structure if needed
        try createFolderStructure(at: url)
        
        self.storageFolderURL = url
    }
    
    /// Get the current storage folder URL
    public func getStorageFolderURL() -> URL? {
        return storageFolderURL
    }
    
    /// Create the required folder structure
    private func createFolderStructure(at url: URL) throws {
        // Create main folder
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        // Create timesheets subfolder
        let timesheetsURL = url.appendingPathComponent(timesheetsFolder)
        if !fileManager.fileExists(atPath: timesheetsURL.path) {
            try fileManager.createDirectory(at: timesheetsURL, withIntermediateDirectories: true)
        }
        
        // Create time-entries subfolder
        let entriesURL = url.appendingPathComponent("time-entries")
        if !fileManager.fileExists(atPath: entriesURL.path) {
            try fileManager.createDirectory(at: entriesURL, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Configuration
    
    /// Load configuration from storage
    public func loadConfiguration() throws -> AppConfiguration {
        guard let folderURL = storageFolderURL else {
            return AppConfiguration()
        }
        
        let configURL = folderURL.appendingPathComponent(configFileName)
        
        guard fileManager.fileExists(atPath: configURL.path) else {
            return AppConfiguration(storageFolder: folderURL.path)
        }
        
        let data = try Data(contentsOf: configURL)
        var config = try decoder.decode(AppConfiguration.self, from: data)
        config.storageFolder = folderURL.path
        return config
    }
    
    /// Save configuration to storage
    public func saveConfiguration(_ config: AppConfiguration) throws {
        guard let folderURL = storageFolderURL else {
            throw StorageError.noStorageFolder
        }
        
        let configURL = folderURL.appendingPathComponent(configFileName)
        let data = try encoder.encode(config)
        try data.write(to: configURL)
    }
    
    // MARK: - Time Entries
    
    /// Load time entries from storage
    public func loadTimeEntries() throws -> [TimeEntry] {
        guard let folderURL = storageFolderURL else {
            return []
        }
        
        let entriesURL = folderURL
            .appendingPathComponent("time-entries")
            .appendingPathComponent(entriesFileName)
        
        guard fileManager.fileExists(atPath: entriesURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: entriesURL)
        return try decoder.decode([TimeEntry].self, from: data)
    }
    
    /// Save time entries to storage
    public func saveTimeEntries(_ entries: [TimeEntry]) throws {
        guard let folderURL = storageFolderURL else {
            throw StorageError.noStorageFolder
        }
        
        let entriesURL = folderURL
            .appendingPathComponent("time-entries")
            .appendingPathComponent(entriesFileName)
        
        let data = try encoder.encode(entries)
        try data.write(to: entriesURL)
    }
    
    // MARK: - Timesheets
    
    /// Load all timesheets from storage
    public func loadTimesheets() throws -> [Timesheet] {
        guard let folderURL = storageFolderURL else {
            return []
        }
        
        let timesheetsURL = folderURL.appendingPathComponent(timesheetsFolder)
        
        guard fileManager.fileExists(atPath: timesheetsURL.path) else {
            return []
        }
        
        let fileURLs = try fileManager.contentsOfDirectory(
            at: timesheetsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        var timesheets: [Timesheet] = []
        
        for fileURL in fileURLs {
            let data = try Data(contentsOf: fileURL)
            let timesheet = try decoder.decode(Timesheet.self, from: data)
            timesheets.append(timesheet)
        }
        
        return timesheets.sorted { $0.periodStart > $1.periodStart }
    }
    
    /// Save a timesheet to storage
    public func saveTimesheet(_ timesheet: Timesheet) throws {
        guard let folderURL = storageFolderURL else {
            throw StorageError.noStorageFolder
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let fileName = "\(formatter.string(from: timesheet.periodStart))-\(timesheet.id.uuidString.prefix(8)).json"
        
        let timesheetURL = folderURL
            .appendingPathComponent(timesheetsFolder)
            .appendingPathComponent(fileName)
        
        let data = try encoder.encode(timesheet)
        try data.write(to: timesheetURL)
    }
    
    /// Deterministic path for a period so macOS and iOS write the same file (no duplicate backups).
    private func periodTimesheetURL(periodStart: Date, periodEnd: Date, timeZone: TimeZone) -> URL? {
        guard let folderURL = storageFolderURL else { return nil }
        var cal = Calendar.current
        cal.timeZone = timeZone
        let startDay = cal.component(.year, from: periodStart) * 10000 + cal.component(.month, from: periodStart) * 100 + cal.component(.day, from: periodStart)
        let endDay = cal.component(.year, from: periodEnd) * 10000 + cal.component(.month, from: periodEnd) * 100 + cal.component(.day, from: periodEnd)
        let fileName = "period-\(startDay)_\(endDay).json"
        return folderURL
            .appendingPathComponent(timesheetsFolder)
            .appendingPathComponent(fileName)
    }
    
    public func timesheetFileExistsForPeriod(periodStart: Date, periodEnd: Date, timeZone: TimeZone) -> Bool {
        guard let url = periodTimesheetURL(periodStart: periodStart, periodEnd: periodEnd, timeZone: timeZone) else {
            return false
        }
        return fileManager.fileExists(atPath: url.path)
    }
    
    public func saveTimesheetForPeriod(_ timesheet: Timesheet, timeZone: TimeZone) throws {
        guard let folderURL = storageFolderURL else {
            throw StorageError.noStorageFolder
        }
        guard let url = periodTimesheetURL(periodStart: timesheet.periodStart, periodEnd: timesheet.periodEnd, timeZone: timeZone) else {
            throw StorageError.invalidPath
        }
        let data = try encoder.encode(timesheet)
        try data.write(to: url)
    }
    
    /// Delete a timesheet from storage
    public func deleteTimesheet(_ timesheet: Timesheet) throws {
        guard let folderURL = storageFolderURL else {
            throw StorageError.noStorageFolder
        }
        
        let timesheetsURL = folderURL.appendingPathComponent(timesheetsFolder)
        
        let fileURLs = try fileManager.contentsOfDirectory(
            at: timesheetsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        
        for fileURL in fileURLs {
            let data = try Data(contentsOf: fileURL)
            let existingTimesheet = try decoder.decode(Timesheet.self, from: data)
            if existingTimesheet.id == timesheet.id {
                try fileManager.removeItem(at: fileURL)
                return
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Get the default storage folder path based on platform
    public static func defaultStoragePath() -> String {
        #if os(macOS)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("SimpleTimesheet").path
        #else
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("SimpleTimesheet").path
        #endif
    }
    
    /// Check if a path is a valid storage folder
    public func isValidStorageFolder(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        
        if !exists {
            // Try to create it
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
                return true
            } catch {
                return false
            }
        }
        
        return isDirectory.boolValue && fileManager.isWritableFile(atPath: path)
    }
}

/// Storage-related errors
public enum StorageError: LocalizedError {
    case noStorageFolder
    case invalidPath
    case fileNotFound
    case encodingError
    case decodingError
    
    public var errorDescription: String? {
        switch self {
        case .noStorageFolder:
            return "No storage folder configured. Please set a storage folder in settings."
        case .invalidPath:
            return "The specified path is invalid or inaccessible."
        case .fileNotFound:
            return "The requested file was not found."
        case .encodingError:
            return "Failed to encode data for storage."
        case .decodingError:
            return "Failed to decode stored data."
        }
    }
}

#endif // !SKIP
