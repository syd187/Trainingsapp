import Foundation

public struct BodyweightLoadCalculator: Sendable {
    public init() {}

    public func sevenDayAverage(from entries: [WeightEntry], endingAt date: Date, calendar: Calendar = .current) -> Decimal? {
        let dayEnd = calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60)
        guard let start = calendar.date(byAdding: .day, value: -7, to: dayEnd) else { return nil }
        let recent = entries.filter { $0.date >= start && $0.date < dayEnd }
        guard !recent.isEmpty else { return nil }
        let total = recent.reduce(Decimal(0)) { $0 + $1.weight }
        return total / Decimal(recent.count)
    }

    public func systemTrainingMax(externalMax: Decimal, referenceBodyweight: Decimal?) throws -> Decimal {
        guard let referenceBodyweight, referenceBodyweight > 0 else {
            throw ProgressionError.missingBodyweightReference
        }
        return externalMax + referenceBodyweight
    }

    public func externalDisplayWeight(systemPrescription: Decimal, referenceBodyweight: Decimal) -> Decimal {
        systemPrescription - referenceBodyweight
    }
}
