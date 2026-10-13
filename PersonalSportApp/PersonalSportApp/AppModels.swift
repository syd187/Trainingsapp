import Foundation
import SwiftData

enum SportSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case calendar = "Calendar"
    case planner = "Training Planner"
    case progress = "Progress"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .calendar: "calendar"
        case .planner: "list.bullet.rectangle.fill"
        case .progress: "chart.xyaxis.line"
        case .settings: "gearshape.fill"
        }
    }
}

enum LoadKind: String, CaseIterable, Identifiable {
    case externalWeight
    case bodyweightPlusExternal
    case bodyweightReps
    case staticHold
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .externalWeight: "External Weight"
        case .bodyweightPlusExternal: "Bodyweight + External"
        case .bodyweightReps: "Bodyweight Reps"
        case .staticHold: "Static Skill"
        case .none: "None"
        }
    }
}

enum WorkoutKindValue: String, CaseIterable, Identifiable {
    case strength
    case simpleActivity
    case importedActivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Strength"
        case .simpleActivity: "Simple Activity"
        case .importedActivity: "Imported Activity"
        }
    }
}

enum ExerciseRoleValue: String, CaseIterable, Identifiable {
    case major
    case accessory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .major: "Major"
        case .accessory: "Accessory"
        }
    }
}

enum ProgressionCycleStatusValue: String, CaseIterable, Identifiable {
    case active
    case completed
    case abandoned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "Active"
        case .completed: "Completed"
        case .abandoned: "Abandoned"
        }
    }
}

enum DayStatusValue: String, CaseIterable, Identifiable {
    case normal
    case rest
    case sick
    case vacation
    case travel
    case ignore
    case deload

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .rest: "Rest"
        case .sick: "Sick"
        case .vacation: "Vacation"
        case .travel: "Travel"
        case .ignore: "Ignore"
        case .deload: "Deload"
        }
    }

    var preventsTraining: Bool {
        switch self {
        case .normal, .ignore:
            false
        case .rest, .sick, .vacation, .travel, .deload:
            true
        }
    }
}

struct PlannedDayItem: Identifiable, Equatable {
    var id: String
    var date: Date
    var workoutId: UUID
    var workoutName: String
    var kind: WorkoutKindValue
    var hour: Int?
    var minute: Int?
    var isPostponed: Bool

    var timeText: String? {
        guard let hour, let minute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }
}

@Model
final class ScaleModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var calibrationOffsetKg: Double?
    var isArchived: Bool
    var createdAt: Date

    init(name: String, calibrationOffsetKg: Double? = nil, isArchived: Bool = false) {
        self.id = UUID()
        self.name = name
        self.calibrationOffsetKg = calibrationOffsetKg
        self.isArchived = isArchived
        self.createdAt = .now
    }
}

@Model
final class BodyWeightEntryModel {
    @Attribute(.unique) var id: UUID
    var measuredAt: Date
    var weightKg: Double
    var scaleId: UUID?
    var scaleName: String

    init(measuredAt: Date = .now, weightKg: Double, scaleId: UUID? = nil, scaleName: String) {
        self.id = UUID()
        self.measuredAt = measuredAt
        self.weightKg = weightKg
        self.scaleId = scaleId
        self.scaleName = scaleName
    }
}

@Model
final class MorningCheckInModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var completedAt: Date
    var weightEntryId: UUID?
    var hasPain: Bool

    init(
        date: Date,
        completedAt: Date = .now,
        weightEntryId: UUID? = nil,
        hasPain: Bool
    ) {
        self.id = UUID()
        self.date = date
        self.completedAt = completedAt
        self.weightEntryId = weightEntryId
        self.hasPain = hasPain
    }
}

@Model
final class PainEntryModel {
    @Attribute(.unique) var id: UUID
    var morningCheckInId: UUID
    var region: String
    var intensity: Int
    var note: String
    var createdAt: Date

    init(morningCheckInId: UUID, region: String, intensity: Int, note: String = "") {
        self.id = UUID()
        self.morningCheckInId = morningCheckInId
        self.region = region
        self.intensity = intensity
        self.note = note
        self.createdAt = .now
    }
}

@Model
final class ExerciseModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var loadTypeRaw: String
    var referenceMaxKg: Double?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    var progressionStrategy: String?
    var startingTrainingMaxKg: Double?
    var currentTrainingMaxKg: Double?
    var currentBlock: Int
    var currentWeekInBlock: Int
    var weightIncrementKg: Double

    init(
        name: String,
        loadType: LoadKind,
        referenceMaxKg: Double? = nil,
        progressionStrategy: String? = nil,
        startingTrainingMaxKg: Double? = nil,
        currentTrainingMaxKg: Double? = nil,
        currentBlock: Int = 1,
        currentWeekInBlock: Int = 1,
        weightIncrementKg: Double = 2.5
    ) {
        self.id = UUID()
        self.name = name
        self.loadTypeRaw = loadType.rawValue
        self.referenceMaxKg = referenceMaxKg
        self.isArchived = false
        self.createdAt = .now
        self.updatedAt = .now
        self.progressionStrategy = progressionStrategy
        self.startingTrainingMaxKg = startingTrainingMaxKg
        self.currentTrainingMaxKg = currentTrainingMaxKg ?? startingTrainingMaxKg
        self.currentBlock = currentBlock
        self.currentWeekInBlock = currentWeekInBlock
        self.weightIncrementKg = weightIncrementKg
    }

    var loadType: LoadKind {
        get { LoadKind(rawValue: loadTypeRaw) ?? .none }
        set { loadTypeRaw = newValue.rawValue }
    }

    var hasMajorProgression: Bool {
        guard progressionStrategy != nil else { return false }
        return loadType == .bodyweightReps || currentTrainingMaxKg != nil
    }
}

