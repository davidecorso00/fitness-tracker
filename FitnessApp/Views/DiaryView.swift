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

    /// Storico recente: alimenta sia le scorciatoie "hai mangiato spesso questo"
    /// sia la copia del pasto di ieri. Limitato alle voci più recenti per non
    /// scorrere tutto l'archivio a ogni ridisegno.
    @Query(sort: \FoodEntry.date, order: .reverse) private var recentHistory: [FoodEntry]
    @Query private var allLimits: [AppLimits]

    private var historyWindow: [FoodEntry] { Array(recentHistory.prefix(400)) }

    private var yesterdayKey: String { appState.currentDate.adding(days: -1).dateKey }

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
                        MealSection(
                            meal: meal,
                            dateKey: appState.currentDateKey,
                            date: appState.currentDate,
                            budget: allLimits.first.map { $0.budget(for: meal) } ?? 0,
                            showBudget: !SoftMode.attiva && (allLimits.first?.mealBudgetsEnabled ?? true),
                            suggestions: historyWindow.recentFoods(meal: meal, limit: 3),
                            yesterdayEntries: historyWindow.entries(on: yesterdayKey, meal: meal),
                            editingEntry: $editingEntry
                        ) {
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
    let date: Date
    let budget: Double
    let showBudget: Bool
    /// Alimenti già mangiati spesso a questo pasto: un tap li rimette con la
    /// stessa quantità dell'ultima volta.
    let suggestions: [RecentFood]
    let yesterdayEntries: [FoodEntry]
    @Binding var editingEntry: FoodEntry?
    let onAdd: () -> Void

    @Query private var allEntries: [FoodEntry]

    init(meal: MealType, dateKey: String, date: Date, budget: Double, showBudget: Bool,
         suggestions: [RecentFood], yesterdayEntries: [FoodEntry],
         editingEntry: Binding<FoodEntry?>, onAdd: @escaping () -> Void) {
        self.meal = meal
        self.dateKey = dateKey
        self.date = date
        self.budget = budget
        self.showBudget = showBudget
        self.suggestions = suggestions
        self.yesterdayEntries = yesterdayEntries
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

    private var mealBudget: CalorieBudget {
        CalorieBudget(consumed: mealKcal, target: budget)
    }

    /// Suggerimenti non ancora presenti nel pasto di oggi.
    private var freshSuggestions: [RecentFood] {
        let already = Set(entries.map(\.foodName))
        return suggestions.filter { !already.contains($0.foodName) }
    }

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

            // Scorciatoie: i cibi che ripeti a questo pasto, un tap e sono dentro
            if !freshSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(freshSuggestions) { recent in
                            Button { quickAdd(recent) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(recent.foodName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                        Text("\(recent.grams.smartFormat)g · \(Int(recent.kcal)) kcal")
                                            .font(.system(size: 10))
                                            .foregroundColor(.muted)
                                    }
                                }
                                .foregroundColor(.acc)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.acc.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(Color.card)
                .listRowSeparator(.hidden)
            }

            HStack(spacing: 14) {
                Button { onAdd() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("Aggiungi a \(meal.rawValue.lowercased())")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.acc)
                }
                .buttonStyle(.plain)

                Spacer()

                if !yesterdayEntries.isEmpty {
                    Button { copyYesterday() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Copia da ieri")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.card)
            .listRowSeparator(.hidden)
        } header: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(meal.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.txt).textCase(nil)
                    Spacer()
                    if showBudget && budget > 0 {
                        Text("\(mealKcal.smartFormat) / \(Int(budget)) kcal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(mealBudget.isOver ? .gymOrange : .muted)
                            .textCase(nil)
                    } else {
                        Text("\(mealKcal.smartFormat) kcal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.muted).textCase(nil)
                    }
                }
                if showBudget && budget > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule()
                                .fill(mealBudget.isOver ? Color.gymOrange : Color.acc.opacity(0.75))
                                .frame(width: geo.size.width * min(mealBudget.progress, 1))
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        }
    }

    private func quickAdd(_ recent: RecentFood) {
        QuickLog.add(recent, meal: meal, date: date, context: context)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func copyYesterday() {
        let copied = QuickLog.copyMeal(yesterdayEntries, to: date, meal: meal, context: context)
        if copied > 0 { UINotificationFeedbackGenerator().notificationOccurred(.success) }
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
    @Query(sort: \FoodEntry.date, order: .reverse) private var history: [FoodEntry]
    @Query private var allLimits: [AppLimits]
    @State private var search = ""
    @State private var tab = 0  // 0 = Alimenti, 1 = Piatti
    @State private var selectedFood: FoodItem?
    @State private var grams = "100"
    @State private var portions = "1"
    @State private var inputMode: InputMode = .grams
    @State private var showEditFood = false
    @State private var showQuickAdd = false
    @State private var addCustomMealItem: AddCustomMealToDiaryItem?

    /// Preferiti in cima, poi il resto in ordine alfabetico.
    var filtered: [FoodItem] {
        let base = search.isEmpty
            ? foods
            : foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
        return base.sorted { a, b in
            a.isFavorite == b.isFavorite ? a.name < b.name : a.isFavorite
        }
    }

    /// Ultimi alimenti di questo pasto, pronti da rimettere con la stessa quantità.
    private var recents: [RecentFood] {
        Array(history.prefix(400)).recentFoods(meal: meal, limit: 8)
    }

    /// Calorie della giornata a cui si sta aggiungendo.
    private var dayBudget: CalorieBudget {
        let key = date.dateKey
        let eaten = history.filter { $0.dayKey == key }.reduce(0.0) { $0 + $1.kcalSnapshot }
        return CalorieBudget(consumed: eaten, target: allLimits.first?.kcalTarget ?? 0)
    }

    /// L'anteprima dello sforamento sparisce in modalità morbida: nei giorni
    /// dopo un episodio non deve esserci niente da pareggiare.
    private var warningEnabled: Bool {
        !SoftMode.attiva && (allLimits.first?.overBudgetWarningEnabled ?? true)
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

                                // Effetto sulla giornata, prima di confermare
                                if warningEnabled, dayBudget.target > 0, effectiveGrams > 0 {
                                    budgetPreview(adding: food.kcal(for: effectiveGrams))
                                        .padding(.horizontal, 20)
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

                        // Ripeti quello che mangi di solito a questo pasto: un tap
                        if search.isEmpty && !recents.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(text: "Recenti · \(meal.rawValue.lowercased())")
                                    .padding(.horizontal, 20)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(recents) { recent in
                                            Button { addRecent(recent) } label: {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(recent.foodName)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.txt)
                                                        .lineLimit(1)
                                                    Text("\(recent.grams.smartFormat)g · \(Int(recent.kcal)) kcal")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.muted)
                                                }
                                                .frame(maxWidth: 150, alignment: .leading)
                                                .padding(.horizontal, 12).padding(.vertical, 9)
                                                .background(Color.card,
                                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(Color.acc.opacity(0.25), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 10)
                        }

                        List {
                            ForEach(filtered) { food in
                                Button {
                                    selectedFood = food
                                    grams = "100"; portions = "1"
                                    inputMode = food.portionName != nil ? .portion : .grams
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 5) {
                                                if food.isFavorite {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.gymOrange)
                                                }
                                                Text(food.name)
                                                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                                            }
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
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { toggleFavorite(food) } label: {
                                        Label(food.isFavorite ? "Togli" : "Preferito",
                                              systemImage: food.isFavorite ? "star.slash" : "star.fill")
                                    }
                                    .tint(.gymOrange)
                                }
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

    private func addRecent(_ recent: RecentFood) {
        QuickLog.add(recent, meal: meal, date: date, context: context)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func toggleFavorite(_ food: FoodItem) {
        food.isFavorite.toggle()
        try? context.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Dove ti porta questa porzione. Solo informazione: niente blocchi, niente
    /// giudizi — il pulsante per aggiungere resta identico in ogni caso.
    @ViewBuilder
    private func budgetPreview(adding kcal: Double) -> some View {
        let after = dayBudget.adding(kcal)
        HStack(spacing: 8) {
            Image(systemName: after.isOver ? "info.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(after.isOver ? .gymOrange : .acc)
            Text(after.isOver
                 ? "Con questa porzione arrivi a +\(Int(after.consumed - after.target)) kcal sul target"
                 : "Dopo questa porzione ti restano \(Int(after.remaining)) kcal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(after.isOver ? .gymOrange : .muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((after.isOver ? Color.gymOrange : Color.acc).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
