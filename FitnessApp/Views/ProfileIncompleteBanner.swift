import SwiftUI

// MARK: - Avviso profilo incompleto
//
// Senza altezza, data di nascita o almeno una pesata il metabolismo basale non
// si calcola: quei giorni restano fuori da deficit, grasso stimato e predizioni.
// Prima succedeva in silenzio e le pagine sembravano semplicemente vuote.

/// Cosa manca per calcolare il metabolismo basale (vuoto = niente).
func missingRestingInputs(profile: UserProfile?, hasWeight: Bool) -> [String] {
    var missing: [String] = []
    if (profile?.heightCm ?? 0) <= 0 { missing.append("altezza") }
    if profile?.birthDate == nil { missing.append("data di nascita") }
    if !hasWeight { missing.append("peso") }
    return missing
}

struct ProfileIncompleteBanner: View {
    let missing: [String]
    /// Se c'è, mostra il pulsante per aprire le impostazioni.
    var onOpenSettings: (() -> Void)? = nil

    private var list: String {
        guard missing.count > 1 else { return missing.first ?? "" }
        return missing.dropLast().joined(separator: ", ") + " e " + (missing.last ?? "")
    }

    var body: some View {
        if !missing.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 16)).foregroundColor(.gymOrange)
                    Text("Profilo incompleto: \(missing.count == 1 ? "manca" : "mancano") \(list). Senza, il consumo del giorno non si calcola e deficit, grasso stimato e predizioni restano vuoti.")
                        .font(.system(size: 13)).foregroundColor(.txt)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let onOpenSettings {
                    Button("Completa il profilo", action: onOpenSettings)
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.acc)
                } else {
                    Text("Completalo in Impostazioni › Profilo.")
                        .font(.system(size: 12)).foregroundColor(.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.gymOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
}
