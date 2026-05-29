import SwiftUI
import SwiftData

// Wrapper per distinguere "nuovo" vs "modifica" nello sheet
struct FoodEditItem: Identifiable {
    let id = UUID()
    let food: FoodItem?
}

struct FoodsView: View {
    @Binding var showSettings: Bool
    var embedded: Bool = false
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var search = ""
    @State private var sheetItem: FoodEditItem?

    var filtered: [FoodItem] {
        search.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Group {
            if embedded {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.muted)
                        TextField("Cerca alimento...", text: $search)
                            .foregroundColor(.txt).tint(.acc2)
                        Button {
                            sheetItem = FoodEditItem(food: nil)
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

                    foodList
                }
            } else {
                ZStack { Color.bg.ignoresSafeArea() }
                .overlay(
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alimenti")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.txt)
                                Text("Database personale")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.muted)
                            }
                            Spacer()
                            Button {
                                sheetItem = FoodEditItem(food: nil)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                                    Text("Nuovo").font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(Color.acc, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            GearBtn { showSettings = true }
                        }
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.muted)
                            TextField("Cerca alimento...", text: $search)
                                .foregroundColor(.txt).tint(.acc2)
                        }
                        .padding(12)
                        .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 20).padding(.bottom, 8)

                        foodList
                    }
                )
            }
        }
        .sheet(item: $sheetItem) { item in
            FoodFormSheet(food: item.food)
        }
    }

    private var foodList: some View {
        List {
            ForEach(filtered) { food in
                FoodRow(food: food)
                    .onTapGesture { sheetItem = FoodEditItem(food: food) }
                    .listRowBackground(Color.white.opacity(0.03))
                    .listRowSeparatorTint(Color.white.opacity(0.04))
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            context.delete(food); try? context.save()
                        } label: { Label("Elimina", systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            sheetItem = FoodEditItem(food: food)
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

struct FoodRow: View {
    let food: FoodItem
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "dddddd"))
                let saltStr = food.saltPer100g > 0 ? " · Sa \(food.saltPer100g.smartFormat)g" : ""
                Text("P \(food.proteinPer100g.smartFormat)g · C \(food.carbsPer100g.smartFormat)g · G \(food.fatPer100g.smartFormat)g · Fi \(food.fiberPer100g.smartFormat)g\(saltStr)")
                    .font(.system(size: 11)).foregroundColor(.muted)
                if let pName = food.portionName, let pGrams = food.portionGrams {
                    Text("\(pName) = \(pGrams.smartFormat)g")
                        .font(.system(size: 11)).foregroundColor(.acc2)
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
        .padding(.vertical, 12)
    }
}

// MARK: - Food Form Sheet

struct FoodFormSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem?

    @State private var name: String
    @State private var baseGrams: String
    @State private var kcal: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var saturatedFat: String
    @State private var salt: String
    @State private var portionName: String
    @State private var portionGrams: String

    init(food: FoodItem?) {
        self.food = food
        _name         = State(initialValue: food?.name ?? "")
        _baseGrams    = State(initialValue: "100")
        _kcal         = State(initialValue: food.map { $0.kcalPer100g.smartFormat } ?? "")
        _protein      = State(initialValue: food.map { $0.proteinPer100g.smartFormat } ?? "")
        _carbs        = State(initialValue: food.map { $0.carbsPer100g.smartFormat } ?? "")
        _fat          = State(initialValue: food.map { $0.fatPer100g.smartFormat } ?? "")
        _fiber        = State(initialValue: food.map { $0.fiberPer100g.smartFormat } ?? "")
        _sugar        = State(initialValue: food.map { $0.sugarPer100g.smartFormat } ?? "")
        _saturatedFat = State(initialValue: food.map { $0.saturatedFatPer100g.smartFormat } ?? "")
        _salt         = State(initialValue: food.map { $0.saltPer100g.smartFormat } ?? "")
        _portionName  = State(initialValue: food?.portionName ?? "")
        _portionGrams = State(initialValue: food?.portionGrams.map { $0.smartFormat } ?? "")
    }

    var isValid: Bool { !name.isEmpty && Double(kcal.replacingOccurrences(of: ",", with: ".")) != nil }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Nome").frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Es. Petto di pollo", text: $name)
                                    .foregroundColor(.txt).tint(.acc2)
                                    .padding(12).background(Color.white.opacity(0.06)).cornerRadius(12)
                            }
                        }
                        HTCard {
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Text("Valori per")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.muted)
                                        .kerning(0.7)
                                        .textCase(.uppercase)
                                    TextField("100", text: $baseGrams)
                                        .keyboardType(.numberPad)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.acc2).tint(.acc2)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 64)
                                        .padding(.vertical, 5).padding(.horizontal, 8)
                                        .background(Color.white.opacity(0.06)).cornerRadius(8)
                                    Text("g")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.muted)
                                    Spacer()
                                    if (Double(baseGrams) ?? 100) != 100 {
                                        Text("verranno convertiti a /100g")
                                            .font(.system(size: 10)).foregroundColor(.gymOrange)
                                    }
                                }
                                .padding(.bottom, 4)
                                NumericField(label: "Calorie (kcal)", value: $kcal, color: .ringRed)
                                NumericField(label: "Proteine (g)",   value: $protein, color: .ringGreen)
                                NumericField(label: "Carboidrati (g)", value: $carbs, color: .gymBlue)
                                NumericField(label: "Grassi (g)",     value: $fat, color: .gymOrange)
                            }
                        }
                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Micronutrienti per 100g").frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Fibre (g)",      value: $fiber, color: .gymGreen)
                                NumericField(label: "Zuccheri (g)",   value: $sugar, color: .gymPink)
                                NumericField(label: "Gr. saturi (g)", value: $saturatedFat, color: .gymOrange)
                                NumericField(label: "Sale (g)",       value: $salt,        color: .muted)
                            }
                        }
                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Porzione (opzionale)").frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    Text("Nome porzione")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "AEAEB2"))
                                    Spacer()
                                    TextField("es. 1 fetta", text: $portionName)
                                        .foregroundColor(.acc2).tint(.acc2)
                                        .font(.system(size: 14, weight: .semibold))
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 120)
                                        .padding(.vertical, 8).padding(.horizontal, 12)
                                        .background(Color.white.opacity(0.06)).cornerRadius(10)
                                }
                                NumericField(label: "Grammi porzione", value: $portionGrams, color: .acc2)
                            }
                        }
                        PillButton(label: food == nil ? "Aggiungi alimento" : "Salva modifiche", disabled: !isValid) { save() }
                            .padding(.bottom, 40)
                    }
                    .padding(20)
                }
            )
            .navigationTitle(food == nil ? "Nuovo alimento" : "Modifica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                if food != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Elimina") {
                            if let f = food { context.delete(f); try? context.save() }
                            dismiss()
                        }
                        .foregroundColor(.gymPink)
                    }
                }
            }
        }
        .presentationBackground(Color.bg)
    }

    private func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func save() {
        let base   = parse(baseGrams).isZero ? 100 : parse(baseGrams)
        let factor = 100.0 / base

        let k  = parse(kcal)  * factor
        let p  = parse(protein) * factor
        let c  = parse(carbs) * factor
        let f  = parse(fat)   * factor
        let fi = parse(fiber) * factor
        let s  = parse(sugar) * factor
        let sf = parse(saturatedFat) * factor
        let sa = parse(salt) * factor
        let pName  = portionName.isEmpty ? nil : portionName
        let pGrams = Double(portionGrams.replacingOccurrences(of: ",", with: "."))

        if let existing = food {
            existing.name = name
            existing.kcalPer100g = k; existing.proteinPer100g = p
            existing.carbsPer100g = c; existing.fatPer100g = f
            existing.fiberPer100g = fi; existing.sugarPer100g = s
            existing.saturatedFatPer100g = sf
            existing.saltPer100g = sa
            existing.portionName = pName; existing.portionGrams = pGrams
        } else {
            let newFood = FoodItem(name: name, kcalPer100g: k, proteinPer100g: p,
                carbsPer100g: c, fatPer100g: f, fiberPer100g: fi,
                sugarPer100g: s, saturatedFatPer100g: sf, saltPer100g: sa,
                portionName: pName, portionGrams: pGrams)
            context.insert(newFood)
        }
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
