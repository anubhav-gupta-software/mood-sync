import Foundation

public enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .all: "All"
        }
    }
}

public enum HistoryChart {
    /// One point per day: the latest check-in that day.
    public static func dailyLatest(
        _ entries: [MoodEntry],
        in range: HistoryRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MoodEntry] {
        let filtered = entries.filter { entry in
            guard let start = startDate(for: range, now: now, calendar: calendar) else {
                return true
            }
            return entry.createdAt >= start
        }
        let grouped = Dictionary(grouping: filtered) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }
        return grouped.keys.sorted().compactMap { day in
            grouped[day]?.max { $0.createdAt < $1.createdAt }
        }
    }

    public static func filtered(
        _ entries: [MoodEntry],
        in range: HistoryRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [MoodEntry] {
        guard let start = startDate(for: range, now: now, calendar: calendar) else {
            return entries.sorted { $0.createdAt < $1.createdAt }
        }
        return entries.filter { $0.createdAt >= start }.sorted { $0.createdAt < $1.createdAt }
    }

    private static func startDate(for range: HistoryRange, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .week:
            return calendar.date(byAdding: .day, value: -6, to: today)
        case .month:
            return calendar.date(byAdding: .day, value: -29, to: today)
        case .all:
            return nil
        }
    }
}

public enum HistoryStats {
    public static func mostCommonLabel(_ entries: [MoodEntry]) -> String? {
        guard !entries.isEmpty else { return nil }
        let counts = Dictionary(grouping: entries, by: \.label).mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key > rhs.key
            }
            return lhs.value < rhs.value
        }?.key
    }

    public static func averageValence(_ entries: [MoodEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.valence }
        return total / Double(entries.count)
    }

    public static func word(for valence: Double) -> String {
        if valence >= 0.55 { return "bright" }
        if valence >= 0.2 { return "steady" }
        if valence >= -0.2 { return "even" }
        if valence >= -0.55 { return "heavy" }
        return "low"
    }
}
