import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Notification helper

private enum MedicineNotifications {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func schedule(_ medicine: Medicine) {
        guard medicine.notificationEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = medicine.name
        content.body = "Non hai ancora preso \(medicine.name) oggi."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = medicine.notificationHour
        comps.minute = medicine.notificationMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "farmacia-\(medicine.stableId)",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    static func cancel(stableId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["farmacia-\(stableId)"])
    }

    // Re-schedules any medicine whose repeating notification was cancelled (e.g. taken yesterday).
    static func rescheduleIfNeeded(_ medicines: [Medicine]) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let ids = Set(pending.map { $0.identifier })
            for med in medicines where med.notificationEnabled {
                if !ids.contains("farmacia-\(med.stableId)") { schedule(med) }
            }
        }
    }
}

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
    @Query private var allDoses: [MedicineDose]
    @Query private var allLogs: [MedicineLog]

    private func medicine(for dose: MedicineDose) -> Medicine? {
        allMedicines.first { $0.stableId == dose.medicineStableId }
    }

    private func doses(phase: String) -> [MedicineDose] {
        allDoses.filter { dose in
            guard medicine(for: dose)?.isDaily == true else { return false }
            return !dose.useTime && dose.timingPhase == phase
        }
        .sorted { a, b in
            a.medicineStableId == b.medicineStableId
                ? a.sortOrder < b.sortOrder
                : a.medicineStableId < b.medicineStableId
        }
    }

    private var timedDoses: [MedicineDose] {
        allDoses.filter { dose in
            guard medicine(for: dose)?.isDaily == true else { return false }
            return dose.useTime
        }
        .sorted { ($0.timingHour * 60 + $0.timingMinute) < ($1.timingHour * 60 + $1.timingMinute) }
    }

    private var onDemandDoses: [MedicineDose] {
        allDoses.filter { medicine(for: $0)?.isDaily == false }
            .sorted { a, b in
                a.medicineStableId == b.medicineStableId
                    ? a.sortOrder < b.sortOrder
                    : a.medicineStableId < b.medicineStableId
            }
    }

    private func isTaken(_ dose: MedicineDose) -> Bool {
        allLogs.first { $0.doseStableId == dose.stableId && $0.dayKey == dateKey }?.taken ?? false
    }

    private func toggle(_ dose: MedicineDose) {
        var markedTaken = false
        if let log = allLogs.first(where: { $0.doseStableId == dose.stableId && $0.dayKey == dateKey }) {
            log.taken.toggle()
            markedTaken = log.taken
        } else {
            context.insert(MedicineLog(doseStableId: dose.stableId, dayKey: dateKey, taken: true))
            markedTaken = true
        }
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard markedTaken, let med = medicine(for: dose), med.notificationEnabled else { return }
        let medDoses = allDoses.filter { $0.medicineStableId == med.stableId }
        let allTaken = medDoses.allSatisfy { d in
            if d.stableId == dose.stableId { return true }
            return allLogs.first { $0.doseStableId == d.stableId && $0.dayKey == dateKey }?.taken ?? false
        }
        if allTaken {
            let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let nowMins = (now.hour ?? 0) * 60 + (now.minute ?? 0)
            if nowMins < med.notificationHour * 60 + med.notificationMinute {
                MedicineNotifications.cancel(stableId: med.stableId)
            }
        }
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
                    let mattina = doses(phase: "Mattina")
                    let pomeriggio = doses(phase: "Pomeriggio")
                    let sera = doses(phase: "Sera")
                    let timed = timedDoses
                    let onDemand = onDemandDoses

                    if !mattina.isEmpty {
                        MedicineGroupCard(phase: "Mattina", icon: "sunrise.fill", color: .gymOrange,
                                          doses: mattina, medicines: allMedicines, isTaken: isTaken, toggle: toggle)
                    }
                    if !pomeriggio.isEmpty {
                        MedicineGroupCard(phase: "Pomeriggio", icon: "sun.max.fill", color: Color(hex: "FFD60A"),
                                          doses: pomeriggio, medicines: allMedicines, isTaken: isTaken, toggle: toggle)
                    }
                    if !sera.isEmpty {
                        MedicineGroupCard(phase: "Sera", icon: "moon.fill", color: Color(hex: "BF5AF2"),
                                          doses: sera, medicines: allMedicines, isTaken: isTaken, toggle: toggle)
                    }
                    if !timed.isEmpty {
                        MedicineGroupCard(phase: "Orario specifico", icon: "clock.fill", color: .ringBlue,
                                          doses: timed, medicines: allMedicines, isTaken: isTaken, toggle: toggle)
                    }
                    if !onDemand.isEmpty {
                        MedicineGroupCard(phase: "Al bisogno", icon: "pills.fill", color: .muted,
                                          doses: onDemand, medicines: allMedicines, isTaken: isTaken, toggle: toggle)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .onAppear { MedicineNotifications.rescheduleIfNeeded(allMedicines) }
    }
}

