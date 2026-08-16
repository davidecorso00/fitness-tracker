import SwiftUI
import SwiftData

// MARK: - Recupero database

/// Traccia il caso in cui l'apertura del database è fallita e il vecchio store è stato
/// messo da parte: l'app riparte vuota, quindi l'utente va avvisato che può ripristinare
/// un backup invece di ritrovarsi i dati spariti senza spiegazioni.
enum StoreRecovery {
    private static let defaultsKey = "lastPreservedStorePath"

    static var preservedPath: String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    static func record(path: String) {
        UserDefaults.standard.set(path, forKey: defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

// MARK: - App Entry Point

@main
struct FitnessAppApp: App {

    let container: ModelContainer = {
        let schema = Schema([
            FoodItem.self, FoodEntry.self, DayLog.self,
            AppLimits.self, SportEntry.self,
            UserProfile.self, TargetHistory.self,
            WaterEntry.self,
            Medicine.self, MedicineDose.self, MedicineLog.self,
            CustomMeal.self, CustomMealIngredient.self,
            Exercise.self, WorkoutTemplate.self, TemplateExercise.self, TemplateExerciseSet.self,
            WorkoutSession.self, WorkoutEntry.self, WorkoutSet.self,
            RunSession.self, JumpRopeSession.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // L'apertura del database è fallita (tipicamente una migrazione non
            // automatica dopo un cambio di schema). NON cancelliamo nulla: mettiamo
            // da parte il vecchio store così i dati restano sempre recuperabili,
            // poi ripartiamo con un database nuovo.
            print("⚠️ ModelContainer fallito: \(error). Metto al sicuro il vecchio database…")
            Self.preserveExistingStore(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("ModelContainer error dopo il salvataggio del vecchio store: \(error)")
            }
        }
    }()

    /// Sposta (NON elimina) i file dello store esistente in una cartella di backup
    /// timestampata accanto al database. Così, anche se la migrazione automatica
    /// fallisce, i dati grezzi non vengono mai persi e possono essere recuperati.
    private static func preserveExistingStore(at storeURL: URL) {
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent   // es. "default.store"

        // Tutti i file correlati: default.store, default.store-wal, default.store-shm, …
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let related = files.filter { $0.lastPathComponent.hasPrefix(base) }
        guard !related.isEmpty else { return }

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = dir.appendingPathComponent("CorruptedStore-\(stamp)", isDirectory: true)
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        for file in related {
            let dest = backupDir.appendingPathComponent(file.lastPathComponent)
            do {
                try fm.moveItem(at: file, to: dest)
            } catch {
                // Se lo spostamento fallisce, come ultima risorsa copiamo: mai eliminare.
                try? fm.copyItem(at: file, to: dest)
            }
        }
        // Segnaliamo l'evento: RootView mostra l'avviso al primo avvio utile.
        StoreRecovery.record(path: backupDir.path)
        print("📦 Vecchio database spostato in: \(backupDir.path)")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(.dark)
                // ── Avvio observer HealthKit ──────────────────────────────
                .onAppear {
                    // Gli App Intents girano nel processo dell'app e riusano
                    // questo contenitore: aprirne un secondo sullo stesso store
                    // significherebbe due scrittori concorrenti.
                    IntentStore.container = container
                    Task { @MainActor in
                        let hk = HealthKitManager.shared
                        await hk.requestAuthorization()
                        hk.startBackgroundObserver(container: container)
                    }
                }
        }
    }
}
