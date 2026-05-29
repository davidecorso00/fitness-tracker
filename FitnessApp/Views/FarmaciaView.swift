import SwiftUI

struct FarmaciaView: View {
    @Binding var showSettings: Bool

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Farmacia")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text("I tuoi farmaci")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.muted)
                    }
                    Spacer()
                    GearBtn { showSettings = true }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.muted.opacity(0.4))
                    Text("In arrivo")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.muted)
                    Text("Questa sezione è in sviluppo")
                        .font(.system(size: 13))
                        .foregroundColor(.muted.opacity(0.6))
                }

                Spacer()
            }
        )
    }
}
