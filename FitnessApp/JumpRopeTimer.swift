import Foundation
import Combine
import HealthKit
import UIKit
import AudioToolbox
import UserNotifications

// MARK: - Jump Rope Timer
//
// Timer a round per il salto con la corda: preparazione + N × (lavoro + recupero).
// Il tempo è ancorato a date reali (le pause lo congelano), lo schermo resta
// sveglio durante la sessione (il telefono sta per terra) e i cambi round sono
// pre-programmati come notifiche locali: se il telefono si blocca comunque,
// arrivano lo stesso — e con il telefono bloccato arrivano al polso.

@MainActor
final class JumpRopeTimer: NSObject, ObservableObject, Identifiable {

    enum Kind { case prep, work, rest }
    enum TimerState { case running, paused, finished }

    struct Phase {
        let kind: Kind
        let round: Int        // 1-based, 0 per la preparazione
        let duration: Double
    }

    let id = UUID()
    let startDate = Date()
    let plannedRounds: Int
    let workSeconds: Int
    let restSeconds: Int
    let phases: [Phase]

    @Published var state: TimerState = .running
    @Published var elapsed: Double = 0
    @Published var currentPhaseIndex: Int = 0
    @Published var kcal: Double = 0
    @Published var currentBPM: Double?

    private let weightKg: Double
    private let notifyRounds: Bool
    private var uiTimer: Timer?
    private var pausedTotal: Double = 0
    private var pauseStartedAt: Date?
    private var lastTick: Date = Date()
    private let healthKit = HealthKitManager.shared
    private var hrQuery: HKQuery?

    // MET stimati: ~11.8 saltando, ~2 nel recupero in piedi
    private let workMET = 11.8
    private let restMET = 2.0
    private static let prepSeconds = 5.0

    init(rounds: Int, workSeconds: Int, restSeconds: Int,
         weightKg: Double, notifyRounds: Bool) {
        self.plannedRounds = max(rounds, 1)
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.weightKg = weightKg > 0 ? weightKg : 70
        self.notifyRounds = notifyRounds

        var p: [Phase] = [Phase(kind: .prep, round: 0, duration: Self.prepSeconds)]
        for r in 1...max(rounds, 1) {
            p.append(Phase(kind: .work, round: r, duration: Double(workSeconds)))
            if r < rounds {
                p.append(Phase(kind: .rest, round: r, duration: Double(restSeconds)))
            }
        }
        self.phases = p
        super.init()
    }

    // ── Derivate ──────────────────────────────────────────────────────────

    var currentPhase: Phase? {
        currentPhaseIndex < phases.count ? phases[currentPhaseIndex] : nil
    }

    var phaseRemaining: Double {
        guard let phase = currentPhase else { return 0 }
        let phaseStart = phases.prefix(currentPhaseIndex).reduce(0) { $0 + $1.duration }
        return max(phase.duration - (elapsed - phaseStart), 0)
    }

    var phaseProgress: Double {
        guard let phase = currentPhase, phase.duration > 0 else { return 1 }
        return 1 - phaseRemaining / phase.duration
    }

    /// Round completati (per il salvataggio anche in caso di stop anticipato)
    var completedRounds: Int {
        guard let phase = currentPhase else { return plannedRounds }
        switch phase.kind {
        case .prep: return 0
        case .work: return phase.round - 1
        case .rest: return phase.round
        }
    }

    var totalSessionSeconds: Double {
        phases.reduce(0) { $0 + $1.duration }
    }

    // ── Ciclo di vita ─────────────────────────────────────────────────────

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true
        if notifyRounds {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            scheduleRoundNotifications()
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.healthKit.requestAuthorization()
            self.hrQuery = self.healthKit.startHeartRateStream { [weak self] bpm in
                self?.currentBPM = bpm
            }
        }
        lastTick = Date()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    func pause() {
        guard state == .running else { return }
        pauseStartedAt = Date()
        state = .paused
        cancelRoundNotifications()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func resume() {
        guard state == .paused else { return }
        if let p = pauseStartedAt { pausedTotal += Date().timeIntervalSince(p) }
        pauseStartedAt = nil
        lastTick = Date()
        state = .running
        if notifyRounds { scheduleRoundNotifications() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Ferma tutto (fine naturale o stop anticipato).
    func finish() {
        guard state != .finished else { return }
        if state == .paused, let p = pauseStartedAt {
            pausedTotal += Date().timeIntervalSince(p)
            pauseStartedAt = nil
        }
        state = .finished
        uiTimer?.invalidate()
        uiTimer = nil
        cancelRoundNotifications()
        healthKit.stopQuery(hrQuery)
        hrQuery = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // ── Tick ──────────────────────────────────────────────────────────────

    private func tick() {
        guard state == .running else { return }
        let now = Date()
        elapsed = now.timeIntervalSince(startDate) - pausedTotal

        // kcal incrementali in base alla fase corrente
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now
        if let phase = currentPhase, delta > 0, delta < 5 {
            let met = phase.kind == .work ? workMET : restMET
            kcal += met * weightKg * (delta / 3600)
        }

        // avanzamento fase
        var acc = 0.0
        var index = phases.count
        for (i, p) in phases.enumerated() {
            acc += p.duration
            if elapsed < acc { index = i; break }
        }
        if index != currentPhaseIndex {
            currentPhaseIndex = index
            phaseChanged()
        }
    }

    private func phaseChanged() {
        if let phase = currentPhase {
            UINotificationFeedbackGenerator().notificationOccurred(phase.kind == .work ? .success : .warning)
            AudioServicesPlaySystemSound(phase.kind == .work ? 1054 : 1057)
        } else {
            // Sessione completata
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1025)
            finish()
        }
    }

    // ── Notifiche pre-programmate per i cambi round ───────────────────────

    private func scheduleRoundNotifications() {
        let center = UNUserNotificationCenter.current()
        var acc = 0.0
        for (i, phase) in phases.enumerated() {
            acc += phase.duration
            let fireIn = acc - elapsed
            guard fireIn > 0.5 else { continue }
            let content = UNMutableNotificationContent()
            if i + 1 < phases.count {
                let next = phases[i + 1]
                if next.kind == .work {
                    content.title = "🔥 Round \(next.round)/\(plannedRounds) — VAI!"
                    content.body = "\(Int(next.duration))″ di lavoro"
                } else {
                    content.title = "💨 Recupero"
                    content.body = "\(Int(next.duration))″ di pausa · round \(next.round)/\(plannedRounds) fatto"
                }
            } else {
                content.title = "✅ Sessione completata"
                content.body = "\(plannedRounds) round — ottimo lavoro!"
            }
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            center.add(UNNotificationRequest(identifier: "rope-\(i)", content: content, trigger: trigger))
        }
    }

    private func cancelRoundNotifications() {
        let ids = phases.indices.map { "rope-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
