import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Contenuto — occupa tutto lo spazio disponibile
            ZStack {
                Color.bg.ignoresSafeArea()
                switch selectedTab {
                case 0: TodayView()
                case 1: DiaryView()
                case 2: FoodsView()
                case 3: ChartsView()
                case 4: LimitsView()
                default: TodayView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar in fondo
            HTTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(appState)
        .onAppear {
            appState.seedFoodsIfNeeded(context: context)
        }
    }
}

// MARK: - Custom Tab Bar

struct HTTabBar: View {
    @Binding var selected: Int

    private let items: [(icon: String, label: String)] = [
        ("circle.fill",         "Oggi"),
        ("list.bullet",         "Diario"),
        ("plus.rectangle",      "Alimenti"),
        ("waveform.path.ecg",   "Grafici"),
        ("slider.horizontal.3", "Limiti"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.brd2)
                .frame(height: 1)

            HStack(spacing: 4) {
                ForEach(0..<items.count, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selected = i }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: items[i].icon)
                                .font(.system(size: 22, weight: .medium))
                            Text(items[i].label)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(selected == i ? .txt : .muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected == i ? Color.acc.opacity(0.15) : .clear)
                        )
                        .overlay(alignment: .bottom) {
                            if selected == i {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.acc2)
                                    .frame(width: 24, height: 3)
                                    .offset(y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .frame(height: 82)

            // Riempie la safe area sotto la home indicator
            Color.bg
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .background(Color.bg.opacity(0.95).background(.ultraThinMaterial))
    }
}
