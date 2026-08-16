import Foundation
import UserNotifications

// Promemoria dei pasti.
//
// Sono l'unico tipo di notifica ammesso da questa parte dell'app: strutturali,
// sempre agli stessi orari, uguali ogni giorno. Non reagiscono mai a quello che
// hai mangiato o non hai mangiato.
//
// Il motivo è che una notifica reattiva — "non hai registrato la cena",
// "sembra un momento difficile" — trasforma l'app in qualcosa che ti guarda, e
// la domanda stessa può innescare il comportamento. Un orario invece è solo un
// orario: mangiare a intervalli regolari è la cosa che più riduce le abbuffate.
//
// Il testo è volutamente piatto: "Spuntino delle 16." Nessuna domanda, nessun
// incoraggiamento, nessun punto esclamativo.

enum MealReminders {

    private static let prefix = "pasto-"

    struct Slot: Identifiable, Equatable {
        let id: String
        let nome: String
        var ora: Int
        var minuto: Int
        var attivo: Bool

        var etichetta: String {
            String(format: "%@ delle %d:%02d", nome, ora, minuto)
        }
    }

    /// Tre pasti più tre spuntini, con intervalli sotto le quattro ore.
    /// Sono modificabili: questi sono solo il punto di partenza.
    static let predefiniti: [Slot] = [
        Slot(id: "colazione", nome: "Colazione",  ora: 8,  minuto: 0,  attivo: true),
        Slot(id: "spuntino1", nome: "Spuntino",   ora: 11, minuto: 0,  attivo: true),
        Slot(id: "pranzo",    nome: "Pranzo",     ora: 13, minuto: 0,  attivo: true),
        Slot(id: "spuntino2", nome: "Spuntino",   ora: 16, minuto: 30, attivo: true),
        Slot(id: "cena",      nome: "Cena",       ora: 20, minuto: 0,  attivo: true),
        Slot(id: "spuntino3", nome: "Spuntino",   ora: 22, minuto: 30, attivo: false),
    ]

    // MARK: - Persistenza

    private static let key = "mealRemindersSlots"
    private static let enabledKey = "mealRemindersEnabled"

    static var attivi: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            newValue ? riprogramma() : cancellaTutti()
        }
    }

    static var slot: [Slot] {
        get {
            guard let raw = UserDefaults.standard.array(forKey: key) as? [[String: Any]],
                  !raw.isEmpty else { return predefiniti }
            return raw.compactMap { d in
                guard let id = d["id"] as? String,
                      let nome = d["nome"] as? String,
                      let ora = d["ora"] as? Int,
                      let minuto = d["minuto"] as? Int,
                      let attivo = d["attivo"] as? Bool else { return nil }
                return Slot(id: id, nome: nome, ora: ora, minuto: minuto, attivo: attivo)
            }
        }
        set {
            let raw = newValue.map {
                ["id": $0.id, "nome": $0.nome, "ora": $0.ora,
                 "minuto": $0.minuto, "attivo": $0.attivo] as [String: Any]
            }
            UserDefaults.standard.set(raw, forKey: key)
            if attivi { riprogramma() }
        }
    }

    // MARK: - Programmazione

    static func chiediPermesso() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func riprogramma() {
        cancellaTutti()
        guard attivi else { return }
        let center = UNUserNotificationCenter.current()

        for s in slot where s.attivo {
            let content = UNMutableNotificationContent()
            // Solo il fatto, senza domande: la formulazione interrogativa
            // ("hai mangiato?") è quella che l'app non deve mai usare.
            content.title = String(format: "%@ delle %d:%02d.", s.nome, s.ora, s.minuto)
            content.sound = .default

            var comps = DateComponents()
            comps.hour = s.ora
            comps.minute = s.minuto

            center.add(UNNotificationRequest(
                identifier: prefix + s.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
        }
    }

    static func cancellaTutti() {
        let ids = predefiniti.map { prefix + $0.id } + slot.map { prefix + $0.id }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: Array(Set(ids)))
    }
}
