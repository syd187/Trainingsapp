import Foundation
import Testing
@testable import PersonalSportCore

@Suite("Bodyweight plus external load")
struct BodyweightLoadTests {
    let calculator = BodyweightLoadCalculator()
    let scaleId = UUID()
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func sevenDayAverageUsesRecentEntries() throws {
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 9)))
        let entries = (0..<7).compactMap { offset -> WeightEntry? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return WeightEntry(date: date, weight: Decimal(78 + offset), scaleId: scaleId)
        } + [
            WeightEntry(date: try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))), weight: 90, scaleId: scaleId)
        ]

        let average = calculator.sevenDayAverage(from: entries, endingAt: end, calendar: calendar)

        #expect(average == 81)
    }

    @Test func systemLoadAndExternalConversion() throws {
        let system = try calculator.systemTrainingMax(externalMax: 40, referenceBodyweight: 78)
        let display = calculator.externalDisplayWeight(systemPrescription: 90.5, referenceBodyweight: 78)

        #expect(system == 118)
        #expect(display == 12.5)
    }

    @Test func missingBodyweightFailsExplicitly() throws {
        #expect(throws: ProgressionError.missingBodyweightReference) {
            _ = try calculator.systemTrainingMax(externalMax: 40, referenceBodyweight: nil)
        }
    }
}
