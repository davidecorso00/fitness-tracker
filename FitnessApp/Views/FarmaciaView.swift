import SwiftUI
import SwiftData

// MARK: - FarmaciaView

struct FarmaciaView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab = 0
    @State private var showAddMedicine = false

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Farmacia")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text(selectedTab == 0 ? appState.currentDate.fullDisplay : "I tuoi farmaci e integratori")
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
                    Text("Oggi").tag(0)
                    Text("Farmaci").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20).padding(.bottom, 8)

                if selectedTab == 0 {
                    MedicineChecklistView(dateKey: appState.currentDateKey)
                } else {
                    MedicineListView(showAdd: $showAddMedicine)
                }
            }
        )
        .sheet(isPresented: $showAddMedicine) {
            AddMedicineSheet()
        }
    }
}

// MARK: - Checklist (Oggi tab)

private struct MedicineChecklistView: View {
    @Environment(\.modelContext) private var context
    let dateKey: String

    @Query private var allMedicines: [Medicine]
    @Query private var allLogs: [MedicineLog]

    private var mattinaGroup: [Medicine] {
        allMedicines.filter { $0.isDaily && !$0.useTime && $0.timingPhase == "Mattina" }
            .sorted { $0.name < $1.name }
    }
    private var pomeriggioGroup: [Medicine] {
        allMedicines.filter { $0.isDaily && !$0.useTime && $0.timingPhase == "Pomeriggio" }
            .sorted { $0.name < $1.name }
    }
    private var seraGroup: [Medicine] {
        allMedicines.filter { $0.isDaily && !$0.useTime && $0.timingPhase == "Sera" }
            .sorted { $0.name < $1.name }
    }
    private var timedGroup: [Medicine] {
        allMedicines.filter { $0.isDaily && $0.useTime }
            .sorted { ($0.timingHour * 60 + $0.timingMinute) < ($1.timingHour * 60 + $1.timingMinute) }
    }
    private var onDemandGroup: [Medicine] {
        allMedicines.filter { !$0.isDaily }.sorted { $0.name < $1.name }
    }

    private func isTaken(_ medicine: Medicine) -> Bool {
        allLogs.first { $0.medicineStableId == medicine.stableId && $0.dayKey == dateKey }?.taken ?? false
    }

    private func toggle(_ medicine: Medicine) {
        if let log = allLogs.first(where: { $0.medicineStableId == medicine.stableId && $0.dayKey == dateKey }) {
            log.taken.toggle()
        } else {
            context.insert(MedicineLog(medicineStableId: medicine.stableId, dayKey: dateKey, taken: true))
        }
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if allMedicines.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.muted.opacity(0.3))
                        Text("Nessun farmaco aggiunto")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(.muted)
                        Text("Vai su \"Farmaci\" per aggiungerne uno")
                            .font(.system(size: 13)).foregroundColor(.muted.opacity(0.6))
                    }
                    .padding(.top, 80)
                } else {
                    if !mattinaGroup.isEmpty {
                        MedicineGroupCard(
                            phase: "Mattina", icon: "sunrise.fill", color: .gymOrange,
                            medicines: mattinaGroup, isTaken: isTaken, toggle: toggle
                        )
                    }
                    if !pomeriggioGroup.isEmpty {
                        MedicineGroupCard(
                            phase: "Pomeriggio", icon: "sun.max.fill", color: Color(hex: "FFD60A"),
                            medicines: pomeriggioGroup, isTaken: isTaken, toggle: toggle
                        )
                    }
                    if !seraGroup.isEmpty {
                        MedicineGroupCard(
                            phase: "Sera", icon: "moon.fill", color: Color(hex: "BF5AF2"),
                            medicines: seraGroup, isTaken: isTaken, toggle: toggle
                        )
                    }
                    if !timedGroup.isEmpty {
                        MedicineGroupCard(
                            phase: "Orario specifico", icon: "clock.fill", color: .ringBlue,
                            medicines: timedGroup, isTaken: isTaken, toggle: toggle
                        )
                    }
                    if !onDemandGroup.isEmpty {
                        MedicineGroupCard(
                            phase: "Al bisogno", icon: "pills.fill", color: .muted,
                            medicines: onDemandGroup, isTaken: isTaken, toggle: toggle
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

private struct MedicineGroupCard: View {
    let phase: String
    let icon: String
    let color: Color
    let medicines: [Medicine]
    let isTaken: (Medicine) -> Bool
    let toggle: (Medicine) -> Void

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(color)
                    Text(phase)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                    Spacer()
                    let takenCount = medicines.filter { isTaken($0) }.count
                    Text("\(takenCount)/\(medicines.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.muted)
                }

                ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
                    if index > 0 {
                        Rectangle().fill(Color.brd).frame(height: 0.5)
                    }
                    MedicineCheckRow(
                        medicine: medicine,
                        color: color,
                        taken: isTaken(medicine)
                    ) { toggle(medicine) }
                }
            }
        }
    }
}

