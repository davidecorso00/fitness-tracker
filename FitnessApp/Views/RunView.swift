import SwiftUI
import SwiftData
import MapKit
import Charts

// Accent della sezione corsa
private let runAccent = Color.gymCyan
private let runGradient = LinearGradient(colors: [.gymCyan, .gymBlue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)

// MARK: - Run View (tab root)

struct RunView: View {
    @Environment(\.modelContext) private var context
    @Binding var showSettings: Bool

    @Query(sort: \RunSession.date, order: .reverse) private var allRuns: [RunSession]
    @Query(sort: \DayLog.dateKey, order: .reverse) private var allLogs: [DayLog]
    @Query private var allLimits: [AppLimits]

    @State private var tracker: RunTracker?
    @State private var detailRun: RunSession?
    @State private var showJumpRope = false

    // Impostazioni corsa (persistono tra sessioni)
    @AppStorage("runModeIntervals") private var intervalsMode = false
    @AppStorage("runIntervalRounds") private var intervalRounds = 4
    @AppStorage("runIntervalWork") private var intervalWork = 4      // minuti
    @AppStorage("runIntervalRest") private var intervalRest = 3      // minuti
    @AppStorage("runNotifyKm") private var notifyKm = true
    @AppStorage("runNotifyMinutes") private var notifyMinutes = 0    // 0 = off

    private var lastKnownWeight: Double {
        allLogs.first { $0.weight != nil }?.weight ?? 70
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    PageHeader("Cardio", subtitle: "Corsa GPS e salto con la corda", showSettings: $showSettings)

                    VStack(spacing: 14) {
                        // Avvio corsa
                        Button { startRun() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 22, weight: .bold))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Inizia corsa")
                                        .font(.system(size: 17, weight: .bold))
                                    Text("GPS · percorso, passo e calorie in tempo reale")
                                        .font(.system(size: 11, weight: .medium))
                                        .opacity(0.8)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(18)
                            .background(runGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        // Zona salto con la corda
                        Button { showJumpRope = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "figure.jumprope")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.gymOrange)
                                    .frame(width: 42, height: 42)
                                    .background(Color.gymOrange.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Salto con la corda")
                                        .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                                    Text("Timer a round · Tabata, boxe e cicli liberi")
                                        .font(.system(size: 11)).foregroundColor(.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.muted)
                            }
                            .padding(14)
                            .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        // Impostazioni corsa: cicli e notifiche
                        runSetupCard

                        // Obiettivo settimanale
                        if let target = allLimits.first?.weeklyRunKmTarget, target > 0 {
                            WeeklyRunGoalCard(targetKm: target)
                        }

                        // Storico
                        if allRuns.isEmpty {
                            HTCard {
                                VStack(spacing: 10) {
                                    Image(systemName: "figure.run")
                                        .font(.system(size: 32)).foregroundColor(.muted)
                                    Text("Nessuna corsa registrata.\nPremi \"Inizia corsa\" e parti!")
                                        .font(.system(size: 13)).foregroundColor(.muted)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 20)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionLabel(text: "Storico corse")
                                    .padding(.top, 6)
                                ForEach(allRuns) { run in
                                    Button { detailRun = run } label: {
                                        RunRow(run: run)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 100)
                }
            }
        )
        .fullScreenCover(item: $tracker) { tracker in
            ActiveRunView(tracker: tracker) { save in
                endRun(save: save)
            }
        }
        .sheet(item: $detailRun) { run in
            RunDetailView(run: run, onDelete: { deleteRun(run) })
        }
        .sheet(isPresented: $showJumpRope) {
            JumpRopeView()
        }
    }

    // ── Impostazioni corsa ────────────────────────────────────────────────

    private var runSetupCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Modalità")
                Picker("Modalità", selection: $intervalsMode) {
                    Text("Libera").tag(false)
                    Text("Cicli").tag(true)
                }
                .pickerStyle(.segmented)

                if intervalsMode {
                    VStack(spacing: 8) {
                        setupStepper(label: "Ripetizioni", value: $intervalRounds, range: 1...12, unit: "×")
                        setupStepper(label: "Lavoro", value: $intervalWork, range: 1...30, unit: "min")
                        setupStepper(label: "Recupero", value: $intervalRest, range: 1...30, unit: "min")
                        Text("\(intervalRounds) × (\(intervalWork)' lavoro + \(intervalRest)' recupero) — es. norvegese 4×4")
                            .font(.system(size: 11)).foregroundColor(.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 2)
                }

                Rectangle().fill(Color.brd).frame(height: 0.5)

                SectionLabel(text: "Notifiche durante la corsa")
                Toggle(isOn: $notifyKm) {
                    Text("Ogni chilometro")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.txt)
                }
                .tint(runAccent)
                HStack {
                    Text("Ogni N minuti")
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.txt)
                    Spacer()
                    Picker("", selection: $notifyMinutes) {
                        Text("Off").tag(0)
                        Text("1").tag(1)
                        Text("5").tag(5)
                        Text("10").tag(10)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                Text("Con il telefono in tasca le notifiche arrivano sull'Apple Watch.")
                    .font(.system(size: 11)).foregroundColor(.muted)
            }
        }
    }

    private func setupStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium)).foregroundColor(.txt)
            Spacer()
            HStack(spacing: 14) {
                stepBtn(icon: "minus") {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                }
                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundColor(runAccent)
                    .frame(width: 64)
                stepBtn(icon: "plus") {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                }
            }
        }
    }

    private func stepBtn(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold)).foregroundColor(.txt)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func startRun() {
        let phases = intervalsMode
            ? RunPhase.plan(rounds: intervalRounds, workMinutes: intervalWork, restMinutes: intervalRest)
            : []
        let t = RunTracker(weightKg: lastKnownWeight, phases: phases,
                           notifyEveryKm: notifyKm, notifyEveryMinutes: notifyMinutes)
        t.start()
        tracker = t
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func endRun(save: Bool) {
        guard let t = tracker else { return }
        t.finish()
        let shouldSave = save && t.distanceMeters > 10
        tracker = nil   // dismissa il fullScreenCover
        guard shouldSave else { return }

        Task { @MainActor in
            let hr = await t.finalHeartRateStats()
            let run = RunSession(date: t.startDate,
                                 distanceMeters: t.distanceMeters,
                                 durationSeconds: t.elapsed,
                                 kcalBurned: t.kcal,
                                 splitSeconds: t.splitSeconds,
                                 route: t.route,
                                 avgHeartRate: hr.avg,
                                 maxHeartRate: hr.max,
                                 hrSeries: hr.series)
            context.insert(run)
            // La corsa entra nel sistema attività esistente: le kcal contano nei totali
            // giornalieri come ogni altro sport. `autoTracked` evita che vengano sommate
            // due volte quando Apple Health ha già registrato l'energia attiva.
            context.insert(SportEntry(dayKey: run.dayKey, sportName: SportType.running.rawValue,
                                      durationMinutes: max(1, Int(t.elapsed / 60)),
                                      kcalBurned: t.kcal.rounded(),
                                      autoTracked: true, sourceId: run.stableId))
            try? context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Apre il dettaglio dopo che il cover ha finito l'animazione di chiusura
            try? await Task.sleep(for: .seconds(0.6))
            detailRun = run
        }
    }

    private func deleteRun(_ run: RunSession) {
        deleteTwinSportEntry(sourceId: run.stableId, dayKey: run.dayKey,
                             sportName: SportType.running.rawValue,
                             kcal: run.kcalBurned, context: context)
        context.delete(run)
        try? context.save()
        detailRun = nil
    }
}

