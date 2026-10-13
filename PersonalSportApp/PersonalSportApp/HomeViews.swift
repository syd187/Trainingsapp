import SwiftUI

struct HomeScreen: View {
    let manualTodayItems: [PlannedDayItem]
    let latestWeight: Double?
    let rollingWeight: Double?
    let importedActivities: [ImportedActivityDataModel]
    let steps: Double?
    let loadSummary: TrainingLoadSummary
    let checkInCompleted: Bool
    let scales: [ScaleModel]
    let sleepRecord: SleepRecordModel?
    let settings: AppSettingsModel?
    let isMorningWindow: Bool
    let activeSession: TrainingSessionModel?
    let startAction: () -> Void
    let completeCheckInAction: (MorningCheckInInput) -> Void
    let missedCheckInAction: () -> Void
    let saveImportedActivityRPE: (ImportedActivityDataModel, Int) -> Void
    let openCalendarAction: () -> Void

    @State private var showsSleepDetail = false
    @State private var checkInWeight = ""
    @State private var selectedScaleId: UUID?
    @State private var hasPain = false
    @State private var painRegion = "Finger / Hand"
    @State private var painIntensity = 3
    @State private var painNote = ""
    @FocusState private var weightFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero

            if !checkInCompleted && isMorningWindow {
                morningCard
                plannedTrainingCard
                importedActivitiesCard
                calendarLink
            } else {
                todayDashboard
                if !checkInCompleted {
                    missedCheckInCard
                }
                plannedTrainingCard
                importedActivitiesCard
                calendarLink
            }
        }
        .onAppear {
            prepareCheckInDefaults()
        }
        .onChange(of: activeScaleKey) { _, _ in
            prepareCheckInDefaults()
        }
        .sheet(isPresented: $showsSleepDetail) {
            SleepDetailSheet(record: sleepRecord, config: sleepConfig)
                .presentationDetents([.large])
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("ClimberHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            LinearGradient(colors: [.clear, AppColors.midnight.opacity(0.84)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(heroGreeting)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.72))

                Text("Pauls-Sport-App")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
            }
            .padding(18)
        }
        .frame(height: 210)
    }

    private var morningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Morning Check-in")
                    .sectionTitle()
                Spacer()
                Button {
                    showsSleepDetail = true
                } label: {
                    Label("Sleep Detail", systemImage: "moon.zzz.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .labelStyle(.iconOnly)
                        .foregroundStyle(AppColors.periwinkle)
                        .frame(width: 34, height: 34)
                        .background(AppColors.midnight.opacity(0.42), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                MetricLine(title: "Sleep Score", value: sleepScoreText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MetricLine(title: "Sleep", value: sleepDurationText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                MetricLine(title: "Ruhepuls min", value: restingHeartRateText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MetricLine(title: "Nachtpuls ø", value: sleepingHeartRateText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Weight")
                    .miniLabel()
                HStack(spacing: 10) {
                    TextField(latestWeight.map { String(format: "%.1f", $0) } ?? "Weight", text: $checkInWeight)
                        .keyboardType(.decimalPad)
                        .focused($weightFocused)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                        .padding(.horizontal, 14)
                        .frame(height: 54)
                        .background(AppColors.midnight.opacity(0.44), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("kg")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.64))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Scale")
                    .miniLabel()
                if activeScales.isEmpty {
                    Text("Keine aktive Waage. Lege sie unter Settings > Waagen an.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.66))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.midnight.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Picker("Scale", selection: $selectedScaleId) {
                        ForEach(activeScales) { scale in
                            Text(scale.name).tag(Optional(scale.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.periwinkle)
                }

                if let calibrationPreviewText {
                    Text(calibrationPreviewText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Pain / discomfort?")
                    .miniLabel()
                Picker("Pain", selection: $hasPain) {
                    Text("No").tag(false)
                    Text("Yes").tag(true)
                }
                .pickerStyle(.segmented)

                if hasPain {
                    VStack(spacing: 10) {
                        Picker("Region", selection: $painRegion) {
                            ForEach(["Finger / Hand", "Wrist", "Elbow", "Shoulder", "Back", "Hip", "Knee", "Ankle / Foot", "Other"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        Stepper("Intensity \(painIntensity)", value: $painIntensity, in: 1...10)
                            .foregroundStyle(AppColors.periwinkle)
                        TextField("Optional note", text: $painNote, axis: .vertical)
                            .padding(12)
                            .background(AppColors.midnight.opacity(0.44), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                }
            }

            Button(action: completeInlineCheckIn) {
                Label("Complete Check-in", systemImage: "checkmark.circle.fill")
                    .primaryButton()
            }
            .disabled(parsedCheckInWeight == nil || selectedScale == nil)
            .opacity(parsedCheckInWeight == nil || selectedScale == nil ? 0.45 : 1)
        }
        .panel()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    weightFocused = false
                }
            }
        }
    }

    private var missedCheckInCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppColors.periwinkle)
                .frame(width: 42, height: 42)
                .background(AppColors.blueberry.opacity(0.35), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Check-in missed")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text("Du kannst ihn noch nachtragen.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.64))
            }

            Spacer()

            Button("Add now", action: missedCheckInAction)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .buttonStyle(.borderedProminent)
                .tint(AppColors.periwinkle)
                .foregroundStyle(AppColors.midnight)
        }
        .panel()
    }

    private var todayDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Heute").sectionTitle()
                Spacer()
                Text(checkInCompleted ? "Check-in erledigt" : "Check-in offen")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(checkInCompleted ? AppColors.midnight : AppColors.periwinkle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(checkInCompleted ? AppColors.periwinkle : AppColors.midnight.opacity(0.48), in: Capsule())
            }

            HStack(spacing: 12) {
                Button {
                    showsSleepDetail = true
                } label: {
                    MetricBox(title: "Sleep Score", value: sleepScoreText)
                }
                .buttonStyle(.plain)

                Button {
                    showsSleepDetail = true
                } label: {
                    MetricBox(title: "Sleep", value: sleepDurationText)
                }
                .buttonStyle(.plain)

                MetricBox(title: "Steps", value: stepsText)
            }
            HStack(spacing: 12) {
                MetricBox(title: "Load", value: loadSummary.overallText)
                MetricBox(title: "Muskulär", value: loadSummary.muscularText)
                MetricBox(title: "Cardio", value: loadSummary.cardioText)
            }
            HStack(spacing: 12) {
                MetricBox(title: "Ruhepuls min", value: restingHeartRateText)
                MetricBox(title: "Nachtpuls ø", value: sleepingHeartRateText)
            }
            HStack(spacing: 12) {
                MetricBox(title: "Gewicht", value: latestWeightText)
                MetricBox(title: "7T-Schnitt", value: rollingWeightText)
            }
        }
        .panel()
    }

    private var plannedTrainingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's planned training")
                    .sectionTitle()
                Spacer()
                if let rollingWeight {
                    Text("7d \(String(format: "%.1f kg", rollingWeight))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.66))
                }
            }

            if manualTodayItems.isEmpty {
                Text("No planned training today.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.7))
            } else {
                ForEach(manualTodayItems) { item in
                    PlannedTrainingRow(item: item)
                }
            }

            Button(action: startAction) {
                Label(activeSession == nil ? startTitle : "Resume active training", systemImage: activeSession == nil ? "play.fill" : "arrow.up.forward.circle.fill")
                    .primaryButton()
            }
        }
        .panel()
    }

    @ViewBuilder
    private var importedActivitiesCard: some View {
        if !importedActivities.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Heute importiert").sectionTitle()
                ForEach(importedActivities) { activity in
                    HStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.periwinkle)
                            .frame(width: 38, height: 38)
                            .background(AppColors.blueberry.opacity(0.34), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(runTitle(for: activity))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle)
                            Text(activity.start.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                        }
                        Spacer()
                        Menu {
                            ForEach(1...10, id: \.self) { rpe in
                                Button("RPE \(rpe)") { saveImportedActivityRPE(activity, rpe) }
                            }
                        } label: {
                            Text(activity.sessionRPE.map { "RPE \($0)" } ?? "RPE")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.midnight)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(AppColors.periwinkle, in: Capsule())
                        }
                    }
                    .padding(12)
                    .background(AppColors.midnight.opacity(0.32), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .panel()
        }
    }

    private func runTitle(for activity: ImportedActivityDataModel) -> String {
        guard let meters = activity.distanceMeters, meters > 0 else { return "Running" }
        return String(format: "Running · %.2f km", meters / 1_000)
    }

    private var calendarLink: some View {
        Button(action: openCalendarAction) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.periwinkle)
                    .frame(width: 38, height: 38)
                    .background(AppColors.blueberry.opacity(0.42), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Kalender")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text("Trainingswoche, Verschiebungen und freie Tage")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.58))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            }
            .padding(14)
            .background(AppColors.indigo.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppColors.blueberry.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var startTitle: String {
        manualTodayItems.isEmpty ? "Choose workout" : "Start Training"
    }

    private var heroGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11:
            return "GUTEN MORGEN"
        case 11..<17:
            return "GUTEN TAG"
        case 17..<22:
            return "GUTEN ABEND"
        default:
            return "HEUTE"
        }
    }

    private var sleepConfig: SleepScoreConfig {
        SleepScoreConfig(settings: settings)
    }

    private var sleepBreakdown: SleepScoreBreakdown {
        SleepScoreCalculator.breakdown(record: sleepRecord, config: sleepConfig)
    }

    private var sleepScoreText: String {
        sleepBreakdown.score.map(String.init) ?? "-"
    }

    private var sleepDurationText: String {
        guard let minutes = sleepRecord?.totalMinutes, minutes > 0 else { return "-" }
        return "\(Int(minutes) / 60)h \(Int(minutes) % 60)m"
    }

    private var restingHeartRateText: String {
        sleepRecord?.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "-"
    }

    private var sleepingHeartRateText: String {
        sleepRecord?.averageSleepingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "-"
    }

    private var stepsText: String {
        guard let steps, steps > 0 else { return "-" }
        return steps.formatted(.number.precision(.fractionLength(0)))
    }

    private var latestWeightText: String {
        latestWeight.map { String(format: "%.1f kg", $0) } ?? "-"
    }

    private var rollingWeightText: String {
        rollingWeight.map { String(format: "%.1f kg", $0) } ?? "-"
    }

    private var activeScales: [ScaleModel] {
        scales.filter { !$0.isArchived }
    }

    private var activeScaleKey: String {
        activeScales.map { "\($0.id.uuidString):\($0.name):\($0.calibrationOffsetKg ?? 0)" }.joined(separator: "|")
    }

    private var selectedScale: ScaleModel? {
        if let selectedScaleId, let scale = activeScales.first(where: { $0.id == selectedScaleId }) {
            return scale
        }
        return activeScales.first
    }

    private var parsedCheckInWeight: Double? {
        Double(checkInWeight.replacingOccurrences(of: ",", with: "."))
    }

    private var calibrationPreviewText: String? {
        guard let raw = parsedCheckInWeight, let selectedScale else { return nil }
        let offset = selectedScale.calibrationOffsetKg ?? 0
        guard abs(offset) >= 0.005 else {
            return "Gespeichert: \(String(format: "%.1f kg", raw))"
        }
        return "Gespeichert: \(String(format: "%.1f kg", raw + offset)) · Offset \(String(format: "%+.2f kg", offset))"
    }

    private func prepareCheckInDefaults() {
        if checkInWeight.isEmpty, let latestWeight {
            checkInWeight = String(format: "%.1f", latestWeight)
        }
        if selectedScaleId == nil || !activeScales.contains(where: { $0.id == selectedScaleId }) {
            selectedScaleId = activeScales.first?.id
        }
    }

    private func completeInlineCheckIn() {
        guard let parsedCheckInWeight, let selectedScale else { return }
        weightFocused = false
        completeCheckInAction(MorningCheckInInput(
            weightKg: parsedCheckInWeight,
            scaleId: selectedScale.id,
            scaleName: selectedScale.name,
            hasPain: hasPain,
            painRegion: painRegion,
            painIntensity: painIntensity,
            painNote: painNote
        ))
    }
}

