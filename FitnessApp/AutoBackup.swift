import Foundation
import SwiftData

// Backup automatico, silenzioso, una volta al giorno.
//
// COSA PROTEGGE: una migrazione del database andata storta, un aggiornamento
// che rompe qualcosa, una cancellazione per sbaglio. In questi casi i file
// restano nel contenitore dell'app e si ripristinano dalle impostazioni.
//
// COSA NON PROTEGGE: telefono perso, rubato, rotto o app disinstallata. Quei
// file spariscono insieme all'app. Per quello serve un export manuale su
// iCloud Drive o su un altro dispositivo — ed è per questo che le impostazioni
// mostrano da quanto tempo non ne fai uno.
//
// Non usa CloudKit di proposito: SwiftData con CloudKit non supporta
// @Attribute(.unique), che qui sta su DayLog.dateKey. Toglierlo significherebbe
// gestire i duplicati a mano su tutto lo storico.

@MainActor
enum AutoBackup {

    private static let ultimoAutoKey = "autoBackupUltimo"
    private static let ultimoManualeKey = "autoBackupUltimoManuale"
    private static let abilitatoKey = "autoBackupAbilitato"

    /// Quante copie tenere. Le più vecchie vengono eliminate.
    private static let copieDaTenere = 7

    static var abilitato: Bool {
        get { UserDefaults.standard.object(forKey: abilitatoKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: abilitatoKey) }
    }

    static var ultimoAutomatico: Date? {
        get { data(forKey: ultimoAutoKey) }
        set { salva(newValue, forKey: ultimoAutoKey) }
    }

    /// Aggiornato quando l'utente esporta a mano. È l'unico backup che
    /// sopravvive alla perdita del telefono.
    static var ultimoManuale: Date? {
        get { data(forKey: ultimoManualeKey) }
        set { salva(newValue, forKey: ultimoManualeKey) }
    }

    /// Giorni dall'ultimo export manuale. nil se non ne è mai stato fatto uno.
    static var giorniDallUltimoManuale: Int? {
        guard let d = ultimoManuale else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }

    // MARK: - Cartella

    static var cartella: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("BackupAutomatici", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// I backup presenti, dal più recente.
    static var copie: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cartella, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .sorted { a, b in modificato(a) > modificato(b) }
    }

    // MARK: - Esecuzione

    /// Esegue il backup se non ne è stato fatto uno oggi. Da chiamare quando
    /// l'app va in background: non deve mai rallentare l'avvio.
    static func eseguiSeServe(context: ModelContext) {
        guard abilitato else { return }
        if let ultimo = ultimoAutomatico,
           Calendar.current.isDateInToday(ultimo) { return }
        esegui(context: context)
    }

    @discardableResult
    static func esegui(context: ModelContext) -> Bool {
        do {
            let data = try BackupManager.export(context: context)
            let nome = "auto-\(Date().dateKey).json"
            try data.write(to: cartella.appendingPathComponent(nome), options: .atomic)
            ultimoAutomatico = Date()
            pulisci()
            return true
        } catch {
            print("Backup automatico fallito: \(error)")
            return false
        }
    }

    /// Tiene solo le copie più recenti.
    private static func pulisci() {
        let tutte = copie
        guard tutte.count > copieDaTenere else { return }
        for url in tutte.dropFirst(copieDaTenere) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Utilità

    private static func modificato(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast
    }

    private static func data(forKey key: String) -> Date? {
        let t = UserDefaults.standard.double(forKey: key)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    private static func salva(_ date: Date?, forKey key: String) {
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
