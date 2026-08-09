import Foundation

enum PrepScheduleState: Equatable, Sendable {
    case scheduled(Date)
    case finalCheck(Date)
    case stopped
    case targetPassed
}

struct PrepScheduleCalculator: Sendable {
    let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func nextCheckIn(
        now: Date,
        targetDate: Date,
        status: PrepReadinessStatus,
        intensity: PrepIntensity
    ) -> PrepScheduleState {
        guard status != .ready else { return .stopped }

        let start = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: targetDate)
        let remainingDays = calendar.dateComponents([.day], from: start, to: target).day ?? 0
        guard remainingDays >= 0 else { return .targetPassed }
        guard remainingDays > 0 else { return .finalCheck(targetDate) }
        guard remainingDays > 2 else {
            return .finalCheck(addingDays(1, to: now, notAfter: targetDate))
        }

        let fraction = status == .notReady ? 0.20 : 0.40
        let intensityMultiplier: Double = switch intensity {
        case .high: 0.75
        case .normal: 1.00
        case .low: 1.25
        }
        let baseDays = Double(remainingDays) * fraction * intensityMultiplier
        let statusMinimum = status == .notReady ? 1 : 2
        let statusMaximum = status == .notReady ? 4 : 7
        let periodMaximum: Int = switch remainingDays {
        case 31...: 7
        case 15...30: 5
        case 8...14: 3
        case 3...7: 2
        default: 1
        }
        let interval = min(
            periodMaximum,
            statusMaximum,
            max(statusMinimum, Int(baseDays.rounded()))
        )
        return .scheduled(addingDays(interval, to: now, notAfter: targetDate))
    }

    func shouldScheduleRetry(retryCount: Int) -> Bool {
        retryCount < 1
    }

    private func addingDays(_ days: Int, to date: Date, notAfter target: Date) -> Date {
        let value = calendar.date(byAdding: .day, value: days, to: date)
            ?? date.addingTimeInterval(TimeInterval(days * 86_400))
        return min(value, target)
    }
}
