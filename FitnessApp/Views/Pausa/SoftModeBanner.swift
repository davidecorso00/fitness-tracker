import SwiftUI

/// Riga che prende il posto delle calorie residue mentre la modalità morbida
/// è attiva. Dice cosa sta succedendo e come uscirne, senza drammi.
struct SoftModeBanner: View {
    @State private var attiva = SoftMode.attiva

    var body: some View {
        if attiva {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Pausa.seafoam)
                Text("I numeri sono nascosti. Oggi il diario è un diario.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.muted)
                Spacer(minLength: 4)
                Button("Rimetti") {
                    SoftMode.spegni()
                    attiva = false
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Pausa.seafoam)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Pausa.seafoam.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear { attiva = SoftMode.attiva }
        }
    }
}

/// Comando per accendere la modalità morbida a mano, dalle impostazioni.
struct SoftModeCard: View {
    @State private var attiva = SoftMode.attiva
    @State private var scegliDurata = false

    var body: some View {
        LimitGroup(title: "Nascondi i numeri") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mette in pausa calorie residue, budget e avvisi sul target. I dati restano, spariscono solo dalla vista.")
                    .font(.system(size: 12))
                    .foregroundColor(.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if attiva {
                    Button("Rimetti i numeri") {
                        SoftMode.spegni(); attiva = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Pausa.seafoam)
                } else {
                    Button("Nascondi i numeri") { scegliDurata = true }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Pausa.seafoam)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
        .confirmationDialog("Per quanto?", isPresented: $scegliDurata, titleVisibility: .visible) {
            ForEach(SoftMode.Durata.allCases) { d in
                Button(d.etichetta) { SoftMode.accendi(d); attiva = true }
            }
            Button("Annulla", role: .cancel) {}
        }
        .onAppear { attiva = SoftMode.attiva }
    }
}
