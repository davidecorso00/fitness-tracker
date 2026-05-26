import Foundation
import HealthKit
import SwiftData

// MARK: - HealthKitManager (Obiettivo 2: Vero Sync con Apple Health)
//
// CAMBIAMENTI RISPETTO ALLA VERSIONE PRECEDENTE:
// ─────────────────────────────────────────────
// 1. Rimosso @Published isAuthorized (non necessario nella UI corrente).
// 2. Aggiunto fetchAndSyncToday(context:) → metodo "tutto-in-uno" chiamabile
//    da TodayView onAppear e quando l'utente torna in foreground.
// 3. Aggiunto startBackgroundObserver(context:) → observer HealthKit che
//    riceve push di nuovi dati da Apple Watch in background, aggiorna
//    automaticamente il DayLog senza che l'utente debba fare nulla.
// 4. I metodi fetchSteps / fetchActiveCalories sono rimasti identici
//    (async/await puro, zero callback).

@MainActor
final class HealthKitManager {

    // ── Store ─────────────────────────────────────────────────────────────
    private let healthStore = HKHealthStore()

    // Observer query per aggiornamenti in background (step + calorie attive)
    private var stepsObserver:    HKObserverQuery?
    private var caloriesObserver: HKObserverQuery?

    // ── Disponibilità ─────────────────────────────────────────────────────
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // ── Tipi di dati richiesti ─────────────────────────────────────────────
    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned)
        ]
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - 1. Richiesta Permessi
    // ─────────────────────────────────────────────────────────────────────

    /// Chiede all'utente i permessi di lettura per passi e calorie attive.
    /// Restituisce `true` se l'autorizzazione è andata a buon fine.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            print("HealthKit: autorizzazione fallita → \(error)")
            return false
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - 2. Fetch Passi
    // ─────────────────────────────────────────────────────────────────────

    /// Ritorna il totale passi del giorno indicato (o 0 se HealthKit non disponibile).
    func fetchSteps(for date: Date) async -> Int {
        guard isAvailable else { return 0 }

        let (start, end) = dayBounds(for: date)

        // IMPORTANTE: NON usare .strictStartDate per i passi.
        // Con Apple Watch i campioni hanno startDate/endDate che possono
        // sconfinare sui minuti a cavallo della mezzanotte. Con strictStartDate
        // quei campioni vengono ignorati e il totale risulta troppo basso.
        // Senza opzioni HealthKit usa la sua deduplicazione interna (come Fitness.app).
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        do {
            let sum: Double = try await withCheckedThrowingContinuation { cont in
                let query = HKStatisticsQuery(
                    quantityType: HKQuantityType(.stepCount),
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, stats, error in
                    if let error { cont.resume(throwing: error); return }
                    // sumQuantity() usa già la deduplicazione HealthKit:
                    // non somma due volte gli stessi passi da iPhone e Watch.
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
    // MARK: - 3. Fetch Calorie Attive
    // ─────────────────────────────────────────────────────────────────────

    /// Ritorna le calorie attive bruciate reali del giorno indicato.
    /// Questo valore include la lettura dall'Apple Watch se presente.
    func fetchActiveCalories(for date: Date) async -> Double {
        guard isAvailable else { return 0 }

        let (start, end) = dayBounds(for: date)
        // Stesso ragionamento dei passi: senza strictStartDate per non perdere
        // campioni Watch a cavallo della mezzanotte.
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
    // MARK: - 4. Sync "tutto-in-uno" → DayLog di SwiftData
    // ─────────────────────────────────────────────────────────────────────

    /// Recupera passi + calorie attive per `date` e li salva nel DayLog
    /// corrispondente nel contesto SwiftData.
    ///
    /// **Uso consigliato:**
    /// ```swift
    /// .onAppear {
    ///     Task { await appState.healthKit.fetchAndSync(for: appState.currentDate, context: context) }
    /// }
    /// .onChange(of: appState.currentDate) { _, new in
    ///     Task { await appState.healthKit.fetchAndSync(for: new, context: context) }
    /// }
    /// ```
    func fetchAndSync(for date: Date, context: ModelContext) async {
        guard isAvailable else { return }

        // Richiedi permessi se non ancora concessi (no-op se già dati)
        await requestAuthorization()

        async let steps    = fetchSteps(for: date)
        async let calories = fetchActiveCalories(for: date)

        let (s, c) = await (steps, calories)

        // Recupera o crea il DayLog per questa data
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

        // Aggiorna solo se HealthKit ha dati migliori di quelli manuali.
        // Regola: se l'utente ha inserito i passi manualmente (> 0) e HealthKit
        // ritorna 0 (es. permesso negato), non sovrascriviamo il valore manuale.
        if s > 0 { log.steps = s }
        if c > 0 { log.activeCaloriesBurned = c }

        try? context.save()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - 5. Observer in Background (aggiornamento automatico)
    // ─────────────────────────────────────────────────────────────────────

    /// Avvia due observer query HealthKit (passi + calorie attive).
    /// Ogni volta che Apple Watch o iPhone scrive nuovi dati, il callback
    /// chiama `fetchAndSync` per aggiornare SwiftData in automatico.
    ///
    /// Chiamare **una sola volta** all'avvio dell'app (in `FitnessAppApp`).
    func startBackgroundObserver(container: ModelContainer) {
        guard isAvailable else { return }

        let types: [HKQuantityTypeIdentifier] = [.stepCount, .activeEnergyBurned]

        for typeID in types {
            let quantityType = HKQuantityType(typeID)

            // Nota: catturiamo `container` (Sendable) invece di `context` (non-Sendable).
            // Il ModelContext viene ricreato sul MainActor dove è richiesto.
            let observer = HKObserverQuery(sampleType: quantityType, predicate: nil) { [weak self] _, completion, error in
                guard let self, error == nil else { completion(); return }

                Task { @MainActor in
                    // mainContext è sempre accessibile dal container su MainActor
                    await self.fetchAndSync(for: Date(), context: container.mainContext)
                    completion()
                }
            }

            healthStore.execute(observer)

            // Abilita delivery in background (richiede Background Modes → HealthKit nel target)
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { success, error in
                if let error {
                    print("HealthKit: enableBackgroundDelivery fallito per \(typeID.rawValue) → \(error)")
                }
            }

            // Salviamo i riferimenti per poterli fermare in futuro
            if typeID == .stepCount         { stepsObserver    = observer }
            if typeID == .activeEnergyBurned { caloriesObserver = observer }
        }
    }

    /// Ferma gli observer (es. in deinit o logout).
    func stopBackgroundObservers() {
        if let q = stepsObserver    { healthStore.stop(q) }
        if let q = caloriesObserver { healthStore.stop(q) }
        stepsObserver    = nil
        caloriesObserver = nil
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Utility privata
    // ─────────────────────────────────────────────────────────────────────

    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }
}
