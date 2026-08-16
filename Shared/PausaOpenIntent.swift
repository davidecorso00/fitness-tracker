import AppIntents
import Foundation

// Intent condiviso fra l'app e l'estensione widget.
//
// Serve al controllo del Centro di Controllo: un controllo gira nel processo
// dell'estensione, quindi l'intent dev'essere compilato in entrambi i target —
// per questo sta in Shared/ e non insieme agli altri intent dell'app.
//
// Il database non è raggiungibile da qui: l'intent lascia un segnale nel
// gruppo condiviso e apre l'app, che al risveglio lo raccoglie e apre lo spazio.

nonisolated enum PausaSignal {
    static let key = "apriPausaRichiesta"

    static func richiedi() {
        UserDefaults(suiteName: fitnessAppGroupID)?.set(true, forKey: key)
    }

    /// Consuma il segnale: restituisce true una volta sola.
    static func consuma() -> Bool {
        guard let ud = UserDefaults(suiteName: fitnessAppGroupID),
              ud.bool(forKey: key) else { return false }
        ud.removeObject(forKey: key)
        return true
    }
}

/// Apre l'app direttamente sullo spazio "Un attimo".
struct ApriPausaIntent: AppIntent {
    static var title: LocalizedStringResource = "Un attimo"
    static var description = IntentDescription("Apre lo spazio per fermarsi un momento.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        PausaSignal.richiedi()
        return .result()
    }
}
