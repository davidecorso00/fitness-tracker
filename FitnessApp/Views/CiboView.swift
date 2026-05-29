import SwiftUI

struct CiboView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab = 0  // 0 = Diario, 1 = Alimenti

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                // Unified header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cibo")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        if selectedTab == 0 {
                            Text(appState.currentDate.fullDisplay)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.muted)
                        } else {
                            Text("Database personale")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.muted)
                        }
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

                // Tab picker
                Picker("", selection: $selectedTab) {
                    Text("Diario").tag(0)
                    Text("Alimenti").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20).padding(.bottom, 8)

                // Content
                if selectedTab == 0 {
                    DiaryView(showSettings: $showSettings, embedded: true)
                } else {
                    FoodsView(showSettings: $showSettings, embedded: true)
                }
            }
        )
    }
}
