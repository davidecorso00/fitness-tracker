import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .environmentObject(appState)
        .onAppear { appState.seedFoodsIfNeeded(context: context) }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
    }

    // MARK: - iOS 18+ Tab API (gets Liquid Glass on iOS 26 automatically)

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Sommario", systemImage: "heart.fill", value: 0) {
                TodayView(showSettings: $showSettings)
            }
            Tab("Diario", systemImage: "list.bullet", value: 1) {
                DiaryView(showSettings: $showSettings)
            }
            Tab("Alimenti", systemImage: "fork.knife", value: 2) {
                FoodsView(showSettings: $showSettings)
            }
            Tab("Grafici", systemImage: "chart.xyaxis.line", value: 3) {
                ChartsView(showSettings: $showSettings)
            }
            Tab("Risultati", systemImage: "trophy.fill", value: 4) {
                ResultsView(showSettings: $showSettings)
            }
        }
        .tint(.ringRed)
        .modifier(TabMinimizeModifier())
    }

    // MARK: - iOS 17 fallback

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            TodayView(showSettings: $showSettings)
                .tabItem { Label("Sommario", systemImage: "heart.fill") }.tag(0)
            DiaryView(showSettings: $showSettings)
                .tabItem { Label("Diario", systemImage: "list.bullet") }.tag(1)
            FoodsView(showSettings: $showSettings)
                .tabItem { Label("Alimenti", systemImage: "fork.knife") }.tag(2)
            ChartsView(showSettings: $showSettings)
                .tabItem { Label("Grafici", systemImage: "chart.xyaxis.line") }.tag(3)
            ResultsView(showSettings: $showSettings)
                .tabItem { Label("Risultati", systemImage: "trophy.fill") }.tag(4)
        }
        .tint(.ringRed)
    }
}

// MARK: - Tab Minimize Modifier (iOS 26+)

struct TabMinimizeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
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