// MARK: - Weekly Goal Card

struct WeeklyRunGoalCard: View {
    let targetKm: Double

    /// Solo le corse della settimana corrente: la card è sempre a schermo nel Sommario,
    /// non ha senso farle caricare tutto lo storico a ogni refresh.
    @Query private var weekRuns: [RunSession]

    init(targetKm: Double) {
        self.targetKm = targetKm
        let start = currentWeekInterval()?.start ?? Calendar.current.startOfDay(for: Date())
        _weekRuns = Query(filter: #Predicate<RunSession> { $0.date >= start })
    }

    private var weekKm: Double {
        weekRuns.reduce(0) { $0 + $1.distanceKm }
    }

    var body: some View {
        let pct = min(weekKm / max(targetKm, 0.01), 1)
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Obiettivo settimanale")
                    Spacer()
                    Text(String(format: "%.1f / %.0f km", weekKm, targetKm))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(weekKm >= targetKm ? runAccent : .muted)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 12)
                        Capsule()
                            .fill(runGradient)
                            .frame(width: geo.size.width * pct, height: 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pct)
                    }
                }
                .frame(height: 12)
            }
        }
    }
}

// MARK: - Run Row

private struct RunRow: View {
    let run: RunSession

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE d MMM · HH:mm"; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 16, weight: .semibold)).foregroundColor(runAccent)
                .frame(width: 38, height: 38)
                .background(runAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.dateFmt.string(from: run.date).capitalized)
                    .font(.system(size: 12, weight: .medium)).foregroundColor(.muted)
                HStack(spacing: 8) {
                    Text(String(format: "%.2f km", run.distanceKm))
                        .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.txt)
                    Text(paceString(run.avgPaceSecPerKm) + " /km")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(runAccent)
                    Text(durationString(run.durationSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.muted)
        }
        .padding(14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - SportEntry gemella

/// Cancella la `SportEntry` creata insieme a una sessione di corsa o corda.
/// Le sessioni nuove hanno `sourceId`; per quelle salvate prima di questo campo si
/// ricade sull'abbinamento per giorno, nome e kcal, com'era prima.
@MainActor
func deleteTwinSportEntry(sourceId: String, dayKey: String, sportName: String,
                          kcal: Double, context: ModelContext) {
    if !sourceId.isEmpty {
        let byId = FetchDescriptor<SportEntry>(
            predicate: #Predicate<SportEntry> { $0.sourceId == sourceId }
        )
        if let twin = (try? context.fetch(byId))?.first {
            context.delete(twin)
            return
        }
    }
    let rounded = kcal.rounded()
    let legacy = FetchDescriptor<SportEntry>(
        predicate: #Predicate<SportEntry> { $0.dayKey == dayKey && $0.sportName == sportName }
    )
    if let twin = (try? context.fetch(legacy))?.first(where: {
        $0.sourceId.isEmpty && abs($0.kcalBurned - rounded) < 1
    }) {
        context.delete(twin)
    }
}

// MARK: - Route helpers

/// Spezza il percorso in segmenti (uno per ogni tratto tra pausa e ripresa)
func routeSegments(_ points: [RoutePoint]) -> [[CLLocationCoordinate2D]] {
    var segments: [[CLLocationCoordinate2D]] = []
    var current: [CLLocationCoordinate2D] = []
    var seg = points.first?.seg ?? 0
    for p in points {
        if p.seg != seg {
            if current.count > 1 { segments.append(current) }
            current = []; seg = p.seg
        }
        current.append(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
    }
    if current.count > 1 { segments.append(current) }
    return segments
}

func fittedRegion(for points: [RoutePoint]) -> MKCoordinateRegion? {
    guard let first = points.first else { return nil }
    var minLat = first.lat, maxLat = first.lat
    var minLon = first.lon, maxLon = first.lon
    for p in points {
        minLat = min(minLat, p.lat); maxLat = max(maxLat, p.lat)
        minLon = min(minLon, p.lon); maxLon = max(maxLon, p.lon)
    }
    return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                       longitude: (minLon + maxLon) / 2),
        span: MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.4, 0.004),
                               longitudeDelta: max((maxLon - minLon) * 1.4, 0.004))
    )
}

