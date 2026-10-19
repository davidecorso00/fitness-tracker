import Foundation
import CoreData
import SwiftData
import Combine

// Sincronizzazione con iCloud (SwiftData + CloudKit).
//
// I dati vanno nel database PRIVATO dell'utente, legato al suo Apple ID: ogni
// persona vede solo i propri, e ogni dispositivo con lo stesso Apple ID li
// ritrova. Chi installa l'app da un altro account parte da zero.
//
// Regole che tengono i dati al sicuro:
// - Lo store resta nello stesso file di prima (stesso URL): niente copie, niente
//   spostamenti. Prima della prima apertura con iCloud se ne fa una copia a parte.
// - Se l'apertura con iCloud fallisce, l'app si apre comunque sullo stesso store
//   senza iCloud, con il motivo mostrato nelle Impostazioni. Il vecchio meccanismo
//   di recupero scatta solo se anche quella apertura fallisce.
// - Su un dispositivo vuoto i dati iniziali (alimenti, esercizi, obiettivi) si
//   creano solo dopo che l'iCloud ha consegnato i propri, per non duplicarli.

@MainActor
final class CloudSync: ObservableObject {

    static let shared = CloudSync()

    nonisolated static let containerID = "iCloud.davideCorso.FitnessApp"
    nonisolated static let enabledKey = "iCloudSyncEnabled"
    private static let storeCopyDoneKey = "preCloudStoreCopyDone"

    /// Pubblicata a ogni importazione da iCloud andata a buon fine.
    static let importFinished = Notification.Name("cloudSyncImportFinished")

    enum Mode: Equatable { case off, active, failed(String) }

    @Published private(set) var mode: Mode = .off
    @Published private(set) var lastImport: Date?
    @Published private(set) var lastExport: Date?
    @Published private(set) var lastError: String?

    private var lastImportEnd: Date?
    private var settled = false
    private var observer: NSObjectProtocol?

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// L'account iCloud è connesso (indicazione, non garanzia che la sincronia funzioni).
    var accountAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    /// I dati iniziali si possono creare: iCloud spento o non riuscito, oppure
    /// l'attesa del primo scambio è finita.
    var seedingAllowed: Bool { mode != .active || settled }

    // MARK: - Apertura del database

    /// Apre il database con iCloud; se non riesce, senza. Lancia solo se anche
    /// l'apertura locale fallisce.
    func openContainer(schema: Schema) throws -> ModelContainer {
        let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if Self.isEnabled {
            Self.copyStoreOnce(at: local.url)
            do {
                let cloud = ModelConfiguration(schema: schema, url: local.url,
                                               cloudKitDatabase: .private(Self.containerID))
                let container = try ModelContainer(for: schema, configurations: cloud)
                mode = .active
                startObserving()
                return container
            } catch {
                mode = .failed(error.localizedDescription)
                print("⚠️ iCloud non attivo: \(error)")
            }
        }
        return try ModelContainer(for: schema, configurations: local)
    }

    /// Copia i file del database (senza spostarli) prima della prima apertura con
    /// iCloud, che modifica lo schema. Una volta sola.
    private static func copyStoreOnce(at storeURL: URL) {
        guard !UserDefaults.standard.bool(forKey: storeCopyDoneKey) else { return }
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        let base = storeURL.lastPathComponent
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let related = files.filter { $0.lastPathComponent.hasPrefix(base) }
        guard !related.isEmpty else {           // primo avvio: niente da copiare
            UserDefaults.standard.set(true, forKey: storeCopyDoneKey)
            return
        }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = dir.appendingPathComponent("PreCloud-\(stamp)", isDirectory: true)
        do {
            try fm.createDirectory(at: backup, withIntermediateDirectories: true)
            for file in related {
                try fm.copyItem(at: file, to: backup.appendingPathComponent(file.lastPathComponent))
            }
            UserDefaults.standard.set(true, forKey: storeCopyDoneKey)
            print("📦 Copia del database prima di iCloud: \(backup.path)")
        } catch {
            print("⚠️ Copia prima di iCloud non riuscita: \(error)")
        }
    }

    // MARK: - Eventi di sincronizzazione

    private func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let end = event.endDate else { return }
            let type = event.type
            let ok = event.succeeded
            let message = event.error?.localizedDescription
            MainActor.assumeIsolated { self?.handle(type: type, end: end, ok: ok, error: message) }
        }
    }

    private func handle(type: NSPersistentCloudKitContainer.EventType, end: Date, ok: Bool, error: String?) {
        if !ok {
            lastError = error ?? "Errore sconosciuto"
            return
        }
        lastError = nil
        switch type {
        case .import:
            lastImport = end
            lastImportEnd = end
            NotificationCenter.default.post(name: Self.importFinished, object: nil)
        case .export:
            lastExport = end
        default:
            break
        }
    }

    // MARK: - Primo avvio su un dispositivo vuoto

    /// Su un dispositivo che ha già dati non aspetta. Su uno vuoto aspetta che
    /// iCloud consegni i suoi (primo scambio concluso e poi 4 secondi senza novità),
    /// al massimo 15 secondi: offline o senza account l'app parte comunque.
    func waitUntilSettled(storeHadData: Bool) async {
        defer { settled = true }
        guard mode == .active, !storeHadData else { return }
        let started = Date()
        while Date().timeIntervalSince(started) < 15 {
            if let end = lastImportEnd, Date().timeIntervalSince(end) >= 4 { return }
            try? await Task.sleep(for: .milliseconds(400))
        }
    }
}

