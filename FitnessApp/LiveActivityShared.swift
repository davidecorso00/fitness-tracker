import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit

// Mirrored in FitnessWidget/LiveActivities.swift — ActivityKit abbina le activity
// tra app ed extension per nome del tipo e forma Codable, quindi le definizioni
// devono restare identiche nei due target (stessa convenzione di WidgetTodayData).

// MARK: - Corsa

struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Ancora del cronometro: Date() - tempo attivo. Il sistema renderizza
        /// il timer da solo via Text(timerInterval:), senza update ogni secondo.
        var startedAt: Date
        var isPaused: Bool
        var elapsedAtPause: Double
        var distanceMeters: Double
        var avgPaceSecPerKm: Double?
        var kcal: Double
    }
}

// MARK: - Riposo palestra

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var totalSeconds: Int
    }
    var workoutName: String
}
#endif
