import Foundation
import SwiftUI

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(EventKit)
import EventKit
#endif

@MainActor
final class HealthIntegration: ObservableObject {
    @Published var statusText = "Not connected"
    @Published var lastImportText = "No Health data imported yet"
    @Published var diagnosticsText = "Noch kein Health-Check ausgeführt."
    @Published var isWorking = false

    func recordPersistenceResult(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            lastImportText += " Lokal in PSA gespeichert."
            diagnosticsText += "\nSwiftData: Import lokal gespeichert."
        case let .failure(error):
            statusText = "Import speichern fehlgeschlagen"
            lastImportText = "Health-Daten wurden gelesen, konnten aber nicht lokal gespeichert werden."
            diagnosticsText += "\nSwiftData Speicherfehler: \(error.localizedDescription)"
        }
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    func requestAccess() {
        requestAccess { _ in }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "Health is not available on this device"
            lastImportText = "HealthKit works only on a real iPhone with Health available."
            diagnosticsText = "HealthKit ist auf diesem Gerät nicht verfügbar. Teste Health nur auf einem echten iPhone, nicht im Simulator."
            completion(false)
            return
        }

        isWorking = true
        statusText = "Requesting"
        lastImportText = "Health-Berechtigungen werden angefragt."
        diagnosticsText = "HealthKit verfügbar: ja\nAngefragte Lesedaten: \(Self.requiredReadTypeLabels.joined(separator: ", "))"

