import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var preservedStorePath: String?
    @State private var mostraPausa = false

    var body: some View {
        tabView
        .environmentObject(appState)
        // Lo spazio "Un attimo" si apre sopra tutto, mai dentro la navigazione
        // del diario: il tracker non deve restare visibile nemmeno di sbieco.
        .fullScreenCover(isPresented: $mostraPausa) {
            PausaSpaceView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .apriPausa)) { _ in
            mostraPausa = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pausaVaiAMangiare)) { _ in
            selectedTab = 1
        }
        .onAppear {
            appState.seedFoodsIfNeeded(context: context)
            appState.seedExercisesIfNeeded(context: context)
            appState.migrateExercisesIfNeeded(context: context)
            appState.migrateTemplateExercisesIfNeeded(context: context)
            appState.setupInitialTargets(context: context)
            preservedStorePath = StoreRecovery.preservedPath
            if PausaSignal.consuma() { mostraPausa = true }
        }
        // Il controllo del Centro di Controllo lascia un segnale nel gruppo
        // condiviso e apre l'app: qui lo si raccoglie.
        .onChange(of: scenePhase) { _, fase in
            if fase == .active, PausaSignal.consuma() { mostraPausa = true }
        }
        // Deep link dal widget: dcfitness://sommario, ://cibo, ://acqua
        .onOpenURL { url in
            switch url.host() {
            case "cibo", "acqua": selectedTab = 1
            case "palestra":      selectedTab = 3
            case "cardio":        selectedTab = 7
            case "pausa":         mostraPausa = true
            default:              selectedTab = 0
            }
        }
        .alert("Database ripartito da zero", isPresented: Binding(
            get: { preservedStorePath != nil },
            set: { if !$0 { preservedStorePath = nil } }
        )) {
            Button("Ripristina un backup") {
                StoreRecovery.clear()
                preservedStorePath = nil
                showSettings = true
            }
            Button("Ho capito", role: .cancel) {
                StoreRecovery.clear()
                preservedStorePath = nil
            }
        } message: {
            Text("""
                 Non è stato possibile aprire il database esistente, così l'app è ripartita con \
                 uno vuoto. I dati vecchi non sono stati cancellati: sono al sicuro sul \
                 dispositivo. Puoi rimettere tutto a posto importando l'ultimo backup dalle \
                 impostazioni.
                 """)
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

    // MARK: - Tab bar

    private var tabView: some View {
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
            Tab("Cardio", systemImage: "figure.run", value: 7) {
                RunView(showSettings: $showSettings)
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
        .tabBarMinimizeBehavior(.onScrollDown)
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
            PausaBtn()
            GearBtn { showSettings = true }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
    }
}

// MARK: - Ingresso allo spazio "Un attimo"

/// Presente in ogni testata, sempre nello stesso posto. Nel momento in cui
/// serve non si cerca: si sa già dov'è. Non cambia aspetto in base ai dati e
/// non si accende mai in reazione a quello che hai mangiato — sarebbe un
/// giudizio travestito da aiuto.
struct PausaBtn: View {
    var body: some View {
        Button {
            NotificationCenter.default.post(name: .apriPausa, object: nil)
        } label: {
            Image(systemName: "wind")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Pausa.seafoam)
                .frame(width: 36, height: 36)
                .background(Color.card, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Un attimo")
    }
}

extension Notification.Name {
    static let apriPausa = Notification.Name("apriPausa")
}
