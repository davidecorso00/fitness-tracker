import SwiftUI
import SwiftData

// MARK: - Keyboard dismiss helper

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}

// MARK: - Identifiable wrappers

struct CustomMealEditItem: Identifiable {
    let id = UUID()
    let meal: CustomMeal?
}

struct AddCustomMealToDiaryItem: Identifiable {
    let id = UUID()
    let meal: CustomMeal
    let mealType: MealType
    let date: Date
}

// MARK: - CustomMealsView (list + management)

struct CustomMealsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomMeal.name) private var meals: [CustomMeal]

    @State private var editItem: CustomMealEditItem?
    @State private var search = ""

    var filtered: [CustomMeal] {
        search.isEmpty ? meals : meals.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.muted)
                TextField("Cerca piatto...", text: $search)
                    .foregroundColor(.txt).tint(.acc2)
                Button {
                    editItem = CustomMealEditItem(meal: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.acc)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 8)

            if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 44)).foregroundColor(.muted)
                    Text("Nessun piatto personalizzato")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.muted)
                    Text("Tocca + per crearne uno")
                        .font(.system(size: 13)).foregroundColor(.muted.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { meal in
                        CustomMealRow(meal: meal)
                            .onTapGesture { editItem = CustomMealEditItem(meal: meal) }
                            .listRowBackground(Color.white.opacity(0.03))
                            .listRowSeparatorTint(Color.white.opacity(0.04))
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    context.delete(meal); try? context.save()
                                } label: { Label("Elimina", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editItem = CustomMealEditItem(meal: meal)
                                } label: { Label("Modifica", systemImage: "pencil") }
                                .tint(.acc)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .sheet(item: $editItem) { item in
            CustomMealFormSheet(meal: item.meal)
        }
    }
}

// MARK: - Row

struct CustomMealRow: View {
    let meal: CustomMeal
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name.isEmpty ? "Senza nome" : meal.name)
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                Text("\(meal.ingredients.count) ingredienti · \(meal.portions.smartFormat) porzioni")
                    .font(.system(size: 11)).foregroundColor(.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(meal.kcalPerPortion.smartFormat)
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.txt)
                Text("kcal/porz.").font(.system(size: 10)).foregroundColor(.muted)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Form Sheet (create / edit)

