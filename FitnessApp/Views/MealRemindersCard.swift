import SwiftUI
import SwiftData

/// Promemoria dei pasti: orari fissi, uguali ogni giorno.
struct MealRemindersCard: View {
    @State private var attivi = MealReminders.attivi
    @State private var slot = MealReminders.slot

    var body: some View {
        LimitGroup(title: "Orari dei pasti") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Promemoria a orari fissi, sempre gli stessi. Non reagiscono mai a quello che hai registrato: mangiare a intervalli regolari è la cosa che più riduce le abbuffate, e un orario è solo un orario.")
                    .font(.system(size: 12))
                    .foregroundColor(.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: $attivi) {
                    Text("Attivi")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "cccccc"))
                }
                .tint(.acc)
                .onChange(of: attivi) { _, v in
                    if v { MealReminders.chiediPermesso() }
                    MealReminders.attivi = v
                }

                if attivi {
                    Rectangle().fill(Color.brd).frame(height: 0.5)

                    ForEach($slot) { $s in
                        HStack {
                            Toggle("", isOn: $s.attivo)
                                .labelsHidden()
                                .tint(.acc)
                                .onChange(of: s.attivo) { _, _ in MealReminders.slot = slot }

                            Text(s.nome)
                                .font(.system(size: 15))
                                .foregroundColor(s.attivo ? Color(hex: "cccccc") : .muted)

                            Spacer()

                            DatePicker("", selection: Binding(
                                get: {
                                    Calendar.current.date(bySettingHour: s.ora, minute: s.minuto,
                                                          second: 0, of: Date()) ?? Date()
                                },
                                set: { nuovo in
                                    let c = Calendar.current.dateComponents([.hour, .minute], from: nuovo)
                                    s.ora = c.hour ?? s.ora
                                    s.minuto = c.minute ?? s.minuto
                                    MealReminders.slot = slot
                                }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .disabled(!s.attivo)
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }
}

// MARK: - Backup automatico

struct AutoBackupCard: View {
    @Environment(\.modelContext) private var context

    @State private var abilitato = AutoBackup.abilitato
    @State private var ultimo = AutoBackup.ultimoAutomatico
    @State private var copie = AutoBackup.copie.count

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM 'alle' HH:mm"; return f
    }()

    var body: some View {
        LimitGroup(title: "Backup automatico") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $abilitato) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Una copia al giorno")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "cccccc"))
                        Text("Silenziosa, quando chiudi l'app. Ne tiene sette.")
                            .font(.system(size: 11)).foregroundColor(.muted)
                    }
                }
                .tint(.acc)
                .onChange(of: abilitato) { _, v in AutoBackup.abilitato = v }

                if let ultimo {
                    Text("Ultima copia: \(Self.fmt.string(from: ultimo)) · \(copie) salvate")
                        .font(.system(size: 12)).foregroundColor(.muted)
                } else {
                    Text("Nessuna copia ancora.")
                        .font(.system(size: 12)).foregroundColor(.muted)
                }

                Button("Fai una copia adesso") {
                    if AutoBackup.esegui(context: context) {
                        ultimo = AutoBackup.ultimoAutomatico
                        copie = AutoBackup.copie.count
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.acc)

                Rectangle().fill(Color.brd).frame(height: 0.5)

                // Va detto chiaramente cosa questo backup NON copre, altrimenti
                // dà una sicurezza che non ha.
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12)).foregroundColor(.gymOrange)
                    Text(avvertenza)
                        .font(.system(size: 11)).foregroundColor(.gymOrange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
        .onAppear {
            abilitato = AutoBackup.abilitato
            ultimo = AutoBackup.ultimoAutomatico
            copie = AutoBackup.copie.count
        }
    }

    private var avvertenza: String {
        let base = "Queste copie stanno dentro l'app: proteggono da un aggiornamento andato storto, non dal telefono perso o dall'app disinstallata. Per quello serve l'export qui sotto, salvato su iCloud Drive."
        if let g = AutoBackup.giorniDallUltimoManuale, g >= 30 {
            return base + " L'ultimo export manuale è di \(g) giorni fa."
        }
        if AutoBackup.giorniDallUltimoManuale == nil {
            return base + " Non ne hai ancora fatto uno."
        }
        return base
    }
}
