import Foundation
import Combine
import CoreLocation
import HealthKit
import UIKit
import UserNotifications
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

// MARK: - Fasi (cicli tipo 4x4 norvegese)

struct RunPhase {
    let name: String        // es. "Lavoro 2/4"
    let isWork: Bool
    let duration: Double    // secondi

    /// Costruisce il piano: rounds × (lavoro + recupero), senza recupero finale.
    static func plan(rounds: Int, workMinutes: Int, restMinutes: Int) -> [RunPhase] {
        var phases: [RunPhase] = []
        for r in 1...max(rounds, 1) {
            phases.append(RunPhase(name: "Lavoro \(r)/\(rounds)", isWork: true,
                                   duration: Double(workMinutes * 60)))
            if r < rounds {
                phases.append(RunPhase(name: "Recupero \(r)/\(rounds - 1)", isWork: false,
                                       duration: Double(restMinutes * 60)))
            }
        }
        return phases
    }
}

// MARK: - Run Tracker
//
// Traccia una corsa via GPS. Il cronometro è basato su date reali (non su un
// timer incrementale), quindi resta corretto anche con schermo bloccato o app
// in background. Il timer da 1s serve solo ad aggiornare la UI in foreground.
// Al termine della corsa il GPS viene spento completamente.

@MainActor
final class RunTracker: NSObject, ObservableObject, Identifiable {

    enum RunState { case waitingGPS, running, paused, finished }

    let id = UUID()

    @Published var state: RunState = .waitingGPS
    @Published var elapsed: Double = 0            // tempo attivo (pause escluse)
    @Published var distanceMeters: Double = 0
    @Published var currentPaceSecPerKm: Double?   // passo istantaneo smussato
    @Published var kcal: Double = 0
    @Published var route: [RoutePoint] = []
    @Published var splitSeconds: [Double] = []
    @Published var permissionDenied = false
    @Published var currentBPM: Double?    // ultimo campione dal Watch via HealthKit
    @Published var currentPhaseIndex: Int = 0

    let startDate = Date()
    let phases: [RunPhase]                // vuoto = corsa libera
    private let weightKg: Double
    private let notifyEveryKm: Bool
    private let notifyEveryMinutes: Int   // 0 = disattivato

    private let manager = CLLocationManager()
    private var uiTimer: Timer?
    private let healthKit = HealthKitManager.shared
    private var hrQuery: HKQuery?
    private var lastMinuteNotified = 0

    private var pausedTotal: Double = 0           // secondi totali in pausa
    private var pauseStartedAt: Date?
    private var lastLocation: CLLocation?
    private var currentSegment = 0
    private var lastSplitElapsed: Double = 0
    private var nextSplitMeters: Double = 1000

    // Filtri GPS
    private let maxHorizontalAccuracy: Double = 35   // metri
    private let maxPlausibleSpeed: Double = 12.5     // m/s (~2'40"/km, oltre è un glitch)

    var avgPaceSecPerKm: Double? {
        guard distanceMeters > 50, elapsed > 0 else { return nil }
        return elapsed / (distanceMeters / 1000)
    }

    // ── Fasi correnti ─────────────────────────────────────────────────────

    var currentPhase: RunPhase? {
        guard !phases.isEmpty, currentPhaseIndex < phases.count else { return nil }
        return phases[currentPhaseIndex]
    }

    /// Secondi mancanti alla fine della fase corrente (nil in corsa libera o a piano finito)
    var phaseRemaining: Double? {
        guard !phases.isEmpty, currentPhaseIndex < phases.count else { return nil }
        let phaseStart = phases.prefix(currentPhaseIndex).reduce(0) { $0 + $1.duration }
        return max(phases[currentPhaseIndex].duration - (elapsed - phaseStart), 0)
    }