// MARK: - Active Run View

struct ActiveRunView: View {
    @ObservedObject var tracker: RunTracker
    let onEnd: (_ save: Bool) -> Void

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showEndDialog = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Mappa live ────────────────────────────────────────────────
            ZStack(alignment: .top) {
                Map(position: $camera) {
                    UserAnnotation()
                    ForEach(Array(routeSegments(tracker.route).enumerated()), id: \.offset) { _, coords in
                        MapPolyline(coordinates: coords)
                            .stroke(runAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 12)

                if tracker.permissionDenied {
                    statusPill(icon: "location.slash.fill",
                               text: "GPS non autorizzato — abilitalo in Impostazioni › Privacy",
                               color: .gymPink)
                } else if tracker.state == .waitingGPS {
                    statusPill(icon: "antenna.radiowaves.left.and.right",
                               text: "Ricerca segnale GPS…", color: .gymOrange)
                } else if tracker.state == .paused {
                    statusPill(icon: "pause.fill", text: "In pausa", color: .gymOrange)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 16)

            // ── Fase corrente (modalità cicli) ────────────────────────────
            if !tracker.phases.isEmpty {
                phaseBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            // ── Metriche live ─────────────────────────────────────────────
            VStack(spacing: 4) {
                Text(durationString(tracker.elapsed))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.txt)
                Text("TEMPO")
                    .font(.system(size: 11, weight: .bold)).kerning(1.2)
                    .foregroundColor(.muted)
            }

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "%.2f", tracker.distanceMeters / 1000))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(runAccent)
                Text("km")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(.muted)
            }
            .padding(.top, 10)

