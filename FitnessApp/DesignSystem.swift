import SwiftUI

// MARK: - Apple Fitness–Inspired Palette

extension Color {
    static let bg      = Color(hex: "000000")
    static let card    = Color(hex: "1C1C1E")
    static let card2   = Color(hex: "2C2C2E")
    static let brd     = Color(hex: "38383A")
    static let brd2    = Color(hex: "2C2C2E")
    static let txt     = Color.white
    static let muted   = Color(hex: "8E8E93")

    // Activity Ring colors (Apple Fitness style)
    static let ringRed   = Color(hex: "FA114F")   // Muovi / Calorie
    static let ringGreen = Color(hex: "92E82A")   // Esercizio
    static let ringBlue  = Color(hex: "00CDEF")   // In piedi / Passi

    // Accents
    static let acc     = Color(hex: "30D158")
    static let acc2    = Color(hex: "30D158")

    // Functional
    static let gymOrange = Color(hex: "FF9F0A")
    static let gymBlue   = Color(hex: "0A84FF")
    static let gymGreen  = Color(hex: "30D158")
    static let gymPink   = Color(hex: "FF375F")
    static let gymGray   = Color(hex: "48484A")
    static let gymCyan   = Color(hex: "64D2FF")

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

// MARK: - Card

struct HTCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.muted)
            .kerning(0.6)
    }
}

// MARK: - Macro Bar

struct MacroBar: View {
    let label: String; let value: Double; let target: Double
    let color: Color; var small: Bool = false

    private var pct: Double { min(value / max(target, 1), 1) }
    private var isOver: Bool { value > target }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: small ? 11 : 13, weight: .medium))
                .foregroundColor(.muted)
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: small ? 5 : 7)
                    Capsule()
                        .fill(isOver ? Color.gymOrange : color)
                        .frame(width: geo.size.width * pct, height: small ? 5 : 7)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pct)
                }
            }
            .frame(height: small ? 5 : 7)

            Text("\(value.smartFormat)/\(target.smartFormat)")
                .font(.system(size: small ? 10 : 11, weight: .bold, design: .rounded))
                .foregroundColor(isOver ? .gymOrange : .white.opacity(0.55))
                .frame(width: 66, alignment: .trailing)
        }
    }
}

// MARK: - Gym Dot

struct GymDot: View {
    let gymColor: GymColor; let isSelected: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                if gymColor == .rest {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .muted)
                } else {
                    Circle()
                        .fill(isSelected ? gymColor.color : gymColor.color.opacity(0.35))
                        .frame(width: isSelected ? 14 : 10)
                }
            }
            .frame(width: 52, height: 52)
            .modifier(GymDotBackground(gymColor: gymColor, isSelected: isSelected))
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct GymDotBackground: ViewModifier {
    let gymColor: GymColor; let isSelected: Bool
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    isSelected
                        ? .regular.tint(gymColor.color).interactive()
                        : .regular,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous),
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? gymColor.color.opacity(0.18) : Color.card2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? gymColor.color.opacity(0.5) : .clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - Numeric Field (easy to clear, large tap target)

struct NumericField: View {
    let label: String
    @Binding var value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "AEAEB2"))
            Spacer()
            HStack(spacing: 0) {
                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .foregroundColor(color).tint(color)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .padding(.vertical, 12).padding(.leading, 14).padding(.trailing, value.isEmpty ? 14 : 4)
                if !value.isEmpty {
                    Button { value = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.muted.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                }
            }
            .frame(minWidth: 120)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Big Input Field (centered, for weight/steps/grams with clear button)

struct BigInputField: View {
    let placeholder: String
    @Binding var value: String
    var color: Color = .txt
    var keyboardType: UIKeyboardType = .decimalPad
    var fontSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 0) {
            if !value.isEmpty {
                Color.clear.frame(width: 30)
            }
            TextField(placeholder, text: $value)
                .keyboardType(keyboardType)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(color).tint(color)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
            if !value.isEmpty {
                Button { value = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.muted.opacity(0.5))
                }
                .buttonStyle(.plain)
                .frame(width: 30)
            }
        }
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Activity Ring

struct ActivityRing: View {
    let progress: Double
    let ringColor: Color
    let lineWidth: CGFloat
    let size: CGFloat
    var appeared: Bool = true

    private var clampedProgress: Double { min(max(progress, 0), 1.5) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: appeared ? clampedProgress : 0)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.5), radius: lineWidth * 0.4)
                .animation(.spring(response: 1.0, dampingFraction: 0.7), value: appeared)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Number formatting

extension Double {
    var formatted0: String { String(format: "%.0f", self) }
    var formatted1: String { String(format: "%.1f", self) }
    var smartFormat: String {
        self == floor(self) ? String(format: "%.0f", self) : String(format: "%.1f", self)
    }
}

extension Int {
    var stepsFormatted: String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.locale = Locale(identifier: "it_IT")
        return n.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Nav Button

struct NavBtn: View {
    let icon: String; var disabled: Bool = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(disabled ? .muted.opacity(0.3) : .white)
                .frame(width: 36, height: 36)
                .background(Color.card, in: Circle())
        }
        .buttonStyle(.plain).disabled(disabled)
    }
}

// MARK: - Gear Button

struct GearBtn: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14, weight: .medium)).foregroundColor(.muted)
                .frame(width: 36, height: 36)
                .background(Color.card, in: Circle())
        }.buttonStyle(.plain)
    }
}

// MARK: - Pill Button (glass-aware on iOS 26+)

struct PillButton: View {
    let label: String
    var color: Color = .acc
    var textColor: Color = .black
    var disabled: Bool = false
    var prominent: Bool = true
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            if prominent {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .tint(color)
                .buttonStyle(.glassProminent)
                .disabled(disabled)
            } else {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .tint(color)
                .buttonStyle(.glass)
                .disabled(disabled)
            }
        } else {
            Button(action: action) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(disabled ? .muted : textColor)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(
                        disabled ? Color.card2 : color,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.plain).disabled(disabled)
        }
    }
}

// MARK: - Glass Floating Button (iOS 26+)

struct GlassButton: View {
    let icon: String
    let label: String
    var color: Color = .acc
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Label(label, systemImage: icon)
                    .font(.system(size: 14, weight: .bold))
            }
            .tint(color)
            .buttonStyle(.glass)
        } else {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 12, weight: .bold))
                    Text(label).font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(color)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(color.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

