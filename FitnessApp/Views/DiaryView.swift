import SwiftUI
import SwiftData

struct DiaryView: View {
    @Binding var showSettings: Bool
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @State private var showAddSheet = false
    @State private var selectedMeal: MealType = .breakfast

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diario")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text(appState.currentDate.fullDisplay)
                            .font(.system(size: 13)).foregroundColor(.muted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Button { appState.goBack() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.muted)
                                .frame(width: 30, height: 30).background(Color.card).cornerRadius(9)
                        }.buttonStyle(.plain)
                        Button { appState.goForward() } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(appState.canGoForward ? .muted : .brd)
                                .frame(width: 30, height: 30).background(Color.card).cornerRadius(9)
                        }.buttonStyle(.plain).disabled(!appState.canGoForward)
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .medium)).foregroundColor(.muted)
                                .frame(width: 30, height: 30).background(Color.card).cornerRadius(9)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                // Lista pasti
                List {
                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealSection(
                            meal: meal,
                            dateKey: appState.currentDateKey
                        ) {
                            selectedMeal = meal
                            showAddSheet = true
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.bg)
            }
        )
        .sheet(isPresented: $showAddSheet) {
            AddFoodSheet(meal: selectedMeal, date: appState.currentDate)
        }
    }
}

// MARK: - Meal Section

struct MealSection: View {
    @Environment(\.modelContext) private var context
    let meal: MealType
    let dateKey: String
    let onAdd: () -> Void

    @Query private var allEntries: [FoodEntry]
    @State private var editingEntry: FoodEntry?

    var entries: [FoodEntry] {
        allEntries.filter { $0.dayKey == dateKey && $0.meal == meal }
    }
    var mealKcal: Double { entries.reduce(0) { $0 + $1.kcalSnapshot } }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.foodName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "dddddd"))
                        Text("\(entry.grams.smartFormat)g · P \(entry.proteinSnapshot.smartFormat)g C \(entry.carbsSnapshot.smartFormat)g G \(entry.fatSnapshot.smartFormat)g")
                            .font(.system(size: 11)).foregroundColor(.muted)
                    }
                    Spacer()
                    Text("\(entry.kcalSnapshot.smartFormat)")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.muted)
                }
                .listRowBackground(Color.card)
                .listRowSeparatorTint(Color.brd2)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        context.delete(entry)
                        try? context.save()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        editingEntry = entry
                    } label: {
                        Label("Modifica", systemImage: "pencil")
                    }
                    .tint(.acc)
                }
            }

            // Pulsante aggiungi
            Button {
                onAdd()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                    Text("Aggiungi a \(meal.rawValue.lowercased())")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.acc2).padding(.vertical, 4)
            }
            .listRowBackground(Color.card)
            .listRowSeparator(.hidden)
        } header: {
            HStack {
                Text(meal.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.txt)
                    .textCase(nil)
                Spacer()
                Text("\(mealKcal.smartFormat) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.muted)
                    .textCase(nil)
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        }
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry)
        }
    }
}

// MARK: - Edit Entry Sheet

struct EditEntrySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: FoodEntry

    @State private var gramsInput = ""

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 24) {
                    Spacer()
                    HTCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.foodName)
                                .font(.system(size: 18, weight: .bold)).foregroundColor(.txt)
                            Text("Pasto: \(entry.meal.rawValue)")
                                .font(.system(size: 13)).foregroundColor(.muted)
                        }
                    }
                    .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        Text("Quantità (grammi)")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                        TextField("100", text: $gramsInput)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.txt).tint(.acc2)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 16).frame(width: 160)
                            .background(Color.card).cornerRadius(16)

                        if let g = Double(gramsInput.replacingOccurrences(of: ",", with: ".")), g > 0 {
                            // Stima kcal basata sul rapporto originale
                            let ratio = g / max(entry.grams, 1)
                            let newKcal = entry.kcalSnapshot * ratio
                            Text("\(newKcal.smartFormat) kcal totali")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.acc2)
                        }
                    }

                    Button {
                        save()
                    } label: {
                        Text("Salva modifiche")
                            .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.acc).cornerRadius(16)
                    }
                    .buttonStyle(.plain).padding(.horizontal, 20)

                    Spacer()
                }
            )
            .navigationTitle("Modifica porzione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Elimina") {
                        context.delete(entry)
                        try? context.save()
                        dismiss()
                    }.foregroundColor(.gymOrange)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.bg)
        .onAppear { gramsInput = entry.grams.smartFormat }
    }

    private func save() {
        guard let g = Double(gramsInput.replacingOccurrences(of: ",", with: ".")), g > 0 else { return }
        let ratio = g / max(entry.grams, 1)
        entry.grams = g
        entry.kcalSnapshot         *= ratio
        entry.proteinSnapshot      *= ratio
        entry.carbsSnapshot        *= ratio
        entry.fatSnapshot          *= ratio
        entry.fiberSnapshot        *= ratio
        entry.sugarSnapshot        *= ratio
        entry.saturatedFatSnapshot *= ratio
        entry.saltSnapshot         *= ratio
        try? context.save()
        dismiss()
    }
}