struct CustomMealFormSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]

    let meal: CustomMeal?

    @State private var name: String
    @State private var portionsStr: String
    @State private var ingredients: [IngredientDraft]
    @State private var showIngredientPicker = false
    @State private var showSaveError = false

    init(meal: CustomMeal?) {
        self.meal = meal
        _name = State(initialValue: meal?.name ?? "")
        _portionsStr = State(initialValue: meal.map { $0.portions.smartFormat } ?? "1")
        _ingredients = State(initialValue: meal?.ingredients.map { ing in
            IngredientDraft(
                foodName: ing.foodName,
                gramsStr: ing.grams.smartFormat,
                kcalPer100g: ing.kcalPer100g, proteinPer100g: ing.proteinPer100g,
                carbsPer100g: ing.carbsPer100g, fatPer100g: ing.fatPer100g,
                fiberPer100g: ing.fiberPer100g, sugarPer100g: ing.sugarPer100g,
                saturatedFatPer100g: ing.saturatedFatPer100g, saltPer100g: ing.saltPer100g
            )
        } ?? [])
    }

    private var portions: Double { Double(portionsStr.replacingOccurrences(of: ",", with: ".")) ?? 1 }
    private var isValid: Bool { !name.isEmpty && !ingredients.isEmpty }

    private var totalKcal: Double    { ingredients.reduce(0) { $0 + $1.kcalPer100g * $1.grams / 100 } }
    private var totalProtein: Double { ingredients.reduce(0) { $0 + $1.proteinPer100g * $1.grams / 100 } }
    private var totalCarbs: Double   { ingredients.reduce(0) { $0 + $1.carbsPer100g * $1.grams / 100 } }
    private var totalFat: Double     { ingredients.reduce(0) { $0 + $1.fatPer100g * $1.grams / 100 } }
    private var p: Double { max(portions, 0.1) }
    private var kcalPerP: Double    { totalKcal / p }
    private var proteinPerP: Double { totalProtein / p }
    private var carbsPerP: Double   { totalCarbs / p }
    private var fatPerP: Double     { totalFat / p }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Name
                        HTCard {
                            VStack(spacing: 10) {
                                SectionLabel(text: "Nome piatto").frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Es. Pasta al tonno", text: $name)
                                    .foregroundColor(.txt).tint(.acc2)
                                    .submitLabel(.done)
                                    .onSubmit { hideKeyboard() }
                                    .padding(12)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Portions
                        HTCard {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    SectionLabel(text: "Porzioni")
                                    Text("Il totale sarà diviso per questo numero")
                                        .font(.system(size: 11)).foregroundColor(.muted)
                                }
                                Spacer()
                                TextField("1", text: $portionsStr)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.acc2).tint(.acc2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                                    .padding(.vertical, 8).padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Ingredients
                        HTCard {
                            VStack(spacing: 10) {
                                HStack {
                                    SectionLabel(text: "Ingredienti")
                                    Spacer()
                                    Button {
                                        hideKeyboard()
                                        showIngredientPicker = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                                            Text("Aggiungi").font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(.acc)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if ingredients.isEmpty {
                                    Text("Nessun ingrediente aggiunto")
                                        .font(.system(size: 13)).foregroundColor(.muted)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 8)
                                } else {
                                    ForEach($ingredients) { $ing in
                                        IngredientDraftRow(draft: $ing) {
                                            ingredients.removeAll { $0.id == ing.id }
                                        }
                                        if ing.id != ingredients.last?.id {
                                            Divider().overlay(Color.white.opacity(0.05))
                                        }
                                    }
                                }
                            }
                        }

                        // Per-portion totals
                        if !ingredients.isEmpty {
                            HTCard {
                                VStack(spacing: 8) {
                                    SectionLabel(text: "Per porzione").frame(maxWidth: .infinity, alignment: .leading)
                                    HStack(spacing: 0) {
                                        macroCell(label: "Kcal",  value: kcalPerP,    color: .ringRed)
                                        macroCell(label: "Prot.", value: proteinPerP, color: .ringGreen)
                                        macroCell(label: "Carb.", value: carbsPerP,   color: .gymBlue)
                                        macroCell(label: "Gras.", value: fatPerP,     color: .gymOrange)
                                    }
                                }
                            }
                        }

                        PillButton(label: meal == nil ? "Crea piatto" : "Salva modifiche", disabled: !isValid) {
                            hideKeyboard(); save()
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(20)
                }
            )
            .navigationTitle(meal == nil ? "Nuovo piatto" : "Modifica piatto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                if meal != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Elimina") {
                            if let m = meal { context.delete(m); try? context.save() }
                            dismiss()
                        }
                        .foregroundColor(.gymPink)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { hideKeyboard() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.acc)
                }
            }
        }
        .presentationBackground(Color.bg)
        .alert("Errore nel salvataggio", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Impossibile salvare il piatto. Riprova.")
        }
        .sheet(isPresented: $showIngredientPicker) {
            IngredientPickerSheet(allFoods: allFoods) { food, grams in
                ingredients.append(IngredientDraft(
                    foodName: food.name, gramsStr: grams.smartFormat,
                    kcalPer100g: food.kcalPer100g, proteinPer100g: food.proteinPer100g,
                    carbsPer100g: food.carbsPer100g, fatPer100g: food.fatPer100g,
                    fiberPer100g: food.fiberPer100g, sugarPer100g: food.sugarPer100g,
                    saturatedFatPer100g: food.saturatedFatPer100g, saltPer100g: food.saltPer100g
                ))
            }
        }
    }

    private func macroCell(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value.smartFormat).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let target: CustomMeal
        if let existing = meal {
            target = existing
        } else {
            target = CustomMeal()
            context.insert(target)
        }

        target.name = name
        target.portions = max(Double(portionsStr.replacingOccurrences(of: ",", with: ".")) ?? 1, 0.1)

        for old in target.ingredients { context.delete(old) }
        target.ingredients = []

        for draft in ingredients {
            let ing = CustomMealIngredient()
            context.insert(ing)
            ing.foodName = draft.foodName
            ing.grams = draft.grams
            ing.kcalPer100g = draft.kcalPer100g
            ing.proteinPer100g = draft.proteinPer100g
            ing.carbsPer100g = draft.carbsPer100g
            ing.fatPer100g = draft.fatPer100g
            ing.fiberPer100g = draft.fiberPer100g
            ing.sugarPer100g = draft.sugarPer100g
            ing.saturatedFatPer100g = draft.saturatedFatPer100g
            ing.saltPer100g = draft.saltPer100g
            target.ingredients.append(ing)  // SwiftData's inverse: sets ing.meal automatically
        }

        do {
            try context.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            print("⚠️ Salvataggio piatto fallito: \(error)")
            showSaveError = true
        }
    }
}

