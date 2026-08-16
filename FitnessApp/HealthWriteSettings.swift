import Foundation
import HealthKit

/// Cosa l'app manda ad Apple Health.
///
/// Sta in `UserDefaults` e non nel database perché serve anche fuori dalle
/// viste (per esempio quando una corsa viene salvata da un task in background).
enum HealthWriteSettings {

    private enum Key {
        static let workouts = "healthWriteWorkouts"
        static let weight   = "healthWriteWeight"
        static let energy   = "healthWriteEnergy"
    }

    /// Allenamenti (palestra, corsa, corda) visibili in Salute e Fitness.
    static var writeWorkouts: Bool {
        get { UserDefaults.standard.object(forKey: Key.workouts) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.workouts) }
    }

    /// Peso corporeo, così altre app lo vedono.
    static var writeWeight: Bool {
        get { UserDefaults.standard.object(forKey: Key.weight) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Key.weight) }
    }

    /// Calorie degli allenamenti dentro l'energia attiva di Health.
    ///
    /// Spento di proposito: l'app *legge* l'energia attiva per calcolare le
    /// calorie bruciate del giorno. Scriverci dentro le proprie stime le farebbe
    /// rientrare dalla porta principale, gonfiando il totale — e se hai l'Apple
    /// Watch quella stessa attività è già registrata da lui.
    static var writeEnergy: Bool {
        get { UserDefaults.standard.bool(forKey: Key.energy) }
        set { UserDefaults.standard.set(newValue, forKey: Key.energy) }
    }
}

// MARK: - Invio degli allenamenti

@MainActor
enum HealthExport {

    /// Manda un allenamento ad Apple Health, se l'utente lo ha lasciato attivo.
    static func send(activity: HKWorkoutActivityType,
                     start: Date, durationSeconds: Double,
                     kcal: Double, distanceMeters: Double? = nil) {
        guard HealthWriteSettings.writeWorkouts, durationSeconds > 0 else { return }
        let end = start.addingTimeInterval(durationSeconds)
        let energy = HealthWriteSettings.writeEnergy ? kcal : nil
        Task {
            await HealthKitManager.shared.saveWorkout(
                activity: activity, start: start, end: end,
                energyKcal: energy, distanceMeters: distanceMeters)
        }
    }

    static func sendWeight(_ kg: Double, on date: Date) {
        guard HealthWriteSettings.writeWeight, kg > 0 else { return }
        Task { await HealthKitManager.shared.saveWeight(kg, on: date) }
    }
}