private struct MedicineCheckRow: View {
    let medicine: Medicine
    let color: Color
    let taken: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(taken ? color : Color.white.opacity(0.25), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if taken {
                        Circle().fill(color).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: taken)

                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(taken ? .muted : .txt)
                        .strikethrough(taken, color: .muted)
                    if medicine.useTime {
                        Text(String(format: "%02d:%02d", medicine.timingHour, medicine.timingMinute))
                            .font(.system(size: 11))
                            .foregroundColor(.muted)
                    }
                }

                Spacer()

                let isF = medicine.category == "Farmaco"
                let catColor = isF ? Color(hex: "FF6B6B") : Color(hex: "4ECDC4")
                Text(medicine.category)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(catColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(catColor.opacity(0.15), in: Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medicine List (Farmaci tab)

private struct MedicineListView: View {
    @Environment(\.modelContext) private var context
    @Binding var showAdd: Bool

    @Query(sort: \Medicine.createdAt) private var medicines: [Medicine]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                GlassButton(icon: "plus", label: "Aggiungi farmaco / integratore", color: .acc) {
                    showAdd = true
                }
                .frame(maxWidth: .infinity)

                if !medicines.isEmpty {
                    HTCard {
                        VStack(spacing: 0) {
                            ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
                                if index > 0 {
                                    Rectangle().fill(Color.brd).frame(height: 0.5).padding(.leading, 50)
                                }
                                MedicineListRow(medicine: medicine)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }
}

private struct MedicineListRow: View {
    @Environment(\.modelContext) private var context
    let medicine: Medicine

    private var isF: Bool { medicine.category == "Farmaco" }
    private var catColor: Color { isF ? Color(hex: "FF6B6B") : Color(hex: "4ECDC4") }

    private var timingLabel: String {
        medicine.useTime
            ? String(format: "%02d:%02d", medicine.timingHour, medicine.timingMinute)
            : medicine.timingPhase
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(catColor.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: isF ? "pills.fill" : "leaf.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(catColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(medicine.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.txt)
                HStack(spacing: 4) {
                    Text(medicine.category).font(.system(size: 11)).foregroundColor(.muted)
                    Text("·").foregroundColor(.muted)
                    Text(medicine.isDaily ? "Giornaliero" : "Al bisogno")
                        .font(.system(size: 11)).foregroundColor(.muted)
                    Text("·").foregroundColor(.muted)
                    Text(timingLabel).font(.system(size: 11)).foregroundColor(.muted)
                }
            }

            Spacer()

            Button {
                context.delete(medicine)
                try? context.save()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.muted)
                    .frame(width: 24, height: 24)
                    .background(Color.card2, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Add Medicine Sheet

private struct AddMedicineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = "Farmaco"
    @State private var isDaily = true
    @State private var useTime = false
    @State private var phase = "Mattina"
    @State private var timingDate = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()

    private let categories = ["Farmaco", "Integratore"]
    private let phases = ["Mattina", "Pomeriggio", "Sera"]
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Nome
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NOME")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.muted).kerning(0.6)
                            TextField("es. Vitamina D, Paracetamolo...", text: $name)
                                .font(.system(size: 16))
                                .foregroundColor(.txt)
                                .padding(14)
                                .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // Tipo
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TIPO")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.muted).kerning(0.6)
                            Picker("", selection: $category) {
                                ForEach(categories, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Giornaliero
                        HTCard {
                            Toggle(isOn: $isDaily) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Giornaliero")
                                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.txt)
                                    Text("Da prendere ogni giorno")
                                        .font(.system(size: 12)).foregroundColor(.muted)
                                }
                            }
                            .tint(Color.acc)
                        }

                        // Orario / Fase
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ORARIO / FASE")
                                .font(.system(size: 11, weight: .bold)).foregroundColor(.muted).kerning(0.6)
                            HTCard {
                                VStack(spacing: 14) {
                                    Picker("", selection: $useTime) {
                                        Text("Fase").tag(false)
                                        Text("Ora specifica").tag(true)
                                    }
                                    .pickerStyle(.segmented)

                                    if useTime {
                                        DatePicker("", selection: $timingDate, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.wheel)
                                            .labelsHidden()
                                            .frame(maxWidth: .infinity)
                                            .colorScheme(.dark)
                                    } else {
                                        Picker("", selection: $phase) {
                                            ForEach(phases, id: \.self) { Text($0).tag($0) }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                }
                            }
                        }

                        PillButton(label: "Aggiungi", disabled: !canSave) { save() }
                    }
                    .padding(20)
                }
            )
            .navigationTitle("Nuovo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.acc)
                }
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let m = Medicine(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            isDaily: isDaily,
            useTime: useTime,
            timingPhase: phase,
            timingHour: cal.component(.hour, from: timingDate),
            timingMinute: cal.component(.minute, from: timingDate)
        )
        context.insert(m)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
