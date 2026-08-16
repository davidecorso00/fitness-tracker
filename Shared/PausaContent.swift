import Foundation

// Contenuti verbali dello spazio: calcoli a mente e curiosità.
//
// Sono di seconda scelta rispetto ai compiti visuospaziali, ma servono a chi
// preferisce le parole. Nessuno dei due è a tempo e nessuno ha un punteggio:
// un compito valutabile, in un momento già storto, aggiunge solo altro peso.

// MARK: - Calcoli

struct MentalMath: Equatable {
    let testo: String
    let risultato: Int

    static func random() -> MentalMath {
        switch Int.random(in: 0..<4) {
        case 0:
            let a = Int.random(in: 10...99), b = Int.random(in: 10...99)
            return MentalMath(testo: "\(a) + \(b)", risultato: a + b)
        case 1:
            let a = Int.random(in: 20...99), b = Int.random(in: 1..<a)
            return MentalMath(testo: "\(a) − \(b)", risultato: a - b)
        case 2:
            let a = Int.random(in: 3...18), b = Int.random(in: 3...18)
            return MentalMath(testo: "\(a) × \(b)", risultato: a * b)
        default:
            let a = Int.random(in: 11...30)
            return MentalMath(testo: "\(a)²", risultato: a * a)
        }
    }
}

// MARK: - Curiosità

struct Curiosita: Equatable {
    let tag: String
    let testo: String

    static let tutte: [Curiosita] = [
        .init(tag: "Geografia", testo: "Il Lago di Lugano sta a cavallo fra Svizzera e Italia, e il confine lo attraversa in mezzo all'acqua."),
        .init(tag: "Geografia", testo: "La Russia attraversa undici fusi orari, più di qualsiasi altro paese."),
        .init(tag: "Storia", testo: "La Confederazione Svizzera nasce nel 1291 con il patto fra tre cantoni."),
        .init(tag: "Geografia", testo: "Il Nilo e il Rio delle Amazzoni si contendono da decenni il titolo di fiume più lungo del mondo."),
        .init(tag: "Storia", testo: "La Biblioteca di Alessandria era uno dei più grandi centri di sapere del mondo antico."),
        .init(tag: "Geografia", testo: "Il Ticino è l'unico cantone svizzero in cui l'italiano è l'unica lingua ufficiale."),
        .init(tag: "Storia", testo: "La Via della Seta collegava Cina ed Europa già più di duemila anni fa."),
        .init(tag: "Geografia", testo: "La Groenlandia è geograficamente parte del Nord America, ma politicamente legata alla Danimarca."),
        .init(tag: "Storia", testo: "L'Impero Romano, al suo apice, si estendeva su tre continenti."),
        .init(tag: "Geografia", testo: "Il Vaticano è lo stato indipendente più piccolo del mondo: meno di mezzo chilometro quadrato."),
        .init(tag: "Storia", testo: "Venezia fu per secoli una repubblica marinara indipendente."),
        .init(tag: "Geografia", testo: "Il Monte Bianco è la vetta più alta delle Alpi ed è diviso fra Italia e Francia."),
        .init(tag: "Storia", testo: "La caduta del Muro di Berlino, nel 1989, segnò simbolicamente la fine della Guerra Fredda."),
        .init(tag: "Geografia", testo: "L'Islanda si trova esattamente sul confine fra la placca euroasiatica e quella nordamericana."),
        .init(tag: "Storia", testo: "Leonardo da Vinci lavorò per anni in Francia, alla corte di Francesco I."),
        .init(tag: "Geografia", testo: "Il punto più profondo dell'oceano, la Fossa delle Marianne, è più profondo di quanto l'Everest sia alto."),
        .init(tag: "Storia", testo: "Il primo orologio meccanico pubblico in Europa comparve nel Trecento, sulle torri delle città."),
        .init(tag: "Geografia", testo: "Il Reno nasce nei Grigioni, in Svizzera, e sfocia nel Mare del Nord."),
    ]

    static func random() -> Curiosita {
        tutte.randomElement() ?? tutte[0]
    }
}
