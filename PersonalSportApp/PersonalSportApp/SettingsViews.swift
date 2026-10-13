import SwiftData
import SwiftUI

struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext

    let settings: AppSettingsModel?
    let scales: [ScaleModel]
    let sbsConfigs: [SBSConfigVersionModel]
    @ObservedObject var health: HealthIntegration
    @ObservedObject var calendarSync: CalendarIntegration
    let connectHealth: () -> Void
    let syncCalendar: () -> Void
    let createSBSConfigVersion: () -> Void

    @State private var newScaleName = ""
    @State private var scaleMessage = ""
    @FocusState private var scaleNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Verbindungen").sectionTitle()

                IntegrationSettingsRow(
                    title: "Apple Health",
                    subtitle: health.lastImportText,
                    status: health.statusText,
                    symbol: "heart.fill",
                    actionTitle: health.isWorking ? "Läuft" : "Verbinden",
                    action: connectHealth
                )
                .disabled(health.isWorking)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Health Diagnose")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.8))
                    Text(health.diagnosticsText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(AppColors.midnight.opacity(0.24), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                IntegrationSettingsRow(
                    title: "Apple Calendar",
                    subtitle: calendarSync.lastSyncText,
                    status: calendarSync.statusText,
                    symbol: "calendar",
                    actionTitle: "Sync",
                    action: syncCalendar
                )
            }
            .panel()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Waagen").sectionTitle()
                    Spacer()
                    Button {
                        addScale()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColors.midnight)
                    .background(AppColors.periwinkle, in: Circle())
                    .accessibilityLabel("Waage hinzufügen")
                }

                TextField("Neue Waage", text: $newScaleName)
                    .textFieldStyle(.roundedBorder)
                    .focused($scaleNameFocused)
                    .submitLabel(.done)
                    .onSubmit(addScale)

                Button {
                    addScale()
                } label: {
                    Label("Waage anlegen", systemImage: "plus.circle.fill")
                        .primaryButton()
                }
                .buttonStyle(.plain)

                if !scaleMessage.isEmpty {
                    Text(scaleMessage)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.68))
                }

                VStack(spacing: 10) {
                    ForEach(scales.filter { !$0.isArchived }) { scale in
                        ScaleEditorRow(scale: scale, archiveTitle: "Archivieren", save: save) {
                            scale.isArchived = true
                            save()
                        }
                    }
                }

                if scales.contains(where: \.isArchived) {
                    Divider().overlay(AppColors.periwinkle.opacity(0.22))
                    Text("Archiv").sectionTitle()
                    VStack(spacing: 10) {
                        ForEach(scales.filter(\.isArchived)) { scale in
                            ScaleEditorRow(scale: scale, archiveTitle: "Reaktivieren", save: save) {
                                scale.isArchived = false
                                save()
                            }
                        }
                    }
                }
            }
            .panel()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SBS Progression Config").sectionTitle()
                        Text("Aktive Version: \(activeSBSConfig?.versionNumber ?? 1) · Änderungen gelten nur für zukünftige Sessions.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.58))
                    }
                    Spacer()
                }

                Button {
                    createSBSConfigVersion()
                } label: {
                    Label("Neue Config-Version aus aktueller erstellen", systemImage: "plus.rectangle.on.rectangle")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.midnight)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.periwinkle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if let config = activeSBSConfig {
                    SBSConfigEditor(config: config, save: save)
                } else {
                    Text("Noch keine SBS-Konfiguration angelegt.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.62))
                }
            }
            .panel()

            if let settings {
                SettingsParameterEditor(settings: settings, save: save)
            }
        }
    }

    private var activeSBSConfig: SBSConfigVersionModel? {
        sbsConfigs.first(where: \.isActive) ?? sbsConfigs.first
    }

    private func addScale() {
        let trimmed = newScaleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "Waage \(nextScaleNumber)" : trimmed
        let finalName = uniqueScaleName(baseName)
        modelContext.insert(ScaleModel(name: finalName))
        newScaleName = ""
        scaleNameFocused = false
        do {
            try modelContext.save()
            scaleMessage = "\(finalName) angelegt."
        } catch {
            scaleMessage = "Waage konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    private var nextScaleNumber: Int {
        scales.filter { !$0.isArchived && $0.name.localizedCaseInsensitiveContains("Waage") }.count + 1
    }

    private func uniqueScaleName(_ name: String) -> String {
        let existing = Set(scales.map(\.name))
        guard existing.contains(name) else { return name }

        var index = 2
        while existing.contains("\(name) \(index)") {
            index += 1
        }
        return "\(name) \(index)"
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            scaleMessage = "Änderung konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }
}

struct IntegrationSettingsRow: View {
    let title: String
    let subtitle: String
    let status: String
    let symbol: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.periwinkle)
                .frame(width: 38, height: 38)
                .background(AppColors.blueberry.opacity(0.42), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text(status)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.midnight)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(AppColors.periwinkle, in: Capsule())
                }
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.58))
                    .lineLimit(2)
            }

            Spacer()

            Button(actionTitle, action: action)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .buttonStyle(.bordered)
                .tint(AppColors.periwinkle)
        }
        .padding(12)
        .background(AppColors.midnight.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ScaleEditorRow: View {
    @Bindable var scale: ScaleModel
    let archiveTitle: String
    let save: () -> Void
    let archiveAction: () -> Void

    @State private var offsetText = ""
    @FocusState private var offsetFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $scale.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .textFieldStyle(.roundedBorder)
                .onChange(of: scale.name) { _, _ in
                    save()
                }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Offset \(formattedOffset)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.72))

                    HStack(spacing: 8) {
                        Button {
                            adjustOffset(by: -0.1)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.periwinkle)

                        TextField("0.00", text: $offsetText)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.center)
                            .textFieldStyle(.roundedBorder)
                            .focused($offsetFocused)
                            .submitLabel(.done)
                            .onSubmit(saveOffset)

                        Button {
                            adjustOffset(by: 0.1)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.periwinkle)
                    }

                    Button {
                        saveOffset()
                    } label: {
                        Label("Offset speichern", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.midnight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AppColors.periwinkle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(archiveTitle, action: archiveAction)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .buttonStyle(.bordered)
                    .tint(AppColors.periwinkle)
            }

            Text("Neue Gewichtseinträge werden mit diesem Offset normalisiert. Positive Werte addieren Gewicht, negative ziehen Gewicht ab.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.periwinkle.opacity(0.58))
        }
        .padding(12)
        .background(AppColors.midnight.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            offsetText = scale.calibrationOffsetKg.map { String(format: "%.2f", $0) } ?? ""
        }
    }

    private func saveOffset() {
        let normalized = offsetText.replacingOccurrences(of: ",", with: ".")
        scale.calibrationOffsetKg = normalized.isEmpty ? nil : Double(normalized)
        offsetText = scale.calibrationOffsetKg.map { String(format: "%.2f", $0) } ?? ""
        offsetFocused = false
        save()
    }

    private func adjustOffset(by delta: Double) {
        let current = scale.calibrationOffsetKg ?? 0
        let next = (current + delta).rounded(toPlaces: 2)
        scale.calibrationOffsetKg = next
        offsetText = String(format: "%.2f", next)
        save()
    }

    private var formattedOffset: String {
        let value = scale.calibrationOffsetKg ?? 0
        return String(format: "%+.2f kg", value)
    }
}

