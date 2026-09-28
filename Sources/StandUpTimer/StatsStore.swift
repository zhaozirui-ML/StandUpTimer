import Foundation

struct DayStats: Codable {
    var pomodorosCompleted = 0
    var breaksTaken = 0
    var breaksSkipped = 0
}

/// 按日期（yyyy-MM-dd，本地时区）持久化统计到
/// ~/Library/Application Support/StandUpTimer/stats.json
@MainActor
final class StatsStore {
    private var days: [String: DayStats] = [:]
    private let fileURL: URL
    private let dayFormatter: DateFormatter

    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter = formatter

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("StandUpTimer", isDirectory: true)
        fileURL = dir.appendingPathComponent("stats.json")
        load()
    }

    var today: DayStats {
        days[todayKey()] ?? DayStats()
    }

    func record(_ event: TimerEvent) {
        var stats = today
        switch event {
        case .pomodoroCompleted: stats.pomodorosCompleted += 1
        case .breakTaken: stats.breaksTaken += 1
        case .breakSkipped: stats.breaksSkipped += 1
        }
        days[todayKey()] = stats
        save()
    }

    private func todayKey() -> String {
        dayFormatter.string(from: Date())
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: DayStats].self, from: data) else { return }
        days = decoded
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(days)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("StatsStore save failed: \(error)")
        }
    }
}
