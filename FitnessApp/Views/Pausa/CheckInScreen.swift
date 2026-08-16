import SwiftUI

// "Cosa c'è adesso?"
//
// Non è un questionario e non è HALT: l'acronimo non è validato, e molte volte
// non è né fame né rabbia né solitudine né stanchezza. Per questo ci sono
// sempre "niente di tutto questo" e "non lo so", con lo stesso peso delle altre.
//
// La risposta più importante è quella alla fame. Se hai fame la cosa giusta è
// mangiare, e l'app deve dirlo senza giri di parole: uno spazio che aiuta solo
// a *non* mangiare starebbe rinforzando la restrizione.

struct CheckInScreen: View {
    let onVaiAMangiare: () -> Void

    private enum Risposta: String, CaseIterable, Identifiable {
        case fame, nervoso, solo, stanco, niente, nonLoSo

        var id: String { rawValue }

        var etichetta: String {
            switch self {
            case .fame:    return "Fame"
            case .nervoso: return "Nervoso"
            case .solo:    return "Solo"
            case .stanco:  return "Stanco"
            case .niente:  return "Niente di tutto questo"
            case .nonLoSo: return "Non lo so"
            }
        }

        var risposta: String {
            switch self {
            case .fame:
                return "Allora è fame. Vai a mangiare, non serve altro."
            case .nervoso:
                return "Il nervoso non si mangia via, ma nemmeno si ragiona via. "
                     + "Se puoi, muovi il corpo: cambia stanza, esci, fai qualcosa con le mani."
            case .solo:
                return "La solitudine è la cosa più difficile da attraversare da soli. "
                     + "C'è qualcuno a cui potresti scrivere adesso, anche solo due righe?"
            case .stanco:
                return "Se sei stanco, abbassa le pretese della serata. "
                     + "Non è il momento di decidere niente."
            case .niente:
                return "Va bene così. Non tutto ha un motivo che si trova subito."
            case .nonLoSo:
                return "Va bene non saperlo. Non serve capirlo per lasciarlo passare."
            }
        }

        /// Solo la fame porta direttamente alla via d'uscita "vado a mangiare".
        var portaAMangiare: Bool { self == .fame }
    }

    @State private var scelta: Risposta?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let scelta {
                VStack(spacing: 20) {
                    Text(scelta.risposta)
                        .font(Pausa.serif(20))
                        .foregroundStyle(Pausa.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .fixedSize(horizontal: false, vertical: true)

                    if scelta.portaAMangiare {
                        PausaButton(title: "Vado a mangiare", tint: Pausa.seafoam,
                                    action: onVaiAMangiare)
                            .padding(.horizontal, 40)
                    }

                    Button("Torna indietro") { self.scelta = nil }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Pausa.inkFaint)
                }
            } else {
                Text("Cosa c'è adesso?")
                    .font(Pausa.serif(23))
                    .foregroundStyle(Pausa.ink)
                    .padding(.bottom, 6)

                Text("Se lo sai. Non serve saperlo.")
                    .font(.system(size: 13))
                    .foregroundStyle(Pausa.inkFaint)
                    .padding(.bottom, 24)

                // Tutte le risposte hanno lo stesso aspetto, comprese le due
                // vie d'uscita: nessuna è quella "giusta".
                VStack(spacing: 8) {
                    ForEach(Risposta.allCases) { r in
                        Button { scelta = r } label: {
                            Text(r.etichetta)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Pausa.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Pausa.card,
                                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Pausa.cardLine, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }

            Spacer()
        }
    }
}
