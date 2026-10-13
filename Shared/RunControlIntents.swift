#if os(iOS)
import AppIntents
import Foundation

// Comandi della corsa o passeggiata in corso, dai pulsanti della Live Activity:
// schermata di blocco, Dynamic Island e Smart Stack dell'Apple Watch.
//
// I pulsanti stanno nell'estensione widget, ma una LiveActivityIntent viene
// eseguita nel processo dell'app: è l'app a impostare `RunControl.handler`
// (RootView), nell'estensione resta nil. Per questo il file sta in Shared/:
// l'intent dev'essere compilato in entrambi i target.

nonisolated enum RunControlAction: Sendable {
    case pause, resume, requestStop, cancelStop, save
}

nonisolated enum RunControl {
    @MainActor static var handler: (@MainActor (RunControlAction) async -> Void)?

    @MainActor static func dispatch(_ action: RunControlAction) async {
        await handler?(action)
    }
}

struct RunPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Metti in pausa"
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.pause)
        return .result()
    }
}

struct RunResumeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Riprendi"
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.resume)
        return .result()
    }
}

/// Primo tocco su "Termina": chiede conferma nella Live Activity stessa
/// (Salva / Continua), così un tocco per sbaglio non chiude l'allenamento.
struct RunRequestStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Termina"
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.requestStop)
        return .result()
    }
}

struct RunCancelStopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Continua"
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.cancelStop)
        return .result()
    }
}

struct RunSaveIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Salva"
    func perform() async throws -> some IntentResult {
        await RunControl.dispatch(.save)
        return .result()
    }
}
#endif