struct SBSConfigEditor: View {
    @Bindable var config: SBSConfigVersionModel
    let save: () -> Void
    @State private var showsProgramPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("6-Wochen-Template").subsectionTitle()
                Text("Der Prompt definiert SBS V1 als wiederholenden 6-Wochen-Block. Woche 7 ist deshalb Block 2 / Woche 1, Woche 13 ist Block 3 / Woche 1.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.58))
                Text("Arbeitssätze = normale Arbeitssets vor dem Rep-Out. Reps = Wiederholungen pro Arbeitssatz. Rep-Out-Ziel = Zielwiederholungen im letzten AMRAP/Rep-Out-Set.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.58))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nur Zusatzgewicht")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.74))

                    SBSWeekEditorRow(
                        title: "Woche 1",
                        intensity: $config.week1Intensity,
                        save: save
                    )
                    SBSWeekEditorRow(
                        title: "Woche 2",
                        intensity: $config.week2Intensity,
                        save: save
                    )
                    SBSWeekEditorRow(
                        title: "Woche 3",
                        intensity: $config.week3Intensity,
                        save: save
                    )
                    SBSWeekEditorRow(
                        title: "Woche 4",
                        intensity: $config.week4Intensity,
                        save: save
                    )
                    SBSWeekEditorRow(
                        title: "Woche 5",
                        intensity: $config.week5Intensity,
                        save: save
                    )
                    SBSWeekEditorRow(
                        title: "Woche 6",
                        intensity: $config.week6Intensity,
                        save: save
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Körpergewicht + Zusatzgewicht")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.74))
                        Text("Diese Intensität gilt für Übungen, bei denen dein Körpergewicht Teil der Systemlast ist.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.periwinkle.opacity(0.56))
                    }

                    SBSIntensityEditorRow(
                        title: "Woche 1",
                        intensity: optionalIntensity(\.bodyweightWeek1Intensity, fallback: { config.week1Intensity }),
                        inheritedPrescription: config.prescription(for: 1),
                        save: save
                    )
                    SBSIntensityEditorRow(
                        title: "Woche 2",
                        intensity: optionalIntensity(\.bodyweightWeek2Intensity, fallback: { config.week2Intensity }),
                        inheritedPrescription: config.prescription(for: 2),
                        save: save
                    )
                    SBSIntensityEditorRow(
                        title: "Woche 3",
                        intensity: optionalIntensity(\.bodyweightWeek3Intensity, fallback: { config.week3Intensity }),
                        inheritedPrescription: config.prescription(for: 3),
                        save: save
                    )
                    SBSIntensityEditorRow(
                        title: "Woche 4",
                        intensity: optionalIntensity(\.bodyweightWeek4Intensity, fallback: { config.week4Intensity }),
                        inheritedPrescription: config.prescription(for: 4),
                        save: save
                    )
                    SBSIntensityEditorRow(
                        title: "Woche 5",
                        intensity: optionalIntensity(\.bodyweightWeek5Intensity, fallback: { config.week5Intensity }),
                        inheritedPrescription: config.prescription(for: 5),
                        save: save
                    )
                    SBSIntensityEditorRow(
                        title: "Woche 6",
                        intensity: optionalIntensity(\.bodyweightWeek6Intensity, fallback: { config.week6Intensity }),
                        inheritedPrescription: config.prescription(for: 6),
                        save: save
                    )
                }
            }

            DisclosureGroup("18-Wochen-Vorschau", isExpanded: $showsProgramPreview) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(1...18, id: \.self) { programWeek in
                        let templateWeek = ((programWeek - 1) % 6) + 1
                        let block = ((programWeek - 1) / 6) + 1
                        let externalPrescription = config.prescription(for: templateWeek, loadType: .externalWeight)
                        let bodyweightPrescription = config.prescription(for: templateWeek, loadType: .bodyweightPlusExternal)
                        SBSProgramPreviewRow(
                            programWeek: programWeek,
                            block: block,
                            templateWeek: templateWeek,
                            externalPrescription: externalPrescription,
                            bodyweightPrescription: bodyweightPrescription
                        )
                    }
                }
                .padding(.top, 8)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.periwinkle)

            Divider().overlay(AppColors.periwinkle.opacity(0.18))

            VStack(alignment: .leading, spacing: 10) {
                Text("TM-Anpassung nach Rep-Out").subsectionTitle()
                PercentStepper(title: "Ziel um 2+ verfehlt", value: $config.belowTargetBy2PlusPercent, save: save)
                PercentStepper(title: "Ziel um 1 verfehlt", value: $config.belowTargetBy1Percent, save: save)
                PercentStepper(title: "Ziel getroffen", value: $config.hitTargetPercent, save: save)
                PercentStepper(title: "Ziel +1", value: $config.beatTargetBy1Percent, save: save)
                PercentStepper(title: "Ziel +2", value: $config.beatTargetBy2Percent, save: save)
                PercentStepper(title: "Ziel +3", value: $config.beatTargetBy3Percent, save: save)
                PercentStepper(title: "Ziel +4", value: $config.beatTargetBy4Percent, save: save)
                PercentStepper(title: "Ziel +5 oder mehr", value: $config.beatTargetBy5PlusPercent, save: save)
            }
        }
    }

    private func optionalIntensity(
        _ keyPath: ReferenceWritableKeyPath<SBSConfigVersionModel, Double?>,
        fallback: @escaping () -> Double
    ) -> Binding<Double> {
        Binding(
            get: { config[keyPath: keyPath] ?? fallback() },
            set: { config[keyPath: keyPath] = $0 }
        )
    }
}

