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
            SettingsView().environmentObject(appState)
        }
    }
}

// MARK: - Apple Fitness Tab Bar

struct HTTabBar: View {
    @Binding var selected: Int

    private let items: [(icon: String, iconFill: String, label: String)] = [
        ("heart",              "heart.fill",              "Sommario"),
        ("list.bullet",        "list.bullet",             "Diario"),
        ("fork.knife",         "fork.knife",              "Alimenti"),
        ("chart.xyaxis.line",  "chart.xyaxis.line",       "Grafici"),
        ("trophy",             "trophy.fill",             "Risultati"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<items.count, id: \.self) { i in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = i }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: selected == i ? items[i].iconFill : items[i].icon)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(selected == i ? .white : .muted)
                                .frame(width: 28, height: 22)
                            Text(items[i].label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(selected == i ? .white : .muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if selected == i {
                                    Capsule()
                                        .fill(Color.white.opacity(0.15))
                                        .matchedGeometryEffect(id: "tabpill", in: tabNS)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(.ultraThinMaterial.opacity(0.97))
        .environment(\.colorScheme, .dark)
    }

    @Namespace private var tabNS
}

// MARK: - Page Header

struct PageHeader: View {
    let title: String; let subtitle: String?
    @Binding var showSettings: Bool

    init(_ title: String, subtitle: String? = nil, showSettings: Binding<Bool>) {
        self.title = title; self.subtitle = subtitle; self._showSettings = showSettings
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.txt)
                if let sub = subtitle {
                    Text(sub).font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                }
            }
            Spacer()
            GearBtn { showSettings = true }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
    }
}
