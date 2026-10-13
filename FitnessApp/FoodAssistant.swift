import Foundation
import Security
import SwiftData
import UIKit

// MARK: - Assistente AI per il diario
//
// Una chat che trasforma "ho mangiato una banana non troppo grande a pranzo"
// (o una foto) in una proposta di voce di diario. Il modello cerca prima nel
// database dell'utente: se un alimento o un piatto corrisponde, ne usa l'id e
// i valori li calcola l'app dai dati salvati; altrimenti stima lui i valori.
// La proposta non viene mai salvata da sola: Conferma apre l'inserimento al
// volo già compilato, e l'utente decide.
//
// Le richieste vanno all'API di Anthropic con la chiave dell'utente, tenuta nel
// portachiavi di questo iPhone.

// MARK: - Chiave API (portachiavi)

enum AIKeyStore {
    private static let service = "dcfitness.anthropic-api"
    private static let account = "api-key"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        var q = query
        q[kSecValueData as String] = Data(key.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Proposta

/// Una riga della proposta: un alimento con i suoi valori per i grammi indicati.
struct AIFoodItem: Identifiable, Equatable {
    enum Source: Equatable { case database, dish, estimate }

    let id = UUID()
    var name: String
    var grams: Double
    var source: Source
    var kcal: Double, protein: Double, carbs: Double, fat: Double
    var fiber: Double, sugar: Double, saturatedFat: Double, salt: Double
}

/// La voce di diario proposta: più alimenti nello stesso messaggio diventano
/// un'unica voce con i valori sommati.
struct AIFoodProposal: Equatable {
    enum State: Equatable { case pending, accepted, declined }

    var name: String
    var meal: MealType
    var date: Date
    var items: [AIFoodItem]
    var state: State = .pending

    var grams: Double        { items.reduce(0) { $0 + $1.grams } }
    var kcal: Double         { items.reduce(0) { $0 + $1.kcal } }
    var protein: Double      { items.reduce(0) { $0 + $1.protein } }
    var carbs: Double        { items.reduce(0) { $0 + $1.carbs } }
    var fat: Double          { items.reduce(0) { $0 + $1.fat } }
    var fiber: Double        { items.reduce(0) { $0 + $1.fiber } }
    var sugar: Double        { items.reduce(0) { $0 + $1.sugar } }
    var saturatedFat: Double { items.reduce(0) { $0 + $1.saturatedFat } }
    var salt: Double         { items.reduce(0) { $0 + $1.salt } }

    /// Un solo alimento preso tale e quale dal database: è già lì, inutile
    /// proporre di salvarlo di nuovo.
    var isSingleDatabaseFood: Bool { items.count == 1 && items[0].source == .database }

    var prefill: QuickAddPrefill {
        QuickAddPrefill(meal: meal, date: date, name: name, grams: grams,
                        kcal: kcal, protein: protein, carbs: carbs, fat: fat,
                        fiber: fiber, sugar: sugar, saturatedFat: saturatedFat, salt: salt,
                        fromDatabase: isSingleDatabaseFood)
    }
}

/// Dati con cui si apre l'inserimento al volo (dall'assistente AI).
struct QuickAddPrefill: Identifiable, Equatable {
    let id = UUID()
    var meal: MealType
    var date: Date
    var name: String
    var grams: Double
    var kcal: Double, protein: Double, carbs: Double, fat: Double
    var fiber: Double, sugar: Double, saturatedFat: Double, salt: Double
    /// L'alimento esiste già nel database: niente opzione "salva nel database".
    var fromDatabase: Bool
}

// MARK: - Messaggi della chat

struct AIChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    var image: UIImage? = nil
    var proposal: AIFoodProposal? = nil
    var isError = false
    /// Il blocco `content` restituito dall'API, rimandato identico nei turni
    /// successivi (la cronologia si allunga soltanto, non si riscrive).
    var apiContent: Any? = nil
    /// Il contenuto inviato per un messaggio dell'utente (testo, ora, foto).
    var apiUserContent: [[String: Any]]? = nil
}

// MARK: - Catalogo dal database

/// Fotografia del database al momento della richiesta: gli id che il modello
/// restituisce sono gli indici di queste liste.
struct AIFoodCatalog {
    struct Food {
        let name: String
        let kcal, protein, carbs, fat, fiber, sugar, saturatedFat, salt: Double   // per 100 g
        let portionName: String?
        let portionGrams: Double?
    }
    struct Dish {
        let name: String
        let weight: Double        // peso del piatto intero (g)
        let portions: Double
        let kcal, protein, carbs, fat, fiber, sugar, saturatedFat, salt: Double   // piatto intero
    }

