import Foundation

public struct TrainingScheduler: Sendable {
    public init() {}

    public func materialize(
        slots: [WeeklyScheduleSlot],
        statuses: [DayStatusPeriod],
        contextEvents _: [DayContextEvent] = [],
        start: Date,
        weeks: Int = 21,
        calendar: Calendar = .current
    ) -> [PlannedTrainingOccurrence] {
        guard weeks > 0 else { return [] }
        let dayStart = calendar.startOfDay(for: start)
        let dayCount = weeks * 7
        let orderedSlots = slots.sorted { lhs, rhs in
            if lhs.weekday == rhs.weekday {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.weekday < rhs.weekday
        }

        var sourceQueue: [PlannedTrainingOccurrence] = []
        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: dayStart) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let slotsForDay = orderedSlots.filter { $0.weekday == weekday }
            for slot in slotsForDay {
                sourceQueue.append(
                    PlannedTrainingOccurrence(
                        sourceSlotId: slot.id,
                        date: date,
                        workoutId: slot.workoutId,
                        workoutName: slot.workoutName,
                        plannedTime: slot.plannedTime
                    )
                )
            }
        }

        var queueIndex = 0
        var result: [PlannedTrainingOccurrence] = []
        for offset in 0..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: dayStart) else { continue }
            if status(on: date, statuses: statuses, calendar: calendar)?.preventsTraining == true {
                continue
            }
            let capacity = max(orderedSlots.filter { $0.weekday == calendar.component(.weekday, from: date) }.count, 1)
            for capacityIndex in 0..<capacity where queueIndex < sourceQueue.count {
                var occurrence = sourceQueue[queueIndex]
                occurrence.date = date
                occurrence.isPostponed = occurrence.date != sourceQueue[queueIndex].date
                occurrence.plannedTime = sourceQueue[queueIndex].plannedTime ?? fallbackTime(for: capacityIndex)
                result.append(occurrence)
                queueIndex += 1
            }
        }
        return result
    }

    public func replace(
        occurrence: PlannedTrainingOccurrence,
        with workout: WorkoutTemplate
    ) -> PlannedTrainingOccurrence {
        var replacement = occurrence
        replacement.workoutId = workout.id
        replacement.workoutName = workout.name
        replacement.isReplacement = true
        return replacement
    }

    public func postpone(
        occurrenceId: UUID,
        in occurrences: [PlannedTrainingOccurrence],
        calendar: Calendar = .current
    ) -> [PlannedTrainingOccurrence] {
        guard let index = occurrences.firstIndex(where: { $0.id == occurrenceId }),
              let targetDate = calendar.date(byAdding: .day, value: 1, to: occurrences[index].date)
        else {
            return occurrences
        }
        var copy = occurrences
        copy[index].date = calendar.startOfDay(for: targetDate)
        copy[index].isPostponed = true
        return copy.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return (lhs.plannedTime?.hour ?? 23) < (rhs.plannedTime?.hour ?? 23)
            }
            return lhs.date < rhs.date
        }
    }

    private func status(on date: Date, statuses: [DayStatusPeriod], calendar: Calendar) -> DayStatusType? {
        let day = calendar.startOfDay(for: date)
        return statuses.first { period in
            let start = calendar.startOfDay(for: period.start)
            let end = calendar.startOfDay(for: period.end)
            return day >= start && day <= end
        }?.type
    }

    private func fallbackTime(for index: Int) -> DateComponents {
        DateComponents(hour: index == 0 ? 18 : 19, minute: 0)
    }
}