@Model
final class StaticSkillVariantModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var name: String
    var sortOrder: Int
    var startingMaxHoldSeconds: Double?
    var bestCleanHoldSeconds: Double?
    var advanceAtSeconds: Double
    var workingHoldFraction: Double
    var workSetCount: Int
    var isActive: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        exerciseId: UUID,
        name: String,
        sortOrder: Int,
        startingMaxHoldSeconds: Double? = nil,
        advanceAtSeconds: Double = 15,
        workingHoldFraction: Double = 0.65,
        workSetCount: Int = 3,
        isActive: Bool = false
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.name = name
        self.sortOrder = sortOrder
        self.startingMaxHoldSeconds = startingMaxHoldSeconds
        self.bestCleanHoldSeconds = startingMaxHoldSeconds
        self.advanceAtSeconds = advanceAtSeconds
        self.workingHoldFraction = workingHoldFraction
        self.workSetCount = workSetCount
        self.isActive = isActive
        self.isArchived = false
        self.createdAt = .now
        self.updatedAt = .now
    }

    var referenceHoldSeconds: Double? {
        bestCleanHoldSeconds ?? startingMaxHoldSeconds
    }

    var prescribedHoldSeconds: Int? {
        guard let referenceHoldSeconds, referenceHoldSeconds > 0 else { return nil }
        return max(1, Int((referenceHoldSeconds * workingHoldFraction).rounded(.down)))
    }
}

@Model
final class StaticHoldRecordModel {
    @Attribute(.unique) var id: UUID
    var trainingSessionId: UUID
    var exerciseId: UUID
    var variantId: UUID
    var setNumber: Int
    var holdSeconds: Double
    var techniqueClean: Bool
    var isAllOutTest: Bool
    var recordedAt: Date

    init(
        trainingSessionId: UUID,
        exerciseId: UUID,
        variantId: UUID,
        setNumber: Int,
        holdSeconds: Double,
        techniqueClean: Bool,
        isAllOutTest: Bool
    ) {
        self.id = UUID()
        self.trainingSessionId = trainingSessionId
        self.exerciseId = exerciseId
        self.variantId = variantId
        self.setNumber = setNumber
        self.holdSeconds = holdSeconds
        self.techniqueClean = techniqueClean
        self.isAllOutTest = isAllOutTest
        self.recordedAt = .now
    }
}