        let readTypes = Self.requiredReadTypes()
        let shareTypes = Set<HKSampleType>()
        let healthStore = store
        healthStore.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { [weak self] requestStatus, requestStatusError in
            let requestStatusText = Self.requestStatusText(requestStatus)
            let requestStatusErrorText = requestStatusError.map { "\nRequest-Status Fehler: \($0.localizedDescription)" } ?? ""

            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
                guard let integration = self else {
                    completion(false)
                    return
                }
                Task { @MainActor in
                    integration.isWorking = false
                    let baseDiagnostics = """
                    HealthKit verfügbar: ja
                    Angefragte Lesedaten: \(Self.requiredReadTypeLabels.joined(separator: ", "))
                    iOS Request-Status: \(requestStatusText)\(requestStatusErrorText)
                    Authorization Callback: \(success ? "abgeschlossen" : "fehlgeschlagen")
                    """

                    if success {
                        integration.statusText = "Requested"
                        integration.lastImportText = "Health-Anfrage abgeschlossen. Apple meldet bei Leserechten nicht eindeutig, ob alles erlaubt wurde; der Import-Check unten zeigt, ob Daten zurückkommen."
                        integration.diagnosticsText = baseDiagnostics
                        completion(true)
                    } else {
                        integration.statusText = "Request failed"
                        integration.lastImportText = error?.localizedDescription ?? "Open iPhone Settings to allow Health access."
                        integration.diagnosticsText = baseDiagnostics + "\nAuthorization Fehler: \(error?.localizedDescription ?? "unbekannt")"
                        completion(false)
                    }
                }
            }
        }
        #else
        statusText = "HealthKit unavailable"
        lastImportText = "Build and run on iPhone to use Health."
        diagnosticsText = "HealthKit kann in diesem Build nicht importiert werden."
        completion(false)
        #endif
    }

    func importRecentData(
        knownRunIdentifiers: Set<String>,
        completion: @escaping ([HealthRunImport], [HealthSleepImport], [HealthWeightImport], [HealthStepImport]) -> Void
    ) {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            statusText = "Health is not available on this device"
            diagnosticsText = "HealthKit ist auf diesem Gerät nicht verfügbar."
            completion([], [], [], [])
            return
        }

        isWorking = true
        statusText = "Importing"
        let group = DispatchGroup()
        let diagnosticsLock = NSLock()
        var diagnostics: [String] = [
            "Import gestartet: \(Date.now.formatted(date: .abbreviated, time: .shortened))",
            "Fenster: Running/Bodyweight 60 Tage, Sleep 15 Tage, Steps 14 Tage"
        ]
        var runs: [HealthRunImport] = []
        var sleeps: [HealthSleepImport] = []
        var weights: [HealthWeightImport] = []
        var steps: [HealthStepImport] = []

        func addDiagnostic(_ message: String) {
            diagnosticsLock.lock()
            diagnostics.append(message)
            diagnosticsLock.unlock()
        }

        group.enter()
        importRuns(knownRunIdentifiers: knownRunIdentifiers, diagnostic: addDiagnostic) { imported in
            runs = imported
            group.leave()
        }

        group.enter()
        importSleep(diagnostic: addDiagnostic) { imported in
            sleeps = imported
            group.leave()
        }

        group.enter()
        importBodyWeights(diagnostic: addDiagnostic) { imported in
            weights = imported
            group.leave()
        }

        group.enter()
        importSteps(diagnostic: addDiagnostic) { imported in
            steps = imported
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.isWorking = false
            self?.statusText = "Connected"
            self?.lastImportText = "Imported \(runs.count) run(s), \(sleeps.count) sleep day(s), \(weights.count) weight value(s), \(steps.count) step day(s)."
            diagnosticsLock.lock()
            let finalDiagnostics = diagnostics
            diagnosticsLock.unlock()
            self?.diagnosticsText = finalDiagnostics.joined(separator: "\n")
            completion(runs, sleeps, weights, steps)
        }
        #else
        statusText = "HealthKit unavailable"
        lastImportText = "Build and run on iPhone to use Health."
        diagnosticsText = "HealthKit kann in diesem Build nicht importiert werden."
        completion([], [], [], [])
        #endif
    }

    #if canImport(HealthKit)
    private static func requiredReadTypes() -> Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .heartRate),
            HKQuantityType.quantityType(forIdentifier: .bodyMass),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        ].compactMap { $0 }.reduce(into: Set<HKObjectType>()) { partial, item in
            partial.insert(item)
        }
    }

    private static let requiredReadTypeLabels = [
        "Workouts",
        "Sleep",
        "Steps",
        "Heart Rate",
        "Body Mass",
        "Active Energy",
        "Walking/Running Distance"
    ]

    nonisolated private static func requestStatusText(_ status: HKAuthorizationRequestStatus) -> String {
        switch status {
        case .shouldRequest:
            return "iOS sollte einen Health-Dialog anzeigen"
        case .unnecessary:
            return "Berechtigungen wurden für diese Datentypen schon beantwortet"
        case .unknown:
            return "unbekannt"
        @unknown default:
            return "unbekannt"
        }
    }

    private func importRuns(knownRunIdentifiers: Set<String>, diagnostic: @escaping (String) -> Void, completion: @escaping ([HealthRunImport]) -> Void) {
        let store = self.store
        let workoutType = HKObjectType.workoutType()
        let start = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .now
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let runPredicate = HKQuery.predicateForWorkouts(with: .running)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, runPredicate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 100, sortDescriptors: [sort]) { _, samples, error in
            if let error {
                diagnostic("Running Query Fehler: \(error.localizedDescription)")
                completion([])
                return
            }
            let workouts = (samples as? [HKWorkout]) ?? []
            // Re-read known workouts as well, because Garmin/Health can amend a workout
            // after its first sync. ContentView upserts these records by Health UUID.
            let candidates = workouts
            let newCount = workouts.filter { !knownRunIdentifiers.contains($0.uuid.uuidString) }.count
            diagnostic("Running Workouts aus Health: \(workouts.count), neu: \(newCount), werden aktualisiert: \(workouts.count - newCount)")
            guard !candidates.isEmpty else {
                completion([])
                return
            }

            let group = DispatchGroup()
            let lock = NSLock()
            var imported: [HealthRunImport] = []

            for workout in candidates {
                group.enter()
                Self.queryHeartRate(store: store, start: workout.startDate, end: workout.endDate) { average, _, maximum in
                    let item = HealthRunImport(
                        externalIdentifier: workout.uuid.uuidString,
                        sourceIdentifier: workout.sourceRevision.source.bundleIdentifier,
                        start: workout.startDate,
                        end: workout.endDate,
                        distanceMeters: Self.distanceMeters(for: workout),
                        averageHeartRate: average,
                        maxHeartRate: maximum,
                        calories: Self.activeEnergyCalories(for: workout)
                    )
                    lock.lock()
                    imported.append(item)
                    lock.unlock()
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(imported.sorted { $0.start > $1.start })
            }
        }
        store.execute(query)
    }

    private func importSleep(diagnostic: @escaping (String) -> Void, completion: @escaping ([HealthSleepImport]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            diagnostic("Sleep Query Fehler: sleepAnalysis Type ist nicht verfügbar")
            completion([])
            return
        }
        let store = self.store
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -15, to: .now) ?? .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1000, sortDescriptors: [sort]) { _, samples, error in
            if let error {
                diagnostic("Sleep Query Fehler: \(error.localizedDescription)")
                completion([])
                return
            }
            let categorySamples = (samples as? [HKCategorySample]) ?? []
            var intervalsByDay: [Date: [SleepInterval]] = [:]

            for sample in categorySamples {
                guard let stage = SleepStage(healthKitValue: sample.value), sample.endDate > sample.startDate else { continue }
                let day = Self.sleepReportDate(forEndDate: sample.endDate, calendar: calendar)
                let interval = SleepInterval(
                    start: sample.startDate,
                    end: sample.endDate,
                    stage: stage,
                    sourceIdentifier: sample.sourceRevision.source.bundleIdentifier
                )
                intervalsByDay[day, default: []].append(interval)
            }

            let sleepBuckets = intervalsByDay
                .compactMap { day, intervals -> SleepBucket? in
                    let bucket = SleepBucket.normalized(date: day, intervals: intervals)
                    if let bucket {
                        let sources = SleepBucket.sourceSummary(intervals: intervals)
                        let gapText = bucket.inferredGapMinutes > 0 ? ", Gap-Fill \(Int(bucket.inferredGapMinutes.rounded()))m" : ""
                        diagnostic("Sleep \(day.formatted(date: .abbreviated, time: .omitted)): Quelle \(bucket.sourceIdentifier)\(gapText), \(sources)")
                    }
                    return bucket
                }
                .filter { $0.totalMinutes > 0 }

            diagnostic("Sleep Samples aus Health: \(categorySamples.count), bereinigte Tage: \(sleepBuckets.count)")
            guard !sleepBuckets.isEmpty else {
                completion([])
                return
            }

            let group = DispatchGroup()
            let lock = NSLock()
            var imports: [HealthSleepImport] = []

            for bucket in sleepBuckets {
                group.enter()
                if let start = bucket.startDate, let end = bucket.endDate {
                    Self.queryHeartRate(store: store, start: start, end: end) { average, minimum, _ in
                        let item = HealthSleepImport(
                            date: bucket.date,
                            totalMinutes: bucket.totalMinutes,
                            remMinutes: bucket.remMinutes,
                            deepMinutes: bucket.deepMinutes,
                            coreMinutes: bucket.coreMinutes,
                            awakeMinutes: bucket.awakeMinutes,
                            averageSleepingHeartRate: average,
                            restingHeartRate: minimum
                        )
                        lock.lock()
                        imports.append(item)
                        lock.unlock()
                        group.leave()
                    }
                } else {
                    let item = HealthSleepImport(
                        date: bucket.date,
                        totalMinutes: bucket.totalMinutes,
                        remMinutes: bucket.remMinutes,
                        deepMinutes: bucket.deepMinutes,
                        coreMinutes: bucket.coreMinutes,
                        awakeMinutes: bucket.awakeMinutes,
                        averageSleepingHeartRate: nil,
                        restingHeartRate: nil
                    )
                    lock.lock()
                    imports.append(item)
                    lock.unlock()
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                completion(imports.sorted { $0.date > $1.date })
            }
        }
        store.execute(query)
    }

    nonisolated private static func queryHeartRate(store: HKHealthStore, start: Date, end: Date, completion: @escaping (Double?, Double?, Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil, nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: predicate,
            options: [.discreteAverage, .discreteMin, .discreteMax]
        ) { _, statistics, _ in
            let unit = HKUnit.count().unitDivided(by: .minute())
            let average = statistics?.averageQuantity()?.doubleValue(for: unit)
            let minimum = statistics?.minimumQuantity()?.doubleValue(for: unit)
            let maximum = statistics?.maximumQuantity()?.doubleValue(for: unit)
            completion(average, minimum, maximum)
        }
        store.execute(query)
    }

    nonisolated static func sleepReportDate(forEndDate endDate: Date, calendar: Calendar) -> Date {
        let endHour = calendar.component(.hour, from: endDate)
        if endHour >= 18,
           let nextDay = calendar.date(byAdding: .day, value: 1, to: endDate) {
            return calendar.startOfDay(for: nextDay)
        }
        return calendar.startOfDay(for: endDate)
    }

    nonisolated private static func activeEnergyCalories(for workout: HKWorkout) -> Double? {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }
        return workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
    }

    nonisolated private static func distanceMeters(for workout: HKWorkout) -> Double? {
        if let total = workout.totalDistance?.doubleValue(for: .meter()), total > 0 {
            return total
        }
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }
        return workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter())
    }

    private func importBodyWeights(diagnostic: @escaping (String) -> Void, completion: @escaping ([HealthWeightImport]) -> Void) {
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            diagnostic("Bodyweight Query Fehler: bodyMass Type ist nicht verfügbar")
            completion([])
            return
        }

        let start = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: bodyMassType, predicate: predicate, limit: 120, sortDescriptors: [sort]) { _, samples, error in
            if let error {
                diagnostic("Bodyweight Query Fehler: \(error.localizedDescription)")
                completion([])
                return
            }
            let quantitySamples = (samples as? [HKQuantitySample]) ?? []
            diagnostic("Bodyweight Samples aus Health: \(quantitySamples.count)")
            completion(quantitySamples.map { sample in
                HealthWeightImport(
                    sourceIdentifier: sample.sourceRevision.source.bundleIdentifier,
                    measuredAt: sample.startDate,
                    weightKg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                )
            })
        }
        store.execute(query)
    }

    private func importSteps(diagnostic: @escaping (String) -> Void, completion: @escaping ([HealthStepImport]) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            diagnostic("Steps Query Fehler: stepCount Type ist nicht verfügbar")
            completion([])
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -14, to: .now) ?? .now)
        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, collection, error in
            if let error {
                diagnostic("Steps Query Fehler: \(error.localizedDescription)")
                completion([])
                return
            }
            guard let collection else {
                diagnostic("Steps Query: keine Statistics Collection")
                completion([])
                return
            }

            var imports: [HealthStepImport] = []
            collection.enumerateStatistics(from: start, to: .now) { statistics, _ in
                let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                imports.append(HealthStepImport(date: calendar.startOfDay(for: statistics.startDate), steps: count))
            }
            diagnostic("Step-Tage aus Health: \(imports.count), Summe: \(Int(imports.reduce(0) { $0 + $1.steps }))")
            completion(imports)
        }
        store.execute(query)
    }
    #endif
}

