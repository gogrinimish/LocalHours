import XCTest
@testable import LocalHoursCore

final class TimeEntryTests: XCTestCase {
    
    // MARK: - Creation Tests
    
    func testTimeEntryCreation() {
        let entry = TimeEntry(
            startTime: Date(),
            description: "Test entry"
        )
        
        XCTAssertFalse(entry.id.uuidString.isEmpty)
        XCTAssertNil(entry.endTime)
        XCTAssertTrue(entry.isActive)
        XCTAssertEqual(entry.description, "Test entry")
        XCTAssertNil(entry.projectName)
        XCTAssertTrue(entry.tags.isEmpty)
    }
    
    func testTimeEntryWithAllFields() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        
        let entry = TimeEntry(
            startTime: start,
            endTime: end,
            description: "Full entry",
            projectName: "Project X",
            tags: ["urgent", "client"]
        )
        
        XCTAssertEqual(entry.startTime, start)
        XCTAssertEqual(entry.endTime, end)
        XCTAssertEqual(entry.description, "Full entry")
        XCTAssertEqual(entry.projectName, "Project X")
        XCTAssertEqual(entry.tags, ["urgent", "client"])
        XCTAssertFalse(entry.isActive)
    }
    
    // MARK: - Duration Tests
    
    func testTimeEntryDurationCompleted() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour
        
        let entry = TimeEntry(
            startTime: startTime,
            endTime: endTime,
            description: "One hour task"
        )
        
        XCTAssertEqual(entry.duration, 3600, accuracy: 1)
        XCTAssertFalse(entry.isActive)
    }
    
    func testTimeEntryDurationActive() {
        let startTime = Date().addingTimeInterval(-1800) // Started 30 min ago
        
        let entry = TimeEntry(
            startTime: startTime,
            description: "Active task"
        )
        
        // Duration should be approximately 30 minutes (1800 seconds)
        XCTAssertEqual(entry.duration, 1800, accuracy: 5)
        XCTAssertTrue(entry.isActive)
    }
    
    func testTimeEntryFormattedDurationMinutes() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(1800) // 30 minutes
        
        let entry = TimeEntry(
            startTime: startTime,
            endTime: endTime,
            description: "Task"
        )
        
        XCTAssertEqual(entry.formattedDuration, "30m")
    }
    
    func testTimeEntryFormattedDurationHoursAndMinutes() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(5400) // 1.5 hours
        
        let entry = TimeEntry(
            startTime: startTime,
            endTime: endTime,
            description: "Task"
        )
        
        XCTAssertEqual(entry.formattedDuration, "1h 30m")
    }
    
    func testTimeEntryFormattedDurationMultipleHours() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(10800) // 3 hours
        
        let entry = TimeEntry(
            startTime: startTime,
            endTime: endTime,
            description: "Task"
        )
        
        XCTAssertEqual(entry.formattedDuration, "3h 0m")
    }
    
    // MARK: - Stop Tests
    
    func testTimeEntryStop() {
        var entry = TimeEntry(startTime: Date())
        
        XCTAssertTrue(entry.isActive)
        XCTAssertTrue(entry.description.isEmpty)
        
        entry.stop(withDescription: "Completed task")
        
        XCTAssertFalse(entry.isActive)
        XCTAssertNotNil(entry.endTime)
        XCTAssertEqual(entry.description, "Completed task")
    }
    
    func testTimeEntryStopOverwritesDescription() {
        var entry = TimeEntry(
            startTime: Date(),
            description: "Initial description"
        )
        
        entry.stop(withDescription: "Final description")
        
        XCTAssertEqual(entry.description, "Final description")
    }
    
    // MARK: - Array Extension Tests
    
    func testTimeEntryArrayTotalDuration() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-7200),
                endTime: now.addingTimeInterval(-3600),
                description: "Task 1"
            ),
            TimeEntry(
                startTime: now.addingTimeInterval(-3600),
                endTime: now,
                description: "Task 2"
            )
        ]
        
        // Total should be 2 hours (7200 seconds)
        XCTAssertEqual(entries.totalDuration, 7200, accuracy: 1)
    }
    
    func testTimeEntryArrayTotalDurationEmpty() {
        let entries: [TimeEntry] = []
        XCTAssertEqual(entries.totalDuration, 0)
    }
    
    func testTimeEntryArrayFormattedTotalDuration() {
        let now = Date()
        let entries: [TimeEntry] = [
            TimeEntry(
                startTime: now.addingTimeInterval(-5400), // 1.5 hours ago
                endTime: now,
                description: "Task"
            )
        ]
        
        XCTAssertEqual(entries.formattedTotalDuration, "1h 30m")
    }
    
    func testTimeEntryGroupByDate() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        
        let entries: [TimeEntry] = [
            TimeEntry(startTime: today, endTime: today.addingTimeInterval(3600), description: "Today 1"),
            TimeEntry(startTime: today.addingTimeInterval(-1800), endTime: today, description: "Today 2"),
            TimeEntry(startTime: yesterday, endTime: yesterday.addingTimeInterval(3600), description: "Yesterday"),
            TimeEntry(startTime: twoDaysAgo, endTime: twoDaysAgo.addingTimeInterval(3600), description: "Two days ago")
        ]
        
        let grouped = entries.groupedByDate()
        
        XCTAssertEqual(grouped.keys.count, 3)
        XCTAssertEqual(grouped[calendar.startOfDay(for: today)]?.count, 2)
        XCTAssertEqual(grouped[calendar.startOfDay(for: yesterday)]?.count, 1)
        XCTAssertEqual(grouped[calendar.startOfDay(for: twoDaysAgo)]?.count, 1)
    }
    
    func testTimeEntryEntriesForDate() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        let entries: [TimeEntry] = [
            TimeEntry(startTime: today, endTime: today.addingTimeInterval(3600), description: "Today"),
            TimeEntry(startTime: yesterday, endTime: yesterday.addingTimeInterval(3600), description: "Yesterday")
        ]
        
        let todayEntries = entries.entries(for: today)
        
        XCTAssertEqual(todayEntries.count, 1)
        XCTAssertEqual(todayEntries.first?.description, "Today")
    }
    
    func testTimeEntryEntriesForDateRange() {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!
        
        let entries: [TimeEntry] = [
            TimeEntry(startTime: today, endTime: today.addingTimeInterval(3600), description: "Today"),
            TimeEntry(startTime: yesterday, endTime: yesterday.addingTimeInterval(3600), description: "Yesterday"),
            TimeEntry(startTime: lastWeek, endTime: lastWeek.addingTimeInterval(3600), description: "Last week")
        ]
        
        let rangeEntries = entries.entries(from: yesterday, to: today)
        
        XCTAssertEqual(rangeEntries.count, 2)
    }
    
    // MARK: - Codable Tests
    
    func testTimeEntryCodable() throws {
        let entry = TimeEntry(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            description: "Test",
            projectName: "Project"
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TimeEntry.self, from: data)
        
        XCTAssertEqual(decoded.id, entry.id)
        XCTAssertEqual(decoded.description, entry.description)
        XCTAssertEqual(decoded.projectName, entry.projectName)
    }
}
