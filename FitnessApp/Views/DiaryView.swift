import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @State private var showAddSheet = false
    @State private var selectedMeal: MealType = .breakfast

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header con navigazione giorni
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diario")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.txt)
                            Text(appState.currentDate.fullDisplay)
                                .font(.system(size: 13))
                                .foregroundColor(.muted)
                        }
                        Spacer()
                        // Mini nav
                        HStack(spacing: 8) {
                            Button { appState.goBack() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.muted)
                                    .frame(width: 30, height: 30)
                                    .background(Color.card)
                                    .cornerRadius(9)
                            }.buttonStyle(.plain)

                            Button { appState.goForward() } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(appState.canGoForward ? .muted : .brd)
                                    .frame(width: 30, height: 30)
                                    .background(Color.card)
                                    .cornerRadius(9)
                            }.buttonStyle(.plain).disabled(!appState.canGoForward)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                    // Pasti
                    VStack(spacing: 0) {
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
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

    var entries: [FoodEntry] {
        allEntries.filter { $0.dayKey == dateKey && $0.meal == meal }
    }

    var mealKcal: Double { entries.reduce(0) { $0 + $1.kcalSnapshot } }

    var body: some View {
        VStack(spacing: 0) {
            // Header pasto
            HStack {
                Text(meal.rawValue)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.txt)
                Spacer()
                Text("\(Int(mealKcal)) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.muted)
            }
            .padding(.vertical, 13)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.brd2).frame(height: 1)
            }

            // Voci
            ForEach(entries) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.foodName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "dddddd"))
                        Text("\(Int(entry.grams))g · P \(Int(entry.proteinSnapshot))g C \(Int(entry.carbsSnapshot))g G \(Int(entry.fatSnapshot))g")
                            .font(.system(size: 11))
                            .foregroundColor(.muted)
                    }
                    Spacer()
                    Text("\(Int(entry.kcalSnapshot))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.muted)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.card2).frame(height: 1)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(entry)
                        try? context.save()
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                }
            }

            // Aggiungi
            Button {
                onAdd()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Aggiungi a \(meal.rawValue.lowercased())")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.acc2)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Add Food Sheet

struct AddFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let meal: MealType
    let date: Date

    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @State private var search = ""
    @State private var selectedFood: FoodItem?
    @State private var grams = "100"

    var filtered: [FoodItem] {
        search.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.muted)
                        TextField("Cerca alimento...", text: $search)
                            .foregroundColor(.txt)
                            .tint(.acc2)
                    }
                    .padding(12)
                    .background(Color.card)
                    .cornerRadius(14)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // Lista alimenti
                    if let food = selectedFood {
                        // Schermata inserimento grammi
                        VStack(spacing: 20) {
                            HTCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(food.name)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.txt)
                                    Text("\(Int(food.kcalPer100g)) kcal · P \(Int(food.proteinPer100g))g · C \(Int(food.carbsPer100g))g · G \(Int(food.fatPer100g))g")
                                        .font(.system(size: 12))
                                        .foregroundColor(.muted)
                                    Text("per 100g")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.muted)
                                }
                            }
                            .padding(.horizontal, 20)

                            VStack(spacing: 8) {
                                Text("Quantità (grammi)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.muted)
                                TextField("100", text: $grams)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.txt)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 16)
                                    .frame(width: 140)
                                    .background(Color.card)
                                    .cornerRadius(16)

                                if let g = Double(grams) {
                                    Text("\(Int(food.kcal(for: g))) kcal totali")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.acc2)
                                }
                            }

                            Button {
                                addFood(food)
                            } label: {
                                Text("Aggiungi a \(meal.rawValue)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.acc)
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)

                            Button("Scegli altro alimento") {
                                selectedFood = nil
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.muted)
                        }
                        .padding(.top, 20)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(filtered) { food in
                                    Button {
                                        selectedFood = food
                                        grams = "100"
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(food.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Color(hex: "dddddd"))
                                                Text("P \(Int(food.proteinPer100g))g · C \(Int(food.carbsPer100g))g · G \(Int(food.fatPer100g))g")
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
                                        .padding(.horizontal, 20)
                                        .overlay(alignment: .bottom) {
                                            Rectangle().fill(Color.card2).frame(height: 1)
                                                .padding(.leading, 20)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            )
            .navigationTitle(selectedFood == nil ? "Aggiungi alimento" : "Quantità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                        .foregroundColor(.muted)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.bg)
    }

    private func addFood(_ food: FoodItem) {
        guard let g = Double(grams), g > 0 else { return }
        let entry = FoodEntry(food: food, grams: g, meal: meal, date: date)
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
