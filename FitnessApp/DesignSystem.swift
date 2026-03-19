import SwiftUI

// MARK: - Palette

extension Color {
    static let bg      = Color(hex: "0f0f14")
    static let card    = Color(hex: "1a1a24")
    static let card2   = Color(hex: "141420")
    static let brd     = Color(hex: "252530")
    static let brd2    = Color(hex: "1e1e2a")
    static let txt     = Color(hex: "f0ede8")
    static let muted   = Color(hex: "666666")
    static let acc     = Color(hex: "7c3aed")
    static let acc2    = Color(hex: "a855f7")

    // Colori palestra
    static let gymOrange = Color(hex: "f97316")
    static let gymBlue   = Color(hex: "3b82f6")
    static let gymGreen  = Color(hex: "10b981")
    static let gymPink   = Color(hex: "ec4899")
    static let gymGray   = Color(hex: "252530")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension GymColor {
    var color: Color {
        switch self {
        case .rest:   return .gymGray
        case .orange: return .gymOrange
        case .blue:   return .gymBlue
        case .green:  return .gymGreen
        case .pink:   return .gymPink
        }
    }
}

// MARK: - Componenti riutilizzabili

struct HTCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(Color.card)
            .cornerRadius(20)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.muted)
            .kerning(0.7)
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color
    var small: Bool = false

    private var pct: Double { min(value / max(target, 1), 1) }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: small ? 11 : 12, weight: .medium))
                .foregroundColor(.muted)
                .frame(width: 66, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.brd).frame(height: 7)
                    RoundedRectangle(cornerRadius: 4).fill(color)
                        .frame(width: geo.size.width * pct, height: 7)
                        .animation(.easeOut(duration: 0.4), value: pct)
                }
            }
            .frame(height: 7)

            Text("\(Int(value))/\(Int(target))g")
                .font(.system(size: small ? 11 : 12, weight: .bold))
                .foregroundColor(Color(hex: "aaaaaa"))
                .frame(width: 62, alignment: .trailing)
        }
    }
}

struct GymDot: View {
    let gymColor: GymColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(gymColor.color)
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(isSelected ? 0.7 : 0), lineWidth: 2.5)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Circle()
                    .fill(Color.white.opacity(isSelected ? 0.6 : 0.3))
                    .frame(width: isSelected ? 16 : 10, height: isSelected ? 16 : 10)
            }
            .animation(.spring(response: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Numero formattato

extension Double {
    var formatted0: String { String(format: "%.0f", self) }
    var formatted1: String { String(format: "%.1f", self) }
}

extension Int {
    var stepsFormatted: String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.locale = Locale(identifier: "it_IT")
        return n.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
