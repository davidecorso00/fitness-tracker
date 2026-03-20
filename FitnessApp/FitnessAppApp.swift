import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {

    let container: ModelContainer = {
        let schema = Schema([FoodItem.self, FoodEntry.self, DayLog.self, AppLimits.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Impossibile creare ModelContainer: \(error)")
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
