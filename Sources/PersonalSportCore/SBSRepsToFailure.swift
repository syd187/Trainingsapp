import Foundation

public enum ProgressionError: Error, Equatable {
    case missingBodyweightReference
    case invalidTrainingMax
    case invalidIncrement
}

public struct SBSWeekPrescription: Codable, Equatable, Sendable {
    public var weekInBlock: Int
    public var weeklyIntensity: Decimal
    public var setCount: Int
    public var workSetReps: Int
    public var repOutTarget: Int

    public init(
        weekInBlock: Int,
        weeklyIntensity: Decimal,
        setCount: Int,
        workSetReps: Int,
        repOutTarget: Int
    ) {
        self.weekInBlock = weekInBlock
        self.weeklyIntensity = weeklyIntensity
        self.setCount = setCount
        self.workSetReps = workSetReps
        self.repOutTarget = repOutTarget
    }
}

public struct SBSConfigVersion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var versionNumber: Int
    public var createdAt: Date
    public var weightIncrement: Decimal
    public var weeks: [SBSWeekPrescription]
    public var adjustmentRules: [Int: Decimal]

    public init(
        id: UUID = UUID(),
        versionNumber: Int = 1,
        createdAt: Date = .now,
        weightIncrement: Decimal,
        weeks: [SBSWeekPrescription] = SBSConfigVersion.defaultSixWeekBlock,
        adjustmentRules: [Int: Decimal] = SBSConfigVersion.defaultAdjustmentRules
    ) {
        self.id = id
        self.versionNumber = versionNumber
        self.createdAt = createdAt
        self.weightIncrement = weightIncrement
        self.weeks = weeks
        self.adjustmentRules = adjustmentRules
    }

    public static let defaultSixWeekBlock = SBSMainLiftReferenceData.sixWeekBlock
    public static let defaultAdjustmentRules = SBSMainLiftReferenceData.adjustmentRules
}

public enum SBSMainLiftReferenceData {
    public static let sourceWorkbookName = "SBS Strength Program reps to failure.xlsx"
    public static let sourceSheets = ["Quick Setup", "Setup", "Untouched", "2x", "3x", "4x", "5x", "6x"]

    public static let sixWeekBlock: [SBSWeekPrescription] = [
        .init(weekInBlock: 1, weeklyIntensity: 0.70, setCount: 4, workSetReps: 5, repOutTarget: 10),
        .init(weekInBlock: 2, weeklyIntensity: 0.75, setCount: 4, workSetReps: 4, repOutTarget: 8),
        .init(weekInBlock: 3, weeklyIntensity: 0.80, setCount: 4, workSetReps: 3, repOutTarget: 6),
        .init(weekInBlock: 4, weeklyIntensity: 0.725, setCount: 4, workSetReps: 5, repOutTarget: 9),
        .init(weekInBlock: 5, weeklyIntensity: 0.775, setCount: 4, workSetReps: 4, repOutTarget: 7),
        .init(weekInBlock: 6, weeklyIntensity: 0.825, setCount: 4, workSetReps: 3, repOutTarget: 5)
    ]

    public static let adjustmentRules: [Int: Decimal] = [
        -2: -0.05,
        -1: -0.02,
        0: 0,
        1: 0.005,
        2: 0.01,
        3: 0.015,
        4: 0.02,
        5: 0.03
    ]
}

public struct ProgressionCycle: Identifiable, Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case active
        case completed
        case abandoned
    }

    public var id: UUID
    public var cycleNumber: Int
    public var startedAt: Date
    public var completedAt: Date?
    public let startingTrainingMax: Decimal
    public var currentTrainingMax: Decimal
    public var finalTrainingMax: Decimal?
    public var currentBlock: Int
    public var currentWeekInBlock: Int
    public var status: Status
    public var activeConfigVersionId: UUID

    public init(
        id: UUID = UUID(),
        cycleNumber: Int,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        startingTrainingMax: Decimal,
        currentTrainingMax: Decimal? = nil,
        finalTrainingMax: Decimal? = nil,
        currentBlock: Int = 1,
        currentWeekInBlock: Int = 1,
        status: Status = .active,
        activeConfigVersionId: UUID
    ) {
        self.id = id
        self.cycleNumber = cycleNumber
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.startingTrainingMax = startingTrainingMax
        self.currentTrainingMax = currentTrainingMax ?? startingTrainingMax
        self.finalTrainingMax = finalTrainingMax
        self.currentBlock = currentBlock
        self.currentWeekInBlock = currentWeekInBlock
        self.status = status
        self.activeConfigVersionId = activeConfigVersionId
    }
}

