import Foundation
import Combine

// HealthKit rimosso per compatibilità con account gratuito.
// I passi si inseriscono manualmente nella schermata Oggi.
// Per abilitare la sincronizzazione automatica con Apple Health
// è necessario il Apple Developer Program (99$/anno).

@MainActor
final class HealthKitManager: ObservableObject {
    func requestAuthorization() async -> Bool { return false }
    func steps(for date: Date) async -> Int { return 0 }
    func stepsHistory(days: Int) async -> [(date: Date, steps: Int)] { return [] }
}