            HStack(spacing: 8) {
                liveStat(value: paceString(tracker.currentPaceSecPerKm), label: "Passo", color: .ringGreen)
                liveStat(value: paceString(tracker.avgPaceSecPerKm), label: "Medio", color: runAccent)
                liveStat(value: tracker.currentBPM.map { "\(Int($0))" } ?? "—", label: "Bpm", color: .gymPink)
                liveStat(value: "\(Int(tracker.kcal))", label: "Kcal", color: .ringRed)
            }
            .padding(.horizontal, 16).padding(.top, 18)

            Spacer(minLength: 16)

            // ── Controlli ─────────────────────────────────────────────────
            HStack(spacing: 12) {
                if tracker.state == .paused {
                    controlButton(icon: "play.fill", label: "Riprendi", bg: Color.gymGreen, fg: .black) {
                        tracker.resume()
                    }
                } else {
                    controlButton(icon: "pause.fill", label: "Pausa", bg: Color.gymOrange, fg: .black) {
                        tracker.pause()
                    }
                }
                controlButton(icon: "stop.fill", label: "Termina", bg: Color.gymPink, fg: .white) {
                    showEndDialog = true
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 30)
        }
        .background(Color.bg.ignoresSafeArea())
        .confirmationDialog("Terminare la corsa?", isPresented: $showEndDialog, titleVisibility: .visible) {
            Button("Salva corsa") { onEnd(true) }
            Button("Scarta corsa", role: .destructive) { onEnd(false) }
            Button("Continua a correre", role: .cancel) {}
        }
    }

    @ViewBuilder private var phaseBanner: some View {
        if let phase = tracker.currentPhase, let remaining = tracker.phaseRemaining {
            let color: Color = phase.isWork ? .gymOrange : .gymGreen
            HStack(spacing: 12) {
                Image(systemName: phase.isWork ? "flame.fill" : "wind")
                    .font(.system(size: 16, weight: .bold)).foregroundColor(color)
                Text(phase.name)
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                Spacer()
                Text(durationString(remaining))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundColor(color)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.4), lineWidth: 1))
        } else {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.gymGreen)
                Text("Cicli completati — corsa libera")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.gymGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func statusPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.card.opacity(0.92), in: Capsule())
        .padding(.top, 14)
    }

    private func liveStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold)).kerning(0.6)
                .foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func controlButton(icon: String, label: String, bg: Color, fg: Color,
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

// MARK: - Run Detail View

struct RunDetailView: View {
    let run: RunSession
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showDeleteConfirm = false

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM yyyy · HH:mm"; return f
    }()

    var body: some View {
        let points = run.routePoints
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Mappa percorso completo
                        if let region = fittedRegion(for: points) {
                            Map(initialPosition: .region(region)) {
                                ForEach(Array(routeSegments(points).enumerated()), id: \.offset) { _, coords in
                                    MapPolyline(coordinates: coords)
                                        .stroke(runAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                                }
                                if let start = points.first {
                                    Marker("Partenza", systemImage: "flag.fill",
                                           coordinate: CLLocationCoordinate2D(latitude: start.lat, longitude: start.lon))
                                        .tint(Color.gymGreen)
                                }
                                if let end = points.last {
                                    Marker("Arrivo", systemImage: "flag.checkered",
                                           coordinate: CLLocationCoordinate2D(latitude: end.lat, longitude: end.lon))
                                        .tint(Color.gymPink)
                                }
                            }
                            .mapStyle(.standard(elevation: .flat))
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }

                        Text(Self.dateFmt.string(from: run.date).capitalized)
                            .font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Statistiche sessione
                        HTCard {
                            VStack(spacing: 14) {
                                HStack(spacing: 10) {
                                    detailStat(value: String(format: "%.2f", run.distanceKm), unit: "km",
                                               label: "Distanza", color: runAccent)
                                    detailStat(value: durationString(run.durationSeconds), unit: "",
                                               label: "Durata", color: .txt)
                                }
                                HStack(spacing: 10) {
                                    detailStat(value: paceString(run.avgPaceSecPerKm), unit: "/km",
                                               label: "Passo medio", color: .ringGreen)
                                    detailStat(value: "\(Int(run.kcalBurned))", unit: "kcal",
                                               label: "Calorie", color: .ringRed)
                                }
                                if run.avgHeartRate > 0 {
                                    HStack(spacing: 10) {
                                        detailStat(value: "\(Int(run.avgHeartRate))", unit: "bpm",
                                                   label: "FC media", color: .gymPink)
                                        detailStat(value: "\(Int(run.maxHeartRate))", unit: "bpm",
                                                   label: "FC max", color: .ringRed)
                                    }
                                }
                            }
                        }

                        // Curva battito cardiaco
                        heartRateChart

                        // Splits per km
                        if !run.splitSeconds.isEmpty {
                            HTCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionLabel(text: "Tempi per chilometro")
                                    let fastest = run.splitSeconds.min() ?? 1
                                    ForEach(Array(run.splitSeconds.enumerated()), id: \.offset) { i, split in
                                        HStack(spacing: 10) {
                                            Text("Km \(i + 1)")
                                                .font(.system(size: 12, weight: .semibold)).foregroundColor(.muted)
                                                .frame(width: 44, alignment: .leading)
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule().fill(Color.white.opacity(0.07)).frame(height: 14)
                                                    Capsule()
                                                        .fill(split == fastest ? Color.gymGreen : runAccent.opacity(0.75))
                                                        .frame(width: geo.size.width * (split > 0 ? fastest / split : 0), height: 14)
                                                }
                                            }
                                            .frame(height: 14)
                                            Text(paceString(split))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundColor(split == fastest ? .gymGreen : .txt)
                                                .frame(width: 56, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20).padding(.bottom, 30)
                }
            )
            .navigationTitle("Dettaglio corsa").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash").foregroundColor(.gymPink)
                    }
                }
            }
            .confirmationDialog("Eliminare questa corsa?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) { onDelete() }
                Button("Annulla", role: .cancel) {}
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { refetchHeartRateIfMissing() }
    }

    // ── Battito cardiaco ──────────────────────────────────────────────────

    @ViewBuilder private var heartRateChart: some View {
        let hr = run.hrPoints
        if !hr.isEmpty {
            HTCard {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Battito cardiaco")
                    Chart(Array(hr.enumerated()), id: \.offset) { _, point in
                        LineMark(x: .value("min", point.t / 60), y: .value("bpm", point.bpm))
                            .foregroundStyle(Color.gymPink)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        AreaMark(x: .value("min", point.t / 60), y: .value("bpm", point.bpm))
                            .foregroundStyle(Color.gymPink.opacity(0.12).gradient)
                            .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { v in
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text("\(Int(d))′").font(.system(size: 9)).foregroundStyle(Color.muted)
                                }
                            }
                            AxisGridLine().foregroundStyle(Color.brd)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text("\(Int(d))").font(.system(size: 9)).foregroundStyle(Color.muted)
                                }
                            }
                            AxisGridLine().foregroundStyle(Color.brd)
                        }
                    }
                    .frame(height: 140)
                }
            }
        }
    }

    /// I campioni del Watch possono sincronizzarsi sul telefono minuti dopo la
    /// corsa: se al salvataggio non c'era nulla, riprova quando si apre il dettaglio.
    private func refetchHeartRateIfMissing() {
        guard run.avgHeartRate == 0 else { return }
        Task { @MainActor in
            // durationSeconds esclude le pause: piccolo buffer per coprirle
            let end = run.date.addingTimeInterval(run.durationSeconds + 300)
            let hr = await HealthKitManager.shared.fetchHeartRateStats(from: run.date, to: end)
            guard hr.avg > 0 else { return }
            run.avgHeartRate = hr.avg
            run.maxHeartRate = hr.max
            run.heartRateData = (try? JSONEncoder().encode(hr.series)) ?? Data()
            try? context.save()
        }
    }

    private func detailStat(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit).font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                }
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold)).kerning(0.6)
                .foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
