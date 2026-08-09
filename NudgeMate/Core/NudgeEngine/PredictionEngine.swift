import Foundation

enum PredictionTimingState: String, Sendable {
    case upcoming
    case withinWindow
    case overdue
}

struct PredictionResult: Hashable, Sendable {
    var expectedWindow: DateWindow
    var notificationDate: Date
    var timingState: PredictionTimingState
}

struct RhythmAdjustmentProposal: Hashable, Sendable {
    var currentIntervalDays: Int
    var suggestedIntervalDays: Int
    var averageShiftDays: Int
}

struct PredictionEngine: Sendable {
    let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func predict(
        lastOccurrence: Date,
        estimate: IntervalEstimate,
        leadTimeDays: Int,
        now: Date
    ) -> PredictionResult {
        let center = calendar.date(
            byAdding: .day,
            value: estimate.baseIntervalDays,
            to: lastOccurrence
        ) ?? lastOccurrence.addingTimeInterval(TimeInterval(estimate.baseIntervalDays * 86_400))
        let start = calendar.date(
            byAdding: .day,
            value: -estimate.variationDays,
            to: center
        ) ?? center.addingTimeInterval(TimeInterval(-estimate.variationDays * 86_400))
        let end = calendar.date(
            byAdding: .day,
            value: estimate.variationDays,
            to: center
        ) ?? center.addingTimeInterval(TimeInterval(estimate.variationDays * 86_400))
        let notificationDate = calendar.date(
            byAdding: .day,
            value: -max(0, leadTimeDays),
            to: start
        ) ?? start

        let state: PredictionTimingState
        if now < start {
            state = .upcoming
        } else if now <= end {
            state = .withinWindow
        } else {
            state = .overdue
        }

        return PredictionResult(
            expectedWindow: DateWindow(start: start, center: center, end: end),
            notificationDate: notificationDate,
            timingState: state
        )
    }

    func nextCycle(
        after window: DateWindow,
        intervalDays: Int
    ) -> DateWindow {
        DateWindow(
            start: addingDays(intervalDays, to: window.start),
            center: addingDays(intervalDays, to: window.center),
            end: addingDays(intervalDays, to: window.end)
        )
    }

    func adjustmentProposal(
        currentIntervalDays: Int,
        recentScheduledAndCompleted: [(scheduled: Date, completed: Date)]
    ) -> RhythmAdjustmentProposal? {
        let recent = Array(recentScheduledAndCompleted.suffix(4))
        guard recent.count == 4 else { return nil }

        let shifts = recent.map {
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: $0.scheduled),
                to: calendar.startOfDay(for: $0.completed)
            ).day ?? 0
        }
        let meaningful = shifts.filter { abs($0) >= 2 }
        guard meaningful.count >= 3 else { return nil }
        let direction = meaningful.first.map { $0 >= 0 ? 1 : -1 } ?? 1
        guard meaningful.filter({ ($0 >= 0 ? 1 : -1) == direction }).count >= 3 else { return nil }

        let averageShift = Int(
            (Double(meaningful.reduce(0, +)) / Double(meaningful.count)).rounded()
        )
        return RhythmAdjustmentProposal(
            currentIntervalDays: currentIntervalDays,
            suggestedIntervalDays: max(1, currentIntervalDays + averageShift),
            averageShiftDays: averageShift
        )
    }

    private func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)
            ?? date.addingTimeInterval(TimeInterval(days * 86_400))
    }
}
