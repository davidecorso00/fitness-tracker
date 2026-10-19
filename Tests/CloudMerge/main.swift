import Foundation

// Verifica dell'unione dei giorni duplicati fra dispositivi.

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}

func day(weight: Double? = nil, steps: Int = 0, gym: String = "rest",
         active: Double = 0, basal: Double = 0) -> DayLogFields {
    DayLogFields(weight: weight, steps: steps, gymColor: gym, activeCalories: active, basalCalories: basal)
}

print("\n1. Una copia vuota e una piena: si tiene la piena")
let iphone = day(weight: 81.2, steps: 9000, gym: "green", active: 520)
let ipad = day()
if let r = resolveDayLogs([ipad, iphone]) {
    check("tiene la copia con i dati", r.keeper == 1)
    check("il contenuto resta quello pieno", r.merged == iphone)
} else { check("risolve", false) }

print("\n2. Stesso risultato in qualunque ordine")
let a = day(weight: 80, steps: 0)
let b = day(weight: nil, steps: 7000, active: 300)
let ab = resolveDayLogs([a, b]), ba = resolveDayLogs([b, a])
check("stesso contenuto unito", ab?.merged == ba?.merged)
check("unione: peso di a, passi e calorie di b",
      ab?.merged == day(weight: 80, steps: 7000, active: 300))
check("la copia tenuta è la stessa (per contenuto)",
      ab.map { [a, b][$0.keeper] } == ba.map { [b, a][$0.keeper] })

print("\n3. Copie identiche: non si cancella niente")
check("identiche → nessuna azione", resolveDayLogs([day(steps: 5), day(steps: 5)]) == nil)
check("una sola copia → nessuna azione", resolveDayLogs([iphone]) == nil)

print("\n4. Tre copie")
if let r = resolveDayLogs([day(), iphone, day(weight: 80)]) {
    check("tiene la più completa", r.keeper == 1)
    check("peso in conflitto: vale la copia tenuta", r.merged.weight == 81.2)
} else { check("risolve", false) }

print("")
if failures == 0 { print("Tutti i controlli superati"); exit(0) }
else { print("\(failures) controlli falliti"); exit(1) }
