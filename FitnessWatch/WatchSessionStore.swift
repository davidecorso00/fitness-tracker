import Foundation
import WatchConnectivity

// Lato orologio del ponte. Non tiene un database: conserva l'ultimo riassunto
// ricevuto dal telefono e gli manda le azioni fatte al polso.
//
// L'ultimo riassunto viene anche salvato su disco, così all'apertura mostra
// subito qualcosa invece di una schermata vuota mentre il telefono risponde.

@MainActor
final class WatchSessionStore: NSObject, ObservableObject {

    static let shared = WatchSessionStore()

    @Published private(set) var summary = WatchSummary()
    @Published private(set) var isReachable = false
    /// Azioni fatte al polso ma non ancora confermate dal telefono.
    @Published private(set) var pendingActions = 0

    private let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("watch-summary.json")
    }()

    private override init() {
        super.init()
        loadCache()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Azioni

    func logWater(_ liters: Double) {
        send(.logWater(liters: liters))
        // Aggiornamento ottimistico: il polso deve rispondere subito.
        summary.waterLiters += liters
    }

    func logFood(_ food: WatchQuickFood) {
        send(.logQuickFood(food))
        summary.kcalEaten += food.kcal
        summary.proteinEaten += food.protein
    }

    private func send(_ action: WatchAction) {
        guard WCSession.isSupported(), let data = WatchPayload.encode(action) else { return }
        let session = WCSession.default
        pendingActions += 1

        if session.isReachable {
            session.sendMessage([WatchAction.messageKey: data], replyHandler: { [weak self] _ in
                Task { @MainActor in self?.pendingActions = max(0, (self?.pendingActions ?? 1) - 1) }
            }, errorHandler: { [weak self] _ in
                // Telefono irraggiungibile a metà invio: la coda affidabile lo recapita dopo.
                session.transferUserInfo([WatchAction.messageKey: data])
                Task { @MainActor in self?.pendingActions = max(0, (self?.pendingActions ?? 1) - 1) }
            })
        } else {
            // Coda affidabile: arriva quando il telefono torna raggiungibile.
            session.transferUserInfo([WatchAction.messageKey: data])
            pendingActions = max(0, pendingActions - 1)
        }
    }

    // MARK: - Cache locale

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = WatchPayload.decode(WatchSummary.self, from: data) else { return }
        summary = cached
    }

    private func saveCache() {
        guard let data = WatchPayload.encode(summary) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    fileprivate func apply(context: [String: Any]) {
        guard let data = context[WatchSummary.contextKey] as? Data,
              let received = WatchPayload.decode(WatchSummary.self, from: data) else { return }
        summary = received
        saveCache()
    }
}

extension WatchSessionStore: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.isReachable = session.isReachable
            if !context.isEmpty { self.apply(context: context) }
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(context: applicationContext) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }
}