struct HealthRunImport {
    var externalIdentifier: String
    var sourceIdentifier: String
    var start: Date
    var end: Date
    var distanceMeters: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var calories: Double?
}

struct HealthSleepImport {
    var date: Date
    var totalMinutes: Double
    var remMinutes: Double
    var deepMinutes: Double
    var coreMinutes: Double
    var awakeMinutes: Double
    var averageSleepingHeartRate: Double?
    var restingHeartRate: Double?
}

struct HealthWeightImport {
    var sourceIdentifier: String
    var measuredAt: Date
    var weightKg: Double
}

struct HealthStepImport {
    var date: Date
    var steps: Double
}

struct SleepBucket {
    static let maximumFilledGapSeconds: TimeInterval = 15 * 60
    static let sleepEpisodeSplitGapSeconds: TimeInterval = 90 * 60

    var date: Date
    var sourceIdentifier: String
    var totalMinutes: Double = 0
    var remMinutes: Double = 0
    var deepMinutes: Double = 0
    var coreMinutes: Double = 0
    var awakeMinutes: Double = 0
    var inferredGapMinutes: Double = 0
    var startDate: Date?
    var endDate: Date?

    static func normalized(date: Date, intervals: [SleepInterval]) -> SleepBucket? {
        let selectedSource = primarySource(in: intervals)
        let rawSelected = intervals
            .filter { $0.sourceIdentifier == selectedSource }
            .filter { $0.end > $0.start }

        guard !rawSelected.isEmpty else { return nil }

        let episodes = sleepEpisodes(in: rawSelected)
        guard let mainEpisode = mainSleepEpisode(from: episodes) else { return nil }

        let gapFilled = fillingShortMeasurementGaps(in: mainEpisode)
        let selected = gapFilled.intervals

        var bucket = SleepBucket(
            date: date,
            sourceIdentifier: selectedSource,
            inferredGapMinutes: gapFilled.inferredGapMinutes,
            startDate: selected.map(\.start).min(),
            endDate: selected.map(\.end).max()
        )

        let boundaries = Array(Set(selected.flatMap { [$0.start, $0.end] })).sorted()
        guard boundaries.count > 1 else { return nil }

        for index in 0..<(boundaries.count - 1) {
            let start = boundaries[index]
            let end = boundaries[index + 1]
            guard end > start else { continue }

            let overlapping = selected.filter { $0.start < end && $0.end > start }
            guard let stage = winningStage(from: overlapping) else { continue }

            let minutes = end.timeIntervalSince(start) / 60
            switch stage {
            case .rem:
                bucket.remMinutes += minutes
                bucket.totalMinutes += minutes
            case .deep:
                bucket.deepMinutes += minutes
                bucket.totalMinutes += minutes
            case .core:
                bucket.coreMinutes += minutes
                bucket.totalMinutes += minutes
            case .awake:
                bucket.awakeMinutes += minutes
            }
        }

        return bucket.totalMinutes > 0 ? bucket : nil
    }

