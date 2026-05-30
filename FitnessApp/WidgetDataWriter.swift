import Foundation
import WidgetKit

enum WidgetDataWriter {
    static func write(
        kcalEaten: Double, kcalTarget: Double,
        proteinEaten: Double, proteinTarget: Double,
        waterLiters: Double, waterTarget: Double,
        steps: Int, stepsTarget: Int
    ) {
        var d = WidgetTodayData()
        d.kcalEaten    = kcalEaten;    d.kcalTarget    = kcalTarget
        d.proteinEaten = proteinEaten; d.proteinTarget = proteinTarget
        d.waterLiters  = waterLiters;  d.waterTarget   = waterTarget
        d.steps        = steps;        d.stepsTarget   = stepsTarget
        d.persist()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
