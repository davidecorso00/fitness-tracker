import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct FitnessAppApp: App {

    let container: ModelContainer = {
        let schema = Schema([
            FoodItem.self, FoodEntry.self, DayLog.self,
            AppLimits.self, SportEntry.self,
            UserProfile.self, TargetHistory.self,
            WaterEntry.self
        ])
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
                .onAppear {
                    let hk = HealthKitManager()
                    Task {
                        await hk.requestAuthorization()
                        hk.startBackgroundObserver(container: container)
                    }
                }
        }
    }
}
