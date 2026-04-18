import Foundation

enum LuumFormatters {
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        return switch (hours, minutes) {
        case let (hours, minutes) where hours > 0 && minutes > 0:
            "\(hours)h \(minutes)m"
        case let (hours, _) where hours > 0:
            "\(hours)h"
        case let (_, minutes) where minutes > 0:
            "\(minutes)m"
        default:
            "0m"
        }
    }

    static func timeRange(start: Date, end: Date) -> String {
        let startLabel = start.formatted(date: .omitted, time: .shortened)
        let endLabel = end.formatted(date: .omitted, time: .shortened)
        return "\(startLabel) - \(endLabel)"
    }

    static func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    static func relativeTime(until date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func percentage(_ numerator: TimeInterval, over denominator: TimeInterval) -> String {
        guard denominator > 0 else { return "0%" }
        let value = (numerator / denominator) * 100
        return "\(Int(value.rounded()))%"
    }
}
