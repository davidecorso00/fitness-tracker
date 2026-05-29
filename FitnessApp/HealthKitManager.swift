import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthKitManager {

    private let healthStore = HKHealthStore()

    private var stepsObserver:  HKObserverQuery?
    private var activeObserver: HKObserverQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned)
        ]
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Autorizzazione
    // ─────────────────────────────────────────────────────────────────────

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
