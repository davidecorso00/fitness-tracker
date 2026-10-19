import SwiftData
import Foundation

// Dati dello spazio "Un Attimo".
//
// Sono i contenuti più personali dell'app, e per questo stanno a parte dal resto:
//   · non finiscono nel backup JSON condivisibile (verificato da un test)
//   · non vengono scritti su HealthKit
//   · le foto restano solo sul dispositivo (file locali, mai nel database);
//     frasi, attività, piani e note con la sincronizzazione attiva viaggiano solo
//     nel TUO iCloud privato, legato al tuo Apple ID (Impostazioni › iCloud)
//   · si cancellano tutti insieme con un comando solo
//
// Quello che NON viene registrato è una scelta, non una dimenticanza: niente
// calorie dell'episodio, niente intensità dell'impulso da 1 a 10, niente conteggi
// mostrati. Quantificare un'abbuffata è impreciso, umiliante, e riporta dentro
// la testa da tracker che è esattamente il problema.

// MARK: - Frasi

/// Una frase che l'utente vorrebbe sentirsi dire. Scritta a mente fredda.
@Model final class PausaFrase {
    var testo: String = ""
    var creataIl: Date = Date()
    var ordine: Int = 0

    init(testo: String, ordine: Int = 0) {
        self.testo = testo
        self.ordine = ordine
        self.creataIl = Date()
    }
}

// MARK: - Attività

/// Qualcosa da fare al posto di. Deliberatamente a bassa energia.
@Model final class PausaAttivita {
    var testo: String = ""
    var creataIl: Date = Date()
    /// Quante volte l'utente ha detto che è servita, meno quante volte no.
    /// Serve solo a ordinare la lista internamente: non viene mai mostrato.
    var utilita: Int = 0
    /// Porta fuori casa o cambia ambiente: nella fascia serale vengono prima.
    var cambiaAmbiente: Bool = false

    init(testo: String, cambiaAmbiente: Bool = false) {
        self.testo = testo
        self.cambiaAmbiente = cambiaAmbiente
        self.creataIl = Date()
    }
}

// MARK: - Foto

/// Foto personali, non corporee: persone, luoghi, ricordi.
///
/// SOLO LEGACY: le foto ora sono file locali (PausaFotoStore) e non passano dal
/// database, che si sincronizza con iCloud. Il modello resta nello schema per
/// leggere le righe vecchie e spostarle (CloudSync.movePausaPhotosToFiles).
@Model final class PausaFoto {
    @Attribute(.externalStorage) var dati: Data = Data()
    var aggiuntaIl: Date = Date()

    init(dati: Data) {
        self.dati = dati
        self.aggiuntaIl = Date()
    }
}

// MARK: - Piani se-allora

/// Intenzione di attuazione: "se succede X, allora faccio Y", decisa a mente
/// fredda. È la forma con più supporto empirico per tradurre un proposito in
/// un'azione quando la capacità di decidere è al minimo.
@Model final class PausaPiano {
    var se: String = ""
    var allora: String = ""
    var attivo: Bool = true
    /// Ora di inizio e fine della fascia in cui il piano è pertinente.
    /// -1 = sempre.
    var daOra: Int = -1
    var aOra: Int = -1
    var creatoIl: Date = Date()

    init(se: String, allora: String, daOra: Int = -1, aOra: Int = -1) {
        self.se = se
        self.allora = allora
        self.daOra = daOra
        self.aOra = aOra
        self.creatoIl = Date()
    }

    /// Pertinente adesso? Se non ha una fascia, sempre.
    func pertinente(alle ora: Int) -> Bool {
        guard attivo else { return false }
        guard daOra >= 0, aOra >= 0 else { return true }
        return daOra <= aOra
            ? (ora >= daOra && ora < aOra)
            : (ora >= daOra || ora < aOra)   // fascia a cavallo della mezzanotte
    }
}

// MARK: - Marker

/// Segno che è successo. Solo data e, se l'utente vuole, una nota libera.
///
/// Nessun numero. La sua unica conseguenza automatica è accendere la modalità
/// morbida per 24 ore: nessuna statistica, nessun grafico, nessuna serie.
@Model final class PausaMarker {
    var quando: Date = Date()
    var nota: String = ""

    init(nota: String = "") {
        self.quando = Date()
        self.nota = nota
    }
}

// MARK: - Contenuti iniziali

enum PausaSeed {

    /// Volutamente scarne: le frasi degli altri funzionano poco, e l'onboarding
    /// chiede subito di scriverne di proprie.
    static let frasi = [
        "Questo momento finisce.",
        "Non è la prima volta e non è l'ultima.",
        "Non devi risolvere niente adesso.",
    ]

    static let attivita: [(String, Bool)] = [
        ("Esci e fai il giro dell'isolato", true),
        ("Fai una doccia calda, senza fretta", false),
        ("Scrivi o chiama qualcuno a cui vuoi bene", false),
        ("Metti una playlist e ascoltala tutta", false),
        ("Sistema un piccolo angolo della stanza", false),
        ("Scarabocchia qualcosa su un foglio", false),
        ("Vai a sederti in un'altra stanza", true),
        ("Scrivi cosa stai provando, senza rileggerlo", false),
    ]

    @MainActor
    static func popolaSeServe(context: ModelContext) {
        // Su un dispositivo nuovo con iCloud le frasi e le attività arrivano da lì.
        guard CloudSync.shared.seedingAllowed else { return }
        if (try? context.fetchCount(FetchDescriptor<PausaFrase>())) == 0 {
            for (i, t) in frasi.enumerated() {
                context.insert(PausaFrase(testo: t, ordine: i))
            }
        }
        if (try? context.fetchCount(FetchDescriptor<PausaAttivita>())) == 0 {
            for (testo, fuori) in attivita {
                context.insert(PausaAttivita(testo: testo, cambiaAmbiente: fuori))
            }
        }
        try? context.save()
    }

    /// Cancella tutto quello che c'è nello spazio. Immediato, senza recupero.
    @MainActor
    static func cancellaTutto(context: ModelContext) {
        try? context.delete(model: PausaFrase.self)
        try? context.delete(model: PausaAttivita.self)
        try? context.delete(model: PausaFoto.self)   // solo righe vecchie, se restano
        PausaFotoStore.deleteAll()
        try? context.delete(model: PausaPiano.self)
        try? context.delete(model: PausaMarker.self)
        try? context.save()
    }
}