private struct MedicineGroupCard: View {
    let phase: String
    let icon: String
    let color: Color
    let doses: [MedicineDose]
    let medicines: [Medicine]
    let isTaken: (MedicineDose) -> Bool
    let toggle: (MedicineDose) -> Void

    private func medicineName(for dose: MedicineDose) -> String {
        medicines.first { $0.stableId == dose.medicineStableId }?.name ?? ""
    }
    private func medicineCategory(for dose: MedicineDose) -> String {
        medicines.first { $0.stableId == dose.medicineStableId }?.category ?? "Farmaco"
    }

    var body: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(color)
                    Text(phase)
                        .font(.system(size: 12, weight: .bold)).foregroundColor(color)
                    Spacer()
                    let takenCount = doses.filter { isTaken($0) }.count
                    Text("\(takenCount)/\(doses.count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(.muted)
                }

                ForEach(Array(doses.enumerated()), id: \.element.id) { index, dose in
                    if index > 0 {
                        Rectangle().fill(Color.brd).frame(height: 0.5)
                    }
                    DoseCheckRow(
                        medicineName: medicineName(for: dose),
                        category: medicineCategory(for: dose),
                        dose: dose,
                        color: color,
                        taken: isTaken(dose)
                    ) { toggle(dose) }
                }
            }
        }
    }
}

