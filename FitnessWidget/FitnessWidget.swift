//
//  FitnessWidget.swift
//  FitnessWidget
//
//  Created by Davide Corso on 30/05/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Shared data (mirrored from main app's WidgetShared.swift)

private let fitnessAppGroupID = "group.davideCorso.FitnessApp"

struct WidgetTodayData: Codable {
    var kcalEaten: Double = 0
    var kcalTarget: Double = 2255
    var proteinEaten: Double = 0
    var proteinTarget: Double = 200
    var waterLiters: Double = 0
    var waterTarget: Double = 2.0
    var steps: Int = 0
    var stepsTarget: Int = 10000

    private static let key = "fitnessTodayWidget"

    static func load() -> WidgetTodayData {
        guard let ud = UserDefaults(suiteName: fitnessAppGroupID),
              let data = ud.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetTodayData.self, from: data)
        else { return WidgetTodayData() }
        return decoded
    }
}

// MARK: - Timeline

struct FitnessEntry: TimelineEntry {
    let date: Date
    let data: WidgetTodayData
}

struct FitnessProvider: TimelineProvider {
    func placeholder(in context: Context) -> FitnessEntry {
        FitnessEntry(date: Date(), data: WidgetTodayData())
    }

    func getSnapshot(in context: Context, completion: @escaping (FitnessEntry) -> Void) {
        completion(FitnessEntry(date: Date(), data: WidgetTodayData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FitnessEntry>) -> Void) {
        let cal = Calendar.current
        let now = Date()
        let entry = FitnessEntry(date: now, data: WidgetTodayData.load())

        // Refresh every 30 min; wake at midnight for day reset
        let next30 = cal.date(byAdding: .minute, value: 30, to: now) ?? now
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        let nextWake = next30 < midnight ? next30 : midnight

        completion(Timeline(entries: [entry], policy: .after(nextWake)))
    }
}

// MARK: - Design tokens

private let widgetBg = Color(red: 19/255, green: 19/255, blue: 29/255)
private let ringGradient = LinearGradient(
    colors: [Color(red: 0.20, green: 0.88, blue: 0.46), Color.cyan],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// MARK: - Small widget — calorie ring only

struct SmallWidgetView: View {
    let data: WidgetTodayData

    private var progress: Double {
        guard data.kcalTarget > 0 else { return 0 }
        return min(data.kcalEaten / data.kcalTarget, 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(data.kcalEaten))")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(Int(data.kcalTarget)) kcal")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(14)
    }
}

// MARK: - Medium widget — left ring + right 3 rows

struct MediumWidgetView: View {
    let data: WidgetTodayData

    private var kcalProgress: Double {
        guard data.kcalTarget > 0 else { return 0 }
        return min(data.kcalEaten / data.kcalTarget, 1.0)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left column: large calorie ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: kcalProgress)
                    .stroke(ringGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(data.kcalEaten))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(Int(data.kcalTarget))")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                    Text("kcal")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.30))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Vertical separator
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 10)

            // Right column: protein, steps, water
            VStack(spacing: 0) {
                MediumMetricRow(
                    icon: "fork.knife",
                    color: Color(red: 1.0, green: 0.65, blue: 0.2),
                    value: "\(Int(data.proteinEaten))",
                    target: "\(Int(data.proteinTarget)) g"
                )
                rowDivider
                MediumMetricRow(
                    icon: "figure.walk",
                    color: Color(red: 0.25, green: 0.85, blue: 0.45),
                    value: "\(data.steps)",
                    target: "\(data.stepsTarget) passi"
                )
                rowDivider
                MediumMetricRow(
                    icon: "drop.fill",
                    color: Color(red: 0.15, green: 0.75, blue: 1.0),
                    value: String(format: "%.1f", data.waterLiters),
                    target: String(format: "%.1f L", data.waterTarget)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}

private struct MediumMetricRow: View {
    let icon: String
    let color: Color
    let value: String
    let target: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(target)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Lock screen circular

struct CircularWidgetView: View {
    let data: WidgetTodayData

    private var progress: Double {
        guard data.kcalTarget > 0 else { return 0 }
        return min(data.kcalEaten / data.kcalTarget, 1.0)
    }

    var body: some View {
        ZStack {
            ProgressView(value: progress)
                .progressViewStyle(.circular)
                .widgetAccentable()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                Text("\(Int(data.kcalEaten))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - Lock screen rectangular

struct RectangularWidgetView: View {
    let data: WidgetTodayData

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("\(Int(data.kcalEaten))/\(Int(data.kcalTarget)) kcal", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            HStack(spacing: 4) {
                Text("🥩")
                    .font(.caption2)
                Text("\(Int(data.proteinEaten))/\(Int(data.proteinTarget)) g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Entry view

struct FitnessWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: FitnessEntry

    var body: some View {
        #if os(visionOS)
        if family == .systemMedium {
            MediumWidgetView(data: entry.data)
        } else {
            SmallWidgetView(data: entry.data)
        }
        #else
        switch family {
        case .systemMedium:
            MediumWidgetView(data: entry.data)
        case .accessoryCircular:
            CircularWidgetView(data: entry.data)
        case .accessoryRectangular:
            RectangularWidgetView(data: entry.data)
        default:
            SmallWidgetView(data: entry.data)
        }
        #endif
    }
}

// MARK: - Widget configuration

struct FitnessWidget: Widget {
    let kind = "FitnessWidget"

    private var families: [WidgetFamily] {
        #if os(visionOS)
        return [.systemSmall, .systemMedium]
        #else
        return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular]
        #endif
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FitnessProvider()) { entry in
            FitnessWidgetEntryView(entry: entry)
                .containerBackground(widgetBg, for: .widget)
        }
        .configurationDisplayName("Fitness")
        .description("Calorie, proteine, acqua e passi di oggi.")
        .supportedFamilies(families)
    }
}
