import SwiftData
import SwiftUI

struct TrainingPlannerScreen: View {
    let exercises: [ExerciseModel]
    let staticSkillVariants: [StaticSkillVariantModel]
    let workouts: [WorkoutModel]
    let memberships: [WorkoutExerciseModel]
    let cycles: [ProgressionCycleModel]
    let sbsConfigs: [SBSConfigVersionModel]
    let weeklySlots: [WeeklySlotModel]
    let latestBodyweight: Double?
    let addExercise: (String, LoadKind, Double?, Double) -> Void
    let deleteExercise: (ExerciseModel) -> Void
    let addStaticVariant: (ExerciseModel, String, Double?) -> Void
    let deleteStaticVariant: (StaticSkillVariantModel) -> Void
    let addWorkout: (String, WorkoutKindValue) -> Void
    let addWorkoutExercise: (WorkoutModel, ExerciseModel, ExerciseRoleValue) -> Void
    let removeWorkoutExercise: (WorkoutExerciseModel) -> Void
    let moveWorkoutExercise: (WorkoutExerciseModel, Int) -> Void
    let addWeeklySlot: (Int, WorkoutModel) -> Void
    let startNewCycle: (ExerciseModel, Double) -> Void
    let saveChanges: () -> Void

    @State private var selectedMode = "Exercises"
    @State private var exerciseName = ""
    @State private var loadType: LoadKind = .externalWeight
    @State private var trainingMax = ""
    @State private var increment = "2.5"
    @State private var workoutName = ""
    @State private var workoutKind: WorkoutKindValue = .strength
    @State private var scheduleWeekday = 2
    @State private var scheduleWorkoutId: UUID?
    @State private var editingWorkout: WorkoutModel?
    @State private var exerciseSwipeOffsets: [UUID: CGFloat] = [:]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Planner", selection: $selectedMode) {
                Text("Exercises").tag("Exercises")
                Text("Workouts").tag("Workouts")
                Text("Weekly").tag("Weekly")
                Text("Cycles").tag("Cycles")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(AppColors.midnight)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedMode == "Exercises" {
                        exerciseEditor
                        editableExercises
                    } else if selectedMode == "Workouts" {
                        workoutEditor
                        editableWorkouts
                    } else if selectedMode == "Weekly" {
                        scheduleEditor
                        editableSchedule
                    } else {
                        cycleEditor
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .sheet(item: $editingWorkout) { workout in
            WorkoutDetailSheet(
                workout: workout,
                exercises: exercises,
                staticSkillVariants: staticSkillVariants,
                memberships: memberships
                    .filter { $0.workoutId == workout.id }
                    .sorted { $0.sortOrder < $1.sortOrder },
                addExercise: addWorkoutExercise,
                removeExercise: removeWorkoutExercise,
                moveExercise: moveWorkoutExercise,
                saveChanges: saveChanges
            )
            .presentationDetents([.large])
        }
    }

