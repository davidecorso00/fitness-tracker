import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

// Ponte dati fra iPhone e Apple Watch.
//
// Il database SwiftData vive sul telefono e non è raggiungibile dall'orologio:
// il Watch riceve un riassunto della giornata e rimanda le azioni fatte al
// polso, che il telefono applica sul database vero. È volutamente asimmetrico —
// una sola fonte di verità, l'orologio non tiene stato proprio.

// MARK: - Riassunto inviato al Watch

/// Fotografia della giornata, abbastanza piccola da stare in un contesto
/// applicativo di WatchConnectivity.
nonisolated struct WatchSummary: Codable, Equatable, Sendable {
    var kcalEaten: Double = 0
    var kcalTarget: Double = 0
    var proteinEaten: Double = 0
    var proteinTarget: Double = 0
    var waterLiters: Double = 0
    var waterTarget: Double = 0
    var steps: Int = 0
    var stepsTarget: Int = 0
    var updatedAt: Date = .distantPast

    /// Alimenti ripetuti di recente, per registrarli dal polso.
    var quickFoods: [WatchQuickFood] = []

    var remainingKcal: Double { kcalTarget - kcalEaten }

    static let contextKey = "watchSummary"
}

nonisolated struct WatchQuickFood: Codable, Equatable, Identifiable, Sendable {
    var id: String { name }
    var name: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var meal: String
}

// MARK: - Azioni rimandate dal Watch

/// Cosa l'orologio chiede al telefono di registrare.
nonisolated enum WatchAction: Codable, Equatable, Sendable {
    case logWater(liters: Double)
    case logQuickFood(WatchQuickFood)

    static let messageKey = "watchAction"
}

// MARK: - Codifica

nonisolated enum WatchPayload {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? decoder.decode(type, from: data)
    }
}