    /// Oltre questo numero gli alimenti in più non vengono mandati (preferiti prima).
    static let maxFoods = 1000

    let foods: [Food]
    let dishes: [Dish]

    @MainActor
    static func load(context: ModelContext) -> AIFoodCatalog {
        let allFoods = (try? context.fetch(FetchDescriptor<FoodItem>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let ordered = allFoods.filter(\.isFavorite) + allFoods.filter { !$0.isFavorite }
        let foods = ordered.prefix(maxFoods).map {
            Food(name: $0.name, kcal: $0.kcalPer100g, protein: $0.proteinPer100g,
                 carbs: $0.carbsPer100g, fat: $0.fatPer100g, fiber: $0.fiberPer100g,
                 sugar: $0.sugarPer100g, saturatedFat: $0.saturatedFatPer100g,
                 salt: $0.saltPer100g, portionName: $0.portionName, portionGrams: $0.portionGrams)
        }
        let allDishes = (try? context.fetch(FetchDescriptor<CustomMeal>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let dishes = allDishes.map {
            Dish(name: $0.name, weight: $0.effectiveWeight, portions: $0.portions,
                 kcal: $0.totalKcal, protein: $0.totalProtein, carbs: $0.totalCarbs,
                 fat: $0.totalFat, fiber: $0.totalFiber, sugar: $0.totalSugar,
                 saturatedFat: $0.totalSaturatedFat, salt: $0.totalSalt)
        }
        return AIFoodCatalog(foods: Array(foods), dishes: dishes)
    }

    /// Testo compatto per il modello: una riga per alimento o piatto.
    var promptText: String {
        func n(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
        var lines = ["ALIMENTI (valori per 100 g: kcal | proteine | carboidrati | grassi | fibre | zuccheri | grassi saturi | sale)"]
        if foods.isEmpty { lines.append("(nessuno)") }
        for (i, f) in foods.enumerated() {
            var line = "F\(i) | \(f.name) | \(n(f.kcal)) | \(n(f.protein)) | \(n(f.carbs)) | \(n(f.fat)) | \(n(f.fiber)) | \(n(f.sugar)) | \(n(f.saturatedFat)) | \(n(f.salt))"
            if let g = f.portionGrams, g > 0 {
                line += " | 1 \(f.portionName ?? "porzione") = \(n(g)) g"
            }
            lines.append(line)
        }
        lines.append("")
        lines.append("PIATTI DELL'UTENTE (valori del piatto intero: peso g | porzioni | kcal | proteine | carboidrati | grassi | fibre | zuccheri | grassi saturi | sale)")
        if dishes.isEmpty { lines.append("(nessuno)") }
        for (i, d) in dishes.enumerated() {
            lines.append("D\(i) | \(d.name) | \(n(d.weight)) | \(n(d.portions)) | \(n(d.kcal)) | \(n(d.protein)) | \(n(d.carbs)) | \(n(d.fat)) | \(n(d.fiber)) | \(n(d.sugar)) | \(n(d.saturatedFat)) | \(n(d.salt))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Client API

enum FoodAssistantError: LocalizedError {
    case missingKey, invalidKey, rateLimited, overloaded, network, refused, truncated
    case server(Int), unreadable

    var errorDescription: String? {
        switch self {
        case .missingKey:  return "Manca la chiave API: inseriscila in Impostazioni › Assistente AI."
        case .invalidKey:  return "La chiave API non è valida o è stata revocata. Controllala in Impostazioni › Assistente AI."
        case .rateLimited: return "Troppe richieste o credito API esaurito. Riprova tra poco o controlla il tuo account su console.anthropic.com."
        case .overloaded:  return "Il servizio è momentaneamente sovraccarico. Riprova tra poco."
        case .network:     return "Connessione non riuscita. Controlla internet e riprova."
        case .refused:     return "Il modello non ha risposto a questa richiesta. Prova a riformularla."
        case .truncated:   return "La risposta è stata interrotta. Riprova, magari con una descrizione più breve."
        case .server(let code): return "Errore del servizio (\(code)). Riprova tra poco."
        case .unreadable:  return "Risposta non comprensibile. Riprova."
        }
    }
}

/// Risposta strutturata del modello, prima di risolvere gli id del database.
private struct AIRawReply: Decodable {
    struct Item: Decodable {
        let name: String
        let grams: Double
        let food_id: Int?
        let dish_id: Int?
        let kcal, protein, carbs, fat, fiber, sugar, saturated_fat, salt: Double
    }
    struct Proposal: Decodable {
        let name: String
        let meal: String?
        let time: String?
        let day_offset: Int
        let items: [Item]
    }
    let reply: String
    let proposal: Proposal?
}

enum FoodAssistantClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let model = "claude-opus-5-5"

    static let instructions = """
    Sei l'assistente nutrizionale di un'app italiana di diario alimentare. L'utente ti dice \
    (a parole, con una foto o entrambe) cosa ha mangiato. Devi capire che cosa, quanto (in \
    grammi), a quale pasto e in che giorno, e proporre una voce di diario con i valori nutrizionali.

    Regole:
    1. Cerca prima nel database dell'utente riportato sotto. Se un alimento (Fn) o un piatto (Dn) \
    corrisponde davvero a quello che ha mangiato (lo stesso cibo, non solo un nome simile), usa il \
    suo id in food_id o dish_id: i valori finali li calcola l'app dai dati salvati. Se nel database \
    non c'è niente di adatto, metti food_id e dish_id a null e stima tu i valori da dati \
    nutrizionali di riferimento medi.
    2. Quantità: usa quella detta dall'utente. Con una foto stima la porzione da piatto, posate, \
    confezione o mano visibili; l'utente può anche indicarla a parole. Traduci espressioni come \
    "non troppo grande", "una fetta", "un pacchetto" in grammi della parte mangiata (una banana \
    media sbucciata pesa circa 120 g). Se un alimento del database ha una porzione definita \
    (per esempio "1 pacchetto = 55 g"), usala.
    3. In ogni voce di items i valori (kcal, proteine, carboidrati, grassi, fibre, zuccheri, \
    grassi saturi, sale, tutti in grammi tranne le kcal) si riferiscono ai grammi della voce, \
    non a 100 g. Mettili anche per le voci prese dal database, come stima.
    4. Più alimenti nello stesso messaggio: un'unica proposta, con un nome riassuntivo (per \
    esempio "Pasta al pomodoro e insalata") e una voce in items per ciascun alimento.
    5. Pasto: se l'utente lo dice, mettilo in meal. Se dice solo un orario ("alle 16"), mettilo \
    in time come HH:mm e lascia meal a null. Se non dice né l'uno né l'altro, lascia entrambi a \
    null: l'app usa l'ora del messaggio. day_offset: 0 per oggi, -1 per ieri, -2 per l'altro ieri.
    6. Se non si capisce che cosa ha mangiato (per esempio la foto non è chiara) chiedi in reply \
    e metti proposal a null. Se invece puoi fare una stima ragionevole, proponi e scrivi in reply, \
    in una o due frasi, le ipotesi che hai fatto (quantità, condimenti).
    7. Se l'utente corregge una proposta ("era più grande", "era ieri", "senza olio"), rifai la \
    proposta completa aggiornata.
    8. Per messaggi che non riguardano il cibo rispondi brevemente in reply con proposal null.
    Scrivi reply in italiano, in modo breve e chiaro, senza elenchi lunghi.
    """

    /// Schema della risposta: un testo per l'utente e, se c'è, la proposta.
    static let schema: [String: Any] = {
        func nullable(_ t: [String: Any]) -> [String: Any] { ["anyOf": [["type": "null"], t]] }
        let number: [String: Any] = ["type": "number"]
        let item: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "grams": number,
                "food_id": nullable(["type": "integer"]),
                "dish_id": nullable(["type": "integer"]),
                "kcal": number, "protein": number, "carbs": number, "fat": number,
                "fiber": number, "sugar": number, "saturated_fat": number, "salt": number,
            ],
            "required": ["name", "grams", "food_id", "dish_id", "kcal", "protein", "carbs",
                         "fat", "fiber", "sugar", "saturated_fat", "salt"],
            "additionalProperties": false,
        ]
        let proposal: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "meal": nullable(["type": "string", "enum": MealType.allCases.map(\.rawValue)]),
                "time": nullable(["type": "string"]),
                "day_offset": ["type": "integer"],
                "items": ["type": "array", "items": item],
            ],
            "required": ["name", "meal", "time", "day_offset", "items"],
            "additionalProperties": false,
        ]
        return [
            "type": "object",
            "properties": [
                "reply": ["type": "string"],
                "proposal": nullable(proposal),
            ],
            "required": ["reply", "proposal"],
            "additionalProperties": false,
        ]
    }()

    /// Contenuto del messaggio dell'utente: foto (se c'è), ora attuale e testo.
    static func userContent(text: String, image: UIImage?, now: Date) -> [[String: Any]] {
        var content: [[String: Any]] = []
        if let image, let data = jpegData(for: image) {
            content.append(["type": "image",
                            "source": ["type": "base64", "media_type": "image/jpeg",
                                       "data": data.base64EncodedString()]])
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM yyyy, HH:mm"
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        content.append(["type": "text",
                        "text": "[Messaggio inviato \(f.string(from: now))]\n\(body.isEmpty ? "(solo foto)" : body)"])
        return content
    }

    /// Foto ridotta a 1280 px sul lato lungo: abbastanza per riconoscere il cibo,
    /// e il costo della richiesta cresce con la risoluzione.
    private static func jpegData(for image: UIImage) -> Data? {
        let maxSide: CGFloat = 1280
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    /// Manda la conversazione e restituisce il blocco `content` grezzo (da
    /// rimandare nei turni successivi) e la risposta decodificata.
    static func send(messages: [[String: Any]], catalog: AIFoodCatalog,
                     apiKey: String) async throws -> (content: Any, reply: String, proposal: AIRawReplyProposal?) {
        var request = URLRequest(url: endpoint, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Se i filtri di sicurezza rifiutano la richiesta, il server la ripassa
        // a un altro modello invece di restituire un rifiuto.
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "fallbacks": "default",
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema],
            ],
            // Istruzioni fisse, poi il database: la parte comune a tutti i turni
            // resta in cache finché il database non cambia.
            "system": [
                ["type": "text", "text": instructions],
                ["type": "text", "text": catalog.promptText, "cache_control": ["type": "ephemeral"]],
            ],
            "messages": messages,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FoodAssistantError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: break
        case 401, 403: throw FoodAssistantError.invalidKey
        case 429: throw FoodAssistantError.rateLimited
        case 529: throw FoodAssistantError.overloaded
        default:
            if let text = String(data: data, encoding: .utf8) { print("⚠️ API \(status): \(text)") }
            throw FoodAssistantError.server(status)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else { throw FoodAssistantError.unreadable }
        switch json["stop_reason"] as? String {
        case "refusal":    throw FoodAssistantError.refused
        case "max_tokens": throw FoodAssistantError.truncated
        default: break
        }
        let text = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
        guard let raw = try? JSONDecoder().decode(AIRawReply.self, from: Data(text.utf8)) else {
            throw FoodAssistantError.unreadable
        }
        return (content, raw.reply, raw.proposal.map(AIRawReplyProposal.init))
    }
}

/// La proposta come l'ha scritta il modello, da risolvere sul catalogo.
struct AIRawReplyProposal {
    struct Item {
        let name: String
        let grams: Double
        let foodID: Int?
        let dishID: Int?
        let kcal, protein, carbs, fat, fiber, sugar, saturatedFat, salt: Double
    }
    let name: String
    let meal: String?
    let time: String?
    let dayOffset: Int
    let items: [Item]

    fileprivate init(_ p: AIRawReply.Proposal) {
        name = p.name; meal = p.meal; time = p.time; dayOffset = p.day_offset
        items = p.items.map {
            Item(name: $0.name, grams: $0.grams, foodID: $0.food_id, dishID: $0.dish_id,
                 kcal: $0.kcal, protein: $0.protein, carbs: $0.carbs, fat: $0.fat,
                 fiber: $0.fiber, sugar: $0.sugar, saturatedFat: $0.saturated_fat, salt: $0.salt)
        }
    }

    /// Valori finali: per gli alimenti e i piatti del database contano i dati
    /// salvati, non la stima del modello. Pasto: quello indicato, altrimenti
    /// dall'orario detto, altrimenti dall'ora del messaggio.
    func resolve(catalog: AIFoodCatalog, sentAt: Date) -> AIFoodProposal? {
        let resolved: [AIFoodItem] = items.compactMap { item in
            let grams = max(item.grams, 0)
            if let id = item.foodID, catalog.foods.indices.contains(id) {
                let f = catalog.foods[id], k = grams / 100
                return AIFoodItem(name: f.name, grams: grams, source: .database,
                                  kcal: f.kcal * k, protein: f.protein * k, carbs: f.carbs * k,
                                  fat: f.fat * k, fiber: f.fiber * k, sugar: f.sugar * k,
                                  saturatedFat: f.saturatedFat * k, salt: f.salt * k)
            }
            if let id = item.dishID, catalog.dishes.indices.contains(id), catalog.dishes[id].weight > 0 {
                let d = catalog.dishes[id], k = grams / d.weight
                return AIFoodItem(name: d.name, grams: grams, source: .dish,
                                  kcal: d.kcal * k, protein: d.protein * k, carbs: d.carbs * k,
                                  fat: d.fat * k, fiber: d.fiber * k, sugar: d.sugar * k,
                                  saturatedFat: d.saturatedFat * k, salt: d.salt * k)
            }
            return AIFoodItem(name: item.name, grams: grams, source: .estimate,
                              kcal: max(item.kcal, 0), protein: max(item.protein, 0),
                              carbs: max(item.carbs, 0), fat: max(item.fat, 0),
                              fiber: max(item.fiber, 0), sugar: max(item.sugar, 0),
                              saturatedFat: max(item.saturatedFat, 0), salt: max(item.salt, 0))
        }
        guard !resolved.isEmpty else { return nil }

        let cal = Calendar.current
        let offset = min(max(dayOffset, -30), 0)
        let day = cal.startOfDay(for: sentAt).adding(days: offset)

        let mealType: MealType
        if let m = meal, let t = MealType(rawValue: m) {
            mealType = t
        } else if let t = time, case let (hh, mm)? = Self.parseTime(t) {
            mealType = MealType.forTime(hour: hh, minute: mm)
        } else {
            let c = cal.dateComponents([.hour, .minute], from: sentAt)
            mealType = MealType.forTime(hour: c.hour ?? 12, minute: c.minute ?? 0)
        }

        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return AIFoodProposal(name: title.isEmpty ? resolved.map(\.name).joined(separator: " e ") : title,
                              meal: mealType, date: day, items: resolved)
    }

    private static func parseTime(_ s: String) -> (Int, Int)? {
        let parts = s.split(whereSeparator: { $0 == ":" || $0 == "." }).compactMap { Int($0) }
        guard let h = parts.first, (0...23).contains(h) else { return nil }
        let m = parts.count > 1 ? parts[1] : 0
        return (0...59).contains(m) ? (h, m) : nil
    }
}

// MARK: - Sessione della chat

/// La conversazione con l'assistente. Vive per tutta la durata dell'app (non
/// dentro la vista), così non si perde passando al diario dopo una conferma.
@MainActor
final class FoodAssistantSession: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var isSending = false

    func send(text: String, image: UIImage?, context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, !trimmed.isEmpty || image != nil else { return }
        guard let key = AIKeyStore.load() else {
            messages.append(AIChatMessage(role: .assistant,
                                          text: FoodAssistantError.missingKey.errorDescription ?? "",
                                          isError: true))
            return
        }

        let now = Date()
        let userContent = FoodAssistantClient.userContent(text: trimmed, image: image, now: now)
        messages.append(AIChatMessage(role: .user, text: trimmed, image: image, apiUserContent: userContent))
        isSending = true

        let catalog = AIFoodCatalog.load(context: context)
        let history = apiHistory()

        Task { @MainActor in
            defer { isSending = false }
            do {
                let result = try await FoodAssistantClient.send(messages: history, catalog: catalog, apiKey: key)
                let proposal = result.proposal?.resolve(catalog: catalog, sentAt: now)
                messages.append(AIChatMessage(role: .assistant, text: result.reply,
                                              proposal: proposal, apiContent: result.content))
            } catch {
                // Il messaggio dell'utente resta a schermo ma esce dalla cronologia
                // mandata all'API: due messaggi utente di fila non sono validi.
                if let i = messages.lastIndex(where: { $0.role == .user }) {
                    messages[i].apiUserContent = nil
                }
                let text = (error as? LocalizedError)?.errorDescription ?? "Qualcosa è andato storto. Riprova."
                messages.append(AIChatMessage(role: .assistant, text: text, isError: true))
            }
        }
    }

    func setProposalState(_ state: AIFoodProposal.State, for messageID: UUID) {
        guard let i = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[i].proposal?.state = state
    }

    func clear() {
        guard !isSending else { return }
        messages.removeAll()
    }

    /// Cronologia per l'API: solo i turni andati a buon fine, alternati utente
    /// e assistente, con il contenuto dell'assistente rimandato identico.
    private func apiHistory() -> [[String: Any]] {
        var result: [[String: Any]] = []
        for m in messages {
            switch m.role {
            case .user:
                guard let content = m.apiUserContent else { continue }
                result.append(["role": "user", "content": content])
            case .assistant:
                guard let content = m.apiContent, result.last?["role"] as? String == "user" else { continue }
                result.append(["role": "assistant", "content": content])
            }
        }
        // Un messaggio utente rimasto senza risposta (errore) non deve restare a
        // metà: l'ultimo turno valido è sempre quello appena aggiunto.
        var cleaned: [[String: Any]] = []
        for (i, turn) in result.enumerated() {
            let isUser = turn["role"] as? String == "user"
            let nextIsUser = i + 1 < result.count && result[i + 1]["role"] as? String == "user"
            if isUser && nextIsUser { continue }
            cleaned.append(turn)
        }
        return cleaned
    }
}
