import SwiftUI
import Combine
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    /// La chat dell'assistente AI: vive qui per non perderla cambiando sezione.
    @StateObject private var assistant = FoodAssistantSession()
    @State private var selectedTab: Int
    @State private var showSettings = false
    @State private var preservedStorePath: String?
    @State private var mostraPausa = false

    /// Le 4 sezioni del menu scelte in Impostazioni; le altre sono in "Altro".
    @AppStorage(TabBarLayout.storageKey) private var menuRaw = TabBarLayout.defaultRaw
    /// Sezione aperta dentro "Altro" (nil = la lista).
    @State private var moreOpened: AppSection?

    init() {
        // Parte dalla prima sezione del menu, che non è per forza il Sommario.
        let saved = UserDefaults.standard.string(forKey: TabBarLayout.storageKey) ?? ""
        _selectedTab = State(initialValue: TabBarLayout.sections(from: saved).first?.tag ?? 0)
    }

    private var barSections: [AppSection] { TabBarLayout.sections(from: menuRaw) }
    private var moreSections: [AppSection] { AppSection.allCases.filter { !barSections.contains($0) } }

    /// Apre una sezione: dal menu se c'è, altrimenti dentro "Altro".
    private func open(_ section: AppSection) {
        if barSections.contains(section) {
            selectedTab = section.tag
        } else {
            moreOpened = section
            selectedTab = AppSection.moreTag
        }
    }

    /// Primo avvio: dati iniziali, copie doppie e recupero da Salute. Su un
    /// dispositivo vuoto con iCloud aspetta prima i dati dell'iCloud, altrimenti
    /// creerebbe alimenti, esercizi e obiettivi che esistono già.
    @MainActor
    private func startupSetup() async {
        let hadData = ((try? context.fetchCount(FetchDescriptor<FoodItem>())) ?? 0) > 0
            || ((try? context.fetchCount(FetchDescriptor<AppLimits>())) ?? 0) > 0
        await CloudSync.shared.waitUntilSettled(storeHadData: hadData)
        CloudDedupe.run(context: context)
        appState.seedFoodsIfNeeded(context: context)
        appState.seedExercisesIfNeeded(context: context)
        appState.migrateExercisesIfNeeded(context: context)
        appState.migrateTemplateExercisesIfNeeded(context: context)
        appState.setupInitialTargets(context: context)
        await HealthKitManager.shared.backfillRecentDays(context: context)
        await CardioRecorder.repairMissingHeartRate(context: context)
    }

    var body: some View {
        tabView
        .environmentObject(appState)
        .environmentObject(assistant)
        // Conferma dall'assistente: si va al diario del giorno giusto e si apre
        // l'inserimento al volo già compilato.
        .onChange(of: appState.pendingQuickAdd?.id) { _, id in
            guard id != nil, let prefill = appState.pendingQuickAdd else { return }
            appState.currentDate = Calendar.current.startOfDay(for: prefill.date)
            open(.cibo)
        }
        .sheet(item: Binding(
            get: { appState.pendingQuickAdd },
            set: { appState.pendingQuickAdd = $0 }
        )) { prefill in
            QuickAddSheet(meal: prefill.meal, date: prefill.date, prefill: prefill,
                          onSaved: appState.onPendingQuickAddSaved)
        }
        // Lo spazio "Un attimo" si apre sopra tutto, mai dentro la navigazione
        // del diario: il tracker non deve restare visibile nemmeno di sbieco.
        .fullScreenCover(isPresented: $mostraPausa) {
            PausaSpaceView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .apriPausa)) { _ in
            mostraPausa = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .pausaVaiAMangiare)) { _ in
            open(.cibo)
        }
        // Menu cambiato dalle impostazioni: se la sezione aperta non c'è più,
        // si torna alla prima; una sezione spostata nel menu esce da "Altro".
        .onChange(of: menuRaw) { _, _ in
            if let opened = moreOpened, barSections.contains(opened) { moreOpened = nil }
            let tags = barSections.map(\.tag) + [AppSection.moreTag]
            if !tags.contains(selectedTab) { selectedTab = barSections.first?.tag ?? 0 }
        }
        .onAppear {
            preservedStorePath = StoreRecovery.preservedPath
            if PausaSignal.consuma() { mostraPausa = true }
            Task { await startupSetup() }
        }
        // Dati arrivati da un altro dispositivo: toglie le copie doppie dello stesso
        // giorno o delle impostazioni, se due dispositivi le hanno create insieme.
        .onReceive(NotificationCenter.default.publisher(for: CloudSync.importFinished)
            .debounce(for: .seconds(3), scheduler: RunLoop.main)) { _ in
            CloudDedupe.run(context: context)
        }
        // Il controllo del Centro di Controllo lascia un segnale nel gruppo
        // condiviso e apre l'app: qui lo si raccoglie.
        .onChange(of: scenePhase) { _, fase in
            guard fase == .active else { return }
            if PausaSignal.consuma() { mostraPausa = true }
            appState.rollOverToTodayIfNeeded()
            Task { await HealthKitManager.shared.backfillRecentDays(context: context) }
            Task { await CardioRecorder.repairMissingHeartRate(context: context) }
        }
        // Mezzanotte con l'app aperta.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            appState.rollOverToTodayIfNeeded()
        }
        // Deep link dal widget: dcfitness://sommario, ://cibo, ://acqua
        .onOpenURL { url in
            switch url.host() {
            case "cibo", "acqua": open(.cibo)
            case "palestra":      open(.palestra)
            case "cardio":        open(.cardio)
            case "pausa":         mostraPausa = true
            default:              open(.sommario)
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

    /// Sempre 5 pulsanti: le 4 sezioni scelte e "Altro" con le rimanenti.
    private var tabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(barSections) { section in
                Tab(section.title, systemImage: section.icon, value: section.tag) {
                    section.content(showSettings: $showSettings)
                }
            }
            Tab("Altro", systemImage: "ellipsis", value: AppSection.moreTag) {
                MoreSectionsView(sections: moreSections, opened: $moreOpened,
                                 showSettings: $showSettings)
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
    /// Nascosto per ora. Lo spazio resta raggiungibile da Siri, dal Centro di
    /// Controllo e da dcfitness://pausa; l'interruttore è in Impostazioni.
    @AppStorage(PausaBtn.visibileKey) private var visibile = false
    static let visibileKey = "mostraPulsantePausa"

    var body: some View {
        if visibile {
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
}

/// Rimette (o toglie) il pulsante "Un attimo" dalle intestazioni.
struct PausaVisibilityCard: View {
    @AppStorage(PausaBtn.visibileKey) private var visibile = false

    var body: some View {
        LimitGroup(title: "Un attimo") {
            Toggle(isOn: $visibile) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pulsante nelle schermate")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "cccccc"))
                    Text("Anche nascosto, lo spazio si apre da Siri o dal Centro di Controllo.")
                        .font(.system(size: 11)).foregroundColor(.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.acc)
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }
}

extension Notification.Name {
    static let apriPausa = Notification.Name("apriPausa")
}
