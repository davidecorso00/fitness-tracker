import SwiftUI

struct CiboView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab = 0  // 0 = Diario, 1 = Alimenti, 2 = Piatti

    private var subtitle: String {
        switch selectedTab {
        case 1: return "Database personale"
        case 2: return "Ricette salvate"
        default: return appState.currentDate.fullDisplay
        }
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cibo")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.muted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        if selectedTab == 0 {
                            NavBtn(icon: "chevron.left") { appState.goBack() }
                            NavBtn(icon: "chevron.right", disabled: !appState.canGoForward) { appState.goForward() }
                        }
                        GearBtn { showSettings = true }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                Picker("", selection: $selectedTab) {
                    Text("Diario").tag(0)
                    Text("Alimenti").tag(1)
                    Text("Piatti").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20).padding(.bottom, 8)

                switch selectedTab {
                case 1:
                    FoodsView(showSettings: $showSettings, embedded: true)
                case 2:
                    CustomMealsView()
                default:
                    DiaryView(showSettings: $showSettings, embedded: true)
                }
            }
        )
    }
}
