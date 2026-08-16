import Foundation
import SwiftData
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// Lato iPhone del ponte con l'orologio: pubblica il riassunto della giornata e
// applica al database le azioni arrivate dal polso.

#if canImport(WatchConnectivity)

@MainActor
final class PhoneWatchSession: NSObject {

    static let shared = PhoneWatchSession()

    private var container: ModelContainer?
    private var lastSent: WatchSummary?

    private override init() { super.init() }

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Manda al Watch la fotografia della giornata. Il contesto applicativo
    /// sostituisce il precedente e sopravvive allo spegnimento dell'app: è la
    /// primitiva giusta per uno stato che cambia spesso ma conta solo l'ultimo.
    func publishSummary() {
        guard let container, WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let summary = buildSummary(context: container.mainContext)
        guard summary != lastSent else { return }   // niente traffico inutile
        lastSent = summary

        guard let data = WatchPayload.encode(summary) else { return }
        try? session.updateApplicationContext([WatchSummary.contextKey: data])
    }

    private func buildSummary(context: ModelContext) -> WatchSummary {
        var s = WatchSummary()
        let key = Date().dateKey

        let limits = (try? context.fetch(FetchDescriptor<AppLimits>()))?.first
        s.kcalTarget    = limits?.kcalTarget ?? 0
        s.proteinTarget = limits?.proteinTarget ?? 0
        s.waterTarget   = limits?.waterTarget ?? 0
        s.stepsTarget   = limits?.stepsTarget ?? 0

        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let today = entries.filter { $0.dayKey == key }
        s.kcalEaten    = today.reduce(0) { $0 + $1.kcalSnapshot }
        s.proteinEaten = today.reduce(0) { $0 + $1.proteinSnapshot }

        let waters = (try? context.fetch(FetchDescriptor<WaterEntry>())) ?? []
        s.waterLiters = waters.filter { $0.dayKey == key }.reduce(0) { $0 + $1.liters }

        let logs = (try? context.fetch(FetchDescriptor<DayLog>())) ?? []
        s.steps = logs.first { $0.dateKey == key }?.steps ?? 0

        // Gli otto alimenti più ripetuti di recente, con la porzione dell'ultima volta.
        let recent = Array(entries.sorted { $0.date > $1.date }.prefix(300))
        s.quickFoods = recent.recentFoods(limit: 8).map {
            WatchQuickFood(name: $0.foodName, grams: $0.grams, kcal: $0.kcal,
                           protein: $0.protein, carbs: $0.carbs, fat: $0.fat,
                           meal: MealType.snack.rawValue)
        }

        s.updatedAt = Date()
        return s
    }

    // MARK: - Applicazione delle azioni

    fileprivate func apply(_ action: WatchAction) {
        guard let context = container?.mainContext else { return }
        switch action {
        case .logWater(let liters):
            context.insert(WaterEntry(dayKey: Date().dateKey, liters: liters))
        case .logQuickFood(let food):
            let meal = MealType(rawValue: food.meal) ?? .snack
            context.insert(FoodEntry(
                foodName: food.name, grams: food.grams, meal: meal, date: Date(),
                kcal: food.kcal, protein: food.protein, carbs: food.carbs, fat: food.fat))
        }
        try? context.save()
        publishSummary()
    }
}

extension PhoneWatchSession: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.publishSummary() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message[WatchAction.messageKey] as? Data,
              let action = WatchPayload.decode(WatchAction.self, from: data) else { return }
        Task { @MainActor in self.apply(action) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        self.session(session, didReceiveMessage: message)
        replyHandler(["ok": true])
    }
}

#else

@MainActor
final class PhoneWatchSession {
    static let shared = PhoneWatchSession()
    func start(container: ModelContainer) {}
    func publishSummary() {}
}

#endif
