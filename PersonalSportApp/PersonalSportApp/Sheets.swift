import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#endif

struct SidebarMenu: View {
    @Binding var selectedSection: SportSection
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image("ClimberArtwork")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Sport")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle)
                    Text("Navigation")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.56))
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.periwinkle)
                .background(AppColors.blueberry.opacity(0.28), in: Circle())
            }

            VStack(spacing: 8) {
                ForEach(SportSection.allCases) { section in
                    SidebarMenuButton(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                        isPresented = false
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Text("Heute")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle.opacity(0.52))
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.midnight.opacity(0.34), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .background(
            AppColors.indigo
                .overlay(AppColors.midnight.opacity(0.42))
                .ignoresSafeArea()
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppColors.periwinkle.opacity(0.12))
                .frame(width: 1)
                .ignoresSafeArea()
        }
    }
}

struct SidebarMenuButton: View {
    let section: SportSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(isSelected ? AppColors.midnight : AppColors.periwinkle)
                    .background(isSelected ? AppColors.periwinkle : AppColors.midnight.opacity(0.34), in: Circle())

                Text(section.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.periwinkle)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.periwinkle.opacity(0.76))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(isSelected ? AppColors.blueberry.opacity(0.54) : Color.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MorningCheckInInput {
    var weightKg: Double?
    var scaleId: UUID?
    var scaleName: String
    var hasPain: Bool
    var painRegion: String
    var painIntensity: Int
    var painNote: String
    var progressPhotoData: Data?
}

struct MorningCheckInSheet: View {
    let scales: [ScaleModel]
    let latestWeight: Double?
    let action: (MorningCheckInInput) -> Void

    @State private var weight = ""
    @State private var selectedScaleId: UUID?
    @State private var hasPain = false
    @State private var painRegion = "Finger / Hand"
    @State private var painIntensity = 3
    @State private var painNote = ""
    @State private var progressPhotoItem: PhotosPickerItem?
    @State private var progressPhotoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    TextField(latestWeight.map { String(format: "%.1f kg", $0) } ?? "Weight kg", text: $weight)
                        .keyboardType(.decimalPad)
                    Picker("Scale", selection: $selectedScaleId) {
                        ForEach(activeScales) { scale in
                            Text(scale.name).tag(Optional(scale.id))
                        }
                    }
                    .pickerStyle(.menu)
                    if let calibrationPreviewText {
                        Text(calibrationPreviewText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pain / discomfort?") {
                    Toggle("Yes", isOn: $hasPain)
                    if hasPain {
                        Picker("Region", selection: $painRegion) {
                            ForEach(["Finger / Hand", "Wrist", "Elbow", "Shoulder", "Back", "Hip", "Knee", "Ankle / Foot", "Other"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        Stepper("Intensity \(painIntensity)", value: $painIntensity, in: 1...10)
                        TextField("Optional note", text: $painNote, axis: .vertical)
                    }
                }

                if isSunday {
                    Section("Progressfoto") {
                        if let progressPhotoData, let image = UIImage(data: progressPhotoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        PhotosPicker(selection: $progressPhotoItem, matching: .images) {
                            Label(progressPhotoData == nil ? "Fortschrittsfoto hinzufügen" : "Foto ändern", systemImage: "photo.badge.plus")
                        }
                    }
                }

                Button("Complete Check-in") {
                    let normalizedWeight = weight.replacingOccurrences(of: ",", with: ".")
                    action(MorningCheckInInput(
                        weightKg: Double(normalizedWeight) ?? latestWeight,
                        scaleId: selectedScale?.id,
                        scaleName: selectedScale?.name ?? "Waage",
                        hasPain: hasPain,
                        painRegion: painRegion,
                        painIntensity: painIntensity,
                        painNote: painNote,
                        progressPhotoData: progressPhotoData
                    ))
                }
            }
            .navigationTitle("Morning Check-in")
            .onAppear {
                weight = latestWeight.map { String(format: "%.1f", $0) } ?? ""
                selectedScaleId = activeScales.first?.id
            }
            .onChange(of: activeScaleKey) { _, _ in
                if selectedScaleId == nil || !activeScales.contains(where: { $0.id == selectedScaleId }) {
                    selectedScaleId = activeScales.first?.id
                }
            }
            .onChange(of: progressPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    progressPhotoData = try? await item.loadTransferable(type: Data.self)
                }
            }
        }
    }

    private var isSunday: Bool {
        Calendar.current.component(.weekday, from: .now) == 1
    }

    private var activeScales: [ScaleModel] {
        scales.filter { !$0.isArchived }
    }

    private var activeScaleKey: String {
        activeScales.map { "\($0.id.uuidString):\($0.name):\($0.calibrationOffsetKg ?? 0)" }.joined(separator: "|")
    }

    private var selectedScale: ScaleModel? {
        activeScales.first { $0.id == selectedScaleId } ?? activeScales.first
    }

    private var parsedWeight: Double? {
        Double(weight.replacingOccurrences(of: ",", with: "."))
    }

    private var calibrationPreviewText: String? {
        guard let raw = parsedWeight, let selectedScale else { return nil }
        let offset = selectedScale.calibrationOffsetKg ?? 0
        guard abs(offset) >= 0.005 else {
            return "Gespeichert: \(String(format: "%.1f kg", raw))"
        }
        return "Gespeichert: \(String(format: "%.1f kg", raw + offset)) · Offset \(String(format: "%+.2f kg", offset))"
    }
}

struct WeightEntrySheet: View {
    let scales: [ScaleModel]
    let latestWeight: Double?
    let save: (Double, ScaleModel) -> Void

    @State private var weight = ""
    @State private var selectedScaleId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                TextField(latestWeight.map { String(format: "%.1f kg", $0) } ?? "Weight kg", text: $weight)
                    .keyboardType(.decimalPad)
                Picker("Scale", selection: $selectedScaleId) {
                    ForEach(activeScales) { scale in
                        Text(scale.name).tag(Optional(scale.id))
                    }
                }
                .pickerStyle(.menu)
                if let calibrationPreviewText {
                    Text(calibrationPreviewText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button("Save Weight") {
                    if let value = Double(weight.replacingOccurrences(of: ",", with: ".")), let selectedScale {
                        save(value, selectedScale)
                    }
                }
                .disabled(selectedScale == nil)
            }
            .navigationTitle("Weight")
            .onAppear {
                weight = latestWeight.map { String(format: "%.1f", $0) } ?? ""
                selectedScaleId = activeScales.first?.id
            }
            .onChange(of: activeScaleKey) { _, _ in
                if selectedScaleId == nil || !activeScales.contains(where: { $0.id == selectedScaleId }) {
                    selectedScaleId = activeScales.first?.id
                }
            }
        }
    }

    private var activeScales: [ScaleModel] {
        scales.filter { !$0.isArchived }
    }

    private var activeScaleKey: String {
        activeScales.map { "\($0.id.uuidString):\($0.name):\($0.calibrationOffsetKg ?? 0)" }.joined(separator: "|")
    }

    private var selectedScale: ScaleModel? {
        activeScales.first { $0.id == selectedScaleId } ?? activeScales.first
    }

    private var parsedWeight: Double? {
        Double(weight.replacingOccurrences(of: ",", with: "."))
    }

    private var calibrationPreviewText: String? {
        guard let raw = parsedWeight, let selectedScale else { return nil }
        let offset = selectedScale.calibrationOffsetKg ?? 0
        guard abs(offset) >= 0.005 else {
            return "Gespeichert: \(String(format: "%.1f kg", raw))"
        }
        return "Gespeichert: \(String(format: "%.1f kg", raw + offset)) · Offset \(String(format: "%+.2f kg", offset))"
    }
}

struct HealthSheet: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var health: HealthIntegration
    let importHealthData: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Du kannst Personal Sport nicht manuell in Health hinzufuegen. Tippe hier zuerst auf Verbinden; danach fragt iOS nach Zugriff und die App erscheint in Health unter Quellen.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                MetricLine(title: "Status", value: health.statusText)
                Text(health.lastImportText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                Button {
                    importHealthData()
                } label: {
                    Label("Health verbinden & importieren", systemImage: "heart.fill")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(health.isWorking)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Diagnose")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(health.diagnosticsText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                #if canImport(UIKit)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("App-Einstellungen oeffnen", systemImage: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.bordered)
                #endif

                Text("Wenn kein iOS-Popup kommt, wurde der Zugriff wahrscheinlich schon einmal abgelehnt. Dann in iPhone Einstellungen die Health-Berechtigungen fuer PersonalSportApp aktivieren.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Health")
        }
    }
}