struct TrainingLoadSummary {
    var overall: Double = 0
    var cardio: Double = 0
    var muscular: Double = 0

    var overallText: String { format(overall) }
    var cardioText: String { format(cardio) }
    var muscularText: String { format(muscular) }

    private func format(_ value: Double) -> String {
        value > 0 ? String(format: "%.0f", value) : "-"
    }
}

struct SleepDetailSheet: View {
    let record: SleepRecordModel?
    let config: SleepScoreConfig

    private var breakdown: SleepScoreBreakdown {
        SleepScoreCalculator.breakdown(record: record, config: config)
    }

    private var totalMinutes: Double {
        record?.totalMinutes ?? 0
    }

    private var phaseMaxMinutes: Double {
        let rem = record?.remMinutes ?? 0
        let deep = record?.deepMinutes ?? 0
        let core = record?.coreMinutes ?? 0
        let awake = record?.awakeMinutes ?? 0
        return max(1, max(max(rem, deep), max(core, awake)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sleep Score").sectionTitle()
                        HStack(alignment: .lastTextBaseline, spacing: 8) {
                            Text(breakdown.score.map(String.init) ?? "-")
                                .font(.system(size: 54, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle)
                            Text("/ 100")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.periwinkle.opacity(0.56))
                        }
                        Text(record == nil ? "Keine Health-Schlafdaten für heute vorhanden." : "Berechnet aus den verfügbaren Health-Schlafdaten und deinen Settings.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                    }
                    .panel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Schlafphasen").sectionTitle()
                        PhaseRow(title: "REM", minutes: record?.remMinutes, totalMinutes: totalMinutes, maxPhaseMinutes: phaseMaxMinutes, color: AppColors.periwinkle)
                        PhaseRow(title: "Tief", minutes: record?.deepMinutes, totalMinutes: totalMinutes, maxPhaseMinutes: phaseMaxMinutes, color: AppColors.blueberry)
                        PhaseRow(title: "Core / Light", minutes: record?.coreMinutes, totalMinutes: totalMinutes, maxPhaseMinutes: phaseMaxMinutes, color: AppColors.indigo)
                        PhaseRow(title: "Wach", minutes: record?.awakeMinutes, totalMinutes: max(totalMinutes + (record?.awakeMinutes ?? 0), 1), maxPhaseMinutes: phaseMaxMinutes, color: .gray)
                    }
                    .panel()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Berechnung").sectionTitle()
                        ScoreComponentRow(title: "Schlafdauer", value: breakdown.durationScore, weight: config.durationWeight)
                        ScoreComponentRow(title: "Tiefschlaf", value: breakdown.deepScore, weight: config.deepWeight)
                        ScoreComponentRow(title: "REM", value: breakdown.remScore, weight: config.remWeight)
                        ScoreComponentRow(title: "Wachzeit Penalty", value: breakdown.awakePenalty.map { -$0 }, weight: config.awakePenaltyWeight)
                    }
                    .panel()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Weitere Werte").sectionTitle()
                        MetricLine(title: "Total Sleep", value: minutesText(record?.totalMinutes))
                        MetricLine(title: "Ruhepuls min", value: record?.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "nicht verfügbar")
                        MetricLine(title: "Nachtpuls ø", value: record?.averageSleepingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "nicht verfügbar")
                    }
                    .panel()
                }
                .padding(18)
            }
            .background(AppColors.midnight.ignoresSafeArea())
            .navigationTitle("Sleep Detail")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func minutesText(_ minutes: Double?) -> String {
        guard let minutes, minutes > 0 else { return "nicht verfügbar" }
        return "\(Int(minutes) / 60)h \(Int(minutes) % 60)m"
    }
}

struct ScoreComponentRow: View {
    let title: String
    let value: Double?
    let weight: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text("Gewichtung \(String(format: "%.2f", weight))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.56))
            }
            Spacer()
            Text(value.map { String(format: "%.0f", $0) } ?? "nicht verfügbar")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle)
        }
    }
}

struct PhaseRow: View {
    let title: String
    let minutes: Double?
    let totalMinutes: Double
    let maxPhaseMinutes: Double
    let color: Color

    private var fraction: Double {
        guard let minutes, maxPhaseMinutes > 0 else { return 0 }
        return max(0, min(1, minutes / maxPhaseMinutes))
    }

    private var percent: Double? {
        guard let minutes, totalMinutes > 0 else { return nil }
        return minutes / totalMinutes * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Spacer()
                Text(minutesText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.72))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.midnight.opacity(0.42))
                    Capsule()
                        .fill(color.opacity(0.86))
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 16)
        }
    }

    private var minutesText: String {
        guard let minutes, minutes > 0 else { return "nicht verfügbar" }
        let percentText = percent.map { String(format: " · %.0f%%", $0) } ?? ""
        return "\(Int(minutes) / 60)h \(Int(minutes) % 60)m\(percentText)"
    }
}
