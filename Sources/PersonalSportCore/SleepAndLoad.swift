import Foundation

public struct SleepRecord: Codable, Equatable, Sendable {
    public var date: Date
    public var totalMinutes: Double?
    public var remMinutes: Double?
    public var deepMinutes: Double?
    public var coreMinutes: Double?
    public var awakeMinutes: Double?
    public var sleepingAverageHeartRate: Double?

    public init(
        date: Date,
        totalMinutes: Double? = nil,
        remMinutes: Double? = nil,
        deepMinutes: Double? = nil,
        coreMinutes: Double? = nil,
        awakeMinutes: Double? = nil,
        sleepingAverageHeartRate: Double? = nil
    ) {
        self.date = date
        self.totalMinutes = totalMinutes
        self.remMinutes = remMinutes
        self.deepMinutes = deepMinutes
        self.coreMinutes = coreMinutes
        self.awakeMinutes = awakeMinutes
        self.sleepingAverageHeartRate = sleepingAverageHeartRate
    }
}

public struct SleepScoreConfig: Codable, Equatable, Sendable {
    public var idealDurationMinutes: Double
    public var durationWeight: Double
    public var deepWeight: Double
    public var remWeight: Double
    public var awakePenaltyWeight: Double

    public init(
        idealDurationMinutes: Double = 8 * 60,
        durationWeight: Double = 0.55,
        deepWeight: Double = 0.18,
        remWeight: Double = 0.17,
        awakePenaltyWeight: Double = 0.10
    ) {
        self.idealDurationMinutes = idealDurationMinutes
        self.durationWeight = durationWeight
        self.deepWeight = deepWeight
        self.remWeight = remWeight
        self.awakePenaltyWeight = awakePenaltyWeight
    }
}

public struct SleepScoreCalculator: Sendable {
    public init() {}

    public func score(record: SleepRecord, config: SleepScoreConfig) -> Int? {
        guard let total = record.totalMinutes, total > 0 else { return nil }
        let durationScore = min(total / config.idealDurationMinutes, 1) * 100
        let deepScore = record.deepMinutes.map { min($0 / max(total * 0.18, 1), 1) * 100 } ?? durationScore
        let remScore = record.remMinutes.map { min($0 / max(total * 0.22, 1), 1) * 100 } ?? durationScore
        let awakePenalty = record.awakeMinutes.map { min($0 / 90, 1) * 100 * config.awakePenaltyWeight } ?? 0
        let raw = durationScore * config.durationWeight
            + deepScore * config.deepWeight
            + remScore * config.remWeight
            - awakePenalty
        return Int(max(0, min(100, raw)).rounded())
    }
}

public struct LoadConfig: Codable, Equatable, Sendable {
    public var strengthOverallMultiplier: Double
    public var simpleOverallMultiplier: Double
    public var cardioDistanceDivisor: Double

    public init(
        strengthOverallMultiplier: Double = 10,
        simpleOverallMultiplier: Double = 8,
        cardioDistanceDivisor: Double = 1000
    ) {
        self.strengthOverallMultiplier = strengthOverallMultiplier
        self.simpleOverallMultiplier = simpleOverallMultiplier
        self.cardioDistanceDivisor = cardioDistanceDivisor
    }
}

public struct LoadSnapshot: Codable, Equatable, Sendable {
    public var overall: Double
    public var cardio: Double
    public var muscular: Double

    public init(overall: Double, cardio: Double, muscular: Double) {
        self.overall = overall
        self.cardio = cardio
        self.muscular = muscular
    }
}

public struct TrainingLoadCalculator: Sendable {
    public init() {}

    public func strength(sessionRPE: Int, bodyFeeling: Int, config: LoadConfig = .init()) -> LoadSnapshot {
        let effort = Double(max(1, min(10, sessionRPE)))
        let feelingModifier = 1 + Double(10 - max(1, min(10, bodyFeeling))) * 0.03
        let muscular = effort * config.strengthOverallMultiplier * feelingModifier
        return LoadSnapshot(overall: muscular, cardio: 0, muscular: muscular)
    }

    public func simpleActivity(sessionRPE: Int, bodyFeeling: Int, config: LoadConfig = .init()) -> LoadSnapshot {
        let effort = Double(max(1, min(10, sessionRPE)))
        let feelingModifier = 1 + Double(10 - max(1, min(10, bodyFeeling))) * 0.02
        let overall = effort * config.simpleOverallMultiplier * feelingModifier
        return LoadSnapshot(overall: overall, cardio: overall * 0.25, muscular: overall * 0.75)
    }

    public func importedRun(distanceMeters: Double?, averageHeartRate: Double?, config: LoadConfig = .init()) -> LoadSnapshot {
        let distance = (distanceMeters ?? 0) / config.cardioDistanceDivisor
        let heartRateFactor = averageHeartRate.map { max(1, $0 / 130) } ?? 1
        let cardio = distance * 12 * heartRateFactor
        return LoadSnapshot(overall: cardio, cardio: cardio, muscular: cardio * 0.15)
    }
}
