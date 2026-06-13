import Foundation

struct UsageLimitSnapshot: Codable, Equatable {
    struct UsageWindow: Codable, Equatable {
        let usedPercentage: Double?
        let resetsAt: TimeInterval?

        var clampedPercentage: Double? {
            guard let usedPercentage else { return nil }
            return min(100, max(0, usedPercentage))
        }

        func effectivePercentage(now: Date) -> Double? {
            if let resetDate, resetDate <= now {
                return 0
            }
            return clampedPercentage
        }

        func roundedPercentage(now: Date) -> Int? {
            effectivePercentage(now: now).map { Int($0.rounded()) }
        }

        var resetDate: Date? {
            resetsAt.map(Date.init(timeIntervalSince1970:))
        }
    }

    let schemaVersion: Int
    let planName: String?
    let currentSession: UsageWindow
    let weekly: UsageWindow
    let displayPercentage: Double?
    let updatedAt: TimeInterval

    func menuBarTitle(now: Date) -> String {
        guard let pct = roundedDisplayPercentage(now: now) else { return "--%" }
        return "\(pct)%"
    }

    private func roundedDisplayPercentage(now: Date) -> Int? {
        let value = currentSession.effectivePercentage(now: now)
            ?? effectiveDisplayPercentage(now: now)
            ?? weekly.effectivePercentage(now: now)
        guard let value else { return nil }
        return Int(min(100, max(0, value)).rounded())
    }

    private func effectiveDisplayPercentage(now: Date) -> Double? {
        if currentSession.usedPercentage != nil,
           let resetDate = currentSession.resetDate,
           resetDate <= now {
            return 0
        }
        guard let displayPercentage else { return nil }
        return min(100, max(0, displayPercentage))
    }

    var updatedDate: Date {
        Date(timeIntervalSince1970: updatedAt)
    }
}

extension UsageLimitSnapshot {
    static let mock = UsageLimitSnapshot(
        schemaVersion: 1,
        planName: "Pro",
        currentSession: UsageWindow(
            usedPercentage: 99,
            resetsAt: Date().addingTimeInterval(108 * 60).timeIntervalSince1970
        ),
        weekly: UsageWindow(
            usedPercentage: 40,
            resetsAt: Calendar.current.nextDate(
                after: Date(),
                matching: DateComponents(hour: 18, minute: 59, weekday: 1),
                matchingPolicy: .nextTime
            )?.timeIntervalSince1970
        ),
        displayPercentage: 99,
        updatedAt: Date().timeIntervalSince1970
    )
}
