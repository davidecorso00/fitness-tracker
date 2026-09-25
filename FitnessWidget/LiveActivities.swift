#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Shared attributes (mirrored from main app's LiveActivityShared.swift)

struct RunActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var isPaused: Bool
        var elapsedAtPause: Double
        var distanceMeters: Double
        var avgPaceSecPerKm: Double?
        var kcal: Double
        var bpm: Double?
        var phaseName: String?
    }
    var isWalk: Bool? = nil
}

struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
        var totalSeconds: Int
    }
    var workoutName: String
}

// MARK: - Design tokens

private let activityBg = Color(red: 19/255, green: 19/255, blue: 29/255)
private let runCyan    = Color(red: 100/255, green: 210/255, blue: 255/255)
private let walkGreen  = Color(red: 48/255,  green: 209/255, blue: 88/255)
private let restOrange = Color(red: 255/255, green: 159/255, blue: 10/255)
private let kcalRed    = Color(red: 250/255, green: 17/255, blue: 79/255)
private let paceGreen  = Color(red: 146/255, green: 232/255, blue: 42/255)
private let hrPink     = Color(red: 255/255, green: 55/255, blue: 95/255)

private func activityPaceString(_ secPerKm: Double?) -> String {
    guard let p = secPerKm, p.isFinite, p > 0, p < 3600 else { return "—" }
    return String(format: "%d'%02d\"", Int(p) / 60, Int(p) % 60)
}

private func activityDurationString(_ seconds: Double) -> String {
    let t = Int(seconds)
    let h = t / 3600, m = (t % 3600) / 60, s = t % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%02d:%02d", m, s)
}

// MARK: - Corsa o passeggiata

private extension RunActivityAttributes {
    var walk: Bool { isWalk == true }
    var icon: String { walk ? "figure.walk" : "figure.run" }
    var title: String { walk ? "Passeggiata" : "Corsa" }
    var accent: Color { walk ? walkGreen : runCyan }
}

// MARK: - Run chrono (system-driven, niente update ogni secondo)

private struct RunChronoText: View {
    let state: RunActivityAttributes.ContentState
    var font: Font = .system(size: 36, weight: .bold, design: .rounded)

    var body: some View {
        if state.isPaused {
            Text(activityDurationString(state.elapsedAtPause))
                .font(font).monospacedDigit().foregroundStyle(.white.opacity(0.6))
        } else {
            Text(timerInterval: state.startedAt...state.startedAt.addingTimeInterval(86400),
                 countsDown: false)
                .font(font).monospacedDigit().foregroundStyle(.white)
        }
    }
}

// MARK: - Run Live Activity

struct RunLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunActivityAttributes.self) { context in
            RunActivityLockView(context: context)
                .activityBackgroundTint(activityBg)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Espanso ──────────────────────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(context.attributes.accent)
                        Text(context.state.isPaused ? "In pausa" : context.attributes.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(String(format: "%.2f km", context.state.distanceMeters / 1000))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(context.attributes.accent)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    RunChronoText(state: context.state)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        expandedStat(value: activityPaceString(context.state.avgPaceSecPerKm),
                                     label: "PASSO MEDIO", color: paceGreen)
                        if let bpm = context.state.bpm {
                            expandedStat(value: "\(Int(bpm))", label: "BPM", color: hrPink)
                        }
                        expandedStat(value: "\(Int(context.state.kcal))",
                                     label: "KCAL", color: kcalRed)
                    }
                    .padding(.top, 6)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.icon)
                    .foregroundStyle(context.attributes.accent)
            } compactTrailing: {
                Text(String(format: "%.1f km", context.state.distanceMeters / 1000))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(context.attributes.accent)
            } minimal: {
                Image(systemName: context.attributes.icon)
                    .foregroundStyle(context.attributes.accent)
            }
            .keylineTint(context.attributes.accent)
        }
        .supplementalActivityFamilies([.small])   // Smart Stack su Apple Watch (watchOS 11+)
    }

    private func expandedStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit().foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vista lock screen / Smart Stack della corsa

private struct RunActivityLockView: View {
    @Environment(\.activityFamily) private var family
    let context: ActivityViewContext<RunActivityAttributes>

    var body: some View {
        if family == .small {
            watchView
        } else {
            lockScreenView
        }
    }

    // Smart Stack del Watch: tempo, km e battiti — i tre dati chiave al polso
    private var watchView: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(context.attributes.accent)
                    if let phase = context.state.phaseName {
                        Text(phase)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                RunChronoText(state: context.state,
                              font: .system(size: 26, weight: .bold, design: .rounded))
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f km", context.state.distanceMeters / 1000))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundStyle(context.attributes.accent)
                if let bpm = context.state.bpm {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill").font(.system(size: 9))
                        Text("\(Int(bpm))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(hrPink)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var lockScreenView: some View {
        HStack(spacing: 14) {
            Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(context.attributes.accent)
                .frame(width: 44, height: 44)
                .background(context.attributes.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                if let phase = context.state.phaseName {
                    Text(phase)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                RunChronoText(state: context.state,
                              font: .system(size: 28, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: "%.2f km", context.state.distanceMeters / 1000))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.attributes.accent)
            }

            VStack(alignment: .trailing, spacing: 5) {
                metric(value: activityPaceString(context.state.avgPaceSecPerKm),
                       label: "/km", color: paceGreen)
                if let bpm = context.state.bpm {
                    metric(value: "\(Int(bpm))", label: "♥", color: hrPink)
                }
                metric(value: "\(Int(context.state.kcal))", label: "kcal", color: kcalRed)
            }
        }
        .padding(16)
    }

    private func metric(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit().foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: - Rest Live Activity

struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            // ── Schermata di blocco ──────────────────────────────────────
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(restOrange)
                    .frame(width: 44, height: 44)
                    .background(restOrange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Riposo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text(context.attributes.workoutName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                    Text(timerInterval: restRange(context.state), countsDown: true)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(restOrange)
                    ProgressView(timerInterval: restRange(context.state), countsDown: true) {
                    } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.linear)
                        .tint(restOrange)
                }
            }
            .padding(16)
            .activityBackgroundTint(activityBg)
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(restOrange)
                        Text("Riposo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.workoutName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: restRange(context.state), countsDown: true)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(restOrange)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: restRange(context.state), countsDown: true) {
                    } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.linear)
                        .tint(restOrange)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(restOrange)
            } compactTrailing: {
                Text(timerInterval: restRange(context.state), countsDown: true)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(restOrange)
                    .frame(maxWidth: 44)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(restOrange)
            }
            .keylineTint(restOrange)
        }
    }

    private func restRange(_ state: RestActivityAttributes.ContentState) -> ClosedRange<Date> {
        let start = state.endDate.addingTimeInterval(-Double(state.totalSeconds))
        return start...state.endDate
    }
}
#endif