public struct ExerciseSessionSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var exerciseId: UUID
    public var progressionCycleId: UUID
    public var progressionConfigVersionId: UUID
    public var blockNumber: Int
    public var weekInBlock: Int
    public var trainingMaxBefore: Decimal
    public var referenceBodyweight: Decimal?
    public var weeklyIntensity: Decimal
    public var prescribedExternalWeight: Decimal?
    public var prescribedSystemWeight: Decimal?
    public var prescribedSetCount: Int
    public var prescribedWorkSetReps: Int
    public var prescribedRepOutTarget: Int
    public var actualRepOutReps: Int?
    public var appliedAdjustmentPercent: Decimal?
    public var trainingMaxAfter: Decimal?
    public var wasSkipped: Bool

    public init(
        id: UUID = UUID(),
        exerciseId: UUID,
        progressionCycleId: UUID,
        progressionConfigVersionId: UUID,
        blockNumber: Int,
        weekInBlock: Int,
        trainingMaxBefore: Decimal,
        referenceBodyweight: Decimal? = nil,
        weeklyIntensity: Decimal,
        prescribedExternalWeight: Decimal? = nil,
        prescribedSystemWeight: Decimal? = nil,
        prescribedSetCount: Int,
        prescribedWorkSetReps: Int,
        prescribedRepOutTarget: Int,
        actualRepOutReps: Int? = nil,
        appliedAdjustmentPercent: Decimal? = nil,
        trainingMaxAfter: Decimal? = nil,
        wasSkipped: Bool = false
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.progressionCycleId = progressionCycleId
        self.progressionConfigVersionId = progressionConfigVersionId
        self.blockNumber = blockNumber
        self.weekInBlock = weekInBlock
        self.trainingMaxBefore = trainingMaxBefore
        self.referenceBodyweight = referenceBodyweight
        self.weeklyIntensity = weeklyIntensity
        self.prescribedExternalWeight = prescribedExternalWeight
        self.prescribedSystemWeight = prescribedSystemWeight
        self.prescribedSetCount = prescribedSetCount
        self.prescribedWorkSetReps = prescribedWorkSetReps
        self.prescribedRepOutTarget = prescribedRepOutTarget
        self.actualRepOutReps = actualRepOutReps
        self.appliedAdjustmentPercent = appliedAdjustmentPercent
        self.trainingMaxAfter = trainingMaxAfter
        self.wasSkipped = wasSkipped
    }
}

public struct SBSRepsToFailureStrategy: Sendable {
    public init() {}

    public func prescription(for cycle: ProgressionCycle, config: SBSConfigVersion) throws -> SBSWeekPrescription {
        guard let prescription = config.weeks.first(where: { $0.weekInBlock == cycle.currentWeekInBlock }) else {
            throw ProgressionError.invalidTrainingMax
        }
        return prescription
    }

    public func roundedPrescriptionWeight(trainingMax: Decimal, intensity: Decimal, increment: Decimal) throws -> Decimal {
        guard trainingMax > 0 else { throw ProgressionError.invalidTrainingMax }
        return try round(trainingMax * intensity, toNearest: increment)
    }

    public func adjustmentPercent(actualReps: Int, targetReps: Int, config: SBSConfigVersion) -> Decimal {
        let delta = actualReps - targetReps
        let clamped = min(max(delta, -2), 5)
        return config.adjustmentRules[clamped] ?? 0
    }

    public func complete(
        cycle: ProgressionCycle,
        actualRepOutReps: Int,
        config: SBSConfigVersion
    ) throws -> (cycle: ProgressionCycle, adjustmentPercent: Decimal) {
        let prescription = try prescription(for: cycle, config: config)
        let adjustment = adjustmentPercent(actualReps: actualRepOutReps, targetReps: prescription.repOutTarget, config: config)
        var next = cycle
        next.currentTrainingMax = cycle.currentTrainingMax * (1 + adjustment)
        if next.currentWeekInBlock == 6 {
            next.currentWeekInBlock = 1
            next.currentBlock += 1
        } else {
            next.currentWeekInBlock += 1
        }
        return (next, adjustment)
    }

    public func startNewCycle(
        after previous: ProgressionCycle?,
        startingTrainingMax override: Decimal?,
        config: SBSConfigVersion,
        now: Date = .now
    ) throws -> ProgressionCycle {
        let proposed = override ?? previous?.finalTrainingMax ?? previous?.currentTrainingMax
        guard let startingTrainingMax = proposed, startingTrainingMax > 0 else {
            throw ProgressionError.invalidTrainingMax
        }
        return ProgressionCycle(
            cycleNumber: (previous?.cycleNumber ?? 0) + 1,
            startedAt: now,
            startingTrainingMax: startingTrainingMax,
            activeConfigVersionId: config.id
        )
    }

    public func round(_ value: Decimal, toNearest increment: Decimal) throws -> Decimal {
        guard increment > 0 else { throw ProgressionError.invalidIncrement }
        let quotient = (value / increment).doubleValue.rounded()
        return Decimal(quotient) * increment
    }
}

private extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
