import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.bg.ignoresSafeArea()
                switch selectedTab {
                case 0: TodayView(showSettings: $showSettings)
                case 1: DiaryView(showSettings: $showSettings)
                case 2: FoodsView(showSettings: $showSettings)
                case 3: ChartsView(showSettings: $showSettings)
                case 4: ResultsView(showSettings: $showSettings)
                default: TodayView(showSettings: $showSettings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HTTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(appState)
        .onAppear { appState.seedFoodsIfNeeded(context: context) }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Custom Tab Bar

struct HTTabBar: View {
    @Binding var selected: Int

    private let items: [(icon: String, label: String)] = [
        ("circle.fill",       "Oggi"),
        ("list.bullet",       "Diario"),
        ("plus.rectangle",    "Alimenti"),
        ("waveform.path.ecg", "Grafici"),
        ("chart.bar.fill",    "Risultati"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.brd2).frame(height: 1)
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
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 14)
                            .fill(selected == i ? Color.acc.opacity(0.15) : .clear))
                        .overlay(alignment: .bottom) {
                            if selected == i {
                                RoundedRectangle(cornerRadius: 2).fill(Color.acc2)
                                    .frame(width: 24, height: 3).offset(y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.top, 8).frame(height: 82)
            Color.bg.frame(maxWidth: .infinity).frame(height: 34)
        }
        .background(Color.bg.opacity(0.95).background(.ultraThinMaterial))
    }
}

// MARK: - Shared Page Header con gear

struct PageHeader: View {
    let title: String
    let subtitle: String?
    @Binding var showSettings: Bool

    init(_ title: String, subtitle: String? = nil, showSettings: Binding<Bool>) {
        self.title = title; self.subtitle = subtitle; self._showSettings = showSettings
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.txt)
                if let sub = subtitle {
                    Text(sub).font(.system(size: 13)).foregroundColor(.muted)
                }
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.muted)
                    .frame(width: 36, height: 36)
                    .background(Color.card).cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
    }
}
