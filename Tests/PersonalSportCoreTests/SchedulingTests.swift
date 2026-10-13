import Foundation
import Testing
@testable import PersonalSportCore

@Suite("Training scheduler")
struct SchedulingTests {
    let scheduler = TrainingScheduler()
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func weeklyScheduleGenerationSupportsMultipleSessionsPerDay() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let pull = UUID()
        let run = UUID()
        let volleyball = UUID()
        let slots = [
            WeeklyScheduleSlot(weekday: 2, workoutId: pull, workoutName: "Pull", sortOrder: 0),
            WeeklyScheduleSlot(weekday: 7, workoutId: run, workoutName: "Running", sortOrder: 0),
            WeeklyScheduleSlot(weekday: 7, workoutId: volleyball, workoutName: "Volleyball", sortOrder: 1)
        ]

        let occurrences = scheduler.materialize(slots: slots, statuses: [], start: start, weeks: 1, calendar: calendar)

        #expect(occurrences.map(\.workoutName) == ["Pull", "Running", "Volleyball"])
    }

    @Test func sickRangeShiftsFutureSessionsAndPreservesOrder() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let sickStart = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 8)))
        let sickEnd = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 10)))
        let slots = [
            WeeklyScheduleSlot(weekday: 2, workoutId: UUID(), workoutName: "Pull", sortOrder: 0),
            WeeklyScheduleSlot(weekday: 3, workoutId: UUID(), workoutName: "Bouldering", sortOrder: 0),
            WeeklyScheduleSlot(weekday: 4, workoutId: UUID(), workoutName: "Running", sortOrder: 0),
            WeeklyScheduleSlot(weekday: 5, workoutId: UUID(), workoutName: "Push", sortOrder: 0)
        ]
        let statuses = [DayStatusPeriod(type: .sick, start: sickStart, end: sickEnd)]

        let occurrences = scheduler.materialize(slots: slots, statuses: statuses, start: start, weeks: 2, calendar: calendar)

        #expect(occurrences.prefix(4).map(\.workoutName) == ["Pull", "Bouldering", "Running", "Push"])
        #expect(calendar.component(.weekday, from: occurrences[1].date) == 6)
        #expect(calendar.component(.weekday, from: occurrences[2].date) == 7)
        #expect(calendar.component(.weekday, from: occurrences[3].date) == 1)
    }

    @Test func vacationRangeShiftsLikeOtherPreventingStatuses() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let vacation = DayStatusPeriod(
            type: .vacation,
            start: try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))),
            end: try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        )
        let slots = [WeeklyScheduleSlot(weekday: 2, workoutId: UUID(), workoutName: "Pull")]

        let occurrences = scheduler.materialize(slots: slots, statuses: [vacation], start: start, weeks: 2, calendar: calendar)

        #expect(calendar.component(.weekday, from: occurrences[0].date) == 3)
        #expect(occurrences[0].isPostponed)
    }

    @Test func singleSkippedTrainingCanBePostponed() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let occurrences = scheduler.materialize(
            slots: [WeeklyScheduleSlot(weekday: 2, workoutId: UUID(), workoutName: "Pull")],
            statuses: [],
            start: start,
            weeks: 1,
            calendar: calendar
        )

        let postponed = scheduler.postpone(occurrenceId: occurrences[0].id, in: occurrences, calendar: calendar)

        #expect(calendar.component(.weekday, from: postponed[0].date) == 3)
        #expect(postponed[0].isPostponed)
    }

    @Test func nightOutDoesNotShiftSchedule() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 7)))
        let nightOut = DayContextEvent(type: .nightOut, date: start)
        let occurrences = scheduler.materialize(
            slots: [WeeklyScheduleSlot(weekday: 2, workoutId: UUID(), workoutName: "Pull")],
            statuses: [],
            contextEvents: [nightOut],
            start: start,
            weeks: 1,
            calendar: calendar
        )

        #expect(calendar.component(.weekday, from: occurrences[0].date) == 2)
    }

    @Test func replacementDoesNotMutateWeeklyScheduleSlot() {
        let slotWorkoutId = UUID()
        let replacementWorkout = WorkoutTemplate(name: "Bouldering", kind: .simpleActivity)
        let occurrence = PlannedTrainingOccurrence(
            sourceSlotId: UUID(),
            date: .now,
            workoutId: slotWorkoutId,
            workoutName: "Pull"
        )

        let replaced = scheduler.replace(occurrence: occurrence, with: replacementWorkout)

        #expect(replaced.workoutName == "Bouldering")
        #expect(replaced.isReplacement)
        #expect(occurrence.workoutName == "Pull")
    }
}
