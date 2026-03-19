import SwiftUI
import SwiftData

struct FoodsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    @State private var search = ""
    @State private var showAdd = false
    @State private var editFood: FoodItem?

    var filtered: [FoodItem] {
        search.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alimenti")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text("Database personale")
                            .font(.system(size: 13))
                            .foregroundColor(.muted)
                    }
                    Spacer()
                    Button {
                        editFood = nil
                        showAdd = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Nuovo")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.acc)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.muted)
                    TextField("Cerca alimento...", text: $search)
                        .foregroundColor(.txt)
                        .tint(.acc2)
                }
                .padding(12)
                .background(Color.card)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brd, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Lista
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { food in
                            FoodRow(food: food)
                                .onTapGesture {
                                    editFood = food
                                    showAdd = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        context.delete(food)
                                        try? context.save()
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
        )
        .sheet(isPresented: $showAdd) {
            FoodFormSheet(food: editFood)
        }
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
                Text("P \(Int(food.proteinPer100g))g · C \(Int(food.carbsPer100g))g · G \(Int(food.fatPer100g))g · Fi \(Int(food.fiberPer100g))g")
                    .font(.system(size: 11))
                    .foregroundColor(.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(food.kcalPer100g))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.txt)
                Text("kcal/100g")
                    .font(.system(size: 10))
                    .foregroundColor(.muted)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.card2).frame(height: 1)
        }
    }
}

// MARK: - Food Form Sheet (nuovo / modifica)

struct FoodFormSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem?   // nil = nuovo

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var sugar = ""
    @State private var saturatedFat = ""

    var isValid: Bool { !name.isEmpty && Double(kcal) != nil }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Nome")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Es. Petto di pollo", text: $name)
                                    .foregroundColor(.txt)
                                    .tint(.acc2)
                                    .padding(12)
                                    .background(Color.brd)
                                    .cornerRadius(12)
                            }
                        }

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Valori per 100g")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Calorie (kcal)", value: $kcal, color: .acc2)
                                NumericField(label: "Proteine (g)",   value: $protein, color: .acc2)
                                NumericField(label: "Carboidrati (g)", value: $carbs, color: .gymBlue)
                                NumericField(label: "Grassi (g)",     value: $fat,   color: .gymOrange)
                            }
                        }

                        HTCard {
                            VStack(spacing: 12) {
                                SectionLabel(text: "Micronutrienti per 100g")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                NumericField(label: "Fibre (g)",       value: $fiber,       color: .gymGreen)
                                NumericField(label: "Zuccheri (g)",    value: $sugar,       color: .gymPink)
                                NumericField(label: "Gr. saturi (g)",  value: $saturatedFat, color: .gymOrange)
                            }
                        }

                        Button {
                            save()
                        } label: {
                            Text(food == nil ? "Aggiungi alimento" : "Salva modifiche")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isValid ? Color.acc : Color.brd)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValid)
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
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { prefill() }
    }

    private func prefill() {
        guard let f = food else { return }
        name = f.name
        kcal = String(Int(f.kcalPer100g))
        protein = String(Int(f.proteinPer100g))
        carbs = String(Int(f.carbsPer100g))
        fat = String(Int(f.fatPer100g))
        fiber = String(Int(f.fiberPer100g))
        sugar = String(Int(f.sugarPer100g))
        saturatedFat = String(Int(f.saturatedFatPer100g))
    }

    private func save() {
        let k = Double(kcal) ?? 0
        let p = Double(protein) ?? 0
        let c = Double(carbs) ?? 0
        let f = Double(fat) ?? 0
        let fi = Double(fiber) ?? 0
        let s = Double(sugar) ?? 0
        let sf = Double(saturatedFat) ?? 0

        if let existing = food {
            existing.name = name
            existing.kcalPer100g = k
            existing.proteinPer100g = p
            existing.carbsPer100g = c
            existing.fatPer100g = f
            existing.fiberPer100g = fi
            existing.sugarPer100g = s
            existing.saturatedFatPer100g = sf
        } else {
            let newFood = FoodItem(name: name, kcalPer100g: k, proteinPer100g: p, carbsPer100g: c, fatPer100g: f, fiberPer100g: fi, sugarPer100g: s, saturatedFatPer100g: sf)
            context.insert(newFood)
        }
        try? context.save()
        dismiss()
    }
}

struct NumericField: View {
    let label: String
    @Binding var value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "cccccc"))
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .foregroundColor(color)
                .tint(color)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.brd)
                .cornerRadius(10)
        }
    }
}
