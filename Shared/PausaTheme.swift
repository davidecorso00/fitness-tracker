import SwiftUI

// Palette dello spazio "Un Attimo", ripresa dalla web app omonima.
//
// È volutamente diversa dal resto dell'app: il tracker è nero, denso, pieno di
// numeri; questo spazio è caldo e vuoto. Il cambio di colore all'ingresso è
// parte della funzione, non decorazione — segnala che qui non si misura niente.

enum Pausa {

    // Fondali
    static let bgDeep  = Color(hex: "141F26")
    static let bgMid   = Color(hex: "1D323C")
    static let card    = Color(hex: "233942")
    static let cardLine = Color(hex: "31474F")

    // Accenti, uno per area
    static let seafoam = Color(hex: "8FBFAE")   // respiro
    static let sand    = Color(hex: "E3BE93")   // distrazioni
    static let lilla   = Color(hex: "B7A8D9")   // mente
    static let mauve   = Color(hex: "D08FA0")   // messaggi

    // Testo
    static let ink      = Color(hex: "F3EFE7")
    static let inkSoft  = Color(hex: "B9C6C3")
    static let inkFaint = Color(hex: "7C8B88")

    /// Sfondo dello spazio: un alone caldo che si spegne verso il basso.
    static var background: some View {
        RadialGradient(
            colors: [bgMid, bgDeep],
            center: .top,
            startRadius: 0,
            endRadius: 700
        )
        .ignoresSafeArea()
    }

    /// Testo serif per le frasi. Nel tracker non compare mai: qui serve a far
    /// leggere piano, non a far scorrere.
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Componenti condivisi dello spazio

/// Etichetta piccola in maiuscoletto, come le "eyebrow" della web app.
struct PausaEyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Pausa.mono(11))
            .kerning(1.6)
            .foregroundStyle(Pausa.inkFaint)
    }
}

/// Riquadro morbido usato per liste e schede dentro lo spazio.
struct PausaCard<Content: View>: View {
    var accent: Color = Pausa.cardLine
    var highlighted: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Pausa.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(highlighted ? accent : Pausa.cardLine, lineWidth: highlighted ? 1.5 : 1)
            )
            .shadow(color: highlighted ? accent.opacity(0.25) : .clear, radius: 14)
    }
}

/// Pulsante pieno, forma morbida.
struct PausaButton: View {
    let title: String
    var tint: Color = Pausa.seafoam
    var foreground: Color = Color(hex: "0F1D19")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Pulsante di contorno, per le scelte secondarie: nello spazio non c'è mai una
/// sola strada, e uscire deve costare quanto restare.
struct PausaOutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Pausa.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Pausa.cardLine, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
