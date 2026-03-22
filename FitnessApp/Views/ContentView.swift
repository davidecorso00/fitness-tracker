import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
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
        .environmentObject(appState)
        .onAppear { appState.seedFoodsIfNeeded(context: context) }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
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
