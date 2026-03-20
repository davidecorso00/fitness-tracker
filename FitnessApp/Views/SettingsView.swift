import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var limits: AppLimits?
    @State private var editing: LimitField?

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if let lim = limits {
                            LimitGroup(title: "Macronutrienti") {
                                LimitRow(label: "Calorie", value: lim.kcalTarget, unit: "kcal") {
                                    editing = LimitField(label: "Calorie", unit: "kcal", current: lim.kcalTarget) { lim.kcalTarget = $0; save() }
                                }
                                LimitRow(label: "Proteine", value: lim.proteinTarget, unit: "g") {
                                    editing = LimitField(label: "Proteine", unit: "g", current: lim.proteinTarget) { lim.proteinTarget = $0; save() }
                                }
                                LimitRow(label: "Carboidrati", value: lim.carbsTarget, unit: "g") {
                                    editing = LimitField(label: "Carboidrati", unit: "g", current: lim.carbsTarget) { lim.carbsTarget = $0; save() }
                                }
                                LimitRow(label: "Grassi", value: lim.fatTarget, unit: "g", last: true) {
                                    editing = LimitField(label: "Grassi", unit: "g", current: lim.fatTarget) { lim.fatTarget = $0; save() }
                                }
                            }
                            LimitGroup(title: "Micronutrienti") {
                                LimitRow(label: "Zuccheri", value: lim.sugarTarget, unit: "g") {
                                    editing = LimitField(label: "Zuccheri", unit: "g", current: lim.sugarTarget) { lim.sugarTarget = $0; save() }
                                }
                                LimitRow(label: "Grassi saturi", value: lim.saturatedFatTarget, unit: "g") {
                                    editing = LimitField(label: "Grassi saturi", unit: "g", current: lim.saturatedFatTarget) { lim.saturatedFatTarget = $0; save() }
                                }
                                LimitRow(label: "Fibre", value: lim.fiberTarget, unit: "g", last: true) {
                                    editing = LimitField(label: "Fibre", unit: "g", current: lim.fiberTarget) { lim.fiberTarget = $0; save() }
                                }
                            }
                            LimitGroup(title: "Attività & Obiettivi") {
                                LimitRow(label: "Passi giornalieri", value: Double(lim.stepsTarget), unit: "") {
                                    editing = LimitField(label: "Passi", unit: "", current: Double(lim.stepsTarget), isInt: true) { lim.stepsTarget = Int($0); save() }
                                }
                                LimitRow(label: "Target peso", value: lim.weightTarget, unit: "kg", last: true) {
                                    editing = LimitField(label: "Target peso", unit: "kg", current: lim.weightTarget) { lim.weightTarget = $0; save() }
                                }
                            }

                            // Data inizio tracciamento
                            VStack(spacing: 0) {
                                SectionLabel(text: "Tracciamento risultati")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
                                HStack {
                                    Text("Data inizio")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color(hex: "cccccc"))
                                    Spacer()
                                    DatePicker("", selection: Binding(
                                        get: { lim.startDate },
                                        set: { lim.startDate = $0; save() }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .tint(.acc2)
                                }
                                .padding(.horizontal, 18).padding(.vertical, 13)
                            }
                            .background(Color.card).cornerRadius(20).padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            )
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }.foregroundColor(.acc2)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { limits = appState.limits(context: context) }
        .sheet(item: $editing) { LimitEditSheet(field: $0) }
    }

    private func save() { try? context.save() }
}

// MARK: - Reusable limit components

struct LimitGroup<Content: View>: View {
    let title: String; let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(spacing: 0) {
            SectionLabel(text: title).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 6)
            content
        }
        .background(Color.card).cornerRadius(20).padding(.horizontal, 20)
    }
}

struct LimitRow: View {
    let label: String; let value: Double; let unit: String
    var last: Bool = false; let onTap: () -> Void
    var displayValue: String {
        unit == "" ? "\(Int(value))" : unit == "kcal" ? "\(Int(value)) \(unit)" : "\(Int(value)) \(unit)"
    }
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(Color(hex: "cccccc"))
                Spacer()
                Text(displayValue).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.acc2)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(Color(hex: "444444"))
            }
            .padding(.horizontal, 18).padding(.vertical, 13)
            .overlay(alignment: .top) {
                if !last { Rectangle().fill(Color.card2).frame(height: 1).padding(.leading, 18) }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LimitField: Identifiable {
    let id = UUID(); let label: String; let unit: String; let current: Double
    var isInt: Bool = false; let onSave: (Double) -> Void
}

struct LimitEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let field: LimitField
    @State private var input = ""
    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 8) {
                        Text(field.label).font(.system(size: 18, weight: .bold)).foregroundColor(.txt)
                        if !field.unit.isEmpty { Text(field.unit).font(.system(size: 14)).foregroundColor(.muted) }
                    }
                    TextField("0", text: $input)
                        .keyboardType(field.isInt ? .numberPad : .decimalPad)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.txt).tint(.acc2).multilineTextAlignment(.center)
                        .padding(.vertical, 20).frame(width: 200).background(Color.card).cornerRadius(20)
                    Button {
                        let raw = input.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(raw) { field.onSave(v) }
                        dismiss()
                    } label: {
                        Text("Salva").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            .frame(width: 200).padding(.vertical, 16).background(Color.acc).cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            )
            .navigationTitle("Modifica").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationDetents([.medium]).presentationBackground(Color.bg)
        .onAppear { input = field.isInt ? "\(Int(field.current))" : field.current.formatted1 }
    }
}