    static func sleepEpisodes(in intervals: [SleepInterval]) -> [[SleepInterval]] {
        let sorted = intervals
            .filter { $0.end > $0.start }
            .sorted { lhs, rhs in
                if lhs.start == rhs.start { return lhs.end < rhs.end }
                return lhs.start < rhs.start
            }
        guard let first = sorted.first else { return [] }

        var episodes: [[SleepInterval]] = [[first]]
        var currentEpisodeEnd = first.end

        for interval in sorted.dropFirst() {
            let gap = interval.start.timeIntervalSince(currentEpisodeEnd)
            if gap >= sleepEpisodeSplitGapSeconds {
                episodes.append([interval])
            } else {
                episodes[episodes.index(before: episodes.endIndex)].append(interval)
            }
            if interval.end > currentEpisodeEnd {
                currentEpisodeEnd = interval.end
            }
        }

        return episodes
    }

    static func mainSleepEpisode(from episodes: [[SleepInterval]]) -> [SleepInterval]? {
        episodes
            .map { episode -> (intervals: [SleepInterval], asleepMinutes: Double, start: Date) in
                let asleepMinutes = episode
                    .filter(\.stage.isAsleep)
                    .reduce(0) { $0 + $1.minutes }
                let start = episode.map(\.start).min() ?? .distantFuture
                return (episode, asleepMinutes, start)
            }
            .filter { $0.asleepMinutes > 0 }
            .sorted { lhs, rhs in
                if lhs.asleepMinutes == rhs.asleepMinutes {
                    return lhs.start < rhs.start
                }
                return lhs.asleepMinutes > rhs.asleepMinutes
            }
            .first?.intervals
    }

