//
//  PersonalSportAppApp.swift
//  PersonalSportApp
//
//  Created by Paul Sattler on 09.09.26.
//

import SwiftUI
import SwiftData

@main
struct PersonalSportAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            ScaleModel.self,
            BodyWeightEntryModel.self,
            MorningCheckInModel.self,
            PainEntryModel.self,
            ExerciseModel.self,
            StaticSkillVariantModel.self,
            StaticHoldRecordModel.self,
            WorkoutModel.self,
            WorkoutExerciseModel.self,
            ProgressionCycleModel.self,
            SBSConfigVersionModel.self,
            WeeklySlotModel.self,
            PlannedTrainingModel.self,
            DayStatusModel.self,
            DayContextEventModel.self,
            DayNoteModel.self,
            ProgressPhotoModel.self,
            TrainingSessionModel.self,
            ExerciseSessionSnapshotModel.self,
            SleepRecordModel.self,
            ImportedActivityDataModel.self,
            AppSettingsModel.self
        ])
    }
}
