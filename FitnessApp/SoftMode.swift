import Foundation

// Modalità morbida: i numeri spariscono dal tracker per un po'.
//
// Si accende da sola per 24 ore dopo un marker, oppure a mano quando serve.
// Mentre è attiva: niente calorie residue, niente sforamenti, niente barre di
// budget, niente avvisi sul target. Il diario resta un diario.
//
// Non tocca i dati: nasconde solo. Quello che registri continua a essere
// registrato, e quando la spegni ritrovi tutto.

enum SoftMode {

    private static let key = "pausaSoftModeFino"

    enum Durata: String, CaseIterable, Identifiable {
        case stasera, ventiquattro, treGiorni

        var id: String { rawValue }

        var etichetta: String {
            switch self {
            case .stasera:      return "Fino a stasera"
            case .ventiquattro: return "24 ore"
            case .treGiorni:    return "Tre giorni"
            }
        }

        func scadenza(da adesso: Date = Date()) -> Date {
            let cal = Calendar.current
            switch self {
            case .stasera:
                let mezzanotte = cal.startOfDay(for: adesso).addingTimeInterval(86_400)
                return mezzanotte
            case .ventiquattro:
                return adesso.addingTimeInterval(86_400)
            case .treGiorni:
                return adesso.addingTimeInterval(3 * 86_400)
            }
        }
    }

    /// Fino a quando i numeri restano nascosti. nil = modalità spenta.
    static var scadenza: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: key)
            guard t > 0 else { return nil }
            let d = Date(timeIntervalSince1970: t)
            return d > Date() ? d : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static var attiva: Bool { scadenza != nil }

    static func accendi(_ durata: Durata) {
        scadenza = durata.scadenza()
    }

    /// Chiamata dopo un marker. Non allunga una modalità già più lunga.
    static func accendiDopoEpisodio() {
        let nuova = Durata.ventiquattro.scadenza()
        if let attuale = scadenza, attuale > nuova { return }
        scadenza = nuova
    }

    static func spegni() {
        scadenza = nil
    }
}