    static func fillingShortMeasurementGaps(in intervals: [SleepInterval]) -> (intervals: [SleepInterval], inferredGapMinutes: Double) {
        let sorted = intervals.sorted { lhs, rhs in
            if lhs.start == rhs.start { return lhs.end < rhs.end }
            return lhs.start < rhs.start
        }
        guard sorted.count > 1 else { return (sorted, 0) }

        var result: [SleepInterval] = []
        var inferredGapMinutes = 0.0

        for index in sorted.indices {
            let current = sorted[index]
            result.append(current)

            guard index < sorted.index(before: sorted.endIndex) else { continue }
            let next = sorted[sorted.index(after: index)]
            let gap = next.start.timeIntervalSince(current.end)

            guard gap > 0,
                  gap <= maximumFilledGapSeconds,
                  current.stage.isAsleep,
                  next.stage.isAsleep
            else { continue }

            let inferred = SleepInterval(
                start: current.end,
                end: next.start,
                stage: .core,
                sourceIdentifier: current.sourceIdentifier,
                isInferred: true
            )
            result.append(inferred)
            inferredGapMinutes += gap / 60
        }

        return (result, inferredGapMinutes)
    }

    static func sourceSummary(intervals: [SleepInterval]) -> String {
        let grouped = Dictionary(grouping: intervals, by: \.sourceIdentifier)
        return grouped
            .map { source, items in
                let asleep = items.filter(\.stage.isAsleep).reduce(0) { $0 + $1.minutes }
                let rem = items.filter { $0.stage == .rem }.reduce(0) { $0 + $1.minutes }
                let deep = items.filter { $0.stage == .deep }.reduce(0) { $0 + $1.minutes }
                let core = items.filter { $0.stage == .core }.reduce(0) { $0 + $1.minutes }
                let awake = items.filter { $0.stage == .awake }.reduce(0) { $0 + $1.minutes }
                return "\(source): total \(Int(asleep.rounded()))m, REM \(Int(rem.rounded()))m, Deep \(Int(deep.rounded()))m, Core \(Int(core.rounded()))m, Awake \(Int(awake.rounded()))m"
            }
            .sorted()
            .joined(separator: ", ")
    }

