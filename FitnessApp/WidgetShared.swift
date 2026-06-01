import Foundation

// Shared between FitnessApp and FitnessWidget targets.
// In Xcode: select this file → File Inspector → Target Membership → check both targets.

let fitnessAppGroupID = "group.davideCorso.FitnessApp"

struct WidgetTodayData: Codable {
    var kcalEaten: Double = 0
    var kcalTarget: Double = 2255
    var proteinEaten: Double = 0
    var proteinTarget: Double = 200
    var waterLiters: Double = 0
    var waterTarget: Double = 2.0
    var steps: Int = 0
    var stepsTarget: Int = 10000

    private static let key = "fitnessTodayWidget"

    static func load() -> WidgetTodayData {
        guard let ud = UserDefaults(suiteName: fitnessAppGroupID),
              let data = ud.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetTodayData.self, from: data)
        else { return WidgetTodayData() }
        return decoded
    }

    func persist() {
        guard let ud = UserDefaults(suiteName: fitnessAppGroupID),
              let data = try? JSONEncoder().encode(self)
        else { return }
        ud.set(data, forKey: Self.key)
    }
}