struct CalendarSyncSheet: View {
    @ObservedObject var calendarSync: CalendarIntegration
    let items: [PlannedDayItem]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Die App bleibt die Quelle. Apple Calendar bekommt nur gespiegelte Termine.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                MetricLine(title: "Status", value: calendarSync.statusText)
                Text(calendarSync.lastSyncText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Button("Mirror next 21 weeks") {
                    calendarSync.requestAccessAndMirror(items: items)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Apple Calendar")
        }
    }
}

struct TrainingChooser: View {
    let items: [PlannedDayItem]
    let allWorkouts: [WorkoutModel]
    let start: (PlannedDayItem) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(items.isEmpty ? "Choose workout" : "Today") {
                    ForEach(items.isEmpty ? allWorkouts.map(\.plannedItem) : items) { item in
                        Button {
                            start(item)
                        } label: {
                            Label(item.workoutName, systemImage: item.kind == .strength ? "dumbbell.fill" : "figure.climbing")
                        }
                    }
                }
            }
            .navigationTitle("Start Training")
        }
    }
}

struct DayDetailSheet: View {
    let date: Date
    let items: [PlannedDayItem]
    let statuses: [DayStatusModel]
    let nightOuts: [DayContextEventModel]
    let note: DayNoteModel?
    let progressPhoto: ProgressPhotoModel?
    let workouts: [WorkoutModel]
    let addTraining: (Date, WorkoutModel) -> Void
    let changeTraining: (PlannedDayItem, WorkoutModel) -> Void
    let removeTraining: (PlannedDayItem) -> Void
    let saveStatus: (DayStatusValue, Date, Date, String) -> Void
    let addNightOut: (Date, String) -> Void
    let saveNote: (Date, String) -> Void
    let saveProgressPhoto: (Date, Data) -> Void
    let deleteProgressPhoto: (ProgressPhotoModel) -> Void