// MARK: - Add Food Sheet

enum InputMode { case grams, portion }

struct AddFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let meal: MealType
    let date: Date

    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var search = ""
    @State private var selectedFood: FoodItem?
    @State private var grams = "100"
    @State private var portions = "1"
    @State private var inputMode: InputMode = .grams
    @State private var showEditFood = false
    @State private var showQuickAdd = false

    var filtered: [FoodItem] {
        search.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var effectiveGrams: Double {
        switch inputMode {
        case .grams: return Double(grams.replacingOccurrences(of: ",", with: ".")) ?? 0
        case .portion:
            let n = Double(portions.replacingOccurrences(of: ",", with: ".")) ?? 1
            return n * (selectedFood?.portionGrams ?? 100)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.muted)
                        TextField("Cerca alimento...", text: $search)
                            .foregroundColor(.txt).tint(.acc2)
                    }
                    .padding(12).background(Color.card).cornerRadius(14)
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)

                    if let food = selectedFood {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                HTCard {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(food.name)
                                                .font(.system(size: 18, weight: .bold)).foregroundColor(.txt)
                                            Text("\(food.kcalPer100g.smartFormat) kcal · P \(food.proteinPer100g.smartFormat)g · C \(food.carbsPer100g.smartFormat)g · G \(food.fatPer100g.smartFormat)g")
                                                .font(.system(size: 12)).foregroundColor(.muted)
                                        }
                                        Spacer()
                                        Button { showEditFood = true } label: {
                                            Image(systemName: "pencil")
                                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.acc2)
                                                .padding(8).background(Color.brd).cornerRadius(10)
                                        }.buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)

                                if food.portionName != nil {
                                    HStack(spacing: 0) {
                                        Button { inputMode = .grams } label: {
                                            Text("Grammi")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(inputMode == .grams ? .white : .muted)
                                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                                .background(inputMode == .grams ? Color.acc : Color.clear)
                                                .cornerRadius(10)
                                        }.buttonStyle(.plain)
                                        Button { inputMode = .portion } label: {
                                            Text(food.portionName ?? "Porzione")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(inputMode == .portion ? .white : .muted)
                                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                                .background(inputMode == .portion ? Color.acc : Color.clear)
                                                .cornerRadius(10)
                                        }.buttonStyle(.plain)
                                    }
                                    .padding(4).background(Color.card).cornerRadius(14)
                                    .padding(.horizontal, 20)
                                }

                                VStack(spacing: 8) {
                                    if inputMode == .grams {
                                        Text("Quantità (grammi)")
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                                        TextField("100", text: $grams).keyboardType(.decimalPad)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.txt).multilineTextAlignment(.center)
                                            .padding(.vertical, 16).frame(width: 140)
                                            .background(Color.card).cornerRadius(16)
                                    } else {
                                        Text("Numero di porzioni")
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                                        TextField("1", text: $portions).keyboardType(.decimalPad)
                                            .font(.system(size: 32, weight: .bold, design: .rounded))
                                            .foregroundColor(.txt).multilineTextAlignment(.center)
                                            .padding(.vertical, 16).frame(width: 140)
                                            .background(Color.card).cornerRadius(16)
                                        if let pg = food.portionGrams {
                                            Text("1 \(food.portionName ?? "porzione") = \(pg.smartFormat)g")
                                                .font(.system(size: 12)).foregroundColor(.muted)
                                        }
                                    }
                                    let eg = effectiveGrams
                                    if eg > 0 {
                                        Text("\(food.kcal(for: eg).smartFormat) kcal · \(eg.smartFormat)g totali")
                                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.acc2)
                                    }
                                }

                                Button { addFood(food) } label: {
                                    Text("Aggiungi a \(meal.rawValue)")
                                        .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                                        .background(Color.acc).cornerRadius(16)
                                }
                                .buttonStyle(.plain).padding(.horizontal, 20)

                                Button("Scegli altro alimento") { selectedFood = nil }
                                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.muted)

                                Spacer()
                            }
                            .padding(.top, 20)
                        }
                    } else {
                        // Pulsante inserimento al volo
                        Button {
                            showQuickAdd = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gymOrange)
                                Text("Inserisci al volo")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gymOrange)
                                Spacer()
                                Text("senza salvare nel database")
                                    .font(.system(size: 11))
                                    .foregroundColor(.muted)
                            }
                            .padding(14)
                            .background(Color.gymOrange.opacity(0.1))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                        List {
                            ForEach(filtered) { food in
                                Button {
                                    selectedFood = food
                                    grams = "100"; portions = "1"
                                    inputMode = food.portionName != nil ? .portion : .grams
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(food.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color(hex: "dddddd"))
                                            Text("P \(food.proteinPer100g.smartFormat)g · C \(food.carbsPer100g.smartFormat)g · G \(food.fatPer100g.smartFormat)g")
                                                .font(.system(size: 11)).foregroundColor(.muted)
                                            if let pn = food.portionName {
                                                Text(pn).font(.system(size: 11)).foregroundColor(.acc2)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(food.kcalPer100g.smartFormat)")
                                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                                .foregroundColor(.txt)
                                            Text("kcal/100g").font(.system(size: 10)).foregroundColor(.muted)
                                        }
                                    }
                                }
                                .listRowBackground(Color.bg)
                                .listRowSeparatorTint(Color.brd2)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            )
            .navigationTitle(selectedFood == nil ? "Aggiungi alimento" : "Quantità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bg)
        .sheet(isPresented: $showEditFood) {
            if let food = selectedFood { FoodFormSheet(food: food) }
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(meal: meal, date: date)
        }
    }

    private func addFood(_ food: FoodItem) {
        let g = effectiveGrams
        guard g > 0 else { return }
        let entry = FoodEntry(food: food, grams: g, meal: meal, date: date)
        context.insert(entry); try? context.save(); dismiss()
    }
}

