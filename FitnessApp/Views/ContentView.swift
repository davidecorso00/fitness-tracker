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
            appState.seedExercisesIfNeeded(context: context)
            appState.migrateExercisesIfNeeded(context: context)
            appState.migrateTemplateExercisesIfNeeded(context: context)
            appState.setupInitialTargets(context: context)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: Binding(
            get: { appState.showWorkoutSheet },
            set: { appState.showWorkoutSheet = $0 }
        )) {
            if let session = appState.activeWorkoutSession {
                WorkoutSessionView(session: session)
                    .environmentObject(appState)
            }
        }
        .overlay(alignment: .bottom) {
            if let session = appState.activeWorkoutSession, !appState.showWorkoutSheet {
                ActiveWorkoutMiniBar(session: session) {
                    appState.showWorkoutSheet = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.showWorkoutSheet)
            }
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

// MARK: - Active Workout Mini Bar

struct ActiveWorkoutMiniBar: View {
    var session: ActiveWorkoutSession
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 15)).foregroundColor(.gymBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.templateName)
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                    Text(session.elapsedDisplay)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gymBlue)
                }
                Spacer()
                Text("Riprendi")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.gymBlue)
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.gymBlue)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gymBlue.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
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
