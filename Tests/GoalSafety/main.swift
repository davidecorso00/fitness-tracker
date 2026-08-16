import Foundation

// Verifica del controllo sul ritmo di dimagrimento.

var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}

print("\n1. Ritmi sostenibili e ritmi no")

// 90 → 85 kg in sei mesi: mezzo chilo ogni tre settimane circa. Tranquillo.
let lento = goalPace(pesoAttuale: 90, pesoObiettivo: 85, giorni: 180,
                     manutenzione: 2600, metabolismoBasale: 1900)
check("ritmo lento è sostenibile", lento?.giudizio == .sostenibile)
check("nessun avviso", lento?.giudizio.avviso == nil)
check("deficit modesto", (lento?.deficitRichiesto ?? 0) < 250)

// 90 → 85 kg in tre settimane: più di un chilo a settimana.
let veloce = goalPace(pesoAttuale: 90, pesoObiettivo: 85, giorni: 21,
                      manutenzione: 2600, metabolismoBasale: 1900)
check("ritmo veloce viene segnalato", veloce?.giudizio.richiedeAttenzione == true)
check("più di un chilo a settimana", (veloce?.kgSettimana ?? 0) > 1)

// 90 → 80 kg in un mese: si finirebbe sotto il metabolismo basale.
let estremo = goalPace(pesoAttuale: 90, pesoObiettivo: 80, giorni: 30,
                       manutenzione: 2600, metabolismoBasale: 1900)
check("sotto il metabolismo viene riconosciuto", estremo?.giudizio == .sottoMetabolismo)
check("calorie risultanti sotto il basale",
      (estremo?.kcalRisultanti ?? 9999) < 1900)

// 90 → 70 kg in dieci giorni: impossibile.
let assurdo = goalPace(pesoAttuale: 90, pesoObiettivo: 70, giorni: 10,
                       manutenzione: 2600, metabolismoBasale: 1900)
check("obiettivo impossibile riconosciuto", assurdo?.giudizio == .irraggiungibile)
check("calorie risultanti negative o nulle", (assurdo?.kcalRisultanti ?? 1) <= 0)

print("\n2. Casi limite")

check("obiettivo già raggiunto → niente da dire",
      goalPace(pesoAttuale: 85, pesoObiettivo: 85, giorni: 90,
               manutenzione: 2600, metabolismoBasale: 1900) == nil)
check("zero giorni → niente da dire",
      goalPace(pesoAttuale: 90, pesoObiettivo: 85, giorni: 0,
               manutenzione: 2600, metabolismoBasale: 1900) == nil)
check("peso mancante → niente da dire",
      goalPace(pesoAttuale: 0, pesoObiettivo: 85, giorni: 90,
               manutenzione: 2600, metabolismoBasale: 1900) == nil)
check("manutenzione sconosciuta → niente da dire",
      goalPace(pesoAttuale: 90, pesoObiettivo: 85, giorni: 90,
               manutenzione: 0, metabolismoBasale: 1900) == nil)

// Senza profilo il metabolismo basale è 0: il controllo sul basale si spegne,
// ma quello sul ritmo deve restare attivo.
let senzaProfilo = goalPace(pesoAttuale: 90, pesoObiettivo: 85, giorni: 21,
                            manutenzione: 2600, metabolismoBasale: 0)
check("senza profilo il ritmo viene comunque valutato",
      senzaProfilo?.giudizio == .ritmoRipido)

// Prendere peso non deve far scattare gli avvisi sul mangiare poco.
let ingrasso = goalPace(pesoAttuale: 70, pesoObiettivo: 75, giorni: 90,
                        manutenzione: 2400, metabolismoBasale: 1700)
check("obiettivo in aumento non è un allarme",
      ingrasso?.giudizio == .sostenibile)
check("deficit negativo, cioè surplus", (ingrasso?.deficitRichiesto ?? 0) < 0)

print("\n3. Testi")

check("il ritmo ripido ha un avviso", GoalPace.Giudizio.ritmoRipido.avviso != nil)
check("il sostenibile non ha avviso", GoalPace.Giudizio.sostenibile.avviso == nil)
check("l'avviso non usa linguaggio clinico",
      !(GoalPace.Giudizio.ritmoRipido.avviso ?? "").lowercased().contains("disturbo"))
check("l'avviso non dà ordini",
      !(GoalPace.Giudizio.sottoMetabolismo.avviso ?? "").lowercased().contains("devi"))

print("")
if failures == 0 { print("TUTTI I CONTROLLI SUPERATI") }
else { print("\(failures) CONTROLLI FALLITI"); exit(1) }