// MARK: - Copie doppie

/// Toglie le copie doppie che due dispositivi possono creare prima di
/// scambiarsi i dati. Prudente: agisce solo sui giorni (DayLog) e sulle
/// impostazioni uniche (obiettivi, profilo), e solo quando le copie sono
/// DIVERSE fra loro, così la scelta è uguale su ogni dispositivo. Copie
/// identiche restano: sono innocue e non si può sapere quale togliere.
@MainActor
enum CloudDedupe {

    static func run(context: ModelContext) {
        var changed = false
        changed = dayLogs(context) || changed
        changed = limits(context) || changed
        changed = profiles(context) || changed
        if changed { try? context.save() }
    }

    private static func dayLogs(_ context: ModelContext) -> Bool {
        guard let all = try? context.fetch(FetchDescriptor<DayLog>()) else { return false }
        var changed = false
        for (_, group) in Dictionary(grouping: all, by: \.dateKey) where group.count > 1 {
            guard let r = resolveDayLogs(group.map(fields)) else { continue }
            let keeper = group[r.keeper]
            keeper.weight = r.merged.weight
            keeper.steps = r.merged.steps
            keeper.gymColor = GymColor(rawValue: r.merged.gymColor) ?? .rest
            keeper.activeCaloriesBurned = r.merged.activeCalories
            keeper.basalCaloriesBurned = r.merged.basalCalories
            for (i, log) in group.enumerated() where i != r.keeper { context.delete(log) }
            changed = true
        }
        return changed
    }

    private static func fields(_ l: DayLog) -> DayLogFields {
        DayLogFields(weight: l.weight, steps: l.steps, gymColor: l.gymColor.rawValue,
                     activeCalories: l.activeCaloriesBurned, basalCalories: l.basalCaloriesBurned)
    }

    // Obiettivi: tiene la copia con più valori diversi da quelli di partenza.
    private static func limits(_ context: ModelContext) -> Bool {
        guard let all = try? context.fetch(FetchDescriptor<AppLimits>()), all.count > 1 else { return false }
        func signature(_ l: AppLimits) -> [String] {
            let numbers: [Double] = [
                l.kcalTarget, l.proteinTarget, l.carbsTarget, l.fatTarget, l.fiberTarget,
                l.sugarTarget, l.saturatedFatTarget, l.saltTarget, Double(l.stepsTarget),
                l.weightTarget, l.waterTarget, l.targetWeight, l.weeklyRunKmTarget,
                l.breakfastPct, l.lunchPct, l.dinnerPct, l.snackPct,
            ]
            var result = numbers.map { "\($0)" }
            result.append(l.targetDate.map { "\($0.timeIntervalSince1970)" } ?? "-")
            result.append(l.macroInputMode)
            result.append("\(l.mealBudgetsEnabled)")
            result.append("\(l.overBudgetWarningEnabled)")
            return result
        }
        let fresh = signature(AppLimits())
        return keepMostFilled(all, signature: signature, fresh: fresh,
                              // A parità vale la data di inizio più vecchia: è quella originale.
                              tieBreak: { String(format: "%012d", Int(4_102_444_800 - $0.startDate.timeIntervalSince1970)) },
                              context: context)
    }

    private static func profiles(_ context: ModelContext) -> Bool {
        guard let all = try? context.fetch(FetchDescriptor<UserProfile>()), all.count > 1 else { return false }
        func signature(_ p: UserProfile) -> [String] {
            [p.heightCm.map { "\($0)" } ?? "-", p.birthDate.map { "\($0.timeIntervalSince1970)" } ?? "-", p.sex.rawValue]
        }
        return keepMostFilled(all, signature: signature, fresh: signature(UserProfile()),
                              tieBreak: { _ in "" }, context: context)
    }

    /// Tiene l'elemento con più campi diversi dal valore di partenza (a parità,
    /// quello con la firma maggiore) ed elimina quelli con una firma diversa.
    /// Copie con la stessa firma della migliore restano, come le firme tutte uguali.
    private static func keepMostFilled<T: PersistentModel>(
        _ items: [T], signature: (T) -> [String], fresh: [String],
        tieBreak: (T) -> String, context: ModelContext
    ) -> Bool {
        let rows = items.map { item -> (item: T, score: Int, key: String) in
            let sig = signature(item)
            let score = zip(sig, fresh).filter { $0 != $1 }.count
            return (item, score, sig.joined(separator: "|") + "|" + tieBreak(item))
        }
        guard rows.contains(where: { $0.key != rows[0].key }),
              let best = rows.max(by: { l, r in l.score != r.score ? l.score < r.score : l.key < r.key })
        else { return false }
        for row in rows where row.key != best.key { context.delete(row.item) }
        return true
    }
}