// MARK: - IngredientDraft (value type for editing)

struct IngredientDraft: Identifiable {
    let id = UUID()
    var foodName: String
    var gramsStr: String
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double
    var sugarPer100g: Double
    var saturatedFatPer100g: Double
    var saltPer100g: Double

    var grams: Double { Double(gramsStr.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var kcalTotal: Double { kcalPer100g * grams / 100 }
}

// MARK: - IngredientDraftRow

struct IngredientDraftRow: View {
    @Binding var draft: IngredientDraft
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.foodName)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.txt)
                    .lineLimit(1)
                Text("\(draft.kcalTotal.smartFormat) kcal")
                    .font(.system(size: 11)).foregroundColor(.muted)
            }
            Spacer(minLength: 4)
            TextField("0", text: $draft.gramsStr)
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.acc2).tint(.acc2)
                .multilineTextAlignment(.center)
                .frame(width: 58)
                .padding(.vertical, 6).padding(.horizontal, 8)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            Text("g")
                .font(.system(size: 12, weight: .medium)).foregroundColor(.muted)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18)).foregroundColor(.muted.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - IngredientPickerSheet

struct IngredientPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let allFoods: [FoodItem]
    let onSelect: (FoodItem, Double) -> Void

    @State private var search = ""
    @State private var selected: FoodItem?
    @State private var gramsStr = "100"

    var filtered: [FoodItem] {
        search.isEmpty ? allFoods : allFoods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
    var grams: Double { Double(gramsStr.replacingOccurrences(of: ",", with: ".")) ?? 100 }

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
                    .padding(12)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)

                    if let food = selected {
                        VStack(spacing: 20) {
                            HTCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(food.name)
                                        .font(.system(size: 16, weight: .bold)).foregroundColor(.txt)
                                    Text("P \(food.proteinPer100g.smartFormat)g · C \(food.carbsPer100g.smartFormat)g · G \(food.fatPer100g.smartFormat)g")
                                        .font(.system(size: 12)).foregroundColor(.muted)
                                }
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 8) {
                                Text("Grammi")
                                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                                TextField("100", text: $gramsStr)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.txt).tint(.acc2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 160)
                                    .padding(.vertical, 10).padding(.horizontal, 16)
                                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                                if grams > 0 {
                                    Text("\((food.kcalPer100g * grams / 100).smartFormat) kcal · P \((food.proteinPer100g * grams / 100).smartFormat)g")
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.acc)
                                }
                            }

                            PillButton(label: "Aggiungi ingrediente") {
                                onSelect(food, grams); dismiss()
                            }
                            .padding(.horizontal, 20)
                            .disabled(grams <= 0)

                            Button("Scegli altro") { selected = nil; search = "" }
                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.muted)
                        }
                        .padding(.top, 8)
                    } else {
                        List {
                            ForEach(filtered) { food in
                                Button {
                                    selected = food
                                    gramsStr = food.portionGrams.map { $0.smartFormat } ?? "100"
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(food.name)
                                                .font(.system(size: 14, weight: .semibold)).foregroundColor(.txt)
                                            Text("P \(food.proteinPer100g.smartFormat) · C \(food.carbsPer100g.smartFormat) · G \(food.fatPer100g.smartFormat)")
                                                .font(.system(size: 11)).foregroundColor(.muted)
                                        }
                                        Spacer()
                                        Text(food.kcalPer100g.smartFormat)
                                            .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.txt)
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
            .navigationTitle("Scegli ingrediente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { hideKeyboard() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.acc)
                }
            }
        }
        .presentationBackground(Color.bg)
    }
}

