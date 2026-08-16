import SwiftUI
import SwiftData

// Lo spazio "Un Attimo".
//
// Regole che valgono per ogni schermata qui dentro, e che non vanno allentate:
//   · nessuna cifra raggiungibile — niente kcal, niente secondi, niente "3 di 6"
//   · "Salta" sempre visibile, in alto a destra, mai ritardato
//   · le vie d'uscita hanno tutte lo stesso peso visivo, compreso "vado a mangiare"
//   · nessuna domanda valutativa in chiusura, nessun verdetto
//
// Si apre in fullScreenCover e mai dentro la navigazione del diario: il tracker
// non deve restare visibile nemmeno di sbieco.

struct PausaSpaceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var frasi: [PausaFrase]
    @Query private var attivita: [PausaAttivita]
    @Query private var piani: [PausaPiano]

    /// Dopo due "salta" in sessioni diverse la sessione parte direttamente
    /// dall'attività. Non viene mai commentato né chiesto perché.
    @AppStorage("pausaSaltiRespiro") private var saltiRespiro = 0

    private enum Tappa { case respiro, attivita, uscita }
    @State private var tappa: Tappa = .respiro
    @State private var mostraLibreria = false
    @State private var mostraDopo = false

    var body: some View {
        ZStack {
            Pausa.background

            VStack(spacing: 0) {
                header

                switch tappa {
                case .respiro:
                    BreathingScreen(
                        frase: fraseCasuale,
                        pianoPertinente: pianoPertinente,
                        onContinua: { tappa = .attivita },
                        onSalta: {
                            saltiRespiro += 1
                            tappa = .attivita
                        })

                case .attivita:
                    ActivityScreen(
                        attivita: attivita,
                        onFine: { tappa = .uscita })

                case .uscita:
                    ExitScreen(
                        frase: fraseCasuale,
                        onResta: { tappa = .attivita },
                        onMangia: { chiudi(andandoAMangiare: true) },
                        onChiudi: { chiudi(andandoAMangiare: false) })
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            PausaSeed.popolaSeServe(context: context)
            // Chi ha già saltato il respiro due volte parte dall'attività.
            if saltiRespiro >= 2 { tappa = .attivita }
        }
        .sheet(isPresented: $mostraLibreria) {
            PausaLibraryView()
        }
        .sheet(isPresented: $mostraDopo) {
            DopoEpisodioView()
        }
    }

    // MARK: - Testata

    private var header: some View {
        HStack {
            Menu {
                Button("Le mie frasi e attività") { mostraLibreria = true }
                Button("È già successo") { mostraDopo = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Pausa.inkFaint)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            PausaEyebrow(text: "Un attimo")

            Spacer()

            Button("Salta") { chiudi(andandoAMangiare: false) }
                .font(Pausa.mono(13))
                .foregroundStyle(Pausa.inkFaint)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Contenuti

    private var fraseCasuale: String {
        frasi.randomElement()?.testo ?? "Questo momento finisce."
    }

    /// Un piano scritto a mente fredda che vale per l'ora attuale.
    private var pianoPertinente: PausaPiano? {
        let ora = Calendar.current.component(.hour, from: Date())
        return piani.first { $0.pertinente(alle: ora) }
    }

    private func chiudi(andandoAMangiare: Bool) {
        dismiss()
        if andandoAMangiare {
            // Il diario si apre normalmente: nessun conteggio, nessuna domanda.
            NotificationCenter.default.post(name: .pausaVaiAMangiare, object: nil)
        }
    }
}

extension Notification.Name {
    static let pausaVaiAMangiare = Notification.Name("pausaVaiAMangiare")
}

// MARK: - Respiro

private struct BreathingScreen: View {
    let frase: String
    let pianoPertinente: PausaPiano?
    let onContinua: () -> Void
    let onSalta: () -> Void

    private let plan = BreathingPlan()
    @State private var inizio = Date()
    @State private var mostraFrase = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { tl in
            let elapsed = tl.date.timeIntervalSince(inizio)
            // Il respiro non finisce mai da solo: chi vuole resta oltre i sei
            // cicli, perché la dose utile sta sopra il minuto.
            let stato = plan.state(at: elapsed.truncatingRemainder(
                dividingBy: max(plan.totalDuration, 1)))

            VStack(spacing: 0) {
                Spacer()

                cerchio(stato: stato)

                Text(stato.phase?.label ?? "")
                    .font(Pausa.mono(14))
                    .kerning(1.4)
                    .foregroundStyle(Pausa.inkSoft)
                    .padding(.top, 26)

                Spacer()

                if let piano = pianoPertinente {
                    PausaCard(accent: Pausa.sand, highlighted: true) {
                        VStack(alignment: .leading, spacing: 6) {
                            PausaEyebrow(text: "L'avevi scritto tu, a mente fredda")
                            Text(piano.allora)
                                .font(Pausa.serif(17))
                                .foregroundStyle(Pausa.ink)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
                }

                if mostraFrase {
                    Text(frase)
                        .font(Pausa.serif(19))
                        .foregroundStyle(Pausa.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)
                        .padding(.bottom, 22)
                        .transition(.opacity)
                }

                PausaButton(title: "Passo a qualcos'altro", tint: Pausa.seafoam) {
                    onContinua()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

                Text("L'obiettivo non è far passare la voglia.\nÈ restare qui mentre c'è.")
                    .font(.system(size: 12))
                    .foregroundStyle(Pausa.inkFaint)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 22)
            }
        }
        .onAppear {
            inizio = Date()
            // La frase resta il tempo di leggerla, poi lascia spazio al respiro.
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                withAnimation(.easeOut(duration: 1.2)) { mostraFrase = false }
            }
        }
    }

    private func cerchio(stato: BreathingState) -> some View {
        // La scala interpola verso il bersaglio della fase: il cerchio respira
        // insieme a te, non a scatti.
        let target = stato.phase?.scale ?? 1
        return Circle()
            .fill(
                RadialGradient(colors: [Pausa.seafoam, Pausa.seafoam.opacity(0.55)],
                               center: .init(x: 0.35, y: 0.3),
                               startRadius: 4, endRadius: 130)
            )
            .frame(width: 130, height: 130)
            .scaleEffect(target)
            .shadow(color: Pausa.seafoam.opacity(0.35), radius: 50)
            .animation(.easeInOut(duration: stato.phase?.duration ?? 4), value: target)
    }
}

// MARK: - Uscita

private struct ExitScreen: View {
    let frase: String
    let onResta: () -> Void
    let onMangia: () -> Void
    let onChiudi: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("♥")
                .font(.system(size: 26))
                .foregroundStyle(Pausa.mauve)

            Text("Sei arrivato in fondo.\nEra tutto quello che serviva.")
                .font(Pausa.serif(22))
                .foregroundStyle(Pausa.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 16)

            Text(frase)
                .font(.system(size: 14))
                .foregroundStyle(Pausa.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .padding(.top, 18)

            Spacer()

            // Le tre uscite hanno lo stesso identico peso. "Vado a mangiare"
            // non è la sconfitta: se la sezione servisse solo a non mangiare
            // starebbe rinforzando la restrizione, che è ciò che alimenta le
            // abbuffate.
            VStack(spacing: 10) {
                PausaOutlineButton(title: "Resto ancora un po'", action: onResta)
                PausaOutlineButton(title: "Vado a mangiare qualcosa", action: onMangia)
                PausaOutlineButton(title: "Chiudo", action: onChiudi)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }
}
