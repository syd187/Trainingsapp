import Foundation
import Testing
@testable import PersonalSportCore

@Suite("Persistence and imports")
struct PersistenceAndImportTests {
    @Test func activeTrainingSessionRestoresAfterRelaunch() throws {
        let persistence = ActiveSessionPersistence()
        let session = ActiveTrainingSession(workoutName: "Pull", kind: .strength, startedAt: Date(timeIntervalSince1970: 1_800))

        let data = try persistence.encode(session)
        let restored = try persistence.restore(from: data)

        #expect(restored == session)
        #expect(restored?.elapsed(at: Date(timeIntervalSince1970: 1_860)) == 60)
    }

    @Test func duplicateHealthKitRunsAreNotImportedTwice() {
        let store = HealthImportStore()
        let existing = ImportedActivity(
            externalIdentifier: "hk-1",
            sourceIdentifier: "com.apple.health",
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 500)
        )
        let duplicate = ImportedActivity(
            externalIdentifier: "hk-1",
            sourceIdentifier: "com.apple.health",
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 500)
        )
        let fresh = ImportedActivity(
            externalIdentifier: "hk-2",
            sourceIdentifier: "com.apple.health",
            start: Date(timeIntervalSince1970: 900),
            end: Date(timeIntervalSince1970: 1_500)
        )

        let merged = store.merge(existing: [existing], incoming: [duplicate, fresh])

        #expect(merged.count == 2)
        #expect(merged.map(\.externalIdentifier) == ["hk-1", "hk-2"])
    }
}
