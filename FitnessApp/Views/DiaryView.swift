import SwiftUI
import SwiftData

// Wrapper for sheet(item:) — fixes meal always defaulting to Colazione
struct AddSheetItem: Identifiable {
    let id = UUID()
    let meal: MealType
    let date: Date
}

struct DiaryView: View {
    @Binding var showSettings: Bool
    var embedded: Bool = false
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @State private var addSheetItem: AddSheetItem?
    @State private var editingEntry: FoodEntry?

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                if !embedded {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diario")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.txt)
                            Text(appState.currentDate.fullDisplay)
                                .font(.system(size: 13, weight: .medium)).foregroundColor(.muted)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            NavBtn(icon: "chevron.left") { appState.goBack() }
                            NavBtn(icon: "chevron.right", disabled: !appState.canGoForward) { appState.goForward() }
                            GearBtn { showSettings = true }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
                }

                List {
                    ForEach(MealType.allCases, id: \.self) { meal in
                        MealSection(meal: meal, dateKey: appState.currentDateKey, editingEntry: $editingEntry) {
                            addSheetItem = AddSheetItem(meal: meal, date: appState.currentDate)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        )
        .sheet(item: $addSheetItem) { item in
            AddFoodSheet(meal: item.meal, date: item.date)
        }
        .sheet(item: $editingEntry) { entry in
            EditEntrySheet(entry: entry)
        }
    }
}

// MARK: - Meal Section

struct MealSection: View {
    @Environment(\.modelContext) private var context
    let meal: MealType
    let dateKey: String
    @Binding var editingEntry: FoodEntry?
    let onAdd: () -> Void

    @Query private var allEntries: [FoodEntry]

    init(meal: MealType, dateKey: String, editingEntry: Binding<FoodEntry?>, onAdd: @escaping () -> Void) {
        self.meal = meal
        self.dateKey = dateKey
        self._editingEntry = editingEntry
        self.onAdd = onAdd
        _allEntries = Query(
            filter: #Predicate<FoodEntry> { $0.dayKey == dateKey },
            sort: \.date
        )
    }

    var entries: [FoodEntry] {
        allEntries.filter { $0.meal == meal }
    }
    var mealKcal: Double { entries.reduce(0) { $0 + $1.kcalSnapshot } }

