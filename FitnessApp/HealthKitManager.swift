import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthKitManager {

    /// Istanza unica. L'observer in background resta vivo solo finché è vivo l'oggetto
    /// che possiede l'`HKHealthStore`: con istanze usa-e-getta la query veniva registrata
    /// e subito persa insieme al manager deallocato.
    static let shared = HealthKitManager()

    private init() {}

    private let healthStore = HKHealthStore()

    private var stepsObserver:  HKObserverQuery?
    private var activeObserver: HKObserverQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate)
        ]
    }

    /// Cosa l'app può scrivere: allenamenti (con durata e distanza), peso, e
    /// l'energia attiva — quest'ultima usata solo se l'utente la abilita, vedi
    /// `HealthWriteSettings.writeEnergy`.
    private var shareTypes: Set<HKSampleType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.bodyMass),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Autorizzazione
    // ─────────────────────────────────────────────────────────────────────

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            return true
        } catch {
            print("HealthKit: autorizzazione fallita → \(error)")
            return false
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Fetch Passi
    // ─────────────────────────────────────────────────────────────────────

    func fetchSteps(for date: Date) async -> Int {
        guard isAvailable else { return 0 }
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        do {
            let sum: Double = try await withCheckedThrowingContinuation { cont in
                let query = HKStatisticsQuery(
                    quantityType: HKQuantityType(.stepCount),
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, stats, error in
                    if let error { cont.resume(throwing: error); return }
                    cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                }
                healthStore.execute(query)
            }
            return Int(sum)
        } catch {
            print("HealthKit: fetch passi fallito → \(error)")
            return 0
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Fetch Calorie Attive (movimento/esercizio)
    // ─────────────────────────────────────────────────────────────────────

    func fetchActiveCalories(for date: Date) async -> Double {
        guard isAvailable else { return 0 }
        let (start, end) = dayBounds(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        do {
            let kcal: Double = try await withCheckedThrowingContinuation { cont in
                let query = HKStatisticsQuery(
                    quantityType: HKQuantityType(.activeEnergyBurned),
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, stats, error in
                    if let error { cont.resume(throwing: error); return }
                    cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
                }
                healthStore.execute(query)
            }
            return kcal
        } catch {
            print("HealthKit: fetch calorie attive fallito → \(error)")
            return 0
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Battito cardiaco (campioni scritti dall'Apple Watch)
    // ─────────────────────────────────────────────────────────────────────

    private static let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    /// Tutti i campioni di battito nell'intervallo: media, massimo e serie
    /// (offset in secondi da `start`). Vuoto se non c'è un Watch che li scrive.
    func fetchHeartRateStats(from start: Date, to end: Date) async -> (avg: Double, max: Double, series: [HRPoint]) {
        guard isAvailable else { return (0, 0, []) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKQuantitySample] = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(.heartRate),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                cont.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
        let bpms = samples.map { $0.quantity.doubleValue(for: Self.bpmUnit) }
        guard !bpms.isEmpty else { return (0, 0, []) }
        let series = zip(samples, bpms).map {
            HRPoint(t: $0.0.startDate.timeIntervalSince(start), bpm: $0.1)
        }
        return (bpms.reduce(0, +) / Double(bpms.count), bpms.max() ?? 0, series)
    }

    /// Stream dei nuovi campioni di battito da adesso in poi (per il valore
    /// live durante la corsa). Restituisce la query da fermare con stopQuery.
    func startHeartRateStream(onSample: @escaping @MainActor @Sendable (Double) -> Void) -> HKQuery? {
        guard isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil)
        // HealthKit invoca l'handler su una coda propria: dev'essere @Sendable,
        // e il valore torna sul main actor via Task.
        let handler: @Sendable (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { _, samples, _, _, _ in
            guard let last = (samples as? [HKQuantitySample])?.max(by: { $0.startDate < $1.startDate }) else { return }
            // Unità creata qui: quella statica è isolata al main actor.
            let bpm = last.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            Task { @MainActor in onSample(bpm) }
        }
        let query = HKAnchoredObjectQuery(
            type: HKQuantityType(.heartRate),
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: handler
        )
        query.updateHandler = handler
        healthStore.execute(query)
        return query
    }

    func stopQuery(_ query: HKQuery?) {
        if let query { healthStore.stop(query) }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Sync tutto-in-uno → DayLog SwiftData
    // ─────────────────────────────────────────────────────────────────────

    func fetchAndSync(for date: Date, context: ModelContext) async {
        guard isAvailable else { return }
        await requestAuthorization()

        async let steps  = fetchSteps(for: date)
        async let active = fetchActiveCalories(for: date)

        let (s, ac) = await (steps, active)

        let key = date.dateKey
        let descriptor = FetchDescriptor<DayLog>(
            predicate: #Predicate { $0.dateKey == key }
        )
        let log: DayLog
        if let existing = try? context.fetch(descriptor).first {
            log = existing
        } else {
            log = DayLog(dateKey: key)
            context.insert(log)
        }

        if s  > 0 { log.steps = s }
        if ac > 0 { log.activeCaloriesBurned = ac }

        try? context.save()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Scrittura su Apple Health
    // ─────────────────────────────────────────────────────────────────────

    /// Salva il peso corporeo. Nessun rischio di doppio conteggio: l'app il peso
    /// lo scrive soltanto, non lo rilegge da Health.
    func saveWeight(_ kg: Double, on date: Date) async {
        guard isAvailable, kg > 0 else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date, end: date)
        do { try await healthStore.save(sample) }
        catch { print("HealthKit: salvataggio peso fallito → \(error)") }
    }

    /// Registra un allenamento in Apple Health.
    ///
    /// `energyKcal` viene scritto **solo** se l'utente lo ha abilitato: l'app usa
    /// l'energia attiva di Health come propria fonte per le calorie bruciate, e
    /// riscriverci dentro le proprie stime creerebbe un anello che gonfia il
    /// totale del giorno. Durata, tipo e distanza non hanno questo problema.
    func saveWorkout(activity: HKWorkoutActivityType,
                     start: Date, end: Date,
                     energyKcal: Double?,
                     distanceMeters: Double?) async {
        guard isAvailable, end > start else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = activity
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())

        do {
            try await builder.beginCollection(at: start)

            var samples: [HKSample] = []
            if let kcal = energyKcal, kcal > 0 {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                    start: start, end: end))
            }
            if let meters = distanceMeters, meters > 0 {
                samples.append(HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .meter(), doubleValue: meters),
                    start: start, end: end))
            }
            if !samples.isEmpty { try await builder.addSamples(samples) }

            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            print("HealthKit: salvataggio allenamento fallito → \(error)")
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Observer in Background
    // ─────────────────────────────────────────────────────────────────────

    func startBackgroundObserver(container: ModelContainer) {
        guard isAvailable else { return }

        let types: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned]

        for typeID in types {
            let quantityType = HKQuantityType(typeID)

            let observer = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, completion, error in
                guard let self, error == nil else { completion(); return }
                Task { @MainActor in
                    await self.fetchAndSync(for: Date(), context: container.mainContext)
                    completion()
                }
            }

            healthStore.execute(observer)
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { _, error in
                if let error {
                    print("HealthKit: enableBackgroundDelivery fallito per \(typeID.rawValue) → \(error)")
                }
            }

            switch typeID {
            case .stepCount:          stepsObserver  = observer
            case .activeEnergyBurned: activeObserver = observer
            default: break
            }
        }
    }

    func stopBackgroundObservers() {
        [stepsObserver, activeObserver].compactMap { $0 }.forEach { healthStore.stop($0) }
        stepsObserver  = nil
        activeObserver = nil
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Utility
    // ─────────────────────────────────────────────────────────────────────

    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }
}