// MARK: - Add Custom Meal To Diary Sheet

struct AddCustomMealToDiarySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let meal: CustomMeal
    let mealType: MealType
    let date: Date

    @State private var portionsStr = "1"
    @State private var kcalStr = ""
    @State private var proteinStr = ""
    @State private var carbsStr = ""
    @State private var fatStr = ""

    private func parse(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var chosenPortions: Double { max(parse(portionsStr), 0.01) }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        HTCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(meal.name)
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.txt)
                                Text("\(meal.ingredients.count) ingredienti · 1 porzione = \(meal.kcalPerPortion.smartFormat) kcal")
                                    .font(.system(size: 12)).foregroundColor(.muted)
                            }
                        }
                        .padding(.horizontal, 20)

                        VStack(spacing: 8) {
                            Text("Numero di porzioni")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                            TextField("1", text: $portionsStr)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.txt).tint(.acc2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 160)
                                .padding(.vertical, 10).padding(.horizontal, 16)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                                .onChange(of: portionsStr) { _, _ in updateMacros() }
                        }

                        HTCard {
                            VStack(spacing: 10) {
                                SectionLabel(text: "Macronutrienti (modificabili)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Calorie (kcal)", value: $kcalStr, color: .ringRed)
                                NumericField(label: "Proteine (g)",   value: $proteinStr, color: .ringGreen)
                                NumericField(label: "Carboidrati (g)", value: $carbsStr, color: .gymBlue)
                                NumericField(label: "Grassi (g)",     value: $fatStr, color: .gymOrange)
                            }
                        }
                        .padding(.horizontal, 20)

                        PillButton(label: "Aggiungi a \(mealType.rawValue)") {
                            hideKeyboard(); addEntry()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 20)
                }
            )
            .navigationTitle("Aggiungi al diario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { hideKeyboard() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.acc)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { updateMacros() }
    }

    private func updateMacros() {
        let p = chosenPortions
        kcalStr    = (meal.kcalPerPortion * p).smartFormat
        proteinStr = (meal.proteinPerPortion * p).smartFormat
        carbsStr   = (meal.carbsPerPortion * p).smartFormat
        fatStr     = (meal.fatPerPortion * p).smartFormat
    }

    private func addEntry() {
        let totalGrams = meal.ingredients.reduce(0) { $0 + $1.grams } * chosenPortions / max(meal.portions, 1)
        let tempFood = FoodItem(
            name: meal.name,
            kcalPer100g: parse(kcalStr) / max(totalGrams, 1) * 100,
            proteinPer100g: parse(proteinStr) / max(totalGrams, 1) * 100,
            carbsPer100g: parse(carbsStr) / max(totalGrams, 1) * 100,
            fatPer100g: parse(fatStr) / max(totalGrams, 1) * 100
        )
        let entry = FoodEntry(food: tempFood, grams: totalGrams, meal: mealType, date: date)
        entry.kcalSnapshot = parse(kcalStr)
        entry.proteinSnapshot = parse(proteinStr)
        entry.carbsSnapshot = parse(carbsStr)
        entry.fatSnapshot = parse(fatStr)
        context.insert(entry)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