struct SBSProgramPreviewRow: View {
    let programWeek: Int
    let block: Int
    let templateWeek: Int
    let externalPrescription: (week: Int, intensity: Double, sets: Int, reps: Int, target: Int)
    let bodyweightPrescription: (week: Int, intensity: Double, sets: Int, reps: Int, target: Int)

    var body: some View {
        HStack(spacing: 10) {
            Text("W\(programWeek)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.midnight)
                .frame(width: 38, height: 30)
                .background(AppColors.periwinkle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Block \(block) · Template W\(templateWeek)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text(String(
                    format: "Zusatz %.1f%% · BW+Zusatz %.1f%% · %dx%d · Rep-Out %@",
                    externalPrescription.intensity * 100,
                    bodyweightPrescription.intensity * 100,
                    externalPrescription.sets,
                    externalPrescription.reps,
                    "\(externalPrescription.target)"
                ))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.58))
            }

            Spacer()
        }
        .padding(10)
        .background(AppColors.midnight.opacity(0.26), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SBSIntensityEditorRow: View {
    let title: String
    @Binding var intensity: Double
    let inheritedPrescription: (week: Int, intensity: Double, sets: Int, reps: Int, target: Int)?
    let save: () -> Void

    init(
        title: String,
        intensity: Binding<Double>,
        inheritedPrescription: (week: Int, intensity: Double, sets: Int, reps: Int, target: Int)? = nil,
        save: @escaping () -> Void
    ) {
        self.title = title
        self._intensity = intensity
        self.inheritedPrescription = inheritedPrescription
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle)
            ParameterStepper(title: "Intensität", value: $intensity, range: 0.5...1.0, step: 0.025, format: "%.3f", save: save)
            if let inheritedPrescription {
                Text("Gemeinsame Wochenvorgabe: \(inheritedPrescription.sets) Arbeitssätze x \(inheritedPrescription.reps) Reps · Rep-Out-Ziel \(inheritedPrescription.target)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.58))
            }
        }
        .padding(12)
        .background(AppColors.midnight.opacity(0.30), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SBSWeekEditorRow: View {
    let title: String
    @Binding var intensity: Double
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle)
            ParameterStepper(title: "Intensität", value: $intensity, range: 0.5...1.0, step: 0.025, format: "%.3f", save: save)
            
        }
        .padding(12)
        .background(AppColors.midnight.opacity(0.30), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SettingsParameterEditor: View {
    @Bindable var settings: AppSettingsModel
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Load Parameters").sectionTitle()
                ParameterStepper(title: "Strength multiplier", value: $settings.strengthLoadMultiplier, range: 1...40, step: 0.5, format: "%.1f", save: save)
                ParameterStepper(title: "Simple multiplier", value: $settings.simpleLoadMultiplier, range: 1...40, step: 0.5, format: "%.1f", save: save)
                ParameterStepper(title: "Cardio distance divisor", value: $settings.cardioDistanceDivisor, range: 100...5000, step: 100, format: "%.0f", save: save)
            }
            .panel()

            VStack(alignment: .leading, spacing: 12) {
                Text("Sleep Score").sectionTitle()
                ParameterStepper(title: "Ideal duration", value: $settings.sleepIdealMinutes, range: 300...660, step: 15, format: "%.0f min", save: save)
                ParameterStepper(title: "Duration weight", value: $settings.sleepDurationWeight, range: 0...1, step: 0.01, format: "%.2f", save: save)
                ParameterStepper(title: "Deep weight", value: $settings.sleepDeepWeight, range: 0...1, step: 0.01, format: "%.2f", save: save)
                PercentParameterStepper(title: "Deep min", value: optionalBinding(\.sleepDeepLowerPercent, defaultValue: 0.16), range: 0.05...0.45, step: 0.01, save: save)
                PercentParameterStepper(title: "Deep ideal", value: optionalBinding(\.sleepDeepIdealPercent, defaultValue: 0.25), range: 0.05...0.45, step: 0.01, save: save)
                PercentParameterStepper(title: "Deep max", value: optionalBinding(\.sleepDeepUpperPercent, defaultValue: 0.31), range: 0.05...0.45, step: 0.01, save: save)
                ParameterStepper(title: "REM weight", value: $settings.sleepREMWeight, range: 0...1, step: 0.01, format: "%.2f", save: save)
                PercentParameterStepper(title: "REM min", value: optionalBinding(\.sleepREMLowerPercent, defaultValue: 0.21), range: 0.05...0.45, step: 0.01, save: save)
                PercentParameterStepper(title: "REM ideal", value: optionalBinding(\.sleepREMIdealPercent, defaultValue: 0.25), range: 0.05...0.45, step: 0.01, save: save)
                PercentParameterStepper(title: "REM max", value: optionalBinding(\.sleepREMUpperPercent, defaultValue: 0.31), range: 0.05...0.45, step: 0.01, save: save)
                ParameterStepper(title: "Awake penalty", value: $settings.sleepAwakePenaltyWeight, range: 0...1, step: 0.01, format: "%.2f", save: save)
            }
            .panel()
        }
    }

    private func optionalBinding(_ keyPath: ReferenceWritableKeyPath<AppSettingsModel, Double?>, defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { settings[keyPath: keyPath] ?? defaultValue },
            set: { settings[keyPath: keyPath] = $0 }
        )
    }
}

struct IntParameterStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.periwinkle.opacity(0.72))
            Stepper(value: $value, in: range) {
                Text("\(value)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
            }
            .onChange(of: value) { _, _ in
                save()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PercentStepper: View {
    let title: String
    @Binding var value: Double
    let save: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text(String(format: "%+.1f%%", value * 100))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            }
            Spacer()
            Stepper("", value: $value, in: -0.20...0.20, step: 0.005)
                .labelsHidden()
                .onChange(of: value) { _, _ in
                    save()
                }
        }
    }
}

struct ParameterStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let save: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text(String(format: format, value))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            }
            Spacer()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value) { _, _ in
                    save()
                }
        }
    }
}

struct PercentParameterStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let save: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.62))
            }
            Spacer()
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value) { _, _ in
                    save()
                }
        }
    }
}
