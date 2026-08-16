import SwiftUI
import SwiftData
import HealthKit

private let ropeAccent = Color.gymOrange
private let ropeGradient = LinearGradient(colors: [.gymOrange, .gymPink],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)

// MARK: - Preset

private struct RopePreset {
    let name: String
    let icon: String
    let rounds: Int
    let work: Int   // secondi
    let rest: Int

    static let all: [RopePreset] = [
        RopePreset(name: "Tabata",       icon: "bolt.fill",          rounds: 8, work: 20,  rest: 10),
        RopePreset(name: "Principiante", icon: "leaf.fill",          rounds: 6, work: 30,  rest: 30),
        RopePreset(name: "Boxe",         icon: "figure.boxing",      rounds: 5, work: 180, rest: 60),
        RopePreset(name: "Resistenza",   icon: "infinity",           rounds: 3, work: 300, rest: 90),
    ]
}

private func secString(_ s: Int) -> String {
    s < 60 ? "\(s)″" : (s % 60 == 0 ? "\(s / 60)′" : "\(s / 60)′\(String(format: "%02d", s % 60))″")
}

// MARK: - Jump Rope View (la zona corda)

struct JumpRopeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \JumpRopeSession.date, order: .reverse) private var allSessions: [JumpRopeSession]
    @Query(sort: \DayLog.dateKey, order: .reverse) private var allLogs: [DayLog]

    @AppStorage("ropeRounds") private var rounds = 6
    @AppStorage("ropeWork") private var work = 60
    @AppStorage("ropeRest") private var rest = 30
    @AppStorage("ropeNotify") private var notifyRounds = true

    @State private var timer: JumpRopeTimer?

    private var lastKnownWeight: Double {
        allLogs.first { $0.weight != nil }?.weight ?? 70
    }

    private var totalDuration: Int {
        rounds * work + max(rounds - 1, 0) * rest + 5
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Preset
                        HTCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(text: "Preset")
                                HStack(spacing: 8) {
                                    ForEach(RopePreset.all, id: \.name) { preset in
                                        presetChip(preset)
                                    }
                                }
                            }
                        }

                        // Configurazione
                        HTCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(text: "Round")
                                ropeStepper(label: "Ripetizioni", value: $rounds, range: 1...20, step: 1) { "\($0) ×" }
                                ropeStepper(label: "Lavoro", value: $work, range: 10...600, step: 10) { secString($0) }
                                ropeStepper(label: "Pausa", value: $rest, range: 0...300, step: 10) { secString($0) }

                                Rectangle().fill(Color.brd).frame(height: 0.5).padding(.vertical, 2)

                                HStack {
                                    Text("Durata totale")
                                        .font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                                    Spacer()
                                    Text(durationString(Double(totalDuration)))
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(ropeAccent)
                                }
                                Toggle(isOn: $notifyRounds) {
                                    Text("Notifiche al cambio round")
                                        .font(.system(size: 14, weight: .medium)).foregroundColor(.txt)
                                }
                                .tint(ropeAccent)
                                Text("Lo schermo resta acceso durante la sessione. Con il telefono bloccato, i round arrivano come notifica (anche sull'Apple Watch).")
                                    .font(.system(size: 11)).foregroundColor(.muted)
                            }
                        }

                        // Avvio
                        Button { startSession() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "figure.jumprope")
                                    .font(.system(size: 20, weight: .bold))
                                Text("Inizia sessione")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(ropeGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        // Record
                        if !allSessions.isEmpty {
                            recordCard
                        }

                        // Storico
                        if !allSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "Storico sessioni")
                                ForEach(allSessions.prefix(15)) { session in
                                    RopeSessionRow(session: session) { deleteSession(session) }
                                }
                            }
                        }
                    }
                    .padding(20).padding(.bottom, 30)
                }
            )
            .navigationTitle("Salto con la corda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationBackground(Color.bg)
        .fullScreenCover(item: $timer) { t in
            ActiveJumpRopeView(timer: t) { save, jumps in
                endSession(save: save, jumps: jumps)
            }
        }
    }

    // ── Componenti ────────────────────────────────────────────────────────

    private func presetChip(_ preset: RopePreset) -> some View {
        let isActive = rounds == preset.rounds && work == preset.work && rest == preset.rest
        return Button {
            rounds = preset.rounds; work = preset.work; rest = preset.rest
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: preset.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? ropeAccent : .muted)
                Text(preset.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isActive ? .txt : .muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text("\(preset.rounds)×\(secString(preset.work))")
                    .font(.system(size: 9))
                    .foregroundColor(.muted)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? ropeAccent.opacity(0.13) : Color.card2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? ropeAccent.opacity(0.45) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func ropeStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>,
                             step: Int, display: @escaping (Int) -> String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium)).foregroundColor(.txt)
            Spacer()
            HStack(spacing: 14) {
                ropeStepBtn(icon: "minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                Text(display(value.wrappedValue))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundColor(ropeAccent)
                    .frame(width: 64)
                ropeStepBtn(icon: "plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
            }
        }
    }

    private func ropeStepBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold)).foregroundColor(.txt)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var recordCard: some View {
        let totalJumps = allSessions.reduce(0) { $0 + $1.jumps }
        let bestJPM = allSessions.compactMap(\.jumpsPerMinute).max()
        return HTCard {
            HStack(spacing: 10) {
                ropeStat(value: "\(allSessions.count)", label: "Sessioni")
                ropeStat(value: totalJumps > 0 ? totalJumps.stepsFormatted : "—", label: "Salti totali")
                ropeStat(value: bestJPM.map { "\(Int($0))" } ?? "—", label: "Max salti/min")
            }
        }
    }

    private func ropeStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(ropeAccent)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold)).kerning(0.5)
                .foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // ── Sessione ──────────────────────────────────────────────────────────

    private func startSession() {
        let t = JumpRopeTimer(rounds: rounds, workSeconds: work, restSeconds: rest,
                              weightKg: lastKnownWeight, notifyRounds: notifyRounds)
        t.start()
        timer = t
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endSession(save: Bool, jumps: Int) {
        guard let t = timer else { return }
        t.finish()
        if save, t.completedRounds > 0 || t.elapsed > 30 {
            let session = JumpRopeSession(date: t.startDate,
                                          rounds: t.completedRounds,
                                          plannedRounds: t.plannedRounds,
                                          workSeconds: t.workSeconds,
                                          restSeconds: t.restSeconds,
                                          activeSeconds: t.elapsed,
                                          kcalBurned: t.kcal,
                                          jumps: jumps)
            context.insert(session)
            // Entra nei totali giornalieri come ogni altro sport. `autoTracked` evita il
            // doppio conteggio quando Apple Health fornisce già l'energia attiva.
            context.insert(SportEntry(dayKey: session.dayKey,
                                      sportName: SportType.jumpRope.rawValue,
                                      durationMinutes: max(1, Int(t.elapsed / 60)),
                                      kcalBurned: t.kcal.rounded(),
                                      autoTracked: true, sourceId: session.stableId))
            try? context.save()

            HealthExport.send(activity: .jumpRope,
                              start: session.date, durationSeconds: session.activeSeconds,
                              kcal: session.kcalBurned)

            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        timer = nil
    }

    private func deleteSession(_ session: JumpRopeSession) {
        deleteTwinSportEntry(sourceId: session.stableId, dayKey: session.dayKey,
                             sportName: SportType.jumpRope.rawValue,
                             kcal: session.kcalBurned, context: context)
        context.delete(session)
        try? context.save()
    }
}

// MARK: - Session Row

private struct RopeSessionRow: View {
    let session: JumpRopeSession
    let onDelete: () -> Void

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE d MMM · HH:mm"; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.jumprope")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(ropeAccent)
                .frame(width: 36, height: 36)
                .background(ropeAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFmt.string(from: session.date).capitalized)
                    .font(.system(size: 11, weight: .medium)).foregroundColor(.muted)
                HStack(spacing: 8) {
                    Text("\(session.rounds)×\(secString(session.workSeconds))")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.txt)
                    Text("\(Int(session.kcalBurned)) kcal")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.ringRed)
                    if let jpm = session.jumpsPerMinute {
                        Text("\(Int(jpm)) salti/min")
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(ropeAccent)
                    }
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.muted)
                    .frame(width: 24, height: 24)
                    .background(Color.card2, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Active Session View

struct ActiveJumpRopeView: View {
    @ObservedObject var timer: JumpRopeTimer
    let onEnd: (_ save: Bool, _ jumps: Int) -> Void

    @State private var showEndDialog = false
    @State private var jumpsInput = ""

    private var phaseColor: Color {
        guard let phase = timer.currentPhase else { return .acc }
        switch phase.kind {
        case .prep: return .gymBlue
        case .work: return .gymOrange
        case .rest: return .gymGreen
        }
    }

    private var phaseLabel: String {
        guard let phase = timer.currentPhase else { return "Completata!" }
        switch phase.kind {
        case .prep: return "Preparati…"
        case .work: return "Round \(phase.round)/\(timer.plannedRounds)"
        case .rest: return "Recupero"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if timer.state == .finished {
                summaryView
            } else {
                activeView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }

    // ── Sessione in corso ─────────────────────────────────────────────────

    private var activeView: some View {
        VStack(spacing: 0) {
            // Round indicator dots
            HStack(spacing: 6) {
                ForEach(1...timer.plannedRounds, id: \.self) { r in
                    Capsule()
                        .fill(r <= timer.completedRounds ? Color.gymOrange
                              : (timer.currentPhase?.kind == .work && timer.currentPhase?.round == r
                                 ? Color.gymOrange.opacity(0.5) : Color.white.opacity(0.10)))
                        .frame(height: 5)
                }
            }
            .padding(.horizontal, 28).padding(.top, 24)

            Spacer()

            // Anello fase
            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.15), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: timer.phaseProgress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: timer.phaseProgress)
                VStack(spacing: 6) {
                    Text(phaseLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(phaseColor)
                    Text(durationString(timer.phaseRemaining.rounded(.up)))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.txt)
                    Text("Totale \(durationString(timer.elapsed))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.muted)
                }
            }
            .frame(width: 280, height: 280)
            .padding(.vertical, 24)

            // Metriche
            HStack(spacing: 10) {
                ropeLiveStat(value: timer.currentBPM.map { "\(Int($0))" } ?? "—",
                             label: "Bpm", color: .gymPink)
                ropeLiveStat(value: "\(Int(timer.kcal))", label: "Kcal", color: .ringRed)
                ropeLiveStat(value: "\(timer.completedRounds)/\(timer.plannedRounds)",
                             label: "Round", color: .gymOrange)
            }
            .padding(.horizontal, 20)

            Spacer()

            // Controlli
            HStack(spacing: 12) {
                if timer.state == .paused {
                    ropeControlBtn(icon: "play.fill", label: "Riprendi", bg: .gymGreen, fg: .black) {
                        timer.resume()
                    }
                } else {
                    ropeControlBtn(icon: "pause.fill", label: "Pausa", bg: .gymOrange, fg: .black) {
                        timer.pause()
                    }
                }
                ropeControlBtn(icon: "stop.fill", label: "Termina", bg: .gymPink, fg: .white) {
                    showEndDialog = true
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .confirmationDialog("Terminare la sessione?", isPresented: $showEndDialog, titleVisibility: .visible) {
            Button("Termina e salva") { timer.finish() }
            Button("Scarta sessione", role: .destructive) { onEnd(false, 0) }
            Button("Continua", role: .cancel) {}
        }
    }

    // ── Riepilogo finale ──────────────────────────────────────────────────

    private var summaryView: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52)).foregroundColor(.gymGreen)
            Text("Sessione completata")
                .font(.system(size: 22, weight: .bold)).foregroundColor(.txt)

            HTCard {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        summaryStat(value: "\(timer.completedRounds)/\(timer.plannedRounds)", label: "Round")
                        summaryStat(value: durationString(timer.elapsed), label: "Durata")
                        summaryStat(value: "\(Int(timer.kcal))", label: "Kcal")
                    }
                    Rectangle().fill(Color.brd).frame(height: 0.5)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quanti salti hai fatto? (opzionale)")
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                        TextField("0", text: $jumpsInput)
                            .keyboardType(.numberPad)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(ropeAccent).tint(ropeAccent)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if let jumps = Int(jumpsInput), jumps > 0, timer.completedRounds > 0 {
                            let jpm = Double(jumps) / (Double(timer.completedRounds * timer.workSeconds) / 60)
                            Text("≈ \(Int(jpm)) salti al minuto")
                                .font(.system(size: 12, weight: .semibold)).foregroundColor(ropeAccent)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            PillButton(label: "Salva sessione", color: .gymOrange, textColor: .black) {
                onEnd(true, Int(jumpsInput) ?? 0)
            }
            .padding(.horizontal, 20)

            Button("Scarta") { onEnd(false, 0) }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.muted)

            Spacer()
        }
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit().foregroundColor(.txt)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold)).kerning(0.5)
                .foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func ropeLiveStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit().foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold)).kerning(0.6)
                .foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func ropeControlBtn(icon: String, label: String, bg: Color, fg: Color,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                Text(label).font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(fg)
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