    static func primarySource(in intervals: [SleepInterval]) -> String {
        let grouped = Dictionary(grouping: intervals, by: \.sourceIdentifier)
        return grouped
            .map { source, items -> (source: String, score: Double) in
                let stagedMinutes = items
                    .filter { $0.stage.isSpecificSleepStage }
                    .reduce(0) { $0 + $1.minutes }
                let asleepMinutes = items
                    .filter(\.stage.isAsleep)
                    .reduce(0) { $0 + $1.minutes }
                let awakeMinutes = items
                    .filter { $0.stage == .awake }
                    .reduce(0) { $0 + $1.minutes }
                return (source, asleepMinutes * 100 + stagedMinutes - awakeMinutes * 0.1)
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.source < rhs.source }
                return lhs.score > rhs.score
            }
            .first?.source ?? "unknown"
    }

    static func winningStage(from intervals: [SleepInterval]) -> SleepStage? {
        intervals
            .sorted { lhs, rhs in
                if lhs.stage.priority == rhs.stage.priority {
                    return lhs.minutes > rhs.minutes
                }
                return lhs.stage.priority > rhs.stage.priority
            }
            .first?.stage
    }
}

struct SleepInterval {
    var start: Date
    var end: Date
    var stage: SleepStage
    var sourceIdentifier: String
    var isInferred: Bool = false

    var minutes: Double {
        end.timeIntervalSince(start) / 60
    }
}

enum SleepStage: Equatable {
    case rem
    case deep
    case core
    case awake

    init?(healthKitValue: Int) {
        #if canImport(HealthKit)
        switch healthKitValue {
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            self = .rem
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            self = .deep
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
             HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            self = .core
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            self = .awake
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    var isAsleep: Bool {
        self != .awake
    }

    var isSpecificSleepStage: Bool {
        switch self {
        case .rem, .deep, .core:
            return true
        case .awake:
            return false
        }
    }

    var priority: Int {
        switch self {
        case .deep, .rem:
            return 4
        case .core:
            return 3
        case .awake:
            return 2
        }
    }
}

@MainActor
final class CalendarIntegration: ObservableObject {
    @Published var statusText = "Not connected"
    @Published var lastSyncText = "No calendar events mirrored yet"
    @Published var isWorking = false

    #if canImport(EventKit)
    private let store = EKEventStore()
    #endif

    func requestAccessAndMirror(items: [PlannedDayItem]) {
        #if canImport(EventKit)
        isWorking = true
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                Task { @MainActor in
                    self?.finishCalendarRequest(granted: granted, error: error, items: items)
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                Task { @MainActor in
                    self?.finishCalendarRequest(granted: granted, error: error, items: items)
                }
            }
        }
        #else
        statusText = "Calendar unavailable"
        lastSyncText = "Build and run on iPhone to use Apple Calendar."
        #endif
    }

    #if canImport(EventKit)
    private func finishCalendarRequest(granted: Bool, error: Error?, items: [PlannedDayItem]) {
        isWorking = false
        guard granted else {
            statusText = "Permission not granted"
            lastSyncText = error?.localizedDescription ?? "Open iPhone Settings to allow Calendar access."
            return
        }

        do {
            let calendar = try sportCalendar()
            var savedCount = 0
            for item in items where item.kind != .importedActivity {
                let start = itemDate(item)
                let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
                let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
                let alreadyExists = store.events(matching: predicate).contains {
                    $0.title == item.workoutName && abs($0.startDate.timeIntervalSince(start)) < 60
                }
                guard !alreadyExists else { continue }

                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = item.workoutName
                event.startDate = start
                event.endDate = end
                event.notes = "Mirrored from Personal Sport. Edit workouts in the app, not in Apple Calendar."
                try store.save(event, span: .thisEvent)
                savedCount += 1
            }
            statusText = "Connected"
            lastSyncText = "\(savedCount) new workout event(s) mirrored to Paul Sport."
        } catch {
            statusText = "Sync failed"
            lastSyncText = error.localizedDescription
        }
    }

    private func sportCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == "Paul Sport" }) {
            return existing
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Paul Sport"
        calendar.source = store.defaultCalendarForNewEvents?.source ?? store.sources.first
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    private func itemDate(_ item: PlannedDayItem) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: item.date)
        components.hour = item.hour ?? 18
        components.minute = item.minute ?? 0
        return Calendar.current.date(from: components) ?? item.date
    }
    #endif
}