    init(weightKg: Double, phases: [RunPhase] = [],
         notifyEveryKm: Bool = false, notifyEveryMinutes: Int = 0) {
        self.weightKg = weightKg > 0 ? weightKg : 70
        self.phases = phases
        self.notifyEveryKm = notifyEveryKm
        self.notifyEveryMinutes = notifyEveryMinutes
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        if !phases.isEmpty || notifyEveryKm || notifyEveryMinutes > 0 {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            permissionDenied = true
        default:
            beginUpdates()
        }
        startUITimer()
        startLiveActivity()
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.healthKit.requestAuthorization()
            self.hrQuery = self.healthKit.startHeartRateStream { [weak self] bpm in
                self?.currentBPM = bpm
            }
        }
    }

    /// Media/max/serie battiti dell'intera corsa (best effort: i campioni del
    /// Watch possono arrivare sul telefono con qualche minuto di ritardo).
    func finalHeartRateStats() async -> (avg: Double, max: Double, series: [HRPoint]) {
        await healthKit.fetchHeartRateStats(from: startDate, to: Date())
    }

    func pause() {
        guard state == .running || state == .waitingGPS else { return }
        refreshElapsed()
        pauseStartedAt = Date()
        state = .paused
        // Il GPS resta acceso per mantenere il fix, ma i punti vengono scartati
        // e alla ripresa il percorso riparte da un nuovo segmento.
        lastLocation = nil
        currentPaceSecPerKm = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pushLiveActivity(force: true)
    }

    func resume() {
        guard state == .paused else { return }
        if let p = pauseStartedAt { pausedTotal += Date().timeIntervalSince(p) }
        pauseStartedAt = nil
        currentSegment += 1
        state = .running
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pushLiveActivity(force: true)
    }

    /// Spegne tutto e congela i dati. Da chiamare una sola volta.
    func finish() {
        guard state != .finished else { return }
        if state == .paused, let p = pauseStartedAt {
            pausedTotal += Date().timeIntervalSince(p)
            pauseStartedAt = nil
        } else {
            refreshElapsed()
        }
        state = .finished
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        uiTimer?.invalidate()
        uiTimer = nil
        healthKit.stopQuery(hrQuery)
        hrQuery = nil
        endLiveActivity()
    }

    // ── Internals ─────────────────────────────────────────────────────────

    private func beginUpdates() {
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    private func startUITimer() {
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refreshElapsed() }
        }
    }

    private func refreshElapsed() {
        guard state == .running || state == .waitingGPS else { return }
        elapsed = Date().timeIntervalSince(startDate) - pausedTotal
        checkPhaseTransition()
        checkMinuteNotification()
    }

    // ── Fasi e notifiche periodiche ───────────────────────────────────────
    // Chiamati da refreshElapsed, che gira sia col timer (foreground) sia a
    // ogni callback GPS (background): funzionano anche a schermo bloccato.

    private func checkPhaseTransition() {
        guard !phases.isEmpty else { return }
        var acc = 0.0
        var index = phases.count   // oltre l'ultima fase = piano completato
        for (i, p) in phases.enumerated() {
            acc += p.duration
            if elapsed < acc { index = i; break }
        }
        guard index != currentPhaseIndex else { return }
        currentPhaseIndex = index
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        if index < phases.count {
            let p = phases[index]
            sendNotification(title: p.isWork ? "🔥 \(p.name)" : "💨 \(p.name)",
                             body: "\(durationString(p.duration)) · \(statsLine())")
        } else {
            sendNotification(title: "✅ Cicli completati",
                             body: "Continua pure a correre · \(statsLine())")
        }
        pushLiveActivity(force: true)
    }

    private func checkMinuteNotification() {
        guard notifyEveryMinutes > 0 else { return }
        let minute = Int(elapsed) / 60
        guard minute > lastMinuteNotified, minute % notifyEveryMinutes == 0 else { return }
        lastMinuteNotified = minute
        sendNotification(title: "⏱ \(minute) min", body: statsLine())
    }

    private func statsLine() -> String {
        var parts = [String(format: "%.2f km", distanceMeters / 1000),
                     durationString(elapsed),
                     paceString(avgPaceSecPerKm) + " /km"]
        if let bpm = currentBPM { parts.append("♥ \(Int(bpm))") }
        return parts.joined(separator: " · ")
    }

    /// Notifica locale immediata: con il telefono in tasca arriva al polso (Watch).
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    fileprivate func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionDenied = false
            if state == .waitingGPS || state == .running { beginUpdates() }
        case .denied, .restricted:
            permissionDenied = true
        default:
            break
        }
    }

    fileprivate func handleLocations(_ locations: [CLLocation]) {
        guard state != .finished else { return }
        for loc in locations {
            // Scarta fix imprecisi, vecchi o precedenti all'avvio
            guard loc.horizontalAccuracy > 0,
                  loc.horizontalAccuracy <= maxHorizontalAccuracy,
                  loc.timestamp >= startDate,
                  abs(loc.timestamp.timeIntervalSinceNow) < 10 else { continue }

            if state == .paused { continue }
            if state == .waitingGPS { state = .running }
            refreshElapsed()

            if let last = lastLocation {
                let delta = loc.distance(from: last)
                let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                // Scarta salti GPS implausibili
                guard dt > 0, delta / dt <= maxPlausibleSpeed else { continue }
                distanceMeters += delta
                kcal += 1.036 * weightKg * (delta / 1000)
                checkSplit()
            }
            lastLocation = loc
            route.append(RoutePoint(lat: loc.coordinate.latitude,
                                    lon: loc.coordinate.longitude,
                                    t: elapsed, seg: currentSegment))
            updateCurrentPace(with: loc)
        }
        pushLiveActivity()
    }

    private func updateCurrentPace(with loc: CLLocation) {
        guard loc.speed > 0.5 else { currentPaceSecPerKm = nil; return }
        let instant = 1000 / loc.speed
        if let prev = currentPaceSecPerKm {
            currentPaceSecPerKm = prev * 0.7 + instant * 0.3   // smussamento EMA
        } else {
            currentPaceSecPerKm = instant
        }
    }

    private func checkSplit() {
        while distanceMeters >= nextSplitMeters {
            splitSeconds.append(elapsed - lastSplitElapsed)
            lastSplitElapsed = elapsed
            nextSplitMeters += 1000
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if notifyEveryKm {
                let km = splitSeconds.count
                sendNotification(title: "📍 Km \(km)",
                                 body: "Ultimo km in \(paceString(splitSeconds.last)) · \(statsLine())")
            }
            pushLiveActivity(force: true)
        }
    }

    // ── Live Activity (schermata di blocco + Dynamic Island) ─────────────

    #if canImport(ActivityKit) && os(iOS)
    private var liveActivity: Activity<RunActivityAttributes>?
    private var lastActivityPush = Date.distantPast

    private var activityState: RunActivityAttributes.ContentState {
        RunActivityAttributes.ContentState(
            startedAt: Date().addingTimeInterval(-elapsed),
            isPaused: state == .paused,
            elapsedAtPause: elapsed,
            distanceMeters: distanceMeters,
            avgPaceSecPerKm: avgPaceSecPerKm,
            kcal: kcal,
            bpm: currentBPM,
            phaseName: currentPhaseIndex < phases.count ? phases[currentPhaseIndex].name : nil)
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: activityState, staleDate: nil)
        liveActivity = try? Activity.request(attributes: RunActivityAttributes(), content: content)
    }

    /// Il cronometro si aggiorna da solo via Text(timerInterval:); qui inviamo
    /// distanza/passo/kcal, con throttle per non aggiornare a raffica.
    private func pushLiveActivity(force: Bool = false) {
        guard let activity = liveActivity else { return }
        guard force || Date().timeIntervalSince(lastActivityPush) >= 15 else { return }
        lastActivityPush = Date()
        let content = ActivityContent(state: activityState, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        liveActivity = nil
        let content = ActivityContent(state: activityState, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .immediate) }
    }
    #else
    private func startLiveActivity() {}
    private func pushLiveActivity(force: Bool = false) {}
    private func endLiveActivity() {}
    #endif
}

// MARK: - CLLocationManagerDelegate

extension RunTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handleAuthorization(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handleLocations(locations) }
    }
}