@Model
final class WorkoutModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(name: String, kind: WorkoutKindValue) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.isArchived = false
        self.createdAt = .now
        self.updatedAt = .now
    }

    var kind: WorkoutKindValue {
        get { WorkoutKindValue(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class WorkoutExerciseModel {
    @Attribute(.unique) var id: UUID
    var workoutId: UUID
    var exerciseId: UUID
    var roleRaw: String
    var sortOrder: Int
    var mainWorkSetCountOverride: Int?
    var accessorySetCountOverride: Int?

    init(workoutId: UUID, exerciseId: UUID, role: ExerciseRoleValue, sortOrder: Int) {
        self.id = UUID()
        self.workoutId = workoutId
        self.exerciseId = exerciseId
        self.roleRaw = role.rawValue
        self.sortOrder = sortOrder
        self.mainWorkSetCountOverride = nil
        self.accessorySetCountOverride = nil
    }

    var role: ExerciseRoleValue {
        get { ExerciseRoleValue(rawValue: roleRaw) ?? .accessory }
        set { roleRaw = newValue.rawValue }
    }
}

@Model
final class ProgressionCycleModel {
    @Attribute(.unique) var id: UUID
    var exerciseId: UUID
    var cycleNumber: Int
    var startedAt: Date
    var completedAt: Date?
    var startingTrainingMaxKg: Double
    var currentTrainingMaxKg: Double
    var finalTrainingMaxKg: Double?
    var currentBlock: Int
    var currentWeekInBlock: Int
    var statusRaw: String
    var activeConfigVersionId: UUID

    init(
        exerciseId: UUID,
        cycleNumber: Int,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        startingTrainingMaxKg: Double,
        currentTrainingMaxKg: Double? = nil,
        finalTrainingMaxKg: Double? = nil,
        currentBlock: Int = 1,
        currentWeekInBlock: Int = 1,
        status: ProgressionCycleStatusValue = .active,
        activeConfigVersionId: UUID = UUID()
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.cycleNumber = cycleNumber
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.startingTrainingMaxKg = startingTrainingMaxKg
        self.currentTrainingMaxKg = currentTrainingMaxKg ?? startingTrainingMaxKg
        self.finalTrainingMaxKg = finalTrainingMaxKg
        self.currentBlock = currentBlock
        self.currentWeekInBlock = currentWeekInBlock
        self.statusRaw = status.rawValue
        self.activeConfigVersionId = activeConfigVersionId
    }

    var status: ProgressionCycleStatusValue {
        get { ProgressionCycleStatusValue(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class SBSConfigVersionModel {
    @Attribute(.unique) var id: UUID
    var versionNumber: Int
    var createdAt: Date
    var isActive: Bool

    var week1Intensity: Double
    var week1SetCount: Int
    var week1WorkSetReps: Int
    var week1RepOutTarget: Int
    var week2Intensity: Double
    var week2SetCount: Int
    var week2WorkSetReps: Int
    var week2RepOutTarget: Int
    var week3Intensity: Double
    var week3SetCount: Int
    var week3WorkSetReps: Int
    var week3RepOutTarget: Int
    var week4Intensity: Double
    var week4SetCount: Int
    var week4WorkSetReps: Int
    var week4RepOutTarget: Int
    var week5Intensity: Double
    var week5SetCount: Int
    var week5WorkSetReps: Int
    var week5RepOutTarget: Int
    var week6Intensity: Double
    var week6SetCount: Int
    var week6WorkSetReps: Int
    var week6RepOutTarget: Int
    var bodyweightWeek1Intensity: Double?
    var bodyweightWeek2Intensity: Double?
    var bodyweightWeek3Intensity: Double?
    var bodyweightWeek4Intensity: Double?
    var bodyweightWeek5Intensity: Double?
    var bodyweightWeek6Intensity: Double?

    var belowTargetBy2PlusPercent: Double
    var belowTargetBy1Percent: Double
    var hitTargetPercent: Double
    var beatTargetBy1Percent: Double
    var beatTargetBy2Percent: Double
    var beatTargetBy3Percent: Double
    var beatTargetBy4Percent: Double
    var beatTargetBy5PlusPercent: Double

    init(versionNumber: Int = 1, createdAt: Date = .now, isActive: Bool = true) {
        self.id = UUID()
        self.versionNumber = versionNumber
        self.createdAt = createdAt
        self.isActive = isActive

        let week1 = SBSReference.week(1)
        let week2 = SBSReference.week(2)
        let week3 = SBSReference.week(3)
        let week4 = SBSReference.week(4)
        let week5 = SBSReference.week(5)
        let week6 = SBSReference.week(6)

        self.week1Intensity = week1.intensity
        self.week1SetCount = week1.sets
        self.week1WorkSetReps = week1.reps
        self.week1RepOutTarget = week1.target
        self.week2Intensity = week2.intensity
        self.week2SetCount = week2.sets
        self.week2WorkSetReps = week2.reps
        self.week2RepOutTarget = week2.target
        self.week3Intensity = week3.intensity
        self.week3SetCount = week3.sets
        self.week3WorkSetReps = week3.reps
        self.week3RepOutTarget = week3.target
        self.week4Intensity = week4.intensity
        self.week4SetCount = week4.sets
        self.week4WorkSetReps = week4.reps
        self.week4RepOutTarget = week4.target
        self.week5Intensity = week5.intensity
        self.week5SetCount = week5.sets
        self.week5WorkSetReps = week5.reps
        self.week5RepOutTarget = week5.target
        self.week6Intensity = week6.intensity
        self.week6SetCount = week6.sets
        self.week6WorkSetReps = week6.reps
        self.week6RepOutTarget = week6.target
        self.bodyweightWeek1Intensity = nil
        self.bodyweightWeek2Intensity = nil
        self.bodyweightWeek3Intensity = nil
        self.bodyweightWeek4Intensity = nil
        self.bodyweightWeek5Intensity = nil
        self.bodyweightWeek6Intensity = nil

        self.belowTargetBy2PlusPercent = -0.05
        self.belowTargetBy1Percent = -0.02
        self.hitTargetPercent = 0
        self.beatTargetBy1Percent = 0.005
        self.beatTargetBy2Percent = 0.01
        self.beatTargetBy3Percent = 0.015
        self.beatTargetBy4Percent = 0.02
        self.beatTargetBy5PlusPercent = 0.03
    }

    func prescription(for week: Int) -> (week: Int, intensity: Double, sets: Int, reps: Int, target: Int) {
        switch week {
        case 2:
            (2, week2Intensity, week2SetCount, week2WorkSetReps, week2RepOutTarget)
        case 3:
            (3, week3Intensity, week3SetCount, week3WorkSetReps, week3RepOutTarget)
        case 4:
            (4, week4Intensity, week4SetCount, week4WorkSetReps, week4RepOutTarget)
        case 5:
            (5, week5Intensity, week5SetCount, week5WorkSetReps, week5RepOutTarget)
        case 6:
            (6, week6Intensity, week6SetCount, week6WorkSetReps, week6RepOutTarget)
        default:
            (1, week1Intensity, week1SetCount, week1WorkSetReps, week1RepOutTarget)
        }
    }

    func prescription(for week: Int, loadType: LoadKind) -> (week: Int, intensity: Double, sets: Int, reps: Int, target: Int) {
        let base = prescription(for: week)
        return (base.week, intensity(for: base.week, loadType: loadType), base.sets, base.reps, base.target)
    }

    func intensity(for week: Int, loadType: LoadKind) -> Double {
        let base = prescription(for: week).intensity
        guard loadType == .bodyweightPlusExternal else { return base }

        switch week {
        case 2:
            return bodyweightWeek2Intensity ?? base
        case 3:
            return bodyweightWeek3Intensity ?? base
        case 4:
            return bodyweightWeek4Intensity ?? base
        case 5:
            return bodyweightWeek5Intensity ?? base
        case 6:
            return bodyweightWeek6Intensity ?? base
        default:
            return bodyweightWeek1Intensity ?? base
        }
    }

    func adjustmentPercent(actual: Int, target: Int) -> Double {
        switch max(-2, min(5, actual - target)) {
        case -2: belowTargetBy2PlusPercent
        case -1: belowTargetBy1Percent
        case 0: hitTargetPercent
        case 1: beatTargetBy1Percent
        case 2: beatTargetBy2Percent
        case 3: beatTargetBy3Percent
        case 4: beatTargetBy4Percent
        default: beatTargetBy5PlusPercent
        }
    }

    func clone(versionNumber: Int) -> SBSConfigVersionModel {
        let copy = SBSConfigVersionModel(versionNumber: versionNumber, isActive: true)
        copy.week1Intensity = week1Intensity
        copy.week1SetCount = week1SetCount
        copy.week1WorkSetReps = week1WorkSetReps
        copy.week1RepOutTarget = week1RepOutTarget
        copy.week2Intensity = week2Intensity
        copy.week2SetCount = week2SetCount
        copy.week2WorkSetReps = week2WorkSetReps
        copy.week2RepOutTarget = week2RepOutTarget
        copy.week3Intensity = week3Intensity
        copy.week3SetCount = week3SetCount
        copy.week3WorkSetReps = week3WorkSetReps
        copy.week3RepOutTarget = week3RepOutTarget
        copy.week4Intensity = week4Intensity
        copy.week4SetCount = week4SetCount
        copy.week4WorkSetReps = week4WorkSetReps
        copy.week4RepOutTarget = week4RepOutTarget
        copy.week5Intensity = week5Intensity
        copy.week5SetCount = week5SetCount
        copy.week5WorkSetReps = week5WorkSetReps
        copy.week5RepOutTarget = week5RepOutTarget
        copy.week6Intensity = week6Intensity
        copy.week6SetCount = week6SetCount
        copy.week6WorkSetReps = week6WorkSetReps
        copy.week6RepOutTarget = week6RepOutTarget
        copy.bodyweightWeek1Intensity = bodyweightWeek1Intensity
        copy.bodyweightWeek2Intensity = bodyweightWeek2Intensity
        copy.bodyweightWeek3Intensity = bodyweightWeek3Intensity
        copy.bodyweightWeek4Intensity = bodyweightWeek4Intensity
        copy.bodyweightWeek5Intensity = bodyweightWeek5Intensity
        copy.bodyweightWeek6Intensity = bodyweightWeek6Intensity
        copy.belowTargetBy2PlusPercent = belowTargetBy2PlusPercent
        copy.belowTargetBy1Percent = belowTargetBy1Percent
        copy.hitTargetPercent = hitTargetPercent
        copy.beatTargetBy1Percent = beatTargetBy1Percent
        copy.beatTargetBy2Percent = beatTargetBy2Percent
        copy.beatTargetBy3Percent = beatTargetBy3Percent
        copy.beatTargetBy4Percent = beatTargetBy4Percent
        copy.beatTargetBy5PlusPercent = beatTargetBy5PlusPercent
        return copy
    }
}

@Model
final class WeeklySlotModel {
    @Attribute(.unique) var id: UUID
    var weekday: Int
    var workoutId: UUID
    var workoutName: String
    var kindRaw: String
    var hour: Int?
    var minute: Int?
    var sortOrder: Int

    init(
        weekday: Int,
        workoutId: UUID,
        workoutName: String,
        kind: WorkoutKindValue,
        hour: Int? = nil,
        minute: Int? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.weekday = weekday
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.kindRaw = kind.rawValue
        self.hour = hour
        self.minute = minute
        self.sortOrder = sortOrder
    }

    var kind: WorkoutKindValue {
        WorkoutKindValue(rawValue: kindRaw) ?? .strength
    }
}

@Model
final class PlannedTrainingModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var workoutId: UUID
    var workoutName: String
    var kindRaw: String
    var hour: Int?
    var minute: Int?
    var isReplacement: Bool
    var isPostponed: Bool
    var replacedWorkoutId: UUID?
    var isSkippedMarker: Bool
    var eventKitIdentifier: String?

    init(
        date: Date,
        workoutId: UUID,
        workoutName: String,
        kind: WorkoutKindValue,
        hour: Int? = nil,
        minute: Int? = nil,
        isReplacement: Bool = false,
        isPostponed: Bool = false,
        replacedWorkoutId: UUID? = nil,
        isSkippedMarker: Bool = false,
        eventKitIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.kindRaw = kind.rawValue
        self.hour = hour
        self.minute = minute
        self.isReplacement = isReplacement
        self.isPostponed = isPostponed
        self.replacedWorkoutId = replacedWorkoutId
        self.isSkippedMarker = isSkippedMarker
        self.eventKitIdentifier = eventKitIdentifier
    }

    var kind: WorkoutKindValue {
        WorkoutKindValue(rawValue: kindRaw) ?? .strength
    }
}

@Model
final class DayStatusModel {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var startDate: Date
    var endDate: Date
    var note: String

    init(type: DayStatusValue, startDate: Date, endDate: Date, note: String = "") {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.note = note
    }

    var type: DayStatusValue {
        get { DayStatusValue(rawValue: typeRaw) ?? .normal }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class DayContextEventModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String

    init(date: Date, note: String = "") {
        self.id = UUID()
        self.date = date
        self.note = note
    }
}

@Model
final class DayNoteModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String

    init(date: Date, note: String) {
        self.id = UUID()
        self.date = date
        self.note = note
    }
}

@Model
final class ProgressPhotoModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    @Attribute(.externalStorage) var imageData: Data

    init(date: Date, imageData: Data) {
        self.id = UUID()
        self.date = date
        self.imageData = imageData
    }
}

@Model
final class TrainingSessionModel {
    @Attribute(.unique) var id: UUID
    var workoutId: UUID?
    var workoutName: String
    var kindRaw: String
    var startedAt: Date
    var endedAt: Date?
    var isMinimized: Bool
    var workSetCompletionMask: String
    var accessoryCompletionMask: String
    var repOutReps: Int?
    var sessionRPE: Int?
    var bodyFeeling: Int?
    var overallLoad: Double?
    var cardioLoad: Double?
    var muscularLoad: Double?
    var staticWorkHoldSeconds: String
    var staticTechniqueMask: String
    var staticAllOutHoldSeconds: Double?
    var staticAllOutTechniqueClean: Bool

    init(workoutId: UUID?, workoutName: String, kind: WorkoutKindValue, startedAt: Date = .now) {
        self.id = UUID()
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.kindRaw = kind.rawValue
        self.startedAt = startedAt
        self.endedAt = nil
        self.isMinimized = false
        self.workSetCompletionMask = "0000"
        self.accessoryCompletionMask = "000"
        self.staticWorkHoldSeconds = "||"
        self.staticTechniqueMask = "000"
        self.staticAllOutHoldSeconds = nil
        self.staticAllOutTechniqueClean = false
    }

    var kind: WorkoutKindValue {
        WorkoutKindValue(rawValue: kindRaw) ?? .strength
    }
}

@Model
final class ExerciseSessionSnapshotModel {
    @Attribute(.unique) var id: UUID
    var trainingSessionId: UUID
    var exerciseName: String
    var progressionConfigVersion: Int
    var blockNumber: Int
    var weekInBlock: Int
    var trainingMaxBeforeKg: Double
    var referenceBodyweightKg: Double?
    var weeklyIntensity: Double
    var prescribedExternalWeightKg: Double?
    var prescribedSystemWeightKg: Double?
    var prescribedSetCount: Int
    var prescribedWorkSetReps: Int
    var prescribedRepOutTarget: Int
    var actualRepOutReps: Int?
    var appliedAdjustmentPercent: Double?
    var trainingMaxAfterKg: Double?
    var wasSkipped: Bool

    init(
        trainingSessionId: UUID,
        exerciseName: String,
        progressionConfigVersion: Int = 1,
        blockNumber: Int,
        weekInBlock: Int,
        trainingMaxBeforeKg: Double,
        referenceBodyweightKg: Double?,
        weeklyIntensity: Double,
        prescribedExternalWeightKg: Double?,
        prescribedSystemWeightKg: Double?,
        prescribedSetCount: Int,
        prescribedWorkSetReps: Int,
        prescribedRepOutTarget: Int,
        actualRepOutReps: Int?,
        appliedAdjustmentPercent: Double?,
        trainingMaxAfterKg: Double?,
        wasSkipped: Bool = false
    ) {
        self.id = UUID()
        self.trainingSessionId = trainingSessionId
        self.exerciseName = exerciseName
        self.progressionConfigVersion = progressionConfigVersion
        self.blockNumber = blockNumber
        self.weekInBlock = weekInBlock
        self.trainingMaxBeforeKg = trainingMaxBeforeKg
        self.referenceBodyweightKg = referenceBodyweightKg
        self.weeklyIntensity = weeklyIntensity
        self.prescribedExternalWeightKg = prescribedExternalWeightKg
        self.prescribedSystemWeightKg = prescribedSystemWeightKg
        self.prescribedSetCount = prescribedSetCount
        self.prescribedWorkSetReps = prescribedWorkSetReps
        self.prescribedRepOutTarget = prescribedRepOutTarget
        self.actualRepOutReps = actualRepOutReps
        self.appliedAdjustmentPercent = appliedAdjustmentPercent
        self.trainingMaxAfterKg = trainingMaxAfterKg
        self.wasSkipped = wasSkipped
    }
}

@Model
final class SleepRecordModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalMinutes: Double?
    var remMinutes: Double?
    var deepMinutes: Double?
    var coreMinutes: Double?
    var awakeMinutes: Double?
    var averageSleepingHeartRate: Double?
    var restingHeartRate: Double?
    var steps: Double?

    init(date: Date) {
        self.id = UUID()
        self.date = date
    }
}

@Model
final class ImportedActivityDataModel {
    @Attribute(.unique) var externalIdentifier: String
    var id: UUID
    var sourceIdentifier: String
    var start: Date
    var end: Date
    var distanceMeters: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var calories: Double?
    var sessionRPE: Int?

    init(
        externalIdentifier: String,
        sourceIdentifier: String,
        start: Date,
        end: Date,
        distanceMeters: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        calories: Double? = nil,
        sessionRPE: Int? = nil
    ) {
        self.externalIdentifier = externalIdentifier
        self.id = UUID()
        self.sourceIdentifier = sourceIdentifier
        self.start = start
        self.end = end
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.calories = calories
        self.sessionRPE = sessionRPE
    }
}

@Model
final class AppSettingsModel {
    @Attribute(.unique) var id: UUID
    var sleepIdealMinutes: Double
    var sleepDurationWeight: Double
    var sleepDeepWeight: Double
    var sleepREMWeight: Double
    var sleepDeepLowerPercent: Double?
    var sleepDeepIdealPercent: Double?
    var sleepDeepUpperPercent: Double?
    var sleepREMLowerPercent: Double?
    var sleepREMIdealPercent: Double?
    var sleepREMUpperPercent: Double?
    var sleepAwakePenaltyWeight: Double
    var strengthLoadMultiplier: Double
    var simpleLoadMultiplier: Double
    var cardioDistanceDivisor: Double

    init() {
        self.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        self.sleepIdealMinutes = 480
        self.sleepDurationWeight = 0.50
        self.sleepDeepWeight = 0.18
        self.sleepREMWeight = 0.17
        self.sleepDeepLowerPercent = 0.16
        self.sleepDeepIdealPercent = 0.25
        self.sleepDeepUpperPercent = 0.31
        self.sleepREMLowerPercent = 0.21
        self.sleepREMIdealPercent = 0.25
        self.sleepREMUpperPercent = 0.31
        self.sleepAwakePenaltyWeight = 0.05
        self.strengthLoadMultiplier = 10
        self.simpleLoadMultiplier = 8
        self.cardioDistanceDivisor = 1000
    }
}

struct SleepScoreConfig {
    var idealSleepMinutes: Double
    var durationWeight: Double
    var deepWeight: Double
    var remWeight: Double
    var deepLowerPercent: Double
    var deepIdealPercent: Double
    var deepUpperPercent: Double
    var remLowerPercent: Double
    var remIdealPercent: Double
    var remUpperPercent: Double
    var awakePenaltyWeight: Double

    init(settings: AppSettingsModel?) {
        self.idealSleepMinutes = settings?.sleepIdealMinutes ?? 480
        self.durationWeight = settings?.sleepDurationWeight ?? 0.50
        self.deepWeight = settings?.sleepDeepWeight ?? 0.18
        self.remWeight = settings?.sleepREMWeight ?? 0.17
        self.deepLowerPercent = settings?.sleepDeepLowerPercent ?? 0.16
        self.deepIdealPercent = settings?.sleepDeepIdealPercent ?? 0.25
        self.deepUpperPercent = settings?.sleepDeepUpperPercent ?? 0.31
        self.remLowerPercent = settings?.sleepREMLowerPercent ?? 0.21
        self.remIdealPercent = settings?.sleepREMIdealPercent ?? 0.25
        self.remUpperPercent = settings?.sleepREMUpperPercent ?? 0.31
        self.awakePenaltyWeight = settings?.sleepAwakePenaltyWeight ?? 0.05
    }
}

struct SleepScoreBreakdown {
    var score: Int?
    var durationScore: Double?
    var deepScore: Double?
    var remScore: Double?
    var awakePenalty: Double?
    var availableWeight: Double
}

enum SleepScoreCalculator {
    static func breakdown(record: SleepRecordModel?, config: SleepScoreConfig) -> SleepScoreBreakdown {
        guard let record, let total = record.totalMinutes, total > 0 else {
            return SleepScoreBreakdown(score: nil, durationScore: nil, deepScore: nil, remScore: nil, awakePenalty: nil, availableWeight: 0)
        }

        let idealMinutes = max(config.idealSleepMinutes, 1)
        let durationScore = min(total / idealMinutes, 1) * 100
        var weightedTotal = durationScore * config.durationWeight
        var availableWeight = config.durationWeight

        var deepScore: Double?
        if let deep = record.deepMinutes {
            let score = percentBandScore(
                value: deep / total,
                lower: config.deepLowerPercent,
                ideal: config.deepIdealPercent,
                upper: config.deepUpperPercent
            )
            deepScore = score
            weightedTotal += score * config.deepWeight
            availableWeight += config.deepWeight
        }

        var remScore: Double?
        if let rem = record.remMinutes {
            let score = percentBandScore(
                value: rem / total,
                lower: config.remLowerPercent,
                ideal: config.remIdealPercent,
                upper: config.remUpperPercent
            )
            remScore = score
            weightedTotal += score * config.remWeight
            availableWeight += config.remWeight
        }

        var awakePenalty: Double?
        if let awake = record.awakeMinutes {
            let penalty = min(awake / 90, 1) * 100 * config.awakePenaltyWeight
            awakePenalty = penalty
            weightedTotal -= penalty
        }

        let normalized = availableWeight > 0 ? weightedTotal / availableWeight : weightedTotal
        let clamped = max(0, min(100, normalized))
        return SleepScoreBreakdown(
            score: Int(clamped.rounded()),
            durationScore: durationScore,
            deepScore: deepScore,
            remScore: remScore,
            awakePenalty: awakePenalty,
            availableWeight: availableWeight
        )
    }

    private static func percentBandScore(value: Double, lower: Double, ideal: Double, upper: Double) -> Double {
        let lower = max(0, min(1, lower))
        let upper = max(lower + 0.01, min(1, upper))
        let ideal = max(lower, min(upper, ideal))

        if value < lower {
            return max(0, 70 * (value / max(lower, 0.01)))
        }
        if value > upper {
            return max(0, 70 * ((1 - value) / max(1 - upper, 0.01)))
        }

        if value <= ideal {
            let distance = (ideal - value) / max(ideal - lower, 0.01)
            return 100 - distance * 30
        }

        let distance = (value - ideal) / max(upper - ideal, 0.01)
        return 100 - distance * 30
    }
}

enum SBSReference {
    static let weeks: [(week: Int, intensity: Double, sets: Int, reps: Int, target: Int)] = [
        (1, 0.70, 4, 5, 10),
        (2, 0.75, 4, 4, 8),
        (3, 0.80, 4, 3, 6),
        (4, 0.725, 4, 5, 9),
        (5, 0.775, 4, 4, 7),
        (6, 0.825, 4, 3, 5)
    ]

    static func week(_ value: Int) -> (week: Int, intensity: Double, sets: Int, reps: Int, target: Int) {
        weeks.first { $0.week == value } ?? weeks[0]
    }

    static func adjustmentPercent(actual: Int, target: Int) -> Double {
        switch max(-2, min(5, actual - target)) {
        case -2: -0.05
        case -1: -0.02
        case 0: 0
        case 1: 0.005
        case 2: 0.01
        case 3: 0.015
        case 4: 0.02
        default: 0.03
        }
    }

    static func rounded(_ value: Double, increment: Double) -> Double {
        guard increment > 0 else { return value }
        return (value / increment).rounded() * increment
    }
}

enum SeedData {
    @MainActor
    static func installIfNeeded(context: ModelContext) {
        let settingsFetch = FetchDescriptor<AppSettingsModel>()
        if ((try? context.fetch(settingsFetch)) ?? []).isEmpty {
            context.insert(AppSettingsModel())
        }

        let sbsFetch = FetchDescriptor<SBSConfigVersionModel>()
        if ((try? context.fetch(sbsFetch)) ?? []).isEmpty {
            context.insert(SBSConfigVersionModel())
        }

        let scaleFetch = FetchDescriptor<ScaleModel>()
        if ((try? context.fetch(scaleFetch)) ?? []).isEmpty {
            context.insert(ScaleModel(name: "Waage 1"))
            context.insert(ScaleModel(name: "Waage 2"))
        }

        let exerciseFetch = FetchDescriptor<ExerciseModel>()
        let exercises = (try? context.fetch(exerciseFetch)) ?? []
        let hasFrontLever = exercises.contains {
            $0.name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .replacingOccurrences(of: " ", with: "")
                .contains("frontlever")
        }
        var exercisesByName = Dictionary(uniqueKeysWithValues: exercises.map { (normalizedSeedName($0.name), $0) })
        if !hasFrontLever {
            let frontLever = ExerciseModel(name: "Front Lever", loadType: .staticHold)
            context.insert(frontLever)
            exercisesByName[normalizedSeedName(frontLever.name)] = frontLever
            ["Advanced Tuck", "Frog Leg", "Straddle"].enumerated().forEach { index, name in
                context.insert(StaticSkillVariantModel(
                    exerciseId: frontLever.id,
                    name: name,
                    sortOrder: index,
                    isActive: index == 0
                ))
            }
        }

        let defaultExercises: [(name: String, loadType: LoadKind, referenceMaxKg: Double?, progression: String?)] = [
            ("Seitheben", .none, nil, nil),
            ("Liegestütze Parallettes", .none, nil, nil),
            ("Liegestütze Ball", .none, nil, nil),
            ("Lying Core Crunches", .none, nil, nil),
            ("Reverse Seitheben", .none, nil, nil),
            ("Trizeps Überkopf", .none, nil, nil),
            ("Frontlever Negatives", .none, nil, nil),
            ("Bizeps Curls Dumbbells", .none, nil, nil),
            ("Bizeps Curls Barbell", .none, nil, nil),
            ("Reverse Deadlifts", .none, nil, nil),
            ("Pistol Squats", .none, nil, nil),
            ("Single Leg Romanian Deadlift", .none, nil, nil),
            ("Romanian Deadlift", .none, nil, nil),
            ("Frontlever Rows", .bodyweightReps, nil, "SBS Reps to Failure"),
            ("Handstandpushups", .bodyweightReps, nil, "SBS Reps to Failure"),
            ("Benchpress", .externalWeight, 100, nil),
            ("Larsen Press", .externalWeight, 90, nil),
            ("Klimmzug", .bodyweightPlusExternal, 50, nil),
            ("Klimmzug hoch", .bodyweightPlusExternal, 40, nil),
            ("Chinups", .bodyweightPlusExternal, 35, nil),
            ("Dips", .bodyweightPlusExternal, 50, nil),
            ("Seated DB Press", .externalWeight, 35, nil),
            ("Handstandpress", .bodyweightReps, nil, "SBS Reps to Failure"),
            ("Dips BW", .bodyweightReps, nil, nil),
            ("Pushups mit Gymnastikball", .bodyweightReps, nil, nil),
            ("Trizeps Extensions", .bodyweightReps, nil, nil),
            ("Abs Curls mit Zusatzgewicht", .bodyweightReps, nil, nil),
            ("Frontlever Drops", .bodyweightReps, nil, nil),
            ("High Pullups", .bodyweightPlusExternal, 35, nil),
            ("Face Pulls", .none, nil, nil),
            ("Bizeps Curls Kabelzug", .none, nil, nil),
            ("Handstandpushups an der Wand", .bodyweightReps, nil, "SBS Reps to Failure"),
            ("Handstandpushups an der Wand + Zusatzgewicht", .bodyweightPlusExternal, nil, nil),
            ("Trizeps Overhead", .none, nil, nil),
            ("Lying Ab Crunches", .none, nil, nil),
            ("Frontlever Pulls", .bodyweightReps, nil, "SBS Reps to Failure")
        ]

        for item in defaultExercises where exercisesByName[normalizedSeedName(item.name)] == nil {
            let exercise = ExerciseModel(
                name: item.name,
                loadType: item.loadType,
                referenceMaxKg: item.referenceMaxKg,
                progressionStrategy: item.progression
            )
            context.insert(exercise)
            exercisesByName[normalizedSeedName(item.name)] = exercise
        }

        exercisesByName[normalizedSeedName("Larsen Press")]?.referenceMaxKg = 90

        let workoutFetch = FetchDescriptor<WorkoutModel>()
        let workouts = (try? context.fetch(workoutFetch)) ?? []
        var workoutsByName = Dictionary(uniqueKeysWithValues: workouts.map { (normalizedSeedName($0.name), $0) })
        for name in ["Bouldern", "Volleyball", "Spikeball"] where workoutsByName[normalizedSeedName(name)] == nil {
            let workout = WorkoutModel(name: name, kind: .simpleActivity)
            context.insert(workout)
            workoutsByName[normalizedSeedName(name)] = workout
        }
        let membershipFetch = FetchDescriptor<WorkoutExerciseModel>()
        var membershipsByWorkout = Dictionary(grouping: (try? context.fetch(membershipFetch)) ?? [], by: \WorkoutExerciseModel.workoutId)

        func ensureWorkout(
            name: String,
            kind: WorkoutKindValue = .strength,
            exercises: [(name: String, role: ExerciseRoleValue, sets: Int?)]
        ) -> WorkoutModel {
            let workout: WorkoutModel
            if let existing = workoutsByName[normalizedSeedName(name)] {
                workout = existing
            } else {
                let created = WorkoutModel(name: name, kind: kind)
                context.insert(created)
                workoutsByName[normalizedSeedName(name)] = created
                workout = created
            }

            var members = membershipsByWorkout[workout.id] ?? []
            for (index, item) in exercises.enumerated() {
                guard let exercise = exercisesByName[normalizedSeedName(item.name)] else { continue }
                if let existing = members.first(where: { $0.exerciseId == exercise.id }) {
                    existing.role = item.role
                    existing.sortOrder = index
                    if item.role == .accessory {
                        existing.accessorySetCountOverride = item.sets
                    }
                    continue
                }
                let membership = WorkoutExerciseModel(
                    workoutId: workout.id,
                    exerciseId: exercise.id,
                    role: item.role,
                    sortOrder: index
                )
                membership.accessorySetCountOverride = item.sets
                context.insert(membership)
                members.append(membership)
            }
            membershipsByWorkout[workout.id] = members
            return workout
        }

        let pushOne = ensureWorkout(name: "Push 1", exercises: [
            ("Seated DB Press", .major, nil),
            ("Handstandpress", .accessory, nil),
            ("Dips BW", .accessory, 3),
            ("Seitheben", .accessory, 5),
            ("Pushups mit Gymnastikball", .accessory, 2),
            ("Trizeps Extensions", .accessory, 3),
            ("Abs Curls mit Zusatzgewicht", .accessory, 3)
        ])

        let pullOne = ensureWorkout(name: "Pull 1", exercises: [
            ("Frontlever Drops", .accessory, 3),
            ("High Pullups", .major, nil),
            ("Frontlever Rows", .accessory, 4),
            ("Chinups", .accessory, 2),
            ("Face Pulls", .accessory, 3),
            ("Bizeps Curls Kabelzug", .accessory, 3),
            ("Bizeps Curls Dumbbells", .accessory, 3)
        ])

        _ = ensureWorkout(name: "Push 2", exercises: [
            ("Larsen Press", .major, nil),
            ("Handstandpushups an der Wand", .accessory, nil),
            ("Pushups mit Gymnastikball", .accessory, 3),
            ("Seitheben", .accessory, 5),
            ("Trizeps Overhead", .accessory, 3),
            ("Lying Ab Crunches", .accessory, 3)
        ])

        _ = ensureWorkout(name: "Pull 2", exercises: [
            ("Klimmzug", .major, nil),
            ("Front Lever", .accessory, 3),
            ("Chinups", .accessory, 2),
            ("Frontlever Pulls", .accessory, nil),
            ("Bizeps Curls Dumbbells", .accessory, 3)
        ])

        _ = ensureWorkout(name: "Mixed 1", exercises: [
            ("Klimmzug", .major, nil),
            ("Larsen Press", .major, nil),
            ("Front Lever", .accessory, 3),
            ("Handstandpushups an der Wand + Zusatzgewicht", .accessory, nil),
            ("Seitheben", .accessory, 6),
            ("Bizeps Curls Dumbbells", .accessory, 3),
            ("Trizeps Overhead", .accessory, 3)
        ])

        let weeklySlotFetch = FetchDescriptor<WeeklySlotModel>()
        let weeklySlots = (try? context.fetch(weeklySlotFetch)) ?? []
        if !weeklySlots.contains(where: { $0.weekday == 2 && $0.workoutId == pushOne.id }) {
            let nextOrder = (weeklySlots.filter { $0.weekday == 2 }.map(\.sortOrder).max() ?? -1) + 1
            context.insert(WeeklySlotModel(
                weekday: 2,
                workoutId: pushOne.id,
                workoutName: pushOne.name,
                kind: pushOne.kind,
                sortOrder: nextOrder
            ))
        }
        if !weeklySlots.contains(where: { $0.weekday == 4 && $0.workoutId == pullOne.id }) {
            let nextOrder = (weeklySlots.filter { $0.weekday == 4 }.map(\.sortOrder).max() ?? -1) + 1
            context.insert(WeeklySlotModel(
                weekday: 4,
                workoutId: pullOne.id,
                workoutName: pullOne.name,
                kind: pullOne.kind,
                sortOrder: nextOrder
            ))
        }

        try? context.save()
    }

    private static func normalizedSeedName(_ name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
    }
}
