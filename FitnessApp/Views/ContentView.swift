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
        .onAppear {
            appState.seedFoodsIfNeeded(context: context)
            appState.setupInitialTargets(context: context)
        }
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
            Tab("Cibo", systemImage: "fork.knife", value: 1) {
                CiboView(showSettings: $showSettings)
            }
            Tab("Farmacia", systemImage: "cross.case.fill", value: 2) {
                FarmaciaView(showSettings: $showSettings)
            }
            Tab("Palestra", systemImage: "dumbbell.fill", value: 3) {
                PalestraView(showSettings: $showSettings)
            }
            Tab("Grafici", systemImage: "chart.xyaxis.line", value: 4) {
                ChartsView(showSettings: $showSettings)
            }
            Tab("Predizioni", systemImage: "chart.line.uptrend.xyaxis", value: 5) {
                PredictionsView(showSettings: $showSettings)
            }
            Tab("Risultati", systemImage: "trophy.fill", value: 6) {
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
            CiboView(showSettings: $showSettings)
                .tabItem { Label("Cibo", systemImage: "fork.knife") }.tag(1)
            FarmaciaView(showSettings: $showSettings)
                .tabItem { Label("Farmacia", systemImage: "cross.case.fill") }.tag(2)
            PalestraView(showSettings: $showSettings)
                .tabItem { Label("Palestra", systemImage: "dumbbell.fill") }.tag(3)
            ChartsView(showSettings: $showSettings)
                .tabItem { Label("Grafici", systemImage: "chart.xyaxis.line") }.tag(4)
            PredictionsView(showSettings: $showSettings)
                .tabItem { Label("Predizioni", systemImage: "chart.line.uptrend.xyaxis") }.tag(5)
            ResultsView(showSettings: $showSettings)
                .tabItem { Label("Risultati", systemImage: "trophy.fill") }.tag(6)
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
