import SwiftUI
import SwiftData

// Le attività dello spazio, ordinate per efficacia documentata:
//   1. segui la forma col dito  — visuospaziale, blocca l'immagine mentale
//   2. guarda una foto          — visuospaziale ma passiva, quindi con consegna
//   3. fai qualcos'altro        — la lista personale
//   4. calcoli e curiosità      — verbali, seconda scelta
//
// Nessuna è a tempo, nessuna ha una risposta giusta, tutte hanno "Non ora".

struct ActivityScreen: View {
    let attivita: [PausaAttivita]
    let onFine: () -> Void

    private enum Scelta: String, CaseIterable, Identifiable {
        case forma, foto, fare, mente
        var id: String { rawValue }
        var titolo: String {
            switch self {
            case .forma: return "Segui la forma"
            case .foto:  return "Guarda una foto"
            case .fare:  return "Fai qualcos'altro"
            case .mente: return "Occupa la testa"
            }
        }
        var icona: String {
            switch self {
            case .forma: return "scribble.variable"
            case .foto:  return "photo.on.rectangle.angled"
            case .fare:  return "figure.walk.motion"
            case .mente: return "brain"
            }
        }
    }

    @State private var scelta: Scelta?

    var body: some View {
        Group {
            if let scelta {
                contenuto(scelta)
            } else {
                menu
            }
        }
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Facciamo questa.\nNon serve che ti piaccia.")
                .font(Pausa.serif(21))
                .foregroundStyle(Pausa.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 26)

            VStack(spacing: 10) {
                ForEach(Scelta.allCases) { s in
                    Button { scelta = s } label: {
                        HStack(spacing: 14) {
                            Image(systemName: s.icona)
                                .font(.system(size: 17))
                                .foregroundStyle(Pausa.lilla)
                                .frame(width: 26)
                            Text(s.titolo)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Pausa.ink)
                            Spacer()
                        }
                        .padding(.vertical, 16).padding(.horizontal, 18)
                        .background(Pausa.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Pausa.cardLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)

            Spacer()

            PausaOutlineButton(title: "Ho finito", action: onFine)
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func contenuto(_ s: Scelta) -> some View {
        VStack(spacing: 0) {
            switch s {
            case .forma: TraceActivity()
            case .foto:  PhotoActivity()
            case .fare:  DoSomethingActivity(attivita: attivita)
            case .mente: MindActivity()
            }

            HStack(spacing: 10) {
                PausaOutlineButton(title: "Non ora") { scelta = nil }
                PausaOutlineButton(title: "Ho finito", action: onFine)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Segui la forma

private struct TraceActivity: View {
    @State private var indice = 0
    @State private var progresso = 0
    @State private var completata = false

    private var forma: TraceShape { TraceShape.shape(index: indice) }

    var body: some View {
        VStack(spacing: 0) {
            Text("Segui la linea col dito.\nSenza fretta, non c'è un tempo.")
                .font(Pausa.serif(18))
                .foregroundStyle(Pausa.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 10)

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let origin = CGPoint(x: (geo.size.width - side) / 2,
                                     y: (geo.size.height - side) / 2)

                ZStack {
                    // Traccia da seguire
                    path(in: side, origin: origin, upTo: forma.points.count - 1)
                        .stroke(Pausa.cardLine, style: .init(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    // Parte già percorsa
                    path(in: side, origin: origin, upTo: progresso)
                        .stroke(Pausa.lilla, style: .init(lineWidth: 10, lineCap: .round, lineJoin: .round))
                    // Il punto dove mettere il dito adesso
                    if !completata, progresso < forma.points.count {
                        let p = forma.points[progresso]
                        Circle()
                            .fill(Pausa.sand)
                            .frame(width: 22, height: 22)
                            .position(x: origin.x + p.x * side, y: origin.y + p.y * side)
                            .shadow(color: Pausa.sand.opacity(0.6), radius: 12)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !completata else { return }
                            let unit = CGPoint(x: (value.location.x - origin.x) / side,
                                               y: (value.location.y - origin.y) / side)
                            progresso = forma.advance(from: progresso, finger: unit)
                            if forma.isComplete(progresso) {
                                completata = true
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            if completata {
                Button {
                    indice += 1
                    progresso = 0
                    completata = false
                } label: {
                    Text("Un'altra")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Pausa.lilla)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 14)
            }
        }
    }

    private func path(in side: CGFloat, origin: CGPoint, upTo end: Int) -> Path {
        Path { p in
            let pts = forma.points
            guard end > 0, !pts.isEmpty else { return }
            let limit = min(end, pts.count - 1)
            p.move(to: CGPoint(x: origin.x + pts[0].x * side, y: origin.y + pts[0].y * side))
            for i in 1...max(limit, 1) {
                p.addLine(to: CGPoint(x: origin.x + pts[i].x * side, y: origin.y + pts[i].y * side))
            }
        }
    }
}

// MARK: - Foto

private struct PhotoActivity: View {
    @Environment(\.modelContext) private var context
    @Query private var foto: [PausaFoto]
    @State private var indice = 0

    var body: some View {
        VStack(spacing: 16) {
            if foto.isEmpty {
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 34))
                    .foregroundStyle(Pausa.inkFaint)
                Text("Non ci sono ancora foto.\nPuoi aggiungerle a mente fredda,\ndal menu in alto a sinistra.")
                    .font(.system(size: 14))
                    .foregroundStyle(Pausa.inkFaint)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                Text("Guarda questa foto.\nTrova tre cose che non avevi notato.")
                    .font(Pausa.serif(18))
                    .foregroundStyle(Pausa.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 10)

                if let img = UIImage(data: foto[indice %% foto.count].dati) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 24)
                }

                Button {
                    indice += 1
                } label: {
                    Text("Un'altra")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Pausa.lilla)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }
}

// MARK: - Fai qualcos'altro

private struct DoSomethingActivity: View {
    @Environment(\.modelContext) private var context
    let attivita: [PausaAttivita]

    @State private var scelta: PausaAttivita?
    @State private var giaValutata = false

    /// Nella fascia serale vengono prima quelle che portano fuori casa.
    private var candidate: [PausaAttivita] {
        let ora = Calendar.current.component(.hour, from: Date())
        let sera = ora >= 19 || ora < 2
        return attivita.sorted { a, b in
            if sera, a.cambiaAmbiente != b.cambiaAmbiente { return a.cambiaAmbiente }
            return a.utilita > b.utilita
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            if let scelta {
                PausaCard(accent: Pausa.sand, highlighted: true) {
                    Text(scelta.testo)
                        .font(Pausa.serif(21))
                        .foregroundStyle(Pausa.ink)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 24)

                if !giaValutata {
                    HStack(spacing: 10) {
                        Text("Ti è servita?")
                            .font(.system(size: 13))
                            .foregroundStyle(Pausa.inkFaint)
                        ForEach(["Sì", "No", "Non lo so"], id: \.self) { r in
                            Button(r) { valuta(r, scelta) }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Pausa.sand)
                        }
                    }
                }

                Button { estrai() } label: {
                    Text("Un'altra")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Pausa.sand)
                }
                .buttonStyle(.plain)
            } else {
                Text("Ti propongo una cosa a caso\ndalla tua lista.")
                    .font(Pausa.serif(19))
                    .foregroundStyle(Pausa.ink)
                    .multilineTextAlignment(.center)
                PausaButton(title: "Scegli per me", tint: Pausa.sand,
                            foreground: Color(hex: "2B1E10")) { estrai() }
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private func estrai() {
        // Pesca fra le prime della lista ordinata, non fra tutte: le cose che
        // hanno funzionato in passato hanno più probabilità di ricapitare.
        let pool = Array(candidate.prefix(max(4, candidate.count / 2)))
        scelta = pool.randomElement() ?? candidate.first
        giaValutata = false
    }

    /// Il micro-feedback serve solo a riordinare la lista. Non viene mai
    /// mostrato, né come conteggio né come statistica.
    private func valuta(_ risposta: String, _ item: PausaAttivita) {
        switch risposta {
        case "Sì": item.utilita += 1
        case "No": item.utilita -= 1
        default:   break
        }
        try? context.save()
        giaValutata = true
    }
}

// MARK: - Occupa la testa

private struct MindActivity: View {
    @State private var modo = 0
    @State private var calcolo = MentalMath.random()
    @State private var mostraRisposta = false
    @State private var curiosita = Curiosita.random()

    var body: some View {
        VStack(spacing: 18) {
            Picker("", selection: $modo) {
                Text("Calcolo").tag(0)
                Text("Curiosità").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 10)

            Text("Non c'è un tempo e non c'è una risposta giusta.")
                .font(.system(size: 12))
                .foregroundStyle(Pausa.inkFaint)

            Spacer()

            if modo == 0 {
                PausaCard(accent: Pausa.lilla) {
                    VStack(spacing: 14) {
                        Text(calcolo.testo)
                            .font(Pausa.mono(30))
                            .foregroundStyle(Pausa.ink)
                        Text(mostraRisposta ? "= \(calcolo.risultato)" : " ")
                            .font(Pausa.mono(20))
                            .foregroundStyle(Pausa.lilla)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .padding(.horizontal, 24)

                HStack(spacing: 10) {
                    Button("Mostra risposta") { mostraRisposta = true }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Pausa.inkSoft)
                    Button("Un altro") {
                        calcolo = MentalMath.random(); mostraRisposta = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Pausa.lilla)
                }
            } else {
                PausaCard(accent: Pausa.lilla) {
                    VStack(alignment: .leading, spacing: 10) {
                        PausaEyebrow(text: curiosita.tag)
                        Text(curiosita.testo)
                            .font(.system(size: 16))
                            .foregroundStyle(Pausa.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 24)

                Button("Un'altra") { curiosita = Curiosita.random() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Pausa.lilla)
            }

            Spacer()
        }
    }
}
