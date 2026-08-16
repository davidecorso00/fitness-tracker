import SwiftUI

/// Prende il posto della serie "giorni in deficit".
///
/// Due differenze che contano. La prima: misura i pasti regolari invece dei
/// giorni in deficit, quindi spinge a mangiare abbastanza e non a mangiare poco.
/// La seconda: è una finestra mobile su sette giorni, non una catena — un giorno
/// storto fa scendere il conteggio di uno e non lo azzera, così ricominciare non
/// costa niente.
struct MealRhythmCard: View {
    let regolarita: MealRegularity

    private static let giorni = ["L", "M", "M", "G", "V", "S", "D"]

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(.ringGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(titolo)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.txt)
                        Text(sottotitolo)
                            .font(.system(size: 12))
                            .foregroundColor(.muted)
                    }
                    Spacer()
                }

                // Un quadratino per giorno, dal più vecchio a oggi.
                HStack(spacing: 5) {
                    ForEach(Array(regolarita.recent.enumerated()), id: \.offset) { _, ok in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(ok ? Color.ringGreen.opacity(0.85) : Color.white.opacity(0.08))
                            .frame(height: 8)
                    }
                }

                if let ore = regolarita.hoursSinceLastMeal {
                    Text(ultimoPasto(ore))
                        .font(.system(size: 12))
                        .foregroundColor(ore >= 5 ? .gymOrange : .muted)
                }
            }
        }
    }

    private var titolo: String {
        let n = regolarita.regularDays
        if n == 0 { return "Pasti regolari" }
        return "\(n) \(n == 1 ? "giorno" : "giorni") con pasti regolari"
    }

    private var sottotitolo: String {
        regolarita.regularDays == 0
            ? "Tre occasioni al giorno, senza buchi troppo lunghi"
            : "negli ultimi \(regolarita.window) giorni"
    }

    /// Constatazione, non avvertimento: mangiare regolarmente è la cosa che
    /// riduce le abbuffate, quindi l'informazione utile è quanto tempo è passato.
    private func ultimoPasto(_ ore: Double) -> String {
        if ore < 1 { return "Ultimo pasto da poco." }
        let h = Int(ore.rounded())
        return "Ultimo pasto \(h) \(h == 1 ? "ora" : "ore") fa."
    }
}
