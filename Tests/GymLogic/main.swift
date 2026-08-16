import Foundation

// Verifica di caricamento bilanciere e progressione del carico.

var failures = 0

func check(_ label: String, _ condition: Bool) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}

// ── 1. Caricamento del bilanciere ─────────────────────────────────────────────

print("\n1. Calcolo dischi")

let l100 = plateLoad(target: 100, bar: 20)
check("100 kg con bilanciere da 20 → 40 per lato", l100.perSide.reduce(0, +) == 40)
check("100 kg è esatto", l100.isExact)
check("100 kg → 25+15", l100.perSide == [25, 15])
check("totale ricostruito", l100.achieved == 100)

let l60 = plateLoad(target: 60, bar: 20)
check("60 kg → 20 per lato", l60.perSide == [20])

let barOnly = plateLoad(target: 20, bar: 20)
check("solo bilanciere: nessun disco", barOnly.perSide.isEmpty)
check("solo bilanciere è esatto", barOnly.isExact)

let below = plateLoad(target: 15, bar: 20)
check("peso sotto il bilanciere → nessun disco", below.perSide.isEmpty)
check("peso sotto il bilanciere → differenza negativa", below.difference < 0)

// 47 kg non è raggiungibile: (47-20)/2 = 13.5 per lato; con i dischi standard
// si arriva a 12.5 e restano 2 kg totali.
let odd = plateLoad(target: 47, bar: 20)
check("peso non raggiungibile → resta sotto", odd.achieved < 47)
check("peso non raggiungibile → riporta quanto manca", odd.difference > 0)
check("peso non raggiungibile → non è esatto", !odd.isExact)
check("comunque il massimo possibile", odd.achieved == 45)

let heavy = plateLoad(target: 180, bar: 20)
check("180 kg → 3 dischi da 25 e uno da 5 per lato", heavy.perSide == [25, 25, 25, 5])
check("180 kg esatto", heavy.isExact)

let noBar = plateLoad(target: 30, bar: 0)
check("senza bilanciere → 15 per lato", noBar.perSide.reduce(0, +) == 15)

check("riepilogo aggrega i dischi uguali", plateSummary([25, 25, 5]) == "2×25 + 1×5")
check("riepilogo con mezzi kg", plateSummary([2.5]) == "1×2.5")
check("riepilogo vuoto", plateSummary([]) == "solo bilanciere")

// Nessun peso deve produrre un totale superiore al richiesto.
var overshoot = false
for t in stride(from: 20.0, through: 200.0, by: 0.5) {
    if plateLoad(target: t, bar: 20).achieved > t + 0.0001 { overshoot = true; break }
}
check("non supera mai il peso richiesto", !overshoot)

// ── 2. Incremento minimo ──────────────────────────────────────────────────────

print("\n2. Incremento del carico")

check("bilanciere leggero → 2.5 kg", weightStep(for: 30, isBarbell: true) == 2.5)
check("bilanciere pesante → 5 kg", weightStep(for: 80, isBarbell: true) == 5)
check("manubri leggeri → 1 kg", weightStep(for: 12, isBarbell: false) == 1)
check("manubri pesanti → 2 kg", weightStep(for: 30, isBarbell: false) == 2)

// ── 3. Progressione ───────────────────────────────────────────────────────────

print("\n3. Consiglio sul carico")

let t0 = Date(timeIntervalSince1970: 1_770_000_000)
func day(_ n: Double) -> Date { t0.addingTimeInterval(-n * 86_400) }

func session(_ daysAgo: Double, _ sets: [(Int, Double)], completed: Bool = true) -> ExerciseSessionRecord {
    ExerciseSessionRecord(date: day(daysAgo),
                          sets: sets.map { SetRecord(reps: $0.0, weight: $0.1, completed: completed) })
}

check("storico vuoto", progressionAdvice(history: []) == .notEnoughData)

// Tutte le serie in cima alla forbice → si sale di peso.
let maxedOut = [session(1, [(12, 60), (12, 60), (12, 60)])]
check("forbice chiusa → aumenta il peso",
      progressionAdvice(history: maxedOut) == .increaseWeight(to: 65, from: 60))

// Dentro la forbice ma non in cima → si aggiungono ripetizioni.
let midRange = [session(1, [(10, 60), (10, 60), (9, 60)])]
check("dentro la forbice → aggiungi ripetizioni",
      progressionAdvice(history: midRange) == .addReps(target: 10, current: 9))

// Sotto la forbice → si consolida.
let belowRange = [session(1, [(6, 80), (5, 80)])]
check("sotto la forbice → consolida",
      progressionAdvice(history: belowRange) == .hold(weight: 80))

// Le serie non completate non contano.
let partial = [session(1, [(12, 60), (12, 60)], completed: false)]
check("serie non completate ignorate", progressionAdvice(history: partial) == .notEnoughData)

// Volume in calo per tre sedute → scarico.
let declining = [
    session(1, [(6, 60), (6, 60)]),      // volume 720
    session(4, [(8, 60), (8, 60)]),      // volume 960
    session(7, [(10, 60), (10, 60)]),    // volume 1200
]
if case .deload = progressionAdvice(history: declining) {
    check("tre sedute in calo → scarico", true)
} else {
    check("tre sedute in calo → scarico", false)
}

// Un calo isolato non deve innescare lo scarico.
let blip = [
    session(1, [(9, 60), (9, 60)]),
    session(4, [(10, 60), (10, 60)]),
    session(7, [(8, 60), (8, 60)]),
]
if case .deload = progressionAdvice(history: blip) {
    check("calo isolato non innesca lo scarico", false)
} else {
    check("calo isolato non innesca lo scarico", true)
}

// L'ordine dello storico non conta: si usa sempre la seduta più recente.
let unordered = [session(9, [(6, 50)]), session(1, [(12, 70), (12, 70)])]
check("usa la seduta più recente a prescindere dall'ordine",
      progressionAdvice(history: unordered) == .increaseWeight(to: 75, from: 70))

// Forbice personalizzata.
check("forbice 5-8: a 8 si sale",
      progressionAdvice(history: [session(1, [(8, 100)])], repRange: 5...8)
        == .increaseWeight(to: 105, from: 100))

// Solo le serie al carico più alto guidano la decisione (riscaldamento escluso).
let withWarmup = [session(1, [(15, 40), (12, 80), (12, 80)])]
check("le serie di riscaldamento non abbassano il giudizio",
      progressionAdvice(history: withWarmup) == .increaseWeight(to: 85, from: 80))

check("formattazione peso intero", (65.0).clean == "65")
check("formattazione peso con mezzo kg", (62.5).clean == "62.5")

print("")
if failures == 0 { print("TUTTI I CONTROLLI SUPERATI") }
else { print("\(failures) CONTROLLI FALLITI"); exit(1) }
