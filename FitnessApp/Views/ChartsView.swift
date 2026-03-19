import SwiftUI
import SwiftData
import Charts

enum ChartPeriod: String, CaseIterable {
    case week  = "7g"
    case month = "30g"
    case quarter = "3m"
    case all   = "Tutto"

    var days: Int {
        switch self {
        case .week:    return 7
        case .month:   return 30
        case .quarter: return 90
        case .all:     return 365
        }
    }
}

struct ChartsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @Query private var allLogs: [DayLog]
    @Query private var allEntries: [FoodEntry]

    @State private var period: ChartPeriod = .week

    // Giorni nel periodo selezionato
    private var dates: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<period.days).reversed().map { today.adding(days: -$0) }
    }

    private func log(for date: Date) -> DayLog? {
        let key = date.dateKey
        return allLogs.first { $0.dateKey == key }
    }

    private func kcal(for date: Date) -> Double {
        let key = date.dateKey
        return allEntries.filter { $0.dayKey == key }.reduce(0) { $0 + $1.kcalSnapshot }
    }

    private func protein(for date: Date) -> Double {
        let key = date.dateKey
        return allEntries.filter { $0.dayKey == key }.reduce(0) { $0 + $1.proteinSnapshot }
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grafici")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.txt)
                            Text("I tuoi progressi")
                                .font(.system(size: 13))
                                .foregroundColor(.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Period selector
                    HStack(spacing: 6) {
                        ForEach(ChartPeriod.allCases, id: \.self) { p in
                            Button {
                                withAnimation { period = p }
                            } label: {
                                Text(p.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(period == p ? .white : .muted)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(period == p ? Color.acc : .clear)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(Color.card)
                    .cornerRadius(14)
                    .padding(.horizontal, 20)

                    // PESO
                    let weightData = dates.compactMap { d -> (Date, Double)? in
                        guard let w = log(for: d)?.weight else { return nil }
                        return (d, w)
                    }
                    if !weightData.isEmpty {
                        ChartCard(title: "Peso") {
                            Chart(weightData, id: \.0) { date, w in
                                LineMark(x: .value("Data", date), y: .value("kg", w))
                                    .foregroundStyle(Color.gymGreen)
                                    .interpolationMethod(.catmullRom)
                                AreaMark(x: .value("Data", date), y: .value("kg", w))
                                    .foregroundStyle(Color.gymGreen.opacity(0.15).gradient)
                                    .interpolationMethod(.catmullRom)
                                PointMark(x: .value("Data", date), y: .value("kg", w))
                                    .foregroundStyle(Color.gymGreen)
                                    .symbolSize(30)
                            }
                            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { v in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                    .foregroundStyle(Color.muted)
                                    .font(.system(size: 10))
                            }}
                            .chartYAxis { AxisMarks { v in
                                AxisValueLabel()
                                    .foregroundStyle(Color.muted)
                                    .font(.system(size: 10))
                                AxisGridLine().foregroundStyle(Color.brd)
                            }}
                            .frame(height: 160)
                        }
                        bigValue: {
                            if let last = weightData.last {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(last.1.formatted1)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.txt)
                                    Text("kg")
                                        .font(.system(size: 14))
                                        .foregroundColor(.muted)
                                    if weightData.count > 1 {
                                        let delta = last.1 - weightData[0].1
                                        Text(delta >= 0 ? "+\(delta.formatted1)" : "\(delta.formatted1)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(delta <= 0 ? .gymGreen : .gymOrange)
                                    }
                                }
                            }
                        }
                    }

                    // CALORIE
                    let kcalData = dates.map { (date: $0, kcal: kcal(for: $0)) }
                    ChartCard(title: "Calorie") {
                        Chart(kcalData, id: \.date) { item in
                            BarMark(x: .value("Data", item.date, unit: .day), y: .value("kcal", item.kcal))
                                .foregroundStyle(item.kcal > 2255 ? Color.gymOrange : Color.acc2)
                                .cornerRadius(6)
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { v in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                .foregroundStyle(Color.muted).font(.system(size: 10))
                        }}
                        .chartYAxis { AxisMarks { v in
                            AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                            AxisGridLine().foregroundStyle(Color.brd)
                        }}
                        .frame(height: 160)
                    } bigValue: {
                        if let today = kcalData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(today.kcal))")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(today.kcal > 2255 ? .gymOrange : .txt)
                                Text("/ 2255 kcal")
                                    .font(.system(size: 14))
                                    .foregroundColor(.muted)
                            }
                        }
                    }

                    // PALESTRA
                    ChartCard(title: "Palestra") {
                        HStack(spacing: 6) {
                            ForEach(dates.suffix(7), id: \.self) { date in
                                let gc = log(for: date)?.gymColor ?? .rest
                                VStack(spacing: 5) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(gc.color)
                                        .frame(width: 34, height: 34)
                                    Text(shortDayLabel(date))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.muted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 8)
                    } bigValue: {
                        let active = dates.suffix(7).filter { (log(for: $0)?.gymColor ?? .rest) != .rest }.count
                        HStack(spacing: 4) {
                            Text("\(active)/7")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.gymBlue)
                            Text("allenamenti")
                                .font(.system(size: 14))
                                .foregroundColor(.muted)
                        }
                    }

                    // PROTEINE
                    let protData = dates.map { (date: $0, p: protein(for: $0)) }
                    ChartCard(title: "Proteine") {
                        Chart(protData, id: \.date) { item in
                            LineMark(x: .value("Data", item.date), y: .value("g", item.p))
                                .foregroundStyle(Color.acc2)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Data", item.date), y: .value("g", item.p))
                                .foregroundStyle(Color.acc2.opacity(0.15).gradient)
                                .interpolationMethod(.catmullRom)
                            RuleMark(y: .value("Target", 200))
                                .foregroundStyle(Color.acc2.opacity(0.4))
                                .lineStyle(StrokeStyle(dash: [4, 4]))
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { v in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                .foregroundStyle(Color.muted).font(.system(size: 10))
                        }}
                        .chartYAxis { AxisMarks { v in
                            AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                            AxisGridLine().foregroundStyle(Color.brd)
                        }}
                        .frame(height: 140)
                    } bigValue: {
                        if let today = protData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(today.p))g")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.acc2)
                                Text("target 200g")
                                    .font(.system(size: 14))
                                    .foregroundColor(.muted)
                            }
                        }
                    }

                    // PASSI
                    let stepsData = dates.map { (date: $0, steps: log(for: $0)?.steps ?? 0) }
                    ChartCard(title: "Passi") {
                        Chart(stepsData, id: \.date) { item in
                            BarMark(x: .value("Data", item.date, unit: .day), y: .value("Passi", item.steps))
                                .foregroundStyle(Color.gymBlue.opacity(item.steps >= 10000 ? 1.0 : 0.65))
                                .cornerRadius(6)
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { v in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                                .foregroundStyle(Color.muted).font(.system(size: 10))
                        }}
                        .chartYAxis { AxisMarks { v in
                            AxisValueLabel().foregroundStyle(Color.muted).font(.system(size: 10))
                            AxisGridLine().foregroundStyle(Color.brd)
                        }}
                        .frame(height: 140)
                    } bigValue: {
                        if let today = stepsData.last {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(today.steps.stepsFormatted)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.gymBlue)
                                let avg = stepsData.isEmpty ? 0 : stepsData.map(\.steps).reduce(0, +) / stepsData.count
                                Text("media \(avg.stepsFormatted)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.muted)
                            }
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        )
    }

    private func shortDayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(3)).capitalized
    }
}

// MARK: - Chart Card

struct ChartCard<Chart: View, BigValue: View>: View {
    let title: String
    let chart: () -> Chart
    let bigValue: () -> BigValue

    init(title: String, @ViewBuilder chart: @escaping () -> Chart, @ViewBuilder bigValue: @escaping () -> BigValue) {
        self.title = title
        self.chart = chart
        self.bigValue = bigValue
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
