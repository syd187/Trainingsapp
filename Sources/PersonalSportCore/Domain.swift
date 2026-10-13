import Foundation

public enum LoadType: String, Codable, CaseIterable, Sendable {
    case externalWeight
    case bodyweightPlusExternal
    case none
}

public enum WorkoutKind: String, Codable, CaseIterable, Sendable {
    case strength
    case simpleActivity
    case importedActivity
}

public enum WorkoutRole: String, Codable, CaseIterable, Sendable {
    case major
    case accessory
}

public enum DayStatusType: String, Codable, CaseIterable, Sendable {
    case normal
    case rest
    case sick
    case vacation
    case travel
    case ignore
    case deload

    public var preventsTraining: Bool {
        switch self {
        case .normal, .ignore:
            false
        case .rest, .sick, .vacation, .travel, .deload:
            true
        }
    }
}

public enum ContextEventType: String, Codable, CaseIterable, Sendable {
    case nightOut
}

public struct Exercise: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var loadType: LoadType
    public var referenceMaxWeight: Decimal?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        loadType: LoadType,
        referenceMaxWeight: Decimal? = nil,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.loadType = loadType
        self.referenceMaxWeight = referenceMaxWeight
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkoutTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: WorkoutKind

    public init(id: UUID = UUID(), name: String, kind: WorkoutKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public struct WeeklyScheduleSlot: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var weekday: Int
    public var workoutId: UUID
    public var workoutName: String
    public var plannedTime: DateComponents?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        weekday: Int,
        workoutId: UUID,
        workoutName: String,
        plannedTime: DateComponents? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.weekday = weekday
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.plannedTime = plannedTime
        self.sortOrder = sortOrder
    }
}

public struct DayStatusPeriod: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: DayStatusType
    public var start: Date
    public var end: Date
    public var note: String?

    public init(id: UUID = UUID(), type: DayStatusType, start: Date, end: Date, note: String? = nil) {
        self.id = id
        self.type = type
        self.start = start
        self.end = end
        self.note = note
    }
}

public struct DayContextEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: ContextEventType
    public var date: Date
    public var note: String?

    public init(id: UUID = UUID(), type: ContextEventType, date: Date, note: String? = nil) {
        self.id = id
        self.type = type
        self.date = date
        self.note = note
    }
}

public struct PlannedTrainingOccurrence: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceSlotId: UUID?
    public var date: Date
    public var workoutId: UUID
    public var workoutName: String
    public var plannedTime: DateComponents?
    public var isReplacement: Bool
    public var isPostponed: Bool
    public var eventKitIdentifier: String?

    public init(
        id: UUID = UUID(),
        sourceSlotId: UUID? = nil,
        date: Date,
        workoutId: UUID,
        workoutName: String,
        plannedTime: DateComponents? = nil,
        isReplacement: Bool = false,
        isPostponed: Bool = false,
        eventKitIdentifier: String? = nil
    ) {
        self.id = id
        self.sourceSlotId = sourceSlotId
        self.date = date
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.plannedTime = plannedTime
        self.isReplacement = isReplacement
        self.isPostponed = isPostponed
        self.eventKitIdentifier = eventKitIdentifier
    }
}

public struct WeightEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var weight: Decimal
    public var scaleId: UUID

    public init(id: UUID = UUID(), date: Date, weight: Decimal, scaleId: UUID) {
        self.id = id
        self.date = date
        self.weight = weight
        self.scaleId = scaleId
    }
}

public struct ImportedActivity: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var externalIdentifier: String
    public var sourceIdentifier: String
    public var start: Date
    public var end: Date
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var calories: Double?

    public init(
        id: UUID = UUID(),
        externalIdentifier: String,
        sourceIdentifier: String,
        start: Date,
        end: Date,
        distanceMeters: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        calories: Double? = nil
    ) {
        self.id = id
        self.externalIdentifier = externalIdentifier
        self.sourceIdentifier = sourceIdentifier
        self.start = start
        self.end = end
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.calories = calories
    }
}
