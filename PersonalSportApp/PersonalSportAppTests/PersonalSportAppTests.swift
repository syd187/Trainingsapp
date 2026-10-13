import Foundation
import Testing
@testable import PersonalSportApp

struct PersonalSportAppTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test func overnightSleepUsesFollowingReportDate() throws {
        let start = date(2026, 9, 9, 23, 0)
        let end = date(2026, 9, 10, 6, 0)
        let reportDate = HealthIntegration.sleepReportDate(forEndDate: end, calendar: calendar)
        let bucket = try #require(SleepBucket.normalized(
            date: reportDate,
            intervals: [interval(start, end, stage: .core)]
        ))

        #expect(bucket.date == date(2026, 9, 10, 0, 0))
        #expect(bucket.startDate == start)
        #expect(bucket.endDate == end)
        #expect(bucket.totalMinutes == 420)
    }

    @Test func midnightCrossingCountsFullDuration() throws {
        let bucket = try #require(SleepBucket.normalized(
            date: date(2026, 9, 10, 0, 0),
            intervals: [interval(date(2026, 9, 9, 23, 30), date(2026, 9, 10, 0, 30), stage: .deep)]
        ))

        #expect(bucket.totalMinutes == 60)
        #expect(bucket.deepMinutes == 60)
    }

    @Test func napAndMainSleepChooseMainEpisode() throws {
        let bucket = try #require(SleepBucket.normalized(
            date: date(2026, 9, 10, 0, 0),
            intervals: [
                interval(date(2026, 9, 9, 20, 0), date(2026, 9, 9, 21, 0), stage: .core),
                interval(date(2026, 9, 9, 23, 0), date(2026, 9, 10, 6, 0), stage: .core)
            ]
        ))

        #expect(bucket.startDate == date(2026, 9, 9, 23, 0))
        #expect(bucket.endDate == date(2026, 9, 10, 6, 0))
        #expect(bucket.totalMinutes == 420)
    }

    @Test func twentyMinuteMeasurementGapStaysSingleEpisode() throws {
        let intervals = [
            interval(date(2026, 9, 9, 23, 0), date(2026, 9, 10, 2, 0), stage: .core),
            interval(date(2026, 9, 10, 2, 20), date(2026, 9, 10, 6, 0), stage: .rem)
        ]
        let episodes = SleepBucket.sleepEpisodes(in: intervals)
        let bucket = try #require(SleepBucket.normalized(date: date(2026, 9, 10, 0, 0), intervals: intervals))

        #expect(episodes.count == 1)
        #expect(bucket.startDate == date(2026, 9, 9, 23, 0))
        #expect(bucket.endDate == date(2026, 9, 10, 6, 0))
        #expect(bucket.totalMinutes == 400)
        #expect(bucket.inferredGapMinutes == 0)
    }

    @Test func sourceSelectionHappensBeforeEpisodeDetection() throws {
        let bucket = try #require(SleepBucket.normalized(
            date: date(2026, 9, 10, 0, 0),
            intervals: [
                interval(date(2026, 9, 9, 20, 0), date(2026, 9, 9, 21, 0), stage: .core, source: "garmin"),
                interval(date(2026, 9, 9, 23, 0), date(2026, 9, 10, 6, 0), stage: .core, source: "garmin"),
                interval(date(2026, 9, 9, 22, 15), date(2026, 9, 10, 5, 45), stage: .core, source: "apple")
            ]
        ))

        #expect(bucket.sourceIdentifier == "garmin")
        #expect(bucket.startDate == date(2026, 9, 9, 23, 0))
        #expect(bucket.endDate == date(2026, 9, 10, 6, 0))
        #expect(bucket.totalMinutes == 420)
    }

    @Test func invalidSleepIntervalsReturnNil() {
        let bucket = SleepBucket.normalized(
            date: date(2026, 9, 10, 0, 0),
            intervals: [
                interval(date(2026, 9, 10, 1, 0), date(2026, 9, 10, 1, 0), stage: .core),
                interval(date(2026, 9, 10, 2, 0), date(2026, 9, 10, 2, 30), stage: .awake)
            ]
        )

        #expect(bucket == nil)
    }

    @Test func staticSkillVariantUsesConfiguredDefaults() {
        let variant = StaticSkillVariantModel(
            exerciseId: UUID(),
            name: "Advanced Tuck",
            sortOrder: 0,
            startingMaxHoldSeconds: 12
        )

        #expect(variant.advanceAtSeconds == 15)
        #expect(variant.workSetCount == 3)
        #expect(variant.workingHoldFraction == 0.65)
        #expect(variant.prescribedHoldSeconds == 7)
    }

    private func interval(_ start: Date, _ end: Date, stage: SleepStage, source: String = "garmin") -> SleepInterval {
        SleepInterval(start: start, end: end, stage: stage, sourceIdentifier: source)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
