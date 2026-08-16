import Foundation

// Controllo sul ritmo richiesto da un obiettivo di peso.
//
// Un deficit troppo aggressivo è uno degli inneschi documentati delle abbuffate:
// si mangia troppo poco, e prima o poi il corpo presenta il conto. L'app conosce
// peso, obiettivo, data e metabolismo basale, quindi può accorgersene da sola.
//
// Il controllo scatta una volta sola, quando l'obiettivo viene impostato o
// modificato, e mai durante la giornata: un avviso che compare mentre mangi
// diventa un giudizio su quello che stai mangiando.

struct GoalPace: Equatable {
    /// Chili da perdere (positivo) o da prendere (negativo).
    var kgDaPerdere: Double
    var giorniDisponibili: Int
    /// Deficit giornaliero implicito, in kcal.
    var deficitRichiesto: Double
    /// Chili a settimana che l'obiettivo richiede.
    var kgSettimana: Double
    /// Calorie che resterebbero da mangiare ogni giorno.
    var kcalRisultanti: Double

    enum Giudizio: Equatable {
        case sostenibile
        /// Ritmo oltre l'1% del peso corporeo a settimana.
        case ritmoRipido
        /// Si finirebbe a mangiare sotto il metabolismo basale.
        case sottoMetabolismo
        /// Il traguardo non è raggiungibile entro la data, nemmeno digiunando.
        case irraggiungibile
    }

    var giudizio: Giudizio
}

/// Un chilo di grasso vale all'incirca 7700 kcal: è l'equivalenza usata in
/// tutta l'app per le stime.
private let kcalPerKg: Double = 7700

/// Valuta il ritmo richiesto. Restituisce nil se manca qualcosa per giudicare.
///
/// - `manutenzione`: le calorie che servono per mantenere il peso, cioè
///   metabolismo basale × fattore di attività.
/// - `metabolismoBasale`: la soglia sotto cui non ha senso scendere.
func goalPace(pesoAttuale: Double,
              pesoObiettivo: Double,
              giorni: Int,
              manutenzione: Double,
              metabolismoBasale: Double) -> GoalPace? {
    guard pesoAttuale > 0, pesoObiettivo > 0, giorni > 0, manutenzione > 0 else { return nil }

    let kg = pesoAttuale - pesoObiettivo
    guard abs(kg) > 0.1 else { return nil }

    let deficit = kg * kcalPerKg / Double(giorni)
    let kgSettimana = kg / Double(giorni) * 7
    let kcalRisultanti = manutenzione - deficit

    let giudizio: GoalPace.Giudizio
    if kcalRisultanti <= 0 {
        giudizio = .irraggiungibile
    } else if metabolismoBasale > 0, kcalRisultanti < metabolismoBasale {
        giudizio = .sottoMetabolismo
    } else if kgSettimana > pesoAttuale * 0.01 {
        // Oltre l'1% del peso corporeo a settimana è più di quanto si possa
        // perdere di grasso: la differenza esce da muscolo e acqua.
        giudizio = .ritmoRipido
    } else {
        giudizio = .sostenibile
    }

    return GoalPace(kgDaPerdere: kg,
                    giorniDisponibili: giorni,
                    deficitRichiesto: deficit,
                    kgSettimana: kgSettimana,
                    kcalRisultanti: kcalRisultanti,
                    giudizio: giudizio)
}

extension GoalPace.Giudizio {
    /// Testo dell'avviso. Constata e propone, non vieta: l'obiettivo resta
    /// quello che l'utente ha deciso.
    var avviso: String? {
        switch self {
        case .sostenibile:
            return nil
        case .ritmoRipido:
            return "Con questa data l'obiettivo chiede di perdere più di un chilo "
                 + "a settimana ogni settimana. È un ritmo che di solito porta a "
                 + "mangiare troppo poco, e mangiare troppo poco è una delle cose "
                 + "che fanno tornare le abbuffate."
        case .sottoMetabolismo:
            return "Con questa data resterebbero meno calorie di quante ne consumi "
                 + "da fermo. È un livello che non si regge a lungo, e di solito "
                 + "finisce con il mangiare molto più del previsto."
        case .irraggiungibile:
            return "Con questa data l'obiettivo non è raggiungibile nemmeno "
                 + "smettendo del tutto di mangiare."
        }
    }

    var richiedeAttenzione: Bool { avviso != nil }
}
