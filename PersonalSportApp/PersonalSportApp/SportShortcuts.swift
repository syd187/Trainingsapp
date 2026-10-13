import AppIntents
import Foundation

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Opens Personal Sport so a workout can be started from Shortcuts.")
    static var openAppWhenRun = true

    @Parameter(title: "Workout Name", default: "Pull")
    var workoutName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(workoutName, forKey: "shortcutRequestedWorkoutName")
        return .result(dialog: "Open Personal Sport to start \(workoutName).")
    }
}

struct EndWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "End Workout"
    static var description = IntentDescription("Opens Personal Sport so the active workout can be ended from Shortcuts.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: "shortcutRequestedEndWorkout")
        return .result(dialog: "Open Personal Sport to end the active workout.")
    }
}

struct PersonalSportShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start workout in \(.applicationName)",
                "Start \(.applicationName) workout"
            ],
            shortTitle: "Start Workout",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: EndWorkoutIntent(),
            phrases: [
                "End workout in \(.applicationName)",
                "Stop \(.applicationName) workout"
            ],
            shortTitle: "End Workout",
            systemImageName: "stop.fill"
        )
    }
}
