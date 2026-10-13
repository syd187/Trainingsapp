import SwiftData
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthAccessRequested") private var healthAccessRequested = false
    @AppStorage("lastAutomaticHealthImportTime") private var lastAutomaticHealthImportTime = 0.0

    @Query(sort: \ScaleModel.createdAt, order: .forward) private var scales: [ScaleModel]
    @Query(sort: \BodyWeightEntryModel.measuredAt, order: .reverse) private var weights: [BodyWeightEntryModel]
    @Query(sort: \MorningCheckInModel.completedAt, order: .reverse) private var checkIns: [MorningCheckInModel]
    @Query(sort: \ExerciseModel.createdAt, order: .forward) private var exercises: [ExerciseModel]
    @Query(sort: \StaticSkillVariantModel.sortOrder, order: .forward) private var staticSkillVariants: [StaticSkillVariantModel]
    @Query(sort: \StaticHoldRecordModel.recordedAt, order: .reverse) private var staticHoldRecords: [StaticHoldRecordModel]
    @Query(sort: \WorkoutModel.createdAt, order: .forward) private var workouts: [WorkoutModel]
    @Query(sort: \WorkoutExerciseModel.sortOrder, order: .forward) private var workoutExercises: [WorkoutExerciseModel]
    @Query(sort: \ProgressionCycleModel.startedAt, order: .reverse) private var progressionCycles: [ProgressionCycleModel]
    @Query(sort: \SBSConfigVersionModel.versionNumber, order: .reverse) private var sbsConfigs: [SBSConfigVersionModel]
    @Query(sort: \WeeklySlotModel.sortOrder, order: .forward) private var weeklySlots: [WeeklySlotModel]
    @Query(sort: \PlannedTrainingModel.date, order: .forward) private var plannedTrainings: [PlannedTrainingModel]
    @Query(sort: \DayStatusModel.startDate, order: .forward) private var dayStatuses: [DayStatusModel]
    @Query(sort: \DayContextEventModel.date, order: .forward) private var nightOuts: [DayContextEventModel]
    @Query(sort: \DayNoteModel.date, order: .forward) private var dayNotes: [DayNoteModel]
    @Query(sort: \ProgressPhotoModel.date, order: .reverse) private var progressPhotos: [ProgressPhotoModel]
    @Query(sort: \TrainingSessionModel.startedAt, order: .reverse) private var sessions: [TrainingSessionModel]
    @Query(sort: \SleepRecordModel.date, order: .reverse) private var sleepRecords: [SleepRecordModel]
    @Query(sort: \ImportedActivityDataModel.start, order: .reverse) private var importedActivities: [ImportedActivityDataModel]
    @Query(sort: \AppSettingsModel.id, order: .forward) private var settings: [AppSettingsModel]

    @StateObject private var health = HealthIntegration()
    @StateObject private var calendarSync = CalendarIntegration()

    @SceneStorage("selectedSportSection") private var selectedSectionRaw = SportSection.home.rawValue
    @State private var showsMenu = false
    @State private var showsCheckIn = false
    @State private var showsWeight = false
    @State private var showsHealth = false
    @State private var showsCalendarSync = false
    @State private var showsTrainingChooser = false
    @State private var showsActiveTraining = false
    @State private var selectedCalendarDate = Date()
    @State private var showsDayDetail = false
    @State private var appNotice: AppNotice?

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.midnight.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if selectedSection == .planner {
                    sectionContent
                } else {
                    ScrollView(showsIndicators: false) {
                        sectionContent
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                            .padding(.bottom, activeSession == nil ? 28 : 96)
                    }
                }
            }

            if let activeSession {
                MiniPlayer(session: activeSession) {
                    activeSession.isMinimized = false
                    showsActiveTraining = true
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            if showsMenu {
                sidebarOverlay
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showsMenu)
        .task {
            SeedData.installIfNeeded(context: modelContext)
            handleShortcutRequests()
            runAutomaticHealthImportIfAllowed()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                runAutomaticHealthImportIfAllowed()
            }
        }
        .sheet(isPresented: $showsCheckIn) {
            MorningCheckInSheet(scales: scales, latestWeight: latestWeight, action: completeCheckIn)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showsWeight) {
            WeightEntrySheet(scales: scales, latestWeight: latestWeight, save: addWeight)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsHealth) {
            HealthSheet(health: health, importHealthData: importHealthData)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsCalendarSync) {
            CalendarSyncSheet(calendarSync: calendarSync, items: upcomingCalendarItems)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsTrainingChooser) {
            TrainingChooser(items: manualTodayItems, allWorkouts: workouts.filter { $0.kind != .importedActivity }, start: startWorkout)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsDayDetail) {
            DayDetailSheet(
                date: selectedCalendarDate,
                items: items(on: selectedCalendarDate),
                statuses: statuses(on: selectedCalendarDate),
                nightOuts: nightOuts(on: selectedCalendarDate),
                note: note(on: selectedCalendarDate),
                progressPhoto: progressPhoto(on: selectedCalendarDate),
                workouts: workouts,
                addTraining: addPlannedTraining,
                changeTraining: changePlannedTraining,
                removeTraining: removePlannedTraining,
                saveStatus: saveDayStatus,
                addNightOut: addNightOut,
                saveNote: saveDayNote,
                saveProgressPhoto: saveProgressPhoto,
                deleteProgressPhoto: deleteProgressPhoto
            )
            .presentationDetents([.large])
        }
        .alert(item: $appNotice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .fullScreenCover(isPresented: $showsActiveTraining) {
            if let activeSession {
                ActiveTrainingView(
                    session: activeSession,
                    workout: workout(for: activeSession.workoutId),
                    exercises: exercises,
                    staticSkillVariants: staticSkillVariants,
                    memberships: workoutExercises,
                    latestBodyweight: rollingSevenDayWeight ?? latestWeight,
                    appSettings: settings.first,
                    sbsConfig: activeSBSConfig,
                    finish: finishTraining
                )
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                showsMenu.toggle()
            } label: {
                Image(systemName: showsMenu ? "xmark" : "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.periwinkle)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedSection.rawValue)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            }

            Spacer()

            Image("ClimberArtwork")
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(AppColors.midnight.opacity(0.96))
    }

    private var sidebarOverlay: some View {
        HStack(spacing: 0) {
            SidebarMenu(selectedSection: selectedSectionBinding, isPresented: $showsMenu)
                .frame(width: min(318, UIScreen.main.bounds.width * 0.82))
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .leading).combined(with: .opacity))

            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture {
                    showsMenu = false
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .home:
            HomeScreen(
                manualTodayItems: manualTodayItems,
                latestWeight: latestWeight,
                rollingWeight: rollingSevenDayWeight,
                importedActivities: importedActivitiesToday,
                steps: todaySteps,
                loadSummary: todayLoadSummary,
                checkInCompleted: todayCheckIn != nil,
                scales: scales,
                sleepRecord: latestSleepRecord,
                settings: settings.first,
                isMorningWindow: Calendar.current.component(.hour, from: .now) < 9,
                activeSession: activeSession,
                startAction: primaryStartAction,
                completeCheckInAction: completeCheckIn,
                missedCheckInAction: { showsCheckIn = true },
                saveImportedActivityRPE: saveImportedActivityRPE,
                openCalendarAction: {
                    selectedSection = .calendar
                }
            )
        case .calendar:
            MonthCalendarScreen(
                referenceDate: .now,
                itemsForDate: items(on:),
                statusesForDate: statuses(on:),
                nightOutsForDate: nightOuts(on:),
                hasProgressPhoto: { progressPhoto(on: $0) != nil },
                dayTapped: { date in
                    selectedCalendarDate = date
                    showsDayDetail = true
                }
            )
        case .planner:
            TrainingPlannerScreen(
                exercises: exercises,
                staticSkillVariants: staticSkillVariants,
                workouts: workouts,
                memberships: workoutExercises,
                cycles: progressionCycles,
                sbsConfigs: sbsConfigs,
                weeklySlots: weeklySlots,
                latestBodyweight: rollingSevenDayWeight ?? latestWeight,
                addExercise: addExercise,
                deleteExercise: deleteExercise,
                addStaticVariant: addStaticVariant,
                deleteStaticVariant: deleteStaticVariant,
                addWorkout: addWorkout,
                addWorkoutExercise: addWorkoutExercise,
                removeWorkoutExercise: removeWorkoutExercise,
                moveWorkoutExercise: moveWorkoutExercise,
                addWeeklySlot: addWeeklySlot,
                startNewCycle: startNewCycle,
                saveChanges: { _ = saveChanges() }
            )
        case .progress:
            ProgressScreen(weights: weights, rollingWeight: rollingSevenDayWeight, addWeightAction: { showsWeight = true })
        case .settings:
            SettingsScreen(
                settings: settings.first,
                scales: scales,
                sbsConfigs: sbsConfigs,
                health: health,
                calendarSync: calendarSync,
                connectHealth: importHealthData,
                syncCalendar: { calendarSync.requestAccessAndMirror(items: upcomingCalendarItems) },
                createSBSConfigVersion: createSBSConfigVersion
            )
        }
    }

    private var selectedSection: SportSection {
        get { SportSection(rawValue: selectedSectionRaw) ?? .home }
        nonmutating set { selectedSectionRaw = newValue.rawValue }
    }

    private var selectedSectionBinding: Binding<SportSection> {
        Binding(
            get: { selectedSection },
            set: { selectedSection = $0 }
        )
    }

    private var activeSession: TrainingSessionModel? {
        sessions.first { $0.endedAt == nil }
    }

    private var activeSBSConfig: SBSConfigVersionModel? {
        sbsConfigs.first(where: \.isActive) ?? sbsConfigs.first
    }

    private var todayCheckIn: MorningCheckInModel? {
        checkIns.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var latestSleepRecord: SleepRecordModel? {
        sleepRecords.first { Calendar.current.isDate($0.date, inSameDayAs: .now) } ?? sleepRecords.first
    }

    private var todaySteps: Double? {
        sleepRecords.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }?.steps
    }

    private var latestWeight: Double? {
        weights.first?.weightKg
    }

    private var rollingSevenDayWeight: Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recent = weights.filter { $0.measuredAt >= cutoff }
        guard !recent.isEmpty else { return latestWeight }
        return recent.map(\.weightKg).reduce(0, +) / Double(recent.count)
    }

    private var todayLoadSummary: TrainingLoadSummary {
        var summary = sessions.reduce(into: TrainingLoadSummary()) { summary, session in
            guard let endedAt = session.endedAt, Calendar.current.isDate(endedAt, inSameDayAs: .now) else { return }
            summary.overall += session.overallLoad ?? 0
            summary.cardio += session.cardioLoad ?? 0
            summary.muscular += session.muscularLoad ?? 0
        }
        let multiplier = settings.first?.simpleLoadMultiplier ?? 8
        for activity in importedActivitiesToday {
            guard let rpe = activity.sessionRPE else { continue }
            let distanceFactor = max(1, (activity.distanceMeters ?? 0) / 1_000)
            let load = Double(rpe) * multiplier * distanceFactor
            summary.overall += load
            summary.cardio += load
        }
        return summary
    }

    private var todayItems: [PlannedDayItem] {
        items(on: .now)
    }

    private var manualTodayItems: [PlannedDayItem] {
        todayItems.filter { $0.kind != .importedActivity }
    }

    private var importedActivitiesToday: [ImportedActivityDataModel] {
        importedActivities.filter { Calendar.current.isDate($0.start, inSameDayAs: .now) }
    }

    private var upcomingCalendarItems: [PlannedDayItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return (0..<(21 * 7)).flatMap { offset -> [PlannedDayItem] in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return [] }
            return items(on: date)
        }
    }

    private func handleShortcutRequests() {
        if let requested = UserDefaults.standard.string(forKey: "shortcutRequestedWorkoutName") {
            UserDefaults.standard.removeObject(forKey: "shortcutRequestedWorkoutName")
            if let workout = workouts.first(where: { $0.name.localizedCaseInsensitiveContains(requested) && $0.kind != .importedActivity }) {
                startWorkout(PlannedDayItem(id: workout.id.uuidString, date: .now, workoutId: workout.id, workoutName: workout.name, kind: workout.kind, hour: nil, minute: nil, isPostponed: false))
            }
        }

        if UserDefaults.standard.bool(forKey: "shortcutRequestedEndWorkout") {
            UserDefaults.standard.removeObject(forKey: "shortcutRequestedEndWorkout")
            if activeSession != nil {
                showsActiveTraining = true
            }
        }
    }

    private func items(on date: Date) -> [PlannedDayItem] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let explicit = plannedTrainings
            .filter { calendar.isDate($0.date, inSameDayAs: day) && !$0.isSkippedMarker }
            .map {
                PlannedDayItem(
                    id: $0.id.uuidString,
                    date: $0.date,
                    workoutId: $0.workoutId,
                    workoutName: $0.workoutName,
                    kind: $0.kind,
                    hour: $0.hour,
                    minute: $0.minute,
                    isPostponed: $0.isPostponed
                )
            }

        let imported = importedActivities
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .map { activity in
                PlannedDayItem(
                    id: activity.id.uuidString,
                    date: activity.start,
                    workoutId: activity.id,
                    workoutName: activityTitle(for: activity),
                    kind: .importedActivity,
                    hour: calendar.component(.hour, from: activity.start),
                    minute: calendar.component(.minute, from: activity.start),
                    isPostponed: false
                )
            }

        let blocked = statuses(on: day).contains { $0.type.preventsTraining }
        guard !blocked else { return (explicit + imported).sorted(by: plannedItemSort) }

        let suppressedWorkoutIds = Set(
            plannedTrainings
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .flatMap { training -> [UUID] in
                    if training.isSkippedMarker { return [training.workoutId] }
                    if training.isReplacement, let replacedWorkoutId = training.replacedWorkoutId { return [replacedWorkoutId] }
                    return []
                }
        )

        let weekday = calendar.component(.weekday, from: day)
        let weekly = weeklySlots
            .filter { $0.weekday == weekday }
            .filter { !suppressedWorkoutIds.contains($0.workoutId) }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                PlannedDayItem(
                    id: $0.id.uuidString + day.description,
                    date: day,
                    workoutId: $0.workoutId,
                    workoutName: $0.workoutName,
                    kind: $0.kind,
                    hour: $0.hour,
                    minute: $0.minute,
                    isPostponed: false
                )
            }

        return (weekly + explicit + imported).sorted(by: plannedItemSort)
    }

    private func activityTitle(for activity: ImportedActivityDataModel) -> String {
        guard let distanceMeters = activity.distanceMeters, distanceMeters > 0 else { return "Running" }
        return String(format: "Running · %.2f km", distanceMeters / 1_000)
    }

    private func logicalRunKey(for run: HealthRunImport) -> String {
        let fiveMinuteStart = Int(run.start.timeIntervalSince1970 / 300)
        return "\(run.sourceIdentifier)|\(fiveMinuteStart)"
    }

    private func importedActivity(_ activity: ImportedActivityDataModel, matches run: HealthRunImport) -> Bool {
        if activity.externalIdentifier == run.externalIdentifier {
            return true
        }

        guard activity.sourceIdentifier == run.sourceIdentifier else {
            return false
        }

        return abs(activity.start.timeIntervalSince(run.start)) < 300 &&
            abs(activity.end.timeIntervalSince(run.end)) < 300
    }

    private func saveImportedActivityRPE(_ activity: ImportedActivityDataModel, _ rpe: Int) {
        activity.sessionRPE = rpe
        _ = saveChanges()
    }

    private func plannedItemSort(_ lhs: PlannedDayItem, _ rhs: PlannedDayItem) -> Bool {
        ((lhs.hour ?? 23), (lhs.minute ?? 59), lhs.workoutName) < ((rhs.hour ?? 23), (rhs.minute ?? 59), rhs.workoutName)
    }

    private func statuses(on date: Date) -> [DayStatusModel] {
        let day = Calendar.current.startOfDay(for: date)
        return dayStatuses.filter {
            let start = Calendar.current.startOfDay(for: $0.startDate)
            let end = Calendar.current.startOfDay(for: $0.endDate)
            return day >= start && day <= end
        }
    }

    private func nightOuts(on date: Date) -> [DayContextEventModel] {
        nightOuts.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func note(on date: Date) -> DayNoteModel? {
        dayNotes.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func progressPhoto(on date: Date) -> ProgressPhotoModel? {
        progressPhotos.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func workout(for id: UUID?) -> WorkoutModel? {
        guard let id else { return nil }
        return workouts.first { $0.id == id }
    }

    private func primaryStartAction() {
        if let activeSession {
            activeSession.isMinimized = false
            showsActiveTraining = true
            return
        }

        if manualTodayItems.count == 1, let item = manualTodayItems.first {
            startWorkout(item)
        } else if manualTodayItems.isEmpty {
            showsTrainingChooser = true
        } else {
            showsTrainingChooser = true
        }
    }

    private func startWorkout(_ item: PlannedDayItem) {
        guard item.kind != .importedActivity else {
            appNotice = AppNotice(
                title: "Running kommt aus Health",
                message: "Imported Activities werden laut Prompt nicht manuell in dieser App gestartet. Starte den Lauf mit deiner Uhr oder Running-App und importiere ihn danach ueber Apple Health."
            )
            return
        }

        if let activeSession {
            activeSession.isMinimized = false
            showsActiveTraining = true
            return
        }

        if let reason = blockedStartReason(for: item) {
            appNotice = AppNotice(title: "Workout kann noch nicht starten", message: reason)
            return
        }

        let session = TrainingSessionModel(workoutId: item.workoutId, workoutName: item.workoutName, kind: item.kind)
        modelContext.insert(session)
        guard saveChanges() else { return }
        showsTrainingChooser = false
        showsActiveTraining = true
    }

    private func blockedStartReason(for item: PlannedDayItem) -> String? {
        guard item.kind == .strength,
              let workout = workout(for: item.workoutId),
              let majorMembership = workoutExercises.first(where: { $0.workoutId == workout.id && $0.role == .major }),
              let major = exercises.first(where: { $0.id == majorMembership.exerciseId }),
              major.loadType == .bodyweightPlusExternal
        else { return nil }

        if rollingSevenDayWeight == nil && latestWeight == nil {
            return "\(major.name) nutzt Bodyweight + External Load. Trage zuerst dein Gewicht im Morning Check-in oder Progress ein, damit die App nicht mit 0 kg Koerpergewicht rechnet."
        }
        return nil
    }

    private func completeCheckIn(_ input: MorningCheckInInput) {
        let date = Calendar.current.startOfDay(for: .now)
        let weightEntry: BodyWeightEntryModel?
        if let weight = input.weightKg {
            let scale = scale(for: input.scaleId, fallbackName: input.scaleName)
            let entry = BodyWeightEntryModel(
                weightKg: calibratedWeight(rawValue: weight, scale: scale),
                scaleId: scale?.id ?? input.scaleId,
                scaleName: scale?.name ?? input.scaleName
            )
            modelContext.insert(entry)
            weightEntry = entry
        } else {
            weightEntry = nil
        }

        let checkIn = MorningCheckInModel(
            date: date,
            weightEntryId: weightEntry?.id,
            hasPain: input.hasPain
        )
        modelContext.insert(checkIn)
        if input.hasPain {
            modelContext.insert(PainEntryModel(morningCheckInId: checkIn.id, region: input.painRegion, intensity: input.painIntensity, note: input.painNote))
        }
        if let imageData = input.progressPhotoData {
            saveProgressPhoto(date: date, imageData: imageData)
        }
        guard saveChanges() else { return }
        showsCheckIn = false
    }

    private func addWeight(weight: Double, scale: ScaleModel) {
        modelContext.insert(BodyWeightEntryModel(weightKg: calibratedWeight(rawValue: weight, scale: scale), scaleId: scale.id, scaleName: scale.name))
        guard saveChanges() else { return }
        showsWeight = false
    }

    private func addExercise(name: String, loadType: LoadKind, trainingMax: Double?, increment: Double) {
        let calculatedSystemTrainingMax = trainingMax.flatMap { systemTrainingMax(loadType: loadType, userEnteredMaxKg: $0) }
        let progression = (calculatedSystemTrainingMax != nil || loadType == .bodyweightReps) ? "SBS Reps to Failure" : nil
        let exercise = ExerciseModel(
            name: name,
            loadType: loadType,
            referenceMaxKg: trainingMax,
            progressionStrategy: progression,
            startingTrainingMaxKg: calculatedSystemTrainingMax,
            currentTrainingMaxKg: calculatedSystemTrainingMax,
            weightIncrementKg: increment
        )
        modelContext.insert(exercise)
        if loadType == .staticHold, isFrontLever(named: name) {
            ["Advanced Tuck", "Frog Leg", "Straddle"].enumerated().forEach { index, name in
                modelContext.insert(StaticSkillVariantModel(
                    exerciseId: exercise.id,
                    name: name,
                    sortOrder: index,
                    isActive: index == 0
                ))
            }
        }
        if let tm = calculatedSystemTrainingMax {
            modelContext.insert(ProgressionCycleModel(
                exerciseId: exercise.id,
                cycleNumber: 1,
                startingTrainingMaxKg: tm,
                activeConfigVersionId: activeSBSConfig?.id ?? UUID()
            ))
        } else if trainingMax != nil && loadType == .bodyweightPlusExternal {
            appNotice = AppNotice(
                title: "Koerpergewicht fehlt",
                message: "Die Exercise wurde angelegt, aber die SBS Progression noch nicht gestartet. Fuer Bodyweight + External braucht die App zuerst einen aktuellen oder 7-Tage-Koerpergewichtswert, damit sie den internen System-TM berechnen kann."
            )
        }
        _ = saveChanges()
    }

    private func deleteExercise(_ exercise: ExerciseModel) {
        workoutExercises
            .filter { $0.exerciseId == exercise.id }
            .forEach { modelContext.delete($0) }
        staticSkillVariants
            .filter { $0.exerciseId == exercise.id }
            .forEach { modelContext.delete($0) }
        progressionCycles
            .filter { $0.exerciseId == exercise.id }
            .forEach { modelContext.delete($0) }
        modelContext.delete(exercise)
        _ = saveChanges()
    }

    private func isFrontLever(named name: String) -> Bool {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .contains("frontlever")
    }

    private func addStaticVariant(exercise: ExerciseModel, name: String, startingMaxHoldSeconds: Double?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let variants = staticSkillVariants.filter { $0.exerciseId == exercise.id && !$0.isArchived }
        modelContext.insert(StaticSkillVariantModel(
            exerciseId: exercise.id,
            name: trimmedName,
            sortOrder: (variants.map(\.sortOrder).max() ?? -1) + 1,
            startingMaxHoldSeconds: startingMaxHoldSeconds,
            isActive: variants.isEmpty
        ))
        exercise.updatedAt = .now
        _ = saveChanges()
    }

    private func deleteStaticVariant(_ variant: StaticSkillVariantModel) {
        let variants = staticSkillVariants
            .filter { $0.exerciseId == variant.exerciseId && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard variants.count > 1 else {
            appNotice = AppNotice(title: "Letzte Progression", message: "Eine statische Übung braucht mindestens eine Progressionsstufe.")
            return
        }

        if variant.isActive, let index = variants.firstIndex(where: { $0.id == variant.id }) {
            let replacement = variants.indices.contains(index + 1) ? variants[index + 1] : variants[index - 1]
            replacement.isActive = true
            replacement.updatedAt = .now
        }
        modelContext.delete(variant)
        _ = saveChanges()
    }

    private func startNewCycle(exercise: ExerciseModel, startingTrainingMax: Double) {
        guard let systemStartingTM = systemTrainingMax(loadType: exercise.loadType, userEnteredMaxKg: startingTrainingMax) else {
            appNotice = AppNotice(
                title: "Koerpergewicht fehlt",
                message: "Fuer Bodyweight + External gibst du den externen Zusatz-Max ein. Die App braucht zusaetzlich dein Koerpergewicht, um daraus den System Training Max zu bilden."
            )
            return
        }

        let activeCycles = progressionCycles.filter { $0.exerciseId == exercise.id && $0.status == .active }
        for cycle in activeCycles {
            cycle.status = .completed
            cycle.completedAt = .now
            cycle.finalTrainingMaxKg = cycle.currentTrainingMaxKg
        }

        let nextNumber = ((progressionCycles.filter { $0.exerciseId == exercise.id }.map(\.cycleNumber).max()) ?? 0) + 1
        exercise.progressionStrategy = "SBS Reps to Failure"
        exercise.referenceMaxKg = startingTrainingMax
        exercise.startingTrainingMaxKg = systemStartingTM
        exercise.currentTrainingMaxKg = systemStartingTM
        exercise.currentBlock = 1
        exercise.currentWeekInBlock = 1
        exercise.updatedAt = .now
        modelContext.insert(ProgressionCycleModel(
            exerciseId: exercise.id,
            cycleNumber: nextNumber,
            startingTrainingMaxKg: systemStartingTM,
            activeConfigVersionId: activeSBSConfig?.id ?? UUID()
        ))
        _ = saveChanges()
    }

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            appNotice = AppNotice(
                title: "Änderung konnte nicht gespeichert werden",
                message: "PSA hat die nicht gespeicherte Änderung zurückgenommen, damit deine restlichen Daten wieder nutzbar sind. Details: \(error.localizedDescription)"
            )
            return false
        }
    }

    private func createSBSConfigVersion() {
        let nextNumber = ((sbsConfigs.map(\.versionNumber).max()) ?? 0) + 1
        let newConfig = activeSBSConfig?.clone(versionNumber: nextNumber) ?? SBSConfigVersionModel(versionNumber: nextNumber)
        sbsConfigs.forEach { $0.isActive = false }
        newConfig.isActive = true
        modelContext.insert(newConfig)
        _ = saveChanges()
    }

    private func addWorkout(name: String, kind: WorkoutKindValue) {
        modelContext.insert(WorkoutModel(name: name, kind: kind))
        _ = saveChanges()
    }

    private func addWorkoutExercise(workout: WorkoutModel, exercise: ExerciseModel, role: ExerciseRoleValue) {
        guard workout.kind != .simpleActivity else { return }
        guard !workoutExercises.contains(where: { $0.workoutId == workout.id && $0.exerciseId == exercise.id }) else { return }
        let nextOrder = (workoutExercises.filter { $0.workoutId == workout.id }.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(WorkoutExerciseModel(workoutId: workout.id, exerciseId: exercise.id, role: role, sortOrder: nextOrder))
        workout.updatedAt = .now
        _ = saveChanges()
    }

    private func removeWorkoutExercise(_ membership: WorkoutExerciseModel) {
        if let workout = workouts.first(where: { $0.id == membership.workoutId }) {
            workout.updatedAt = .now
        }
        modelContext.delete(membership)
        _ = saveChanges()
    }

    private func moveWorkoutExercise(_ membership: WorkoutExerciseModel, by delta: Int) {
        let workoutMemberships = workoutExercises
            .filter { $0.workoutId == membership.workoutId }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard let currentIndex = workoutMemberships.firstIndex(where: { $0.id == membership.id }) else { return }
        let targetIndex = currentIndex + delta
        guard workoutMemberships.indices.contains(targetIndex) else { return }
        let target = workoutMemberships[targetIndex]
        let oldOrder = membership.sortOrder
        membership.sortOrder = target.sortOrder
        target.sortOrder = oldOrder
        if let workout = workouts.first(where: { $0.id == membership.workoutId }) {
            workout.updatedAt = .now
        }
        _ = saveChanges()
    }

    private func systemTrainingMax(loadType: LoadKind, userEnteredMaxKg: Double) -> Double? {
        guard loadType == .bodyweightPlusExternal else { return userEnteredMaxKg }
        guard let bodyweight = rollingSevenDayWeight ?? latestWeight else { return nil }
        return bodyweight + userEnteredMaxKg
    }

    private func addWeeklySlot(weekday: Int, workout: WorkoutModel) {
        let nextOrder = (weeklySlots.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(WeeklySlotModel(weekday: weekday, workoutId: workout.id, workoutName: workout.name, kind: workout.kind, hour: nil, minute: nil, sortOrder: nextOrder))
        _ = saveChanges()
    }

    private func addPlannedTraining(date: Date, workout: WorkoutModel) {
        modelContext.insert(PlannedTrainingModel(date: Calendar.current.startOfDay(for: date), workoutId: workout.id, workoutName: workout.name, kind: workout.kind))
        _ = saveChanges()
    }

    private func changePlannedTraining(_ item: PlannedDayItem, to workout: WorkoutModel) {
        if let explicit = plannedTrainings.first(where: { $0.id.uuidString == item.id }) {
            explicit.workoutId = workout.id
            explicit.workoutName = workout.name
            explicit.kindRaw = workout.kind.rawValue
            explicit.isReplacement = true
            explicit.replacedWorkoutId = explicit.replacedWorkoutId ?? item.workoutId
        } else {
            modelContext.insert(PlannedTrainingModel(
                date: Calendar.current.startOfDay(for: item.date),
                workoutId: workout.id,
                workoutName: workout.name,
                kind: workout.kind,
                hour: item.hour,
                minute: item.minute,
                isReplacement: true,
                replacedWorkoutId: item.workoutId
            ))
        }
        _ = saveChanges()
    }

    private func removePlannedTraining(_ item: PlannedDayItem) {
        if let explicit = plannedTrainings.first(where: { $0.id.uuidString == item.id }) {
            modelContext.delete(explicit)
        } else {
            let skippedDate = Calendar.current.startOfDay(for: item.date)
            modelContext.insert(PlannedTrainingModel(
                date: skippedDate,
                workoutId: item.workoutId,
                workoutName: item.workoutName,
                kind: item.kind,
                hour: item.hour,
                minute: item.minute,
                isSkippedMarker: true
            ))
            let postponedDate = nextEligibleTrainingDate(after: skippedDate)
            modelContext.insert(PlannedTrainingModel(
                date: postponedDate,
                workoutId: item.workoutId,
                workoutName: item.workoutName,
                kind: item.kind,
                hour: item.hour,
                minute: item.minute,
                isPostponed: true
            ))
        }
        _ = saveChanges()
    }

    private func nextEligibleTrainingDate(after date: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        for offset in 1...21 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if statuses(on: candidate).contains(where: { $0.type.preventsTraining }) {
                continue
            }
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    private func saveDayStatus(type: DayStatusValue, start: Date, end: Date, note: String) {
        modelContext.insert(DayStatusModel(type: type, startDate: Calendar.current.startOfDay(for: start), endDate: Calendar.current.startOfDay(for: end), note: note))
        _ = saveChanges()
    }

    private func addNightOut(date: Date, note: String) {
        modelContext.insert(DayContextEventModel(date: Calendar.current.startOfDay(for: date), note: note))
        _ = saveChanges()
    }

    private func saveDayNote(date: Date, note: String) {
        if let existing = self.note(on: date) {
            existing.note = note
        } else {
            modelContext.insert(DayNoteModel(date: Calendar.current.startOfDay(for: date), note: note))
        }
        _ = saveChanges()
    }

    private func saveProgressPhoto(date: Date, imageData: Data) {
        let day = Calendar.current.startOfDay(for: date)
        guard Calendar.current.component(.weekday, from: day) == 1 else { return }

        if let existing = progressPhoto(on: day) {
            existing.imageData = imageData
        } else {
            modelContext.insert(ProgressPhotoModel(date: day, imageData: imageData))
        }
        _ = saveChanges()
    }

    private func deleteProgressPhoto(_ photo: ProgressPhotoModel) {
        modelContext.delete(photo)
        _ = saveChanges()
    }

    private func finishTraining(_ result: TrainingCompletionResult) {
        guard let session = activeSession else { return }
        session.repOutReps = result.repOutReps
        session.sessionRPE = result.sessionRPE
        session.bodyFeeling = result.bodyFeeling
        session.endedAt = .now

        let baseMultiplier = settings.first?.strengthLoadMultiplier ?? 10
        let simpleMultiplier = settings.first?.simpleLoadMultiplier ?? 8
        let rpe = Double(result.sessionRPE)
        let feeling = Double(result.bodyFeeling)
        let feelingModifier = 1 + Double(10 - result.bodyFeeling) * 0.03

        if session.kind == .strength {
            let muscular = rpe * baseMultiplier * feelingModifier
            session.overallLoad = muscular
            session.muscularLoad = muscular
            session.cardioLoad = 0
            saveStrengthSnapshot(for: session, result: result)
        } else {
            let overall = rpe * simpleMultiplier * (1 + (10 - feeling) * 0.02)
            session.overallLoad = overall
            session.cardioLoad = overall * 0.25
            session.muscularLoad = overall * 0.75
        }

        _ = saveChanges()
        showsActiveTraining = false
    }

    private func saveStrengthSnapshot(for session: TrainingSessionModel, result: TrainingCompletionResult) {
        guard let workoutId = session.workoutId else { return }
        let staticSkillExercises = workoutExercises
            .filter { $0.workoutId == workoutId }
            .compactMap { membership in exercises.first { $0.id == membership.exerciseId } }
            .filter { $0.loadType == .staticHold }
        staticSkillExercises.forEach { saveStaticHoldRecords(for: session, exercise: $0) }

        let majorMembership = workoutExercises.first { $0.workoutId == workoutId && $0.role == .major }
        guard let exerciseId = majorMembership?.exerciseId,
              let exercise = exercises.first(where: { $0.id == exerciseId })
        else { return }

        if exercise.loadType == .staticHold {
            return
        }

        guard let trainingMax = exercise.currentTrainingMaxKg,
              let repOut = result.repOutReps
        else {
            if exercise.loadType == .bodyweightReps { advanceBodyweightRepWeek(exercise) }
            return
        }

        let config = activeSBSConfig
        let week = config?.prescription(for: exercise.currentWeekInBlock, loadType: exercise.loadType) ?? SBSReference.week(exercise.currentWeekInBlock)
        let referenceBodyweight = exercise.loadType == .bodyweightPlusExternal ? rollingSevenDayWeight : nil
        let systemWeight = SBSReference.rounded(trainingMax * week.intensity, increment: exercise.weightIncrementKg)
        let externalWeight = exercise.loadType == .bodyweightPlusExternal ? systemWeight - (referenceBodyweight ?? 0) : systemWeight
        let adjustment = config?.adjustmentPercent(actual: repOut, target: week.target) ?? SBSReference.adjustmentPercent(actual: repOut, target: week.target)
        let after = trainingMax * (1 + adjustment)
        let prescribedSetCount = majorMembership?.mainWorkSetCountOverride ?? week.sets

        let snapshot = ExerciseSessionSnapshotModel(
            trainingSessionId: session.id,
            exerciseName: exercise.name,
            progressionConfigVersion: config?.versionNumber ?? 1,
            blockNumber: exercise.currentBlock,
            weekInBlock: exercise.currentWeekInBlock,
            trainingMaxBeforeKg: trainingMax,
            referenceBodyweightKg: referenceBodyweight,
            weeklyIntensity: week.intensity,
            prescribedExternalWeightKg: externalWeight,
            prescribedSystemWeightKg: exercise.loadType == .bodyweightPlusExternal ? systemWeight : nil,
            prescribedSetCount: prescribedSetCount,
            prescribedWorkSetReps: week.reps,
            prescribedRepOutTarget: week.target,
            actualRepOutReps: repOut,
            appliedAdjustmentPercent: adjustment,
            trainingMaxAfterKg: after
        )
        modelContext.insert(snapshot)

        exercise.currentTrainingMaxKg = after
        if let cycle = progressionCycles.first(where: { $0.exerciseId == exercise.id && $0.status == .active }) {
            cycle.currentTrainingMaxKg = after
            cycle.currentBlock = exercise.currentWeekInBlock >= 6 ? exercise.currentBlock + 1 : exercise.currentBlock
            cycle.currentWeekInBlock = exercise.currentWeekInBlock >= 6 ? 1 : exercise.currentWeekInBlock + 1
        }
        if exercise.currentWeekInBlock >= 6 {
            exercise.currentWeekInBlock = 1
            exercise.currentBlock += 1
        } else {
            exercise.currentWeekInBlock += 1
        }
        exercise.updatedAt = .now
    }

    private func advanceBodyweightRepWeek(_ exercise: ExerciseModel) {
        if exercise.currentWeekInBlock >= 6 {
            exercise.currentWeekInBlock = 1
            exercise.currentBlock += 1
        } else {
            exercise.currentWeekInBlock += 1
        }
        exercise.updatedAt = .now
    }

    private func saveStaticHoldRecords(for session: TrainingSessionModel, exercise: ExerciseModel) {
        guard let variant = staticSkillVariants.first(where: { $0.exerciseId == exercise.id && $0.isActive && !$0.isArchived }) else { return }
        let holdValues = session.staticWorkHoldSeconds
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { Double($0) }
        let cleanValues = session.staticTechniqueMask.boolArray(count: variant.workSetCount)

        for index in 0..<variant.workSetCount {
            guard let seconds = holdValues[safe: index] ?? nil, seconds > 0 else { continue }
            modelContext.insert(StaticHoldRecordModel(
                trainingSessionId: session.id,
                exerciseId: exercise.id,
                variantId: variant.id,
                setNumber: index + 1,
                holdSeconds: seconds,
                techniqueClean: cleanValues[safe: index] ?? false,
                isAllOutTest: false
            ))
        }

        if let seconds = session.staticAllOutHoldSeconds, seconds > 0 {
            modelContext.insert(StaticHoldRecordModel(
                trainingSessionId: session.id,
                exerciseId: exercise.id,
                variantId: variant.id,
                setNumber: variant.workSetCount + 1,
                holdSeconds: seconds,
                techniqueClean: session.staticAllOutTechniqueClean,
                isAllOutTest: true
            ))
            if session.staticAllOutTechniqueClean, seconds > (variant.bestCleanHoldSeconds ?? 0) {
                variant.bestCleanHoldSeconds = seconds
                variant.updatedAt = .now
            }
            if session.staticAllOutTechniqueClean, seconds >= variant.advanceAtSeconds {
                activateNextStaticVariant(after: variant, exercise: exercise)
            }
        }
    }

    private func activateNextStaticVariant(after current: StaticSkillVariantModel, exercise: ExerciseModel) {
        let variants = staticSkillVariants
            .filter { $0.exerciseId == exercise.id && !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard let index = variants.firstIndex(where: { $0.id == current.id }) else { return }
        guard variants.indices.contains(index + 1) else {
            appNotice = AppNotice(title: "Leiter abgeschlossen", message: "\(current.name) hat die Freischaltzeit erreicht. Es gibt noch keine nächste Progression.")
            return
        }

        let next = variants[index + 1]
        current.isActive = false
        current.updatedAt = .now
        next.isActive = true
        next.bestCleanHoldSeconds = next.startingMaxHoldSeconds
        next.updatedAt = .now
        exercise.updatedAt = .now
        appNotice = AppNotice(
            title: "Nächste Progression aktiv",
            message: "\(next.name) startet bei \(next.startingMaxHoldSeconds.map { "\(Int($0.rounded())) s" } ?? "offenem Max-Test")."
        )
    }

    private func importHealthData() {
        importHealthData(requestPermission: true)
    }

    private func runAutomaticHealthImportIfAllowed() {
        guard healthAccessRequested else { return }
        guard Date.now.timeIntervalSince1970 - lastAutomaticHealthImportTime > 60 else { return }
        importHealthData(requestPermission: false)
    }

    private func importHealthData(requestPermission: Bool) {
        let known = Set(importedActivities.map(\.externalIdentifier))
        let importBlock = {
            health.importRecentData(knownRunIdentifiers: known) { runs, sleeps, healthWeights, steps in
                var processedRunKeys = Set<String>()
                for run in runs {
                    guard processedRunKeys.insert(logicalRunKey(for: run)).inserted else { continue }
                    let matchingActivities = importedActivities.filter { importedActivity($0, matches: run) }

                    if let existing = matchingActivities.first(where: { $0.externalIdentifier == run.externalIdentifier }) ?? matchingActivities.first {
                        existing.sourceIdentifier = run.sourceIdentifier
                        existing.start = run.start
                        existing.end = run.end
                        existing.distanceMeters = run.distanceMeters
                        existing.averageHeartRate = run.averageHeartRate
                        existing.maxHeartRate = run.maxHeartRate
                        existing.calories = run.calories

                        for duplicate in matchingActivities where duplicate.id != existing.id {
                            modelContext.delete(duplicate)
                        }
                    } else {
                    modelContext.insert(ImportedActivityDataModel(
                        externalIdentifier: run.externalIdentifier,
                        sourceIdentifier: run.sourceIdentifier,
                        start: run.start,
                        end: run.end,
                        distanceMeters: run.distanceMeters,
                        averageHeartRate: run.averageHeartRate,
                        maxHeartRate: run.maxHeartRate,
                        calories: run.calories
                    ))
                    }
                }

            var recordsByDay: [Date: SleepRecordModel] = [:]
            for record in sleepRecords {
                let day = Calendar.current.startOfDay(for: record.date)
                recordsByDay[day] = recordsByDay[day] ?? record
            }

            for sleep in sleeps {
                let day = Calendar.current.startOfDay(for: sleep.date)
                let record = recordsByDay[day] ?? SleepRecordModel(date: day)
                record.totalMinutes = sleep.totalMinutes
                record.remMinutes = sleep.remMinutes
                record.deepMinutes = sleep.deepMinutes
                record.coreMinutes = sleep.coreMinutes
                record.awakeMinutes = sleep.awakeMinutes
                record.averageSleepingHeartRate = sleep.averageSleepingHeartRate
                record.restingHeartRate = sleep.restingHeartRate
                if recordsByDay[day] == nil {
                    modelContext.insert(record)
                    recordsByDay[day] = record
                }
            }

            for stepImport in steps {
                let day = Calendar.current.startOfDay(for: stepImport.date)
                let record = recordsByDay[day] ?? SleepRecordModel(date: day)
                record.steps = stepImport.steps
                if recordsByDay[day] == nil {
                    modelContext.insert(record)
                    recordsByDay[day] = record
                }
            }

            let healthScale = scale(named: "Apple Health") ?? ScaleModel(name: "Apple Health")
            if scale(named: "Apple Health") == nil {
                modelContext.insert(healthScale)
            }
            for healthWeight in healthWeights where !hasImportedHealthWeight(healthWeight) {
                modelContext.insert(BodyWeightEntryModel(
                    measuredAt: healthWeight.measuredAt,
                    weightKg: healthWeight.weightKg,
                    scaleId: healthScale.id,
                    scaleName: healthScale.name
                ))
            }

                do {
                    try modelContext.save()
                    lastAutomaticHealthImportTime = Date.now.timeIntervalSince1970
                    health.recordPersistenceResult(.success(()))
                } catch {
                    modelContext.rollback()
                    health.recordPersistenceResult(.failure(error))
                }
            }
        }

        if requestPermission {
            health.requestAccess { granted in
                guard granted else { return }
                healthAccessRequested = true
                importBlock()
            }
        } else {
            importBlock()
        }
    }

    private func scale(named name: String) -> ScaleModel? {
        scales.first { $0.name == name }
    }

    private func scale(for id: UUID?, fallbackName: String) -> ScaleModel? {
        if let id, let scale = scales.first(where: { $0.id == id }) {
            return scale
        }
        return scale(named: fallbackName)
    }

    private func calibratedWeight(rawValue: Double, scale: ScaleModel?) -> Double {
        rawValue + (scale?.calibrationOffsetKg ?? 0)
    }

    private func hasImportedHealthWeight(_ healthWeight: HealthWeightImport) -> Bool {
        weights.contains { entry in
            entry.scaleName == "Apple Health" &&
            abs(entry.measuredAt.timeIntervalSince(healthWeight.measuredAt)) < 60 &&
            abs(entry.weightKg - healthWeight.weightKg) < 0.05
        }
    }
}

#Preview {
    ContentView()
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
        ], inMemory: true)
}
