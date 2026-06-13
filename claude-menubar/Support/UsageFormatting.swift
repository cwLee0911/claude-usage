import Foundation

enum UsageFormatting {
    private static let weeklyResetFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "(E) a h:mm에 재설정"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f
    }()

    static func countdownText(for date: Date?, now: Date) -> String {
        guard let date else { return "재설정 시간 확인 중" }

        let remaining = Int(date.timeIntervalSince(now).rounded())
        if remaining <= 0 { return "재설정됨" }

        let days = remaining / 86400
        let hours = (remaining % 86400) / 3600
        let minutes = max(0, (remaining % 3600) / 60)

        if days > 0 {
            return "\(days)일 \(hours)시간 후 재설정"
        } else if hours > 0 {
            return "\(hours)시간 \(minutes)분 후 재설정"
        }
        return "\(max(1, minutes))분 후 재설정"
    }

    static func sessionResetText(for date: Date?, now: Date) -> String {
        countdownText(for: date, now: now)
    }

    static func weeklyResetText(for date: Date?, now: Date) -> String {
        guard let date else { return "재설정 확인 중" }
        if date <= now { return "재설정됨" }
        return weeklyResetFormatter.string(from: date)
    }

    static func compactUpdatedText(for date: Date?) -> String {
        guard let date else { return "업데이트 없음" }
        return "업데이트 \(timeFormatter.string(from: date))"
    }
}
