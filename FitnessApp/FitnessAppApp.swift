import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {

    let container: ModelContainer = {
        let schema = Schema([FoodItem.self, FoodEntry.self, DayLog.self, AppLimits.self, SportEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Se il DB esistente non è compatibile, cancella e ricrea
            print("⚠️ ModelContainer fallito: \(error). Ricreo il database...")
            // Cancella tutti i file .store nella directory
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
        }
    }
}
