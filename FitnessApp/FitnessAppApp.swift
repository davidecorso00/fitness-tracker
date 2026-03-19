import SwiftUI
import SwiftData

@main
struct FitnessAppApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: [FoodItem.self, FoodEntry.self, DayLog.self, AppLimits.self])
                .preferredColorScheme(.dark)
        }
    }
}
