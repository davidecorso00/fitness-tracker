#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import SwiftData

/// Riceve i pulsanti della Live Activity di corsa e passeggiata
/// (Shared/RunControlIntents.swift). Si installa all'avvio dell'app, non in una
/// vista: quando l'intent sveglia l'app in background le viste possono non comparire.
@MainActor
enum RunControlHandler {
    static func install(context: ModelContext) {
        endLeftoverActivities()
        RunControl.handler = { action, activityID in
            // Solo la card della sessione in corso comanda qualcosa. Una card
            // rimasta da un processo chiuso (crash, app chiusa durante la corsa)
            // non ha più una sessione dietro: si toglie invece di non rispondere.
            guard let t = RunTracker.current, t.liveActivityID == activityID else {
                await endActivity(id: activityID)
                return
            }
            switch action {
            case .pause:       t.pause()
            case .resume:      t.resume()
            case .requestStop: t.requestStop()
            case .cancelStop:  t.cancelStop()
            case .save:        await CardioRecorder.finish(t, save: true, context: context)
            }
        }
    }

    /// All'avvio non c'è nessuna sessione in corso: ogni Live Activity di corsa
    /// ancora a schermo è rimasta da un processo precedente.
    private static func endLeftoverActivities() {
        let leftovers = Activity<RunActivityAttributes>.activities
        guard !leftovers.isEmpty else { return }
        Task {
            for activity in leftovers { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func endActivity(id: String) async {
        for activity in Activity<RunActivityAttributes>.activities where activity.id == id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
