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
            fatalError("ModelContainer error: \(error)")
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
