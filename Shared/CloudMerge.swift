import Foundation

// Unione di due copie dello stesso giorno (DayLog) create da dispositivi diversi.
//
// Con iCloud due dispositivi possono creare la riga dello stesso giorno prima di
// essersi scambiati i dati. La scelta di quale copia tenere dipende solo dal
// CONTENUTO, mai da identificatori locali: così ogni dispositivo sceglie la
// stessa copia e le cancellazioni non si incrociano (altrimenti due dispositivi
// potrebbero cancellare ciascuno una copia diversa, e sparirebbero entrambe).
// Se le copie sono identiche non si cancella niente: nessuna copia è distinguibile.

struct DayLogFields: Equatable {
    var weight: Double?
    var steps: Int
    /// Valore grezzo di GymColor; "rest" = nessun allenamento.
    var gymColor: String
    var activeCalories: Double
    var basalCalories: Double
}

/// Quanti campi hanno un valore vero, cioè diverso da quello di partenza.
func dayLogScore(_ f: DayLogFields) -> Int {
    (f.weight != nil ? 1 : 0) + (f.steps > 0 ? 1 : 0) + (f.gymColor != "rest" ? 1 : 0)
        + (f.activeCalories > 0 ? 1 : 0) + (f.basalCalories > 0 ? 1 : 0)
}

private func dayLogSortKey(_ f: DayLogFields) -> String {
    "\(f.weight ?? -1)|\(f.steps)|\(f.gymColor)|\(f.activeCalories)|\(f.basalCalories)"
}

/// Ordine totale sui contenuti: più campi veri prima, poi un ordine fisso.
func dayLogPrefers(_ a: DayLogFields, over b: DayLogFields) -> Bool {
    let sa = dayLogScore(a), sb = dayLogScore(b)
    if sa != sb { return sa > sb }
    return dayLogSortKey(a) > dayLogSortKey(b)
}

/// Unisce `other` dentro `keeper`: i valori veri di entrambe, e in caso di
/// conflitto vale la copia tenuta.
func mergeDayLogs(keeper k: DayLogFields, other o: DayLogFields) -> DayLogFields {
    DayLogFields(weight: k.weight ?? o.weight,
                 steps: max(k.steps, o.steps),
                 gymColor: k.gymColor != "rest" ? k.gymColor : o.gymColor,
                 activeCalories: max(k.activeCalories, o.activeCalories),
                 basalCalories: max(k.basalCalories, o.basalCalories))
}

struct DayLogResolution: Equatable {
    /// Indice della copia da tenere.
    var keeper: Int
    /// Contenuto da scrivere nella copia tenuta; le altre si eliminano.
    var merged: DayLogFields
}

/// nil se c'è una sola copia o se sono tutte identiche (niente da fare).
func resolveDayLogs(_ items: [DayLogFields]) -> DayLogResolution? {
    guard items.count > 1, items.contains(where: { $0 != items[0] }) else { return nil }
    let order = items.indices.sorted { i, j in
        items[i] == items[j] ? i < j : dayLogPrefers(items[i], over: items[j])
    }
    let keeper = order[0]
    var merged = items[keeper]
    for i in order.dropFirst() { merged = mergeDayLogs(keeper: merged, other: items[i]) }
    return DayLogResolution(keeper: keeper, merged: merged)
}
