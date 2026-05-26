import SwiftUI
import SwiftData

// MARK: - App Entry Point
//
// CAMBIAMENTI:
// - Aggiunto RootView.onAppear per avviare startBackgroundObserver(context:)
//   dopo che il ModelContainer è pronto.
// - Il container viene passato come @Environment all'app, quindi l'observer
//   lo riceve già inizializzato.

@main
struct FitnessAppApp: App {

    let container: ModelContainer = {
        let schema = Schema([FoodItem.self, FoodEntry.self, DayLog.self, AppLimits.self, SportEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("⚠️ ModelContainer fallito: \(error). Ricreo il database...")
            let storeURL = config.url
            let dir = storeURL.deletingLastPathComponent()
            if let files = try? FileManager.default.contentsOfDirectory(at: dir,
                includingPropertiesForKeys: nil) {
                for file in files where file.lastPathComponent.contains(".store") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("ModelContainer error dopo reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
                // ── Avvio observer HealthKit ──────────────────────────────
                // Si esegue una volta sola quando la finestra appare.
                // L'observer rimane attivo per tutta la vita dell'app e
                // aggiorna automaticamente i DayLog quando arrivano nuovi
                // dati da iPhone o Apple Watch.
                .onAppear {
                    // Passiamo il container (Sendable) invece del context
                    // per evitare il warning "Capture of non-Sendable ModelContext".
                    let hk = HealthKitManager()
                    Task {
                        await hk.requestAuthorization()
                        hk.startBackgroundObserver(container: container)
                    }
                }
        }
    }
}