private struct DoseCheckRow: View {
    let medicineName: String
    let category: String
    let dose: MedicineDose
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
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.black)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: taken)

                VStack(alignment: .leading, spacing: 2) {
                    Text(medicineName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(taken ? .muted : .txt)
                        .strikethrough(taken, color: .muted)
                    HStack(spacing: 4) {
                        Text("\(dose.quantity) \(dose.quantity == 1 ? "pastiglia" : "pastiglie")")
                            .font(.system(size: 11)).foregroundColor(.muted)
                        if dose.useTime {
                            Text("· \(String(format: "%02d:%02d", dose.timingHour, dose.timingMinute))")
                                .font(.system(size: 11)).foregroundColor(.muted)
                        }
                    }
                }

                Spacer()

                let isF = category == "Farmaco"
                let catColor = isF ? Color(hex: "FF6B6B") : Color(hex: "4ECDC4")
                Text(category)
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
    @Query private var allDoses: [MedicineDose]
    @Query private var allLogs: [MedicineLog]

    @State private var editingMedicine: Medicine? = nil

    private func delete(_ medicine: Medicine) {
        MedicineNotifications.cancel(stableId: medicine.stableId)
        let doses = allDoses.filter { $0.medicineStableId == medicine.stableId }
        for dose in doses {
            allLogs.filter { $0.doseStableId == dose.stableId }.forEach { context.delete($0) }
            context.delete(dose)
        }
        context.delete(medicine)
        try? context.save()
    }

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
                                MedicineListRow(
                                    medicine: medicine,
                                    doses: allDoses.filter { $0.medicineStableId == medicine.stableId }
                                        .sorted { $0.sortOrder < $1.sortOrder },
                                    onEdit: { editingMedicine = medicine },
                                    onDelete: { delete(medicine) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .sheet(item: $editingMedicine) { med in
            AddMedicineSheet(
                editing: med,
                doses: allDoses.filter { $0.medicineStableId == med.stableId }
                    .sorted { $0.sortOrder < $1.sortOrder }
            )
        }
    }
}

private struct MedicineListRow: View {
    let medicine: Medicine
    let doses: [MedicineDose]
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isF: Bool { medicine.category == "Farmaco" }
    private var catColor: Color { isF ? Color(hex: "FF6B6B") : Color(hex: "4ECDC4") }

    private var doseSummary: String {
        guard !doses.isEmpty else { return "" }
        return doses.map { d in
            let timing = d.useTime
                ? String(format: "%02d:%02d", d.timingHour, d.timingMinute)
                : d.timingPhase
            return "\(d.quantity)× \(timing)"
        }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(catColor.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: isF ? "pills.fill" : "leaf.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(catColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(medicine.name)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.txt)
                    if medicine.notificationEnabled {
                        HStack(spacing: 2) {
                            Image(systemName: "bell.fill").font(.system(size: 9))
                            Text(String(format: "%02d:%02d", medicine.notificationHour, medicine.notificationMinute))
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.acc.opacity(0.8))
                    }
                }
                HStack(spacing: 4) {
                    Text(medicine.isDaily ? "Giornaliero" : "Al bisogno")
                        .font(.system(size: 11)).foregroundColor(.muted)
                    if !doseSummary.isEmpty {
                        Text("·").foregroundColor(.muted)
                        Text(doseSummary).font(.system(size: 11)).foregroundColor(.muted)
                    }
                }
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.muted)
                    .frame(width: 24, height: 24)
                    .background(Color.card2, in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.muted)
                    .frame(width: 24, height: 24)
                    .background(Color.card2, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Add Medicine Sheet

private struct DoseInput: Identifiable {
    let id = UUID()
    var quantity: Int
    var useTime: Bool
    var timingPhase: String
    var timingDate: Date

    init(quantity: Int = 1, useTime: Bool = false, timingPhase: String = "Mattina", timingHour: Int = 8, timingMinute: Int = 0) {
        self.quantity = quantity
        self.useTime = useTime
        self.timingPhase = timingPhase
        self.timingDate = Calendar.current.date(bySettingHour: timingHour, minute: timingMinute, second: 0, of: Date()) ?? Date()
    }

    init(from dose: MedicineDose) {
        self.quantity = dose.quantity
        self.useTime = dose.useTime
        self.timingPhase = dose.timingPhase
        self.timingDate = Calendar.current.date(bySettingHour: dose.timingHour, minute: dose.timingMinute, second: 0, of: Date()) ?? Date()
    }
}

private struct AddMedicineSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let editingMedicine: Medicine?
    private let existingDoses: [MedicineDose]

    @State private var name: String
    @State private var category: String
    @State private var isDaily: Bool
    @State private var doses: [DoseInput]
    @State private var notificationEnabled: Bool
    @State private var notificationDate: Date

    private let categories = ["Farmaco", "Integratore"]
    private var isEditing: Bool { editingMedicine != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(editing medicine: Medicine? = nil, doses existingDoses: [MedicineDose] = []) {
        self.editingMedicine = medicine
        self.existingDoses = existingDoses
        _name = State(initialValue: medicine?.name ?? "")
        _category = State(initialValue: medicine?.category ?? "Farmaco")
        _isDaily = State(initialValue: medicine?.isDaily ?? true)
        _doses = State(initialValue: existingDoses.isEmpty ? [DoseInput()] : existingDoses.map { DoseInput(from: $0) })
        _notificationEnabled = State(initialValue: medicine?.notificationEnabled ?? false)
        _notificationDate = State(initialValue: {
            let h = medicine?.notificationHour ?? 20
            let m = medicine?.notificationMinute ?? 0
            return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
        }())
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                sheetHeader
                Rectangle().fill(Color.brd).frame(height: 0.5)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        nameSection
                        typeSection
                        dailyToggle
                        dosesSection
                        notificationSection
                        PillButton(label: isEditing ? "Salva" : "Aggiungi", disabled: !canSave) { save() }
                    }
                    .padding(20)
                }
            }
        )
    }

    private var sheetHeader: some View {
        HStack {
            Button("Annulla") { dismiss() }
                .font(.system(size: 15)).foregroundColor(.acc)
            Spacer()
            Text(isEditing ? "Modifica" : "Nuovo")
                .font(.system(size: 16, weight: .semibold)).foregroundColor(.txt)
            Spacer()
            Text("Annulla").font(.system(size: 15)).foregroundColor(.clear)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Nome")
            TextField("es. Vitamina D, Paracetamolo...", text: $name)
                .font(.system(size: 16)).foregroundColor(.txt)
                .padding(14)
                .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Tipo")
            Picker("", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dailyToggle: some View {
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
    }

    private var dosesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Dosi")
                Spacer()
                Button {
                    doses.append(DoseInput())
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22)).foregroundColor(.acc)
                }
                .buttonStyle(.plain)
            }
            doseRows
        }
    }

    private var notificationSection: some View {
        HTCard {
            VStack(spacing: 12) {
                Toggle(isOn: $notificationEnabled) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(notificationEnabled ? .acc : .muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifica promemoria")
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(.txt)
                            Text("Avviso se non ancora preso")
                                .font(.system(size: 12)).foregroundColor(.muted)
                        }
                    }
                }
                .tint(Color.acc)

                if notificationEnabled {
                    Rectangle().fill(Color.brd).frame(height: 0.5)
                    HStack {
                        Text("Orario promemoria")
                            .font(.system(size: 14)).foregroundColor(.muted)
                        Spacer()
                        DatePicker("", selection: $notificationDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                }
            }
        }
    }

    @ViewBuilder private var doseRows: some View {
        ForEach(doses.indices, id: \.self) { i in
            DoseInputRow(dose: $doses[i], canDelete: doses.count > 1) {
                doses.remove(at: i)
            }
        }
    }

    private func save() {
        let cal = Calendar.current
        let notifHour = cal.component(.hour, from: notificationDate)
        let notifMinute = cal.component(.minute, from: notificationDate)

        if let med = editingMedicine {
            // Edit existing
            MedicineNotifications.cancel(stableId: med.stableId)
            med.name = name.trimmingCharacters(in: .whitespaces)
            med.category = category
            med.isDaily = isDaily
            med.notificationEnabled = notificationEnabled
            med.notificationHour = notifHour
            med.notificationMinute = notifMinute
            existingDoses.forEach { context.delete($0) }
            for (i, dose) in doses.enumerated() {
                context.insert(MedicineDose(
                    medicineStableId: med.stableId, quantity: dose.quantity,
                    useTime: dose.useTime, timingPhase: dose.timingPhase,
                    timingHour: cal.component(.hour, from: dose.timingDate),
                    timingMinute: cal.component(.minute, from: dose.timingDate), sortOrder: i
                ))
            }
            try? context.save()
            if notificationEnabled { MedicineNotifications.schedule(med) }
        } else {
            // Add new
            let m = Medicine(name: name.trimmingCharacters(in: .whitespaces), category: category,
                             isDaily: isDaily, notificationEnabled: notificationEnabled,
                             notificationHour: notifHour, notificationMinute: notifMinute)
            context.insert(m)
            for (i, dose) in doses.enumerated() {
                context.insert(MedicineDose(
                    medicineStableId: m.stableId, quantity: dose.quantity,
                    useTime: dose.useTime, timingPhase: dose.timingPhase,
                    timingHour: cal.component(.hour, from: dose.timingDate),
                    timingMinute: cal.component(.minute, from: dose.timingDate), sortOrder: i
                ))
            }
            try? context.save()
            if notificationEnabled {
                MedicineNotifications.requestPermission()
                MedicineNotifications.schedule(m)
            }
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

private struct DoseInputRow: View {
    @Binding var dose: DoseInput
    let canDelete: Bool
    let onDelete: () -> Void

    private let phases = ["Mattina", "Pomeriggio", "Sera"]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 13)).foregroundColor(.acc)
                Stepper(value: $dose.quantity, in: 1...20) {
                    Text("\(dose.quantity) \(dose.quantity == 1 ? "pastiglia" : "pastiglie")")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                }
                .tint(.acc)

                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20)).foregroundColor(.muted.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("", selection: $dose.useTime) {
                Text("Fase").tag(false)
                Text("Ora specifica").tag(true)
            }
            .pickerStyle(.segmented)

            if dose.useTime {
                DatePicker("", selection: $dose.timingDate, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
            } else {
                Picker("", selection: $dose.timingPhase) {
                    ForEach(phases, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(12)
        .background(Color.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