    private var exerciseEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Library").sectionTitle()
            TextField("Exercise name", text: $exerciseName)
                .textFieldStyle(.roundedBorder)
            Picker("Load Type", selection: $loadType) {
                ForEach(LoadKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            if loadType.usesTrainingMax {
                TextField("Starting Training Max, optional", text: $trainingMax)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Weight increment", text: $increment)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            } else if loadType == .bodyweightReps {
                Text("SBS liefert im Workout Intensität, Arbeitssatz-Reps und Rep-Out-Ziel ohne Gewichtsvorgabe.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.66))
            } else if loadType == .staticHold {
                Text("Erstellt deine Leiter Advanced Tuck → Frog Leg → Straddle. Setze danach pro Variante deinen Max-Hold.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.66))
            }
            Button {
                let tm = Double(trainingMax.replacingOccurrences(of: ",", with: "."))
                let inc = Double(increment.replacingOccurrences(of: ",", with: ".")) ?? 2.5
                addExercise(exerciseName, loadType, tm, inc)
                exerciseName = ""
                trainingMax = ""
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill").primaryButton()
            }
            .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .panel()
    }

    private var workoutEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workouts").sectionTitle()
            TextField("Workout name", text: $workoutName)
                .textFieldStyle(.roundedBorder)
            Picker("Workout Type", selection: $workoutKind) {
                ForEach(WorkoutKindValue.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Button {
                addWorkout(workoutName, workoutKind)
                workoutName = ""
            } label: {
                Label("Add Workout", systemImage: "plus.circle.fill").primaryButton()
            }
            .disabled(workoutName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .panel()
    }

    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Schedule").sectionTitle()
            Picker("Day", selection: $scheduleWeekday) {
                ForEach(1...7, id: \.self) { day in
                    Text(day.weekdayName).tag(day)
                }
            }
            .pickerStyle(.menu)
            Picker("Workout", selection: $scheduleWorkoutId) {
                Text("Choose").tag(UUID?.none)
                ForEach(workouts) { workout in
                    Text(workout.name).tag(UUID?.some(workout.id))
                }
            }
            .pickerStyle(.menu)
            Button {
                guard let id = scheduleWorkoutId, let workout = workouts.first(where: { $0.id == id }) else { return }
                addWeeklySlot(scheduleWeekday, workout)
            } label: {
                Label("Add Weekly Slot", systemImage: "calendar.badge.plus").primaryButton()
            }
            .disabled(scheduleWorkoutId == nil)
        }
        .panel()
    }

    private var editableExercises: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exercises.isEmpty {
                ContentUnavailableView(
                    "Noch keine Übungen",
                    systemImage: "figure.strengthtraining.functional",
                    description: Text("Lege oben deine erste Übung an. Sie wird danach hier dauerhaft bearbeitbar angezeigt.")
                )
                .foregroundStyle(AppColors.periwinkle.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            ForEach(exercises) { exercise in
                ZStack(alignment: .trailing) {
                    Button(role: .destructive) {
                        deleteExercise(exercise)
                    } label: {
                        Label("Entfernen", systemImage: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 104, height: 112)
                            .background(.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name", text: Binding(
                        get: { exercise.name },
                        set: { exercise.name = $0; exercise.updatedAt = .now; saveChanges() }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Picker("Load Type", selection: Binding(
                        get: { exercise.loadType },
                        set: { exercise.loadType = $0; exercise.updatedAt = .now; saveChanges() }
                    )) {
                        ForEach(LoadKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)

                    if exercise.loadType.usesTrainingMax {
                    HStack {
                        Text(exercise.loadType == .bodyweightPlusExternal ? "Reference max (+kg)" : "Reference max")
                            .foregroundStyle(AppColors.periwinkle.opacity(0.7))
                        Spacer()
                        TextField("kg", text: numericBinding(
                            get: { exercise.referenceMaxKg },
                            set: { exercise.referenceMaxKg = $0; exercise.updatedAt = .now }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                    }

                    HStack {
                        Text("Increment future")
                            .foregroundStyle(AppColors.periwinkle.opacity(0.7))
                        Spacer()
                        TextField("kg", text: numericBinding(
                            get: { exercise.weightIncrementKg },
                            set: { exercise.weightIncrementKg = $0 ?? 2.5; exercise.updatedAt = .now }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                    }
                    }

                    HStack {
                        Text("Progression")
                            .foregroundStyle(AppColors.periwinkle.opacity(0.7))
                        Spacer()
                        Text(progressText(for: exercise))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(exercise.hasMajorProgression ? AppColors.periwinkle : AppColors.periwinkle.opacity(0.58))
                    }

                    if exercise.loadType == .staticHold {
                        StaticSkillEditor(
                            exercise: exercise,
                            variants: staticSkillVariants
                                .filter { $0.exerciseId == exercise.id && !$0.isArchived }
                                .sorted { $0.sortOrder < $1.sortOrder },
                            addVariant: addStaticVariant,
                            deleteVariant: deleteStaticVariant,
                            saveChanges: saveChanges
                        )
                    }

                }
                .padding(12)
                .background(AppColors.indigo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .offset(x: exerciseSwipeOffsets[exercise.id, default: 0])
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { gesture in
                            guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                            exerciseSwipeOffsets[exercise.id] = min(0, max(-104, gesture.translation.width))
                        }
                        .onEnded { gesture in
                            guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                            withAnimation(.easeOut(duration: 0.18)) {
                                exerciseSwipeOffsets[exercise.id] = gesture.translation.width < -44 ? -104 : 0
                            }
                        }
                )
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var editableWorkouts: some View {
        VStack(alignment: .leading, spacing: 10) {
            if workouts.isEmpty {
                ContentUnavailableView(
                    "Noch keine Workouts",
                    systemImage: "dumbbell.fill",
                    description: Text("Lege oben ein Workout an und öffne es danach, um Übungen hinzuzufügen.")
                )
                .foregroundStyle(AppColors.periwinkle.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            ForEach(workouts) { workout in
                Button {
                    editingWorkout = workout
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: workout.kind == .strength ? "dumbbell.fill" : "figure.climbing")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.periwinkle)
                            .frame(width: 38, height: 38)
                            .background(AppColors.blueberry.opacity(0.42), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle)
                            Text(workoutSummary(for: workout))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                                .lineLimit(1)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.54))
                    }
                    .padding(12)
                    .background(AppColors.indigo.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func workoutSummary(for workout: WorkoutModel) -> String {
        let names = memberships
            .filter { $0.workoutId == workout.id }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { membership in
                exercises.first { $0.id == membership.exerciseId }?.name
            }
        if names.isEmpty {
            return "\(workout.kind.title) · noch keine Übungen"
        }
        return "\(workout.kind.title) · " + names.prefix(3).joined(separator: ", ") + (names.count > 3 ? " +" : "")
    }

    private var editableSchedule: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(weeklySlots) { slot in
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Workout", text: Binding(
                        get: { slot.workoutName },
                        set: { slot.workoutName = $0; saveChanges() }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Picker("Day", selection: Binding(
                        get: { slot.weekday },
                        set: { slot.weekday = $0; saveChanges() }
                    )) {
                        ForEach(1...7, id: \.self) { day in
                            Text(day.weekdayName).tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(AppColors.indigo.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var cycleEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SBS Progression Cycles").sectionTitle()
            if progressionEligibleExercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Noch keine gewichteten Exercises.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text("Lege zuerst eine Exercise mit External Weight oder Bodyweight + External Load an. Danach kannst du hier eine SBS Progression starten.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                }
                .padding(14)
                .background(AppColors.indigo.opacity(0.70), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            ForEach(progressionEligibleExercises) { exercise in
                CycleCard(
                    exercise: exercise,
                    cycles: cycles.filter { $0.exerciseId == exercise.id },
                    config: config(for: cycles.first { $0.exerciseId == exercise.id && $0.status == .active }),
                    latestBodyweight: latestBodyweight,
                    startNewCycle: startNewCycle,
                    saveChanges: saveChanges
                )
            }
        }
    }

    private var progressionEligibleExercises: [ExerciseModel] {
        exercises.filter { !$0.isArchived && $0.loadType.usesTrainingMax }
    }

    private func progressText(for exercise: ExerciseModel) -> String {
        switch exercise.loadType {
        case .staticHold: "Skill-Leiter"
        case .bodyweightReps: "SBS Bodyweight aktiv"
        case .externalWeight, .bodyweightPlusExternal: exercise.hasMajorProgression ? "SBS aktiv" : "In Cycles starten"
        case .none: "Keine Progression"
        }
    }

    private func config(for cycle: ProgressionCycleModel?) -> SBSConfigVersionModel? {
        guard let cycle else { return sbsConfigs.first(where: \.isActive) ?? sbsConfigs.first }
        return sbsConfigs.first { $0.id == cycle.activeConfigVersionId } ?? sbsConfigs.first(where: \.isActive) ?? sbsConfigs.first
    }

    private func numericBinding(get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> Binding<String> {
        Binding(
            get: {
                guard let value = get() else { return "" }
                return String(format: "%.2f", value)
            },
            set: { rawValue in
                let normalized = rawValue.replacingOccurrences(of: ",", with: ".")
                set(Double(normalized))
                saveChanges()
            }
        )
    }
}

private extension LoadKind {
    var usesTrainingMax: Bool {
        self == .externalWeight || self == .bodyweightPlusExternal
    }
}

struct StaticSkillEditor: View {
    @Bindable var exercise: ExerciseModel
    let variants: [StaticSkillVariantModel]
    let addVariant: (ExerciseModel, String, Double?) -> Void
    let deleteVariant: (StaticSkillVariantModel) -> Void
    let saveChanges: () -> Void

    @State private var newVariantName = ""
    @State private var newVariantMax = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Variantenleiter").miniLabel()
                Spacer()
                Text(activeVariant.map { "\($0.workSetCount) Arbeitssätze · \(Int(($0.workingHoldFraction * 100).rounded()))% · Freischalten bei \(Int($0.advanceAtSeconds.rounded())) s" } ?? "Unterste Stufe startet automatisch")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.58))
            }

            Text("Die unterste Stufe ist beim Anlegen aktiv. Ein sauberer All-out-Test schaltet die nächste Stufe automatisch frei und übernimmt ihren Reset-Wert.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.periwinkle.opacity(0.66))

            ForEach(variants) { variant in
                StaticSkillVariantRow(variant: variant, delete: deleteVariant, saveChanges: saveChanges)
            }

            HStack(spacing: 8) {
                TextField("Neue Variante", text: $newVariantName)
                    .textFieldStyle(.roundedBorder)
                TextField("Max s", text: $newVariantMax)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                Button {
                    let max = Double(newVariantMax.replacingOccurrences(of: ",", with: "."))
                    addVariant(exercise, newVariantName, max)
                    newVariantName = ""
                    newVariantMax = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(newVariantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.top, 4)
    }

    private var activeVariant: StaticSkillVariantModel? {
        variants.first(where: \.isActive) ?? variants.first
    }
}

struct StaticSkillVariantRow: View {
    @Bindable var variant: StaticSkillVariantModel
    let delete: (StaticSkillVariantModel) -> Void
    let saveChanges: () -> Void
    @State private var swipeOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                delete(variant)
            } label: {
                Label("Entfernen", systemImage: "trash")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: variant.isActive ? "arrow.right.circle.fill" : "circle")
                        .foregroundStyle(variant.isActive ? AppColors.blueberry : AppColors.periwinkle.opacity(0.42))
                    TextField("Progression", text: $variant.name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: variant.name) { _, _ in
                            variant.updatedAt = .now
                            saveChanges()
                        }
                    if variant.isActive {
                        Text("Aktiv")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.blueberry)
                    }
                }

                HStack(spacing: 8) {
                    StaticSecondsField(title: "Freischalten ab", value: $variant.advanceAtSeconds, saveChanges: saveChanges)
                    StaticOptionalSecondsField(title: "Reset beim Einstieg", value: $variant.startingMaxHoldSeconds, saveChanges: saveChanges)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.indigo, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .offset(x: swipeOffset)
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { gesture in
                        guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                        swipeOffset = min(0, max(-96, gesture.translation.width))
                    }
                    .onEnded { gesture in
                        guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                        withAnimation(.easeOut(duration: 0.18)) {
                            swipeOffset = gesture.translation.width < -42 ? -96 : 0
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StaticSecondsField: View {
    let title: String
    @Binding var value: Double
    let saveChanges: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            TextField("Sekunden", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .onChange(of: value) { _, _ in
                    saveChanges()
                }
        }
    }
}

private struct StaticOptionalSecondsField: View {
    let title: String
    @Binding var value: Double?
    let saveChanges: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            TextField("Sekunden", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .onChange(of: value) { _, _ in
                    saveChanges()
                }
        }
    }
}

struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var workout: WorkoutModel
    let exercises: [ExerciseModel]
    let staticSkillVariants: [StaticSkillVariantModel]
    let memberships: [WorkoutExerciseModel]
    let addExercise: (WorkoutModel, ExerciseModel, ExerciseRoleValue) -> Void
    let removeExercise: (WorkoutExerciseModel) -> Void
    let moveExercise: (WorkoutExerciseModel, Int) -> Void
    let saveChanges: () -> Void

    @State private var selectedExerciseId: UUID?
    @State private var selectedRole: ExerciseRoleValue = .accessory

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Workout name", text: $workout.name)
                        .onChange(of: workout.name) { _, _ in
                            workout.updatedAt = .now
                            saveChanges()
                        }

                    Picker("Type", selection: $workout.kind) {
                        ForEach(WorkoutKindValue.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .onChange(of: workout.kind) { _, _ in
                        workout.updatedAt = .now
                        saveChanges()
                    }
                }

                if workout.kind != .simpleActivity {
                    Section("Enthaltene Übungen") {
                        if memberships.isEmpty {
                            Text("Noch keine Übungen in diesem Workout.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(memberships.enumerated()), id: \.element.id) { index, membership in
                                WorkoutExerciseRow(
                                    membership: membership,
                                    exerciseName: exerciseName(for: membership),
                                    canBeMajor: canBeMajor(membership: membership),
                                    isFirst: index == 0,
                                    isLast: index == memberships.count - 1,
                                    allMemberships: memberships,
                                    saveChanges: saveChanges,
                                    moveUp: { moveExercise(membership, -1) },
                                    moveDown: { moveExercise(membership, 1) },
                                    remove: { removeExercise(membership) }
                                )
                            }
                        }
                    }

                    Section("Übung hinzufügen") {
                        Picker("Übung", selection: $selectedExerciseId) {
                            Text("Auswählen").tag(UUID?.none)
                            ForEach(availableExercises) { exercise in
                                Text(exercise.name).tag(UUID?.some(exercise.id))
                            }
                        }

                        Picker("Rolle", selection: $selectedRole) {
                            ForEach(ExerciseRoleValue.allCases) { role in
                                Text(role.title).tag(role)
                            }
                        }

                        Button {
                            guard let selectedExercise else { return }
                            addExercise(workout, selectedExercise, selectedRole)
                            selectedExerciseId = nil
                            selectedRole = .accessory
                        } label: {
                            Label("Zum Workout hinzufügen", systemImage: "plus.circle.fill")
                        }
                        .disabled(selectedExercise == nil)

                        if selectedRole == .major && selectedExercise.map(isReadyForMajor) != true {
                            Text("Du kannst ihn bereits als Major hinzufügen. Starte den Cycle später unter Cycles, damit SBS-Vorgaben erscheinen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedExerciseId = availableExercises.first?.id
            }
        }
    }

    private var availableExercises: [ExerciseModel] {
        exercises.filter { exercise in
            !exercise.isArchived && !memberships.contains { $0.exerciseId == exercise.id }
        }
    }

    private var selectedExercise: ExerciseModel? {
        availableExercises.first { $0.id == selectedExerciseId } ?? availableExercises.first
    }

    private func exerciseName(for membership: WorkoutExerciseModel) -> String {
        exercises.first { $0.id == membership.exerciseId }?.name ?? "Unbekannte Übung"
    }

    private func canBeMajor(membership: WorkoutExerciseModel) -> Bool {
        guard let exercise = exercises.first(where: { $0.id == membership.exerciseId }) else { return false }
        return isReadyForMajor(exercise)
    }

    private func isReadyForMajor(_ exercise: ExerciseModel) -> Bool {
        if exercise.loadType == .staticHold {
            return staticSkillVariants.contains { $0.exerciseId == exercise.id && $0.isActive && !$0.isArchived }
        }
        return exercise.hasMajorProgression
    }
}

struct WorkoutExerciseRow: View {
    @Bindable var membership: WorkoutExerciseModel
    let exerciseName: String
    let canBeMajor: Bool
    let isFirst: Bool
    let isLast: Bool
    let allMemberships: [WorkoutExerciseModel]
    let saveChanges: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exerciseName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    if membership.role == .major {
                        Text("Arbeitssätze: \(membership.mainWorkSetCountOverride ?? 4)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let setCount = membership.accessorySetCountOverride {
                        Text("Arbeitssätze: \(setCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: moveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(isFirst)

                Button(action: moveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(isLast)
            }

            Picker("Rolle", selection: Binding(
                get: { membership.role },
                set: { newRole in
                    membership.role = newRole
                    saveChanges()
                }
            )) {
                ForEach(ExerciseRoleValue.allCases) { role in
                    Text(role.title).tag(role)
                }
            }
            .pickerStyle(.segmented)

            if membership.role == .major && !canBeMajor {
                Text("Cycle noch nicht gestartet: Gewicht, Reps und Intensität erscheinen nach dem Start unter Cycles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if membership.role == .major {
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: Binding(
                        get: { membership.mainWorkSetCountOverride ?? 4 },
                        set: {
                            membership.mainWorkSetCountOverride = min(max(1, $0), 8)
                            saveChanges()
                        }
                    ), in: 1...8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arbeitssätze in diesem Workout")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text(membership.mainWorkSetCountOverride.map { "\($0) Arbeitssätze" } ?? "SBS-Standard verwenden")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if membership.mainWorkSetCountOverride != nil {
                        Button {
                            membership.mainWorkSetCountOverride = nil
                            saveChanges()
                        } label: {
                            Label("Auf SBS-Standard zurücksetzen", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                        }
                    }
                }
            } else {
                Stepper(value: Binding(
                    get: { membership.accessorySetCountOverride ?? 3 },
                    set: {
                        membership.accessorySetCountOverride = min(max(1, $0), 8)
                        saveChanges()
                    }
                ), in: 1...8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Arbeitssätze in diesem Workout")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("\(membership.accessorySetCountOverride ?? 3) Arbeitssätze")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: remove) {
                Label("Entfernen", systemImage: "trash")
            }
        }
    }
}

struct CycleCard: View {
    let exercise: ExerciseModel
    let cycles: [ProgressionCycleModel]
    let config: SBSConfigVersionModel?
    let latestBodyweight: Double?
    let startNewCycle: (ExerciseModel, Double) -> Void
    let saveChanges: () -> Void

    @State private var newStartingTM = ""
    @State private var showsAdvancedCycleSetup = false

    private var activeCycle: ProgressionCycleModel? {
        cycles.first { $0.status == .active }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text(exercise.progressionStrategy ?? "No progression")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                }
                Spacer()
                Text(activeCycle.map { "Cycle \($0.cycleNumber)" } ?? "Setup")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.midnight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.periwinkle, in: Capsule())
            }

            if let activeCycle {
                HStack(spacing: 10) {
                    MetricBox(title: "Start TM", value: trainingMaxText(activeCycle.startingTrainingMaxKg))
                    MetricBox(title: "Current TM", value: trainingMaxText(activeCycle.currentTrainingMaxKg))
                }

                HStack(spacing: 10) {
                    MetricBox(title: "Programmwoche", value: "W\(absoluteProgramWeek)")
                    MetricBox(title: "Block", value: "\(exercise.currentBlock) / W\(exercise.currentWeekInBlock)")
                    MetricBox(title: "Config", value: config.map { "v\($0.versionNumber)" } ?? "-")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nächste Prescription")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.66))
                    HStack(spacing: 10) {
                        MetricBox(title: "Intensity", value: String(format: "%.1f%%", prescription.intensity * 100))
                        MetricBox(title: "Work", value: "\(prescription.sets)x\(prescription.reps)")
                        MetricBox(title: "Rep-Out", value: "\(prescription.target)")
                    }
                }

                DisclosureGroup("Setup-Korrektur", isExpanded: $showsAdvancedCycleSetup) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nur für falsche Erst-Einrichtung verwenden. Normalerweise laufen Block, Woche und Current TM automatisch über abgeschlossene Rep-Outs.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.58))

                        HStack(spacing: 10) {
                            Stepper("Block \(exercise.currentBlock)", value: Binding(
                                get: { exercise.currentBlock },
                                set: {
                                    exercise.currentBlock = max(1, $0)
                                    activeCycle.currentBlock = exercise.currentBlock
                                    saveChanges()
                                }
                            ), in: 1...99)
                            .foregroundStyle(AppColors.periwinkle)

                            Stepper("Week \(exercise.currentWeekInBlock)", value: Binding(
                                get: { exercise.currentWeekInBlock },
                                set: {
                                    exercise.currentWeekInBlock = min(max(1, $0), 6)
                                    activeCycle.currentWeekInBlock = exercise.currentWeekInBlock
                                    saveChanges()
                                }
                            ), in: 1...6)
                            .foregroundStyle(AppColors.periwinkle)
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keine aktive Progression")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text(setupHelpText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                }
            }

            TextField(startingMaxPlaceholder, text: $newStartingTM)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .onAppear {
                    if newStartingTM.isEmpty, let defaultStartingMax {
                        newStartingTM = String(format: "%.1f", defaultStartingMax)
                    }
                }

            Button {
                guard let value = Double(newStartingTM.replacingOccurrences(of: ",", with: ".")) else { return }
                startNewCycle(exercise, value)
                newStartingTM = ""
            } label: {
                Label(activeCycle == nil ? "SBS Progression starten" : "Neuen Cycle starten", systemImage: "arrow.clockwise.circle.fill").primaryButton()
            }
            .disabled(Double(newStartingTM.replacingOccurrences(of: ",", with: ".")) == nil)

            if !cycles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cycle History")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.66))

                    ForEach(cycles.sorted { $0.cycleNumber > $1.cycleNumber }) { cycle in
                        HStack {
                            Text("Cycle \(cycle.cycleNumber)")
                            Spacer()
                            Text(cycle.status.title)
                            Text(trainingMaxText(cycle.currentTrainingMaxKg))
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.82))
                    }
                }
            }
        }
        .padding(14)
        .background(AppColors.indigo.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var prescription: (week: Int, intensity: Double, sets: Int, reps: Int, target: Int) {
        config?.prescription(for: exercise.currentWeekInBlock, loadType: exercise.loadType) ?? SBSReference.week(exercise.currentWeekInBlock)
    }

    private var absoluteProgramWeek: Int {
        ((max(exercise.currentBlock, 1) - 1) * 6) + min(max(exercise.currentWeekInBlock, 1), 6)
    }

    private var defaultStartingMax: Double? {
        let systemTM = activeCycle?.currentTrainingMaxKg ?? exercise.currentTrainingMaxKg ?? exercise.startingTrainingMaxKg
        guard let systemTM else { return exercise.referenceMaxKg }
        if exercise.loadType == .bodyweightPlusExternal, let latestBodyweight {
            return systemTM - latestBodyweight
        }
        return systemTM
    }

    private var startingMaxPlaceholder: String {
        exercise.loadType == .bodyweightPlusExternal ? "Starting external max, e.g. +40" : "Starting Training Max"
    }

    private var setupHelpText: String {
        if exercise.loadType == .bodyweightPlusExternal {
            return "Gib deinen externen Zusatz-Max ein. Die App addiert dein 7-Tage-Körpergewicht und speichert intern den System Training Max."
        }
        return "Gib den Starting Training Max ein. Danach verändert ihn SBS automatisch über Rep-Outs."
    }

    private func trainingMaxText(_ systemTM: Double) -> String {
        if exercise.loadType == .bodyweightPlusExternal, let latestBodyweight {
            return String(format: "%+.1f kg", systemTM - latestBodyweight)
        }
        return String(format: "%.1f kg", systemTM)
    }
}
