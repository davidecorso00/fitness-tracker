import SwiftUI
#if os(watchOS)
import WatchKit
#endif

// Tre schermate, scorrevoli lateralmente. Al polso serve leggere un numero in
// un secondo e toccare una volta sola: niente navigazione profonda.

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchTodayView()
            WatchWaterView()
            WatchFoodView()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Oggi

struct WatchTodayView: View {
    @EnvironmentObject private var store: WatchSessionStore

    private var budget: CalorieBudget {
        CalorieBudget(consumed: store.summary.kcalEaten, target: store.summary.kcalTarget)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: min(budget.progress, 1))
                        .stroke(budget.isOver ? Color.orange : Color.green,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(abs(budget.remaining)))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(budget.isOver ? "oltre" : "rimaste")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 110, height: 110)
                .padding(.top, 4)

                metric("Mangiate", "\(Int(store.summary.kcalEaten))",
                       of: "\(Int(store.summary.kcalTarget)) kcal")
                metric("Proteine", "\(Int(store.summary.proteinEaten))",
                       of: "\(Int(store.summary.proteinTarget)) g")
                metric("Passi", "\(store.summary.steps)",
                       of: "\(store.summary.stepsTarget)")

                if store.summary.updatedAt == .distantPast {
                    Text("Apri l'app sull'iPhone per sincronizzare")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Oggi")
    }

    private func metric(_ label: String, _ value: String, of target: String) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
            Text("/ \(target)").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Acqua

struct WatchWaterView: View {
    @EnvironmentObject private var store: WatchSessionStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(String(format: "%.1f / %.1f L",
                            store.summary.waterLiters, store.summary.waterTarget))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)

                waterButton("Bicchiere", "0.2 L", 0.2)
                waterButton("Bottiglietta", "0.5 L", 0.5)
                waterButton("Bottiglia", "1.5 L", 1.5)

                if store.pendingActions > 0 {
                    Label("\(store.pendingActions) in invio", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Acqua")
    }

    private func waterButton(_ title: String, _ subtitle: String, _ liters: Double) -> some View {
        Button {
            store.logWater(liters)
            WKInterfaceDeviceHaptic.success()
        } label: {
            HStack {
                Image(systemName: "drop.fill").foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Cibo rapido

struct WatchFoodView: View {
    @EnvironmentObject private var store: WatchSessionStore

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if store.summary.quickFoods.isEmpty {
                    Text("Nessun alimento recente.\nRegistrane qualcuno dall'iPhone.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                } else {
                    ForEach(store.summary.quickFoods) { food in
                        Button {
                            store.logFood(food)
                            WKInterfaceDeviceHaptic.success()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(food.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                    Text("\(food.grams.clean)g · \(Int(food.kcal)) kcal")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Rapido")
    }
}

// MARK: - Feedback aptico

enum WKInterfaceDeviceHaptic {
    static func success() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
}
