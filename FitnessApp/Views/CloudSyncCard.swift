import SwiftUI
import UIKit

/// Stato della sincronizzazione con iCloud (FitnessApp/CloudSync.swift) e interruttore.
struct CloudSyncCard: View {
    @ObservedObject private var sync = CloudSync.shared
    @AppStorage(CloudSync.enabledKey) private var enabled = true

    var body: some View {
        LimitGroup(title: "iCloud") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $enabled) {
                    Text("Sincronizza con iCloud")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "cccccc"))
                }
                .tint(.acc)

                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true)

                if case .failed(let detail) = sync.mode {
                    Text(detail)
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.muted)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Copia i dettagli") { UIPasteboard.general.string = detail }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.acc2)
                }

                if sync.mode == .active {
                    detail("Ultima ricezione: \(format(sync.lastImport))")
                    detail("Ultimo invio: \(format(sync.lastExport))")
                }
                detail(sync.accountAvailable
                       ? "Account iCloud: connesso"
                       : "Account iCloud: non rilevato. Accedi con il tuo Apple ID in Impostazioni di iOS.")
                if let error = sync.lastError {
                    detail("Ultimo errore: \(error)")
                }
                detail("I dati stanno nel tuo iCloud privato, legati al tuo Apple ID, e si aggiornano su "
                       + "iPhone, iPad e Mac quando apri l'app. Chi usa l'app con un altro Apple ID non "
                       + "vede i tuoi dati. L'interruttore vale dalla prossima apertura dell'app.")
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }

    private var statusText: String {
        switch sync.mode {
        case .active:        return "Attiva"
        case .off:           return enabled ? "Parte alla prossima apertura dell'app" : "Spenta"
        case .failed:        return "Non riuscita: i dati restano solo su questo dispositivo."
        }
    }

    private var statusColor: Color {
        switch sync.mode {
        case .active: return .ringGreen
        case .off:    return .muted
        case .failed: return .gymOrange
        }
    }

    private func format(_ date: Date?) -> String {
        date.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "ancora nessuna"
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11)).foregroundColor(.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}