    @State private var selectedWorkoutId: UUID?
    @State private var replacementWorkoutIds: [String: UUID] = [:]
    @State private var selectedStatus: DayStatusValue = .rest
    @State private var statusEnd = Date()
    @State private var statusNote = ""
    @State private var nightOutNote = ""
    @State private var dayNote = ""
    @State private var progressPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Geplantes Training") {
                    if plannedItems.isEmpty {
                        Picker("Workout", selection: $selectedWorkoutId) {
                            Text("Choose").tag(UUID?.none)
                            ForEach(workouts) { workout in
                                Text(workout.name).tag(UUID?.some(workout.id))
                            }
                        }
                        Button("+ Add Training") {
                            guard let id = selectedWorkoutId, let workout = workouts.first(where: { $0.id == id }) else { return }
                            addTraining(date, workout)
                        }
                    } else {
                        ForEach(plannedItems) { item in
                            VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.workoutName + (item.isPostponed ? " · postponed" : ""))
                                    if let time = item.timeText {
                                        Text(time).font(.caption)
                                    }
                                }
                                Spacer()
                                Button("Remove / Skip") {
                                    removeTraining(item)
                                }
                            }
                                Picker("Ersetzen durch", selection: replacementBinding(for: item)) {
                                    ForEach(workouts.filter { !$0.isArchived }) { workout in
                                        Text(workout.name).tag(workout.id)
                                    }
                                }
                                .onChange(of: replacementBinding(for: item).wrappedValue) { _, workoutId in
                                    guard workoutId != item.workoutId,
                                          let workout = workouts.first(where: { $0.id == workoutId })
                                    else { return }
                                    changeTraining(item, workout)
                                }
                            }
                        }
                    }
                }

                if !importedItems.isEmpty {
                    Section("Importierte Aktivitäten") {
                        ForEach(importedItems) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.workoutName)
                                Text("Aus Apple Health importiert · nicht im Trainingsplan veränderbar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Day Status") {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(DayStatusValue.allCases.filter { $0 != .normal }) {
                            Text($0.title).tag($0)
                        }
                    }
                    DatePicker("To", selection: $statusEnd, displayedComponents: .date)
                    TextField("Notes", text: $statusNote)
                    Button("Save Status") {
                        saveStatus(selectedStatus, date, statusEnd, statusNote)
                    }
                    if !statuses.isEmpty {
                        ForEach(statuses) { status in
                            Text("\(status.type.title): \(status.note)")
                        }
                    }
                }

                Section("Context Events") {
                    TextField("Night Out note", text: $nightOutNote)
                    Button("Add Night Out") {
                        addNightOut(date, nightOutNote)
                        nightOutNote = ""
                    }
                    ForEach(nightOuts) { event in
                        Text(event.note.isEmpty ? "Night Out" : "Night Out: \(event.note)")
                    }
                }

                Section("Day Notes") {
                    TextField("Note", text: $dayNote, axis: .vertical)
                    Button("Save Note") {
                        saveNote(date, dayNote)
                    }
                }

                Section("Progressfoto") {
                    if let progressPhoto, let image = UIImage(data: progressPhoto.imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 340)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if isSunday {
                            Button("Foto entfernen", role: .destructive) {
                                deleteProgressPhoto(progressPhoto)
                            }
                        }
                    }

                    if isSunday {
                        PhotosPicker(selection: $progressPhotoItem, matching: .images) {
                            Label(progressPhoto == nil ? "Fortschrittsfoto hinzufügen" : "Foto ersetzen", systemImage: "photo.badge.plus")
                        }
                    } else if progressPhoto == nil {
                        Text("Fortschrittsfotos können jeweils sonntags hinzugefügt werden.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .onAppear {
                statusEnd = date
                dayNote = note?.note ?? ""
                for item in plannedItems {
                    replacementWorkoutIds[item.id] = item.workoutId
                }
            }
            .onChange(of: progressPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let imageData = try? await item.loadTransferable(type: Data.self) else { return }
                    saveProgressPhoto(date, imageData)
                    progressPhotoItem = nil
                }
            }
        }
    }

    private var isSunday: Bool {
        Calendar.current.component(.weekday, from: date) == 1
    }

    private func replacementBinding(for item: PlannedDayItem) -> Binding<UUID> {
        Binding(
            get: { replacementWorkoutIds[item.id] ?? item.workoutId },
            set: { replacementWorkoutIds[item.id] = $0 }
        )
    }

    private var plannedItems: [PlannedDayItem] {
        items.filter { $0.kind != .importedActivity }
    }

    private var importedItems: [PlannedDayItem] {
        items.filter { $0.kind == .importedActivity }
    }
}

struct FinishTrainingSheet: View {
    @Binding var sessionRPE: Int
    @Binding var bodyFeeling: Int
    let save: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Session RPE") {
                    Stepper("\(sessionRPE)", value: $sessionRPE, in: 1...10)
                }
                Section("Body Feeling") {
                    Stepper("\(bodyFeeling)", value: $bodyFeeling, in: 1...10)
                }
                Button("Save Training", action: save)
            }
            .navigationTitle("End Training")
        }
    }
}

struct TrainingCompletionResult {
    var repOutReps: Int?
    var sessionRPE: Int
    var bodyFeeling: Int
}