// MARK: - Quick Add Sheet (al volo, senza salvare nel database)

struct QuickAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let meal: MealType
    let date: Date

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var saturatedFat = ""
    @State private var salt = ""
    @State private var grams = "100"

    var isValid: Bool { !name.isEmpty && Double(kcal.replacingOccurrences(of: ",", with: ".")) != nil }

    private func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Info banner
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14)).foregroundColor(.gymOrange)
                            Text("Questo alimento verrà aggiunto solo al diario di oggi, non al database.")
                                .font(.system(size: 13)).foregroundColor(.muted)
                        }
                        .padding(14)
                        .background(Color.gymOrange.opacity(0.1))
                        .cornerRadius(14)

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Nome").frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Es. Pizza margherita", text: $name)
                                    .foregroundColor(.txt).tint(.acc2)
                                    .padding(12).background(Color.brd).cornerRadius(12)
                            }
                        }

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Valori nutrizionali").frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Grammi",        value: $grams,       color: .txt)
                                NumericField(label: "Calorie (kcal)", value: $kcal,       color: .acc2)
                                NumericField(label: "Proteine (g)",   value: $protein,    color: .acc2)
                                NumericField(label: "Carboidrati (g)", value: $carbs,     color: .gymBlue)
                                NumericField(label: "Grassi (g)",     value: $fat,        color: .gymOrange)
                            }
                        }

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Micronutrienti (opzionale)").frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Fibre (g)",      value: $fiber,        color: .gymGreen)
                                NumericField(label: "Zuccheri (g)",   value: $sugar,        color: .gymPink)
                                NumericField(label: "Gr. saturi (g)", value: $saturatedFat, color: .gymOrange)
                                NumericField(label: "Sale (g)",       value: $salt,         color: .muted)
                            }
                        }

                        Button { save() } label: {
                            Text("Aggiungi a \(meal.rawValue)")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(isValid ? Color.acc : Color.brd).cornerRadius(16)
                        }
                        .buttonStyle(.plain).disabled(!isValid).padding(.bottom, 40)
                    }
                    .padding(20)
                }
            )
            .navigationTitle("Inserimento al volo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationBackground(Color.bg)
    }

    private func save() {
        let g   = parse(grams).isZero ? 100 : parse(grams)
        let k   = parse(kcal)
        let p   = parse(protein)
        let c   = parse(carbs)
        let f   = parse(fat)
        let fi  = parse(fiber)
        let s   = parse(sugar)
        let sf  = parse(saturatedFat)
        let sa  = parse(salt)

        // Crea un FoodItem temporaneo (non inserito nel context)
        // I valori sono già totali per la quantità indicata,
        // li convertiamo in per-100g per usare FoodEntry normalmente
        let factor = g > 0 ? 100.0 / g : 1.0
        let tempFood = FoodItem(
            name: name,
            kcalPer100g: k * factor,
            proteinPer100g: p * factor,
            carbsPer100g: c * factor,
            fatPer100g: f * factor,
            fiberPer100g: fi * factor,
            sugarPer100g: s * factor,
            saturatedFatPer100g: sf * factor,
            saltPer100g: sa * factor
        )

        let entry = FoodEntry(food: tempFood, grams: g, meal: meal, date: date)
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
