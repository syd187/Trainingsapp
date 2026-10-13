import SwiftData
import SwiftUI

struct ActiveTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: TrainingSessionModel
    let workout: WorkoutModel?
    let exercises: [ExerciseModel]
    let staticSkillVariants: [StaticSkillVariantModel]
    let memberships: [WorkoutExerciseModel]
    let latestBodyweight: Double?
    let appSettings: AppSettingsModel?
    let sbsConfig: SBSConfigVersionModel?
    let finish: (TrainingCompletionResult) -> Void

    @State private var repOutText = ""
    @State private var staticWorkHoldTexts = ["", "", ""]
    @State private var staticTechnique = [false, false, false]
    @State private var staticAllOutText = ""
    @State private var staticAllOutTechniqueClean = false
    @State private var sessionRPE = 7
    @State private var bodyFeeling = 7
    @State private var showsFinish = false
    @FocusState private var focusedField: ActiveTrainingField?

    enum ActiveTrainingField: Hashable {
        case repOut
    }

    var body: some View {
        ZStack {
            AppColors.midnight.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                activeHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    if session.kind == .strength {
                        strengthBody
                    } else {
                        simpleBody
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                Button {
                    focusedField = nil
                    showsFinish = true
                } label: {
                    Label("End Training", systemImage: "stop.fill").primaryButton()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .background(AppColors.midnight.opacity(0.96))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    focusedField = nil
                }
            }
        }
        .onAppear(perform: restoreStaticHoldInputs)
        .sheet(isPresented: $showsFinish) {
            FinishTrainingSheet(sessionRPE: $sessionRPE, bodyFeeling: $bodyFeeling) {
                finish(TrainingCompletionResult(repOutReps: Int(repOutText), sessionRPE: sessionRPE, bodyFeeling: bodyFeeling))
                dismiss()
            }
            .presentationDetents([.medium])
        }
    }

    private var activeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppColors.periwinkle)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.72))
                }

                Text(session.workoutName)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                    Text(formatElapsed(context.date.timeIntervalSince(session.startedAt)))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.68))
                }
            }
            Spacer()
            Button {
                session.isMinimized = true
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.periwinkle)
        }
        .padding(16)
        .background(AppColors.indigo.opacity(0.62), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(AppColors.blueberry.opacity(0.34), lineWidth: 1))
    }

    private var strengthBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let major {
                if major.loadType == .staticHold {
                    staticSkillBody(for: major)
                } else {
                let prescription = sbsConfig?.prescription(for: major.currentWeekInBlock, loadType: major.loadType) ?? SBSReference.week(major.currentWeekInBlock)
                let setCount = majorMembership?.mainWorkSetCountOverride ?? prescription.sets
                let systemWeight = SBSReference.rounded((major.currentTrainingMaxKg ?? 0) * prescription.intensity, increment: major.weightIncrementKg)
                let displayed = major.loadType == .bodyweightPlusExternal ? latestBodyweight.map { systemWeight - $0 } : systemWeight

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(major.name.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.66))
                            Text(dynamicHeadlineText(loadType: major.loadType, weight: displayed, reps: prescription.reps))
                                .font(.system(size: 46, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text("SBS · Block \(major.currentBlock), Woche \(major.currentWeekInBlock)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text("\(Int(prescription.intensity * 1000) / 10)%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(major.loadType == .bodyweightReps ? "PLAN" : "TM")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(AppColors.midnight)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(AppColors.periwinkle, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
                .panel()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Arbeitssätze").sectionTitle()
                    ForEach(0..<setCount, id: \.self) { index in
                        CheckRow(
                            title: "Set \(index + 1)",
                            subtitle: "\(prescription.reps) Wiederholungen",
                            isOn: workSetBinding(index, count: setCount),
                            symbol: "checkmark"
                        )
                    }

                    Divider().overlay(AppColors.periwinkle.opacity(0.18))

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Rep-Out")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle)
                            Text("Ziel: \(prescription.target) Wiederholungen")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                        }
                        Spacer()
                        TextField("0", text: $repOutText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .repOut)
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AppColors.periwinkle)
                            .frame(width: 82, height: 54)
                            .background(AppColors.midnight.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.blueberry.opacity(0.42), lineWidth: 1))
                    }
                }
                .panel()
                }
            }

            ForEach(staticAccessorySkills, id: \.id) { exercise in
                staticSkillBody(for: exercise)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Accessories").sectionTitle()
                    Spacer()
                    Text("\(completedAccessoryCount)/\(accessories.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.midnight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.periwinkle, in: Capsule())
                }

                if accessories.isEmpty {
                    Text("Keine Accessories in diesem Workout.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                } else {
                    ForEach(Array(accessories.enumerated()), id: \.element.id) { index, exercise in
                        CheckRow(
                            title: exercise.name,
                            subtitle: accessorySetText(for: exercise),
                            isOn: accessoryBinding(index),
                            symbol: "sparkles"
                        )
                    }
                }
            }
            .panel()
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private var simpleBody: some View {
        VStack(alignment: .center, spacing: 24) {
            Spacer()
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                Text(formatElapsed(context.date.timeIntervalSince(session.startedAt)))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
            }
            Text("Minimal tracking: start, stop, RPE, body feeling.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.periwinkle.opacity(0.64))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func staticSkillBody(for exercise: ExerciseModel) -> some View {
        if let variant = activeStaticVariant(for: exercise) {
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.66))
                Text(variant.name)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                HStack(spacing: 10) {
                    MetricBox(title: "Max sauber", value: variant.referenceHoldSeconds.map { "\(Int($0.rounded())) s" } ?? "Test offen")
                    MetricBox(title: "Arbeit", value: variant.prescribedHoldSeconds.map { "\($0) s" } ?? "-")
                    MetricBox(title: "Aufstieg", value: "\(Int(variant.advanceAtSeconds.rounded())) s")
                }
                Text("\(variant.workSetCount) normale Holds bei \(Int((variant.workingHoldFraction * 100).rounded())) % deines Max-Holds, danach ein sauberer All-out-Test.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            }
            .panel()

            VStack(alignment: .leading, spacing: 12) {
                Text("Arbeitsholds").sectionTitle()
                ForEach(0..<variant.workSetCount, id: \.self) { index in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Hold \(index + 1)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle)
                            Text("Ziel: \(variant.prescribedHoldSeconds ?? 0) s")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.60))
                        }
                        Spacer()
                        TextField("s", text: staticHoldBinding(index))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 60, height: 42)
                            .background(AppColors.midnight.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button {
                            staticTechnique[index].toggle()
                            persistStaticHoldInputs()
                        } label: {
                            Image(systemName: staticTechnique[index] ? "checkmark.seal.fill" : "checkmark.seal")
                                .foregroundStyle(staticTechnique[index] ? AppColors.periwinkle : AppColors.periwinkle.opacity(0.45))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Technik sauber für Hold \(index + 1)")
                    }
                }

                Divider().overlay(AppColors.periwinkle.opacity(0.18))

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("All-out-Test")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle)
                        Text("Nur sauber ausgeführte Sekunden zählen für die Freischaltzeit von \(Int(variant.advanceAtSeconds.rounded())) s.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.60))
                    }
                    Spacer()
                    TextField("s", text: $staticAllOutText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 60, height: 42)
                        .background(AppColors.midnight.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: staticAllOutText) { _, _ in persistStaticHoldInputs() }
                    Button {
                        staticAllOutTechniqueClean.toggle()
                        persistStaticHoldInputs()
                    } label: {
                        Image(systemName: staticAllOutTechniqueClean ? "checkmark.seal.fill" : "checkmark.seal")
                            .foregroundStyle(staticAllOutTechniqueClean ? AppColors.periwinkle : AppColors.periwinkle.opacity(0.45))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Technik sauber für All-out-Test")
                }
            }
            .panel()
        } else {
            Text("Für diesen statischen Skill ist noch keine aktive Variante eingerichtet.")
                .foregroundStyle(AppColors.periwinkle.opacity(0.65))
                .panel()
        }
    }

    private func prescriptionWeightText(loadType: LoadKind, value: Double?) -> String {
        guard let value else { return "Bodyweight fehlt" }
        if loadType == .bodyweightPlusExternal {
            return String(format: "%+.1f kg", value)
        }
        return value.kgText
    }

    private func dynamicHeadlineText(loadType: LoadKind, weight: Double?, reps: Int) -> String {
        guard loadType == .bodyweightReps else { return prescriptionWeightText(loadType: loadType, value: weight) }
        return "\(reps) Reps"
    }

    private func activeStaticVariant(for exercise: ExerciseModel) -> StaticSkillVariantModel? {
        staticSkillVariants.first { $0.exerciseId == exercise.id && $0.isActive && !$0.isArchived }
    }

    private func staticHoldBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { staticWorkHoldTexts[safe: index] ?? "" },
            set: { value in
                guard staticWorkHoldTexts.indices.contains(index) else { return }
                staticWorkHoldTexts[index] = value
                persistStaticHoldInputs()
            }
        )
    }

    private func restoreStaticHoldInputs() {
        let values = session.staticWorkHoldSeconds.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        staticWorkHoldTexts = (0..<3).map { values[safe: $0] ?? "" }
        staticTechnique = session.staticTechniqueMask.boolArray(count: 3)
        staticAllOutText = session.staticAllOutHoldSeconds.map { String(format: "%.1f", $0) } ?? ""
        staticAllOutTechniqueClean = session.staticAllOutTechniqueClean
    }

    private func persistStaticHoldInputs() {
        session.staticWorkHoldSeconds = staticWorkHoldTexts.joined(separator: "|")
        session.staticTechniqueMask = staticTechnique.maskString
        session.staticAllOutHoldSeconds = Double(staticAllOutText.replacingOccurrences(of: ",", with: "."))
        session.staticAllOutTechniqueClean = staticAllOutTechniqueClean
        saveSession()
    }

    private var major: ExerciseModel? {
        guard let exerciseId = majorMembership?.exerciseId else { return nil }
        return exercises.first { $0.id == exerciseId }
    }

    private var majorMembership: WorkoutExerciseModel? {
        guard let workoutId = workout?.id,
              let membership = memberships.first(where: { $0.workoutId == workoutId && $0.role == .major })
        else { return nil }
        return membership
    }

    private var accessories: [ExerciseModel] {
        guard let workoutId = workout?.id else { return [] }
        let accessoryIds = memberships
            .filter { $0.workoutId == workoutId && $0.role == .accessory }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(\.exerciseId)
        return accessoryIds.compactMap { id in exercises.first { $0.id == id } }
            .filter { $0.loadType != .staticHold }
    }

    private var staticAccessorySkills: [ExerciseModel] {
        guard let workoutId = workout?.id else { return [] }
        return memberships
            .filter { $0.workoutId == workoutId && $0.role == .accessory }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { membership in exercises.first { $0.id == membership.exerciseId } }
            .filter { $0.loadType == .staticHold }
    }

    private var completedAccessoryCount: Int {
        let values = session.accessoryCompletionMask.boolArray(count: accessories.count)
        return values.filter { $0 }.count
    }

    private func accessorySetText(for exercise: ExerciseModel) -> String {
        guard let workoutId = workout?.id,
              let membership = memberships.first(where: { $0.workoutId == workoutId && $0.exerciseId == exercise.id })
        else { return "Accessory abhaken" }
        let setCount = membership.accessorySetCountOverride ?? 3
        return "\(setCount) Arbeitssätze · abhaken"
    }

    private func workSetBinding(_ index: Int, count: Int) -> Binding<Bool> {
        Binding(
            get: { session.workSetCompletionMask.boolArray(count: count)[safe: index] ?? false },
            set: { value in
                var values = session.workSetCompletionMask.boolArray(count: count)
                values[index] = value
                session.workSetCompletionMask = values.maskString
                saveSession()
            }
        )
    }

    private func accessoryBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { session.accessoryCompletionMask.boolArray(count: max(3, accessories.count))[safe: index] ?? false },
            set: { value in
                var values = session.accessoryCompletionMask.boolArray(count: max(3, accessories.count))
                values[index] = value
                session.accessoryCompletionMask = values.maskString
                saveSession()
            }
        )
    }

    private func saveSession() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}

struct CheckRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let symbol: String

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isOn ? AppColors.periwinkle : AppColors.midnight.opacity(0.42))
                    Image(systemName: isOn ? symbol : "circle")
                        .font(.system(size: isOn ? 15 : 12, weight: .bold))
                        .foregroundStyle(isOn ? AppColors.midnight : AppColors.periwinkle.opacity(0.56))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.58))
                }

                Spacer()
            }
            .padding(12)
            .background(isOn ? AppColors.blueberry.opacity(0.52) : AppColors.midnight.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isOn ? AppColors.periwinkle.opacity(0.30) : AppColors.blueberry.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
