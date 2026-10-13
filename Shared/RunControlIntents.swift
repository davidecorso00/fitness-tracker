#if os(iOS)
import AppIntents
import Foundation

// Comandi della corsa o passeggiata in corso, dai pulsanti della Live Activity:
// schermata di blocco, Dynamic Island e Smart Stack dell'Apple Watch.
//
// I pulsanti stanno nell'estensione widget, ma una LiveActivityIntent viene
// eseguita nel processo dell'app: è l'app a impostare `RunControl.handler`
// (RunControlHandler, all'avvio), nell'estensione resta nil. Per questo il file sta in Shared/:
// l'intent dev'essere compilato in entrambi i target.
// Non compaiono in Comandi Rapidi e Spotlight (isDiscoverable = false): servono
// l'id della card, che si conosce solo dalla Live Activity.

nonisolated enum RunControlAction: Sendable {
    case pause, resume, requestStop, cancelStop, save
}

nonisolated enum RunControl {
    /// Azione e id della Live Activity su cui è stato toccato il pulsante.
    @MainActor static var handler: (@MainActor (RunControlAction, String) async -> Void)?

    @MainActor static func dispatch(_ action: RunControlAction, activityID: String) async {
        await handler?(action, activityID)
    }
}

struct RunPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Metti in pausa"
    static var isDiscoverable: Bool { false }
    @Parameter(title: "Live Activity") var activityID: String
    init() {}
    init(activityID: String) { self.activityID = activityID }
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.pause, activityID: activityID)
        return .result()
    }
}

struct RunResumeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Riprendi"
    static var isDiscoverable: Bool { false }
    @Parameter(title: "Live Activity") var activityID: String
    init() {}
    init(activityID: String) { self.activityID = activityID }
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.resume, activityID: activityID)
        return .result()
    }
}

/// Primo tocco su "Termina": chiede conferma nella Live Activity stessa
/// (Salva / Continua), così un tocco per sbaglio non chiude l'allenamento.
struct RunRequestStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Termina"
    static var isDiscoverable: Bool { false }
    @Parameter(title: "Live Activity") var activityID: String
    init() {}
    init(activityID: String) { self.activityID = activityID }
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.requestStop, activityID: activityID)
        return .result()
    }
}

struct RunCancelStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Continua"
    static var isDiscoverable: Bool { false }
    @Parameter(title: "Live Activity") var activityID: String
    init() {}
    init(activityID: String) { self.activityID = activityID }
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.cancelStop, activityID: activityID)
        return .result()
    }
}

struct RunSaveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Salva"
    static var isDiscoverable: Bool { false }
    @Parameter(title: "Live Activity") var activityID: String
    init() {}
    init(activityID: String) { self.activityID = activityID }
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.save, activityID: activityID)
        return .result()
    }
}
#endif
