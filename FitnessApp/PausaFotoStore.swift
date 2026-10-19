import UIKit
import Foundation

/// Foto di "Un attimo": file in una cartella dell'app, NON nel database.
///
/// Il database si sincronizza con iCloud (CloudSync.swift), le foto no: restano
/// solo su questo dispositivo, come l'utente ha chiesto. Per questo non sono più
/// righe di `PausaFoto`; il modello resta solo per migrare le foto già salvate.
enum PausaFotoStore {

    struct Item: Identifiable, Equatable {
        let id: String
        let url: URL
        let date: Date
        var image: UIImage? { UIImage(contentsOfFile: url.path) }
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PausaFoto", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Dalla più vecchia alla più recente.
    static func list() -> [Item] {
        let keys: [URLResourceKey] = [.creationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys) else { return [] }
        return files.filter { $0.pathExtension == "jpg" }.map { url in
            let date = (try? url.resourceValues(forKeys: Set(keys)).creationDate) ?? .distantPast
            return Item(id: url.lastPathComponent, url: url, date: date)
        }.sorted { $0.date < $1.date }
    }

    /// Salva e controlla che il file scritto abbia la dimensione giusta.
    @discardableResult
    static func save(_ jpeg: Data, date: Date = Date()) -> Bool {
        let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try jpeg.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.creationDate: date], ofItemAtPath: url.path)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return (attributes[.size] as? Int) == jpeg.count
        } catch {
            return false
        }
    }

    static func delete(_ item: Item) {
        try? FileManager.default.removeItem(at: item.url)
    }

    static func deleteAll() {
        for item in list() { delete(item) }
    }
}
