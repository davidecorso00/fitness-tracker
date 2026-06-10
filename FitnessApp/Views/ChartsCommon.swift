import SwiftUI
import Charts

// MARK: - Periodo unificato
//
// Unico selettore per tutte le schermate grafici:
// settimana / mese / 3 mesi / 6 mesi / anno / tutto.

enum StatPeriod: String, CaseIterable {
    case week        = "7g"
    case month       = "30g"
    case threeMonths = "3m"
    case sixMonths   = "6m"
    case year        = "1a"
    case all         = "Tutto"

    /// nil = dall'inizio dei dati
    var days: Int? {
        switch self {
        case .week:        return 7
        case .month:       return 30
        case .threeMonths: return 90
        case .sixMonths:   return 180
        case .year:        return 365
        case .all:         return nil
        }
    }

    /// Data di inizio del periodo. Per "Tutto" usa la data più vecchia dei dati
    /// (fallback: un anno).
    func startDate(earliest: Date?) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        if let d = days { return today.adding(days: -(d - 1)) }
        let fallback = today.adding(days: -364)
        guard let e = earliest else { return fallback }
        return min(Calendar.current.startOfDay(for: e), today)
    }

    /// Tutti i giorni del periodo, in ordine crescente fino a oggi.
    func dates(earliest: Date?) -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = startDate(earliest: earliest)
        let n = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        return (0..<max(n, 1)).map { start.adding(days: $0) }
    }
}

struct PeriodPicker: View {
    @Binding var period: StatPeriod
    var body: some View {
        Picker("Periodo", selection: $period) {
            ForEach(StatPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
    }
}

// MARK: - Chart Card (layout uniforme per ogni metrica)

struct ChartCard<Chart: View, BigValue: View>: View {
    let title: String
    let chart: () -> Chart
    let bigValue: () -> BigValue

    init(title: String, @ViewBuilder chart: @escaping () -> Chart, @ViewBuilder bigValue: @escaping () -> BigValue) {
        self.title = title; self.chart = chart; self.bigValue = bigValue
    }

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel(text: title)
                bigValue()
                chart()
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Assi standard

struct StandardDateAxis: ViewModifier {
    func body(content: Content) -> some View {
        content.chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    .foregroundStyle(Color.muted).font(.system(size: 10))
            }
        }
    }
}

extension View {
    func standardDateAxis() -> some View { modifier(StandardDateAxis()) }

    func standardYAxis(suffix: String = "") -> some View {
        chartYAxis {
            AxisMarks { v in
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text("\(d.smartFormat)\(suffix)").font(.system(size: 9)).foregroundStyle(Color.muted)
                    }
                }
                AxisGridLine().foregroundStyle(Color.brd)
            }
        }
    }
}

// MARK: - Aggregazioni condivise

/// Media mobile centrata su `window` punti (per il trend smussato del peso).
func movingAverage(_ values: [(Date, Double)], window: Int = 7) -> [(Date, Double)] {
    guard values.count > 2 else { return values }
    let half = max(window / 2, 1)
    return values.indices.map { i in
        let lo = max(0, i - half), hi = min(values.count - 1, i + half)
        let slice = values[lo...hi]
        return (values[i].0, slice.reduce(0) { $0 + $1.1 } / Double(slice.count))
    }
}

/// Inizio settimana/mese per una data (per i volumi aggregati).
func periodStart(of date: Date, component: Calendar.Component) -> Date? {
    Calendar.current.dateInterval(of: component, for: date)?.start
}

// MARK: - Card panoramica (livello 1)

struct OverviewCard<Mini: View>: View {
    let title: String
    let icon: String
    let color: Color
    let keyValue: String
    let keyLabel: String
    let mini: () -> Mini

    init(title: String, icon: String, color: Color, keyValue: String, keyLabel: String,
         @ViewBuilder mini: @escaping () -> Mini) {
        self.title = title; self.icon = icon; self.color = color
        self.keyValue = keyValue; self.keyLabel = keyLabel; self.mini = mini
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold)).foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(keyValue)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Text(keyLabel)
                        .font(.system(size: 11)).foregroundColor(.muted)
                }
            }

            Spacer(minLength: 8)

            mini()
                .frame(width: 84, height: 40)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.muted)
        }
        .padding(14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Mini bar chart senza assi per le card panoramica.
struct MiniBars: View {
    let values: [Double]
    let color: Color

    var body: some View {
        let maxV = max(values.max() ?? 1, 0.001)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(v > 0 ? 0.9 : 0.18))
                    .frame(height: max(4, CGFloat(v / maxV) * 40))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40, alignment: .bottom)
    }
}

/// Mini linea senza assi per le card panoramica.
struct MiniLine: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let pts = normalized(in: geo.size)
            if pts.count > 1 {
                Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard values.count > 1,
              let minV = values.min(), let maxV = values.max() else { return [] }
        let range = max(maxV - minV, 0.001)
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * stepX,
                    y: size.height - (CGFloat((v - minV) / range) * (size.height - 4)) - 2)
        }
    }
}
