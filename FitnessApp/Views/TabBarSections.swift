import SwiftUI

// MARK: - Sezioni del menu in basso
//
// Il menu ha sempre 5 pulsanti: 4 sezioni scelte in Impostazioni › Menu in basso
// e "Altro", che raccoglie tutte le altre. Così il numero dei pulsanti non cambia
// e ogni sezione resta raggiungibile.

enum AppSection: String, CaseIterable, Identifiable {
    case sommario, cibo, farmacia, palestra, cardio, grafici, predizioni, risultati, ai

    /// Pulsanti scelti dall'utente; il quinto è sempre "Altro".
    static let barSlots = 4
    /// Valore del pulsante "Altro" nel TabView.
    static let moreTag = 99

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sommario:   return "Sommario"
        case .cibo:       return "Cibo"
        case .farmacia:   return "Farmacia"
        case .palestra:   return "Palestra"
        case .cardio:     return "Cardio"
        case .grafici:    return "Grafici"
        case .predizioni: return "Predizioni"
        case .risultati:  return "Risultati"
        case .ai:         return "AI"
        }
    }

    var icon: String {
        switch self {
        case .sommario:   return "heart.fill"
        case .cibo:       return "fork.knife"
        case .farmacia:   return "cross.case.fill"
        case .palestra:   return "dumbbell.fill"
        case .cardio:     return "figure.run"
        case .grafici:    return "chart.xyaxis.line"
        case .predizioni: return "chart.line.uptrend.xyaxis"
        case .risultati:  return "trophy.fill"
        case .ai:         return "sparkles"
        }
    }

    /// Valore del pulsante nel TabView: gli stessi numeri di prima.
    var tag: Int {
        switch self {
        case .sommario:   return 0
        case .cibo:       return 1
        case .farmacia:   return 2
        case .palestra:   return 3
        case .grafici:    return 4
        case .predizioni: return 5
        case .risultati:  return 6
        case .cardio:     return 7
        case .ai:         return 8
        }
    }

    @MainActor @ViewBuilder
    func content(showSettings: Binding<Bool>) -> some View {
        switch self {
        case .sommario:   TodayView(showSettings: showSettings)
        case .cibo:       CiboView(showSettings: showSettings)
        case .farmacia:   FarmaciaView(showSettings: showSettings)
        case .palestra:   PalestraView(showSettings: showSettings)
        case .cardio:     RunView(showSettings: showSettings)
        case .grafici:    ChartsView(showSettings: showSettings)
        case .predizioni: PredictionsView(showSettings: showSettings)
        case .risultati:  ResultsView(showSettings: showSettings)
        case .ai:         AIAssistantView(showSettings: showSettings)
        }
    }
}

// MARK: - Scelta salvata

/// Le sezioni del menu, salvate come "sommario,cibo,farmacia,palestra".
enum TabBarLayout {
    static let storageKey = "menuSezioni"
    /// Le stesse che l'iPhone mostrava prima con 8 sezioni: le prime 4 più "Altro".
    static let defaultSections: [AppSection] = [.sommario, .cibo, .farmacia, .palestra]
    static let defaultRaw = raw(from: defaultSections)

    /// Sempre esattamente `AppSection.barSlots` sezioni diverse: valori mancanti,
    /// doppi o sconosciuti vengono completati con quelle predefinite.
    static func sections(from raw: String) -> [AppSection] {
        var result: [AppSection] = []
        for part in raw.split(separator: ",") {
            if let s = AppSection(rawValue: String(part)), !result.contains(s) { result.append(s) }
        }
        for s in defaultSections + AppSection.allCases
        where result.count < AppSection.barSlots && !result.contains(s) {
            result.append(s)
        }
        return Array(result.prefix(AppSection.barSlots))
    }

    static func raw(from sections: [AppSection]) -> String {
        sections.map(\.rawValue).joined(separator: ",")
    }
}

// MARK: - Altro

/// Le sezioni che non sono nel menu. Una sezione aperta da qui prende il posto
/// della lista, con un pulsante per tornare indietro: niente NavigationStack,
/// perché alcune sezioni (Grafici) ne hanno già uno proprio.
struct MoreSectionsView: View {
    let sections: [AppSection]
    @Binding var opened: AppSection?
    @Binding var showSettings: Bool

    var body: some View {
        if let section = opened, sections.contains(section) {
            section.content(showSettings: $showSettings)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack {
                        Button { opened = nil } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Altro")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.ringRed)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 2)
                    .background(Color.bg)
                }
        } else {
            list
        }
    }

    private var list: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    PageHeader("Altro", subtitle: "Le sezioni che non sono nel menu", showSettings: $showSettings)

                    VStack(spacing: 10) {
                        ForEach(sections) { section in
                            Button { opened = section } label: { row(section) }
                                .buttonStyle(.plain)
                        }
                        Text("Scegli le sezioni del menu in Impostazioni › Menu in basso.")
                            .font(.system(size: 11)).foregroundColor(.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 120)
                }
            }
        )
    }

    private func row(_ section: AppSection) -> some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.ringRed)
                .frame(width: 38, height: 38)
                .background(Color.ringRed.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(section.title)
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.txt)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.muted)
        }
        .padding(14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Impostazioni

/// Scelta delle 4 sezioni del menu. Scegliere una sezione già presente in un'altra
/// posizione scambia le due: le sezioni restano sempre 4 e tutte diverse.
struct TabBarSettingsCard: View {
    @AppStorage(TabBarLayout.storageKey) private var menuRaw = TabBarLayout.defaultRaw

    private var sections: [AppSection] { TabBarLayout.sections(from: menuRaw) }

    var body: some View {
        LimitGroup(title: "Menu in basso") {
            ForEach(0..<AppSection.barSlots, id: \.self) { slot in
                HStack {
                    Text("Posizione \(slot + 1)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "cccccc"))
                    Spacer()
                    Picker("", selection: binding(for: slot)) {
                        ForEach(AppSection.allCases) { section in
                            Label(section.title, systemImage: section.icon).tag(section)
                        }
                    }
                    .labelsHidden()
                    .tint(.acc2)
                }
                .padding(.horizontal, 18).padding(.vertical, 6)
            }
            Text("Il quinto pulsante è sempre \"Altro\", con le sezioni che non hai scelto. Se scegli una sezione già presente, le due si scambiano di posto.")
                .font(.system(size: 11)).foregroundColor(.muted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.top, 4).padding(.bottom, 14)
        }
    }

    private func binding(for slot: Int) -> Binding<AppSection> {
        Binding(
            get: { sections[slot] },
            set: { new in
                var current = sections
                if let other = current.firstIndex(of: new) {
                    current.swapAt(slot, other)
                } else {
                    current[slot] = new
                }
                menuRaw = TabBarLayout.raw(from: current)
            }
        )
    }
}
