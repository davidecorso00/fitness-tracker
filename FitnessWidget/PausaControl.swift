import AppIntents
import SwiftUI
import WidgetKit

// Controllo per il Centro di Controllo.
//
// È il percorso più corto che iOS permetta per arrivare allo spazio "Un attimo":
// si trascina giù il Centro di Controllo e si tocca, senza aprire l'app, senza
// cercare una scheda. Si può anche assegnare al tasto Azione, e allora diventa
// una pressione sola dal telefono bloccato.
//
// Per una funzione che serve in un momento di spinta la differenza fra tre tap
// e uno non è cosmetica.
//
// Come aggiungerlo: Centro di Controllo → matita in alto a sinistra →
// "Aggiungi controllo" → cerca "Un attimo".
// Sul tasto Azione: Impostazioni → Tasto Azione → Controllo → "Un attimo".

@available(iOS 18.0, *)
struct PausaControl: ControlWidget {
    static let kind = "davideCorso.FitnessApp.PausaControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ApriPausaIntent()) {
                Label("Un attimo", systemImage: "wind")
            }
        }
        .displayName("Un attimo")
        .description("Apre lo spazio per fermarsi un momento.")
    }
}
