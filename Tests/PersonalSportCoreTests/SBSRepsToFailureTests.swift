import Foundation
import Testing
@testable import PersonalSportCore

@Suite("SBS reps to failure")
struct SBSRepsToFailureTests {
    let strategy = SBSRepsToFailureStrategy()

    @Test func weeklyPrescriptionCalculation() throws {
        let config = SBSConfigVersion(weightIncrement: 2.5)
        let cycle = ProgressionCycle(cycleNumber: 1, startingTrainingMax: 100, currentWeekInBlock: 4, activeConfigVersionId: config.id)

        let prescription = try strategy.prescription(for: cycle, config: config)
        let weight = try strategy.roundedPrescriptionWeight(
            trainingMax: cycle.currentTrainingMax,
            intensity: prescription.weeklyIntensity,
            increment: config.weightIncrement
        )

        #expect(prescription.setCount == 4)
        #expect(prescription.workSetReps == 5)
        #expect(prescription.repOutTarget == 9)
        #expect(weight == 72.5)
    }

    @Test func trainingMaxAdjustmentFromRepOutPerformance() throws {
        let config = SBSConfigVersion(weightIncrement: 2.5)
        let cycle = ProgressionCycle(cycleNumber: 1, startingTrainingMax: 100, activeConfigVersionId: config.id)

        let result = try strategy.complete(cycle: cycle, actualRepOutReps: 15, config: config)

        #expect(result.adjustmentPercent == 0.03)
        #expect(result.cycle.currentTrainingMax == 103)
        #expect(result.cycle.currentWeekInBlock == 2)
    }

    @Test func weightRoundingUsesExerciseIncrement() throws {
        let rounded = try strategy.roundedPrescriptionWeight(trainingMax: 117, intensity: 0.725, increment: 1.25)
        #expect(rounded == 85)
    }

    @Test func configVersionChangesDoNotRewriteSnapshots() throws {
        let exerciseId = UUID()
        let config = SBSConfigVersion(weightIncrement: 2.5)
        let editedConfig = SBSConfigVersion(versionNumber: 2, weightIncrement: 1.25)
        let cycle = ProgressionCycle(cycleNumber: 1, startingTrainingMax: 100, activeConfigVersionId: config.id)
        let prescription = try strategy.prescription(for: cycle, config: config)
        let snapshot = ExerciseSessionSnapshot(
            exerciseId: exerciseId,
            progressionCycleId: cycle.id,
            progressionConfigVersionId: config.id,
            blockNumber: cycle.currentBlock,
            weekInBlock: cycle.currentWeekInBlock,
            trainingMaxBefore: cycle.currentTrainingMax,
            weeklyIntensity: prescription.weeklyIntensity,
            prescribedExternalWeight: try strategy.roundedPrescriptionWeight(
                trainingMax: cycle.currentTrainingMax,
                intensity: prescription.weeklyIntensity,
                increment: config.weightIncrement
            ),
            prescribedSetCount: prescription.setCount,
            prescribedWorkSetReps: prescription.workSetReps,
            prescribedRepOutTarget: prescription.repOutTarget
        )

        #expect(snapshot.progressionConfigVersionId == config.id)
        #expect(snapshot.progressionConfigVersionId != editedConfig.id)
        #expect(snapshot.prescribedExternalWeight == 70)
    }

    @Test func weekSixMovesToNextBlockWeekOne() throws {
        let config = SBSConfigVersion(weightIncrement: 2.5)
        let cycle = ProgressionCycle(
            cycleNumber: 1,
            startingTrainingMax: 100,
            currentBlock: 1,
            currentWeekInBlock: 6,
            activeConfigVersionId: config.id
        )

        let result = try strategy.complete(cycle: cycle, actualRepOutReps: 7, config: config)

        #expect(result.cycle.currentBlock == 2)
        #expect(result.cycle.currentWeekInBlock == 1)
    }

    @Test func newCycleCreationIsSeparateAndStartingTrainingMaxIsImmutable() throws {
        let config = SBSConfigVersion(weightIncrement: 2.5)
        let previous = ProgressionCycle(cycleNumber: 1, startingTrainingMax: 100, currentTrainingMax: 108, activeConfigVersionId: config.id)

        let next = try strategy.startNewCycle(after: previous, startingTrainingMax: 112, config: config)

        #expect(previous.cycleNumber == 1)
        #expect(previous.startingTrainingMax == 100)
        #expect(next.cycleNumber == 2)
        #expect(next.startingTrainingMax == 112)
        #expect(next.currentTrainingMax == 112)
    }
}