    var body: some View {
        Section {
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.foodName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.txt)
                        Text("\(entry.grams.smartFormat)g · P \(entry.proteinSnapshot.smartFormat) C \(entry.carbsSnapshot.smartFormat) G \(entry.fatSnapshot.smartFormat)")
                            .font(.system(size: 11)).foregroundColor(.muted)
                    }
                    Spacer()
                    Text("\(entry.kcalSnapshot.smartFormat)")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.muted)
                }
                .listRowBackground(Color.card)
                .listRowSeparatorTint(Color.brd)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        context.delete(entry); try? context.save()
                    } label: { Label("Elimina", systemImage: "trash") }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button { editingEntry = entry } label: { Label("Modifica", systemImage: "pencil") }
                    .tint(.acc)
                }
            }

            Button { onAdd() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                    Text("Aggiungi a \(meal.rawValue.lowercased())")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.acc).padding(.vertical, 4)
            }
            .listRowBackground(Color.card)
            .listRowSeparator(.hidden)
        } header: {
            HStack {
                Text(meal.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.txt).textCase(nil)
                Spacer()
                Text("\(mealKcal.smartFormat) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.muted).textCase(nil)
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
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
                        BigInputField(placeholder: "100", value: $gramsInput)
                            .frame(maxWidth: 200)

                        if let g = Double(gramsInput.replacingOccurrences(of: ",", with: ".")), g > 0 {
                            let ratio = g / max(entry.grams, 1)
                            let newKcal = entry.kcalSnapshot * ratio
                            Text("\(newKcal.smartFormat) kcal totali")
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.acc)
                        }
                    }

                    PillButton(label: "Salva modifiche") { save() }
                        .padding(.horizontal, 20)

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
                        context.delete(entry); try? context.save(); UINotificationFeedbackGenerator().notificationOccurred(.success); dismiss()
                    }.foregroundColor(.gymPink)
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
        try? context.save(); UINotificationFeedbackGenerator().notificationOccurred(.success); dismiss()
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
    @Query(sort: \CustomMeal.name) private var customMeals: [CustomMeal]
    @State private var search = ""
    @State private var tab = 0  // 0 = Alimenti, 1 = Piatti
    @State private var selectedFood: FoodItem?
    @State private var grams = "100"
    @State private var portions = "1"
    @State private var inputMode: InputMode = .grams
    @State private var showEditFood = false
    @State private var showQuickAdd = false
    @State private var addCustomMealItem: AddCustomMealToDiaryItem?

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
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.muted)
                        TextField("Cerca alimento...", text: $search)
                            .foregroundColor(.txt).tint(.acc)
                    }
                    .padding(12)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)

                    if selectedFood == nil {
                        Picker("", selection: $tab) {
                            Text("Alimenti").tag(0)
                            Text("Piatti").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                    }

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
                                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.acc)
                                                .padding(8).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }.buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)

                                if food.portionName != nil {
                                    Picker("Modalità", selection: $inputMode) {
                                        Text("Grammi").tag(InputMode.grams)
                                        Text(food.portionName ?? "Porzione").tag(InputMode.portion)
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.horizontal, 20)
                                }

                                VStack(spacing: 8) {
                                    if inputMode == .grams {
                                        Text("Quantità (grammi)")
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                                        BigInputField(placeholder: "100", value: $grams)
                                            .frame(maxWidth: 180)
                                    } else {
                                        Text("Numero di porzioni")
                                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                                        BigInputField(placeholder: "1", value: $portions)
                                            .frame(maxWidth: 180)
                                        if let pg = food.portionGrams {
                                            Text("1 \(food.portionName ?? "porzione") = \(pg.smartFormat)g")
                                                .font(.system(size: 12)).foregroundColor(.muted)
                                        }
                                    }
                                    let eg = effectiveGrams
                                    if eg > 0 {
                                        Text("\(food.kcal(for: eg).smartFormat) kcal · \(eg.smartFormat)g totali")
                                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.acc)
                                    }
                                }

                                PillButton(label: "Aggiungi a \(meal.rawValue)") { addFood(food) }
                                    .padding(.horizontal, 20)

                                Button("Scegli altro alimento") { selectedFood = nil }
                                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.muted)

                                Spacer()
                            }
                            .padding(.top, 20)
                        }
                    } else if tab == 1 {
                        // Custom meals list
                        let filteredMeals = search.isEmpty ? customMeals : customMeals.filter { $0.name.localizedCaseInsensitiveContains(search) }
                        if filteredMeals.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "fork.knife.circle").font(.system(size: 36)).foregroundColor(.muted)
                                Text("Nessun piatto salvato").font(.system(size: 14)).foregroundColor(.muted)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(filteredMeals) { cm in
                                    Button {
                                        addCustomMealItem = AddCustomMealToDiaryItem(meal: cm, mealType: meal, date: date)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(cm.name).font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                                                Text("\(cm.ingredients.count) ingredienti · \(Int(cm.portions)) porz.")
                                                    .font(.system(size: 11)).foregroundColor(.muted)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(cm.kcalPerPortion.smartFormat)
                                                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.txt)
                                                Text("kcal/porz.").font(.system(size: 10)).foregroundColor(.muted)
                                            }
                                        }
                                    }
                                    .listRowBackground(Color.card)
                                    .listRowSeparatorTint(Color.brd)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    } else {
                        // Quick add
                        Button { showQuickAdd = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.gymOrange)
                                Text("Inserisci al volo")
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(.gymOrange)
                                Spacer()
                                Text("senza salvare nel database")
                                    .font(.system(size: 11)).foregroundColor(.muted)
                            }
                            .padding(14)
                            .background(Color.gymOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20).padding(.bottom, 8)

                        List {
                            ForEach(filtered) { food in
                                Button {
                                    selectedFood = food
                                    grams = "100"; portions = "1"
                                    inputMode = food.portionName != nil ? .portion : .grams
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(food.name)
                                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                                            Text("P \(food.proteinPer100g.smartFormat)g · C \(food.carbsPer100g.smartFormat)g · G \(food.fatPer100g.smartFormat)g")
                                                .font(.system(size: 11)).foregroundColor(.muted)
                                            if let pn = food.portionName {
                                                Text(pn).font(.system(size: 11)).foregroundColor(.acc)
                                            }
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(food.kcalPer100g.smartFormat)")
                                                .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.txt)
                                            Text("kcal/100g").font(.system(size: 10)).foregroundColor(.muted)
                                        }
                                    }
                                }
                                .listRowBackground(Color.card)
                                .listRowSeparatorTint(Color.brd)
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
        .sheet(item: $addCustomMealItem) { item in
            AddCustomMealToDiarySheet(meal: item.meal, mealType: item.mealType, date: item.date)
        }
    }

    private func addFood(_ food: FoodItem) {
        let g = effectiveGrams
        guard g > 0 else { return }
        let entry = FoodEntry(food: food, grams: g, meal: meal, date: date)
        context.insert(entry); try? context.save(); UINotificationFeedbackGenerator().notificationOccurred(.success); dismiss()
    }
}

// MARK: - Quick Add Sheet

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
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14)).foregroundColor(.gymOrange)
                            Text("Questo alimento verrà aggiunto solo al diario di oggi, non al database.")
                                .font(.system(size: 13)).foregroundColor(.muted)
                        }
                        .padding(14)
                        .background(Color.gymOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Nome").frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Es. Pizza margherita", text: $name)
                                    .foregroundColor(.txt).tint(.acc)
                                    .padding(12)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Valori nutrizionali").frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Grammi",         value: $grams,   color: .txt)
                                NumericField(label: "Calorie (kcal)", value: $kcal,    color: .acc)
                                NumericField(label: "Proteine (g)",   value: $protein, color: .acc)
                                NumericField(label: "Carboidrati (g)", value: $carbs,  color: .gymBlue)
                                NumericField(label: "Grassi (g)",     value: $fat,     color: .gymOrange)
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

                        PillButton(label: "Aggiungi a \(meal.rawValue)", disabled: !isValid) { save() }
                            .padding(.bottom, 40)
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
        context.insert(entry); try? context.save(); UINotificationFeedbackGenerator().notificationOccurred(.success); dismiss()
    }
}
