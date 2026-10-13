import Foundation

public struct ActiveTrainingSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var workoutName: String
    public var kind: WorkoutKind
    public var startedAt: Date
    public var isMinimized: Bool

    public init(
        id: UUID = UUID(),
        workoutName: String,
        kind: WorkoutKind,
        startedAt: Date,
        isMinimized: Bool = false
    ) {
        self.id = id
        self.workoutName = workoutName
        self.kind = kind
        self.startedAt = startedAt
        self.isMinimized = isMinimized
    }

    public func elapsed(at date: Date = .now) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}

public struct ActiveSessionPersistence: Sendable {
    public init() {}

    public func encode(_ session: ActiveTrainingSession?) throws -> Data {
        try JSONEncoder().encode(session)
    }

    public func restore(from data: Data) throws -> ActiveTrainingSession? {
        try JSONDecoder().decode(Optional<ActiveTrainingSession>.self, from: data)
    }
}
