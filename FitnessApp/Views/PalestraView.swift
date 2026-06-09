import SwiftUI
import SwiftData

// MARK: - Sheet Item Wrappers

struct GymWorkoutItem: Identifiable {
    let id = UUID()
    let template: WorkoutTemplate?
}

struct GymTemplateItem: Identifiable {
    let id = UUID()
    let template: WorkoutTemplate?
}

struct GymExerciseItem: Identifiable {
    let id = UUID()
    let exercise: Exercise?
}

struct GymSessionDetailItem: Identifiable {
    let id = UUID()
    let session: WorkoutSession
}

// MARK: - Local workout state types

struct ActiveSetVM: Identifiable {
    var id = UUID()
    var reps: String = ""
    var weight: String = ""
    var completed = false
    var restSeconds = 90
}

struct ActiveEntryVM: Identifiable {
    var id = UUID()
    var exerciseName: String
    var muscleGroup: String
    var sets: [ActiveSetVM] = []
}

struct TemplateExerciseSetVM: Identifiable {
    var id = UUID()
    var reps: String = "10"
    var weight: String = ""
    var restSeconds: Int = 90
}

struct TemplateExerciseVM: Identifiable {
    var id = UUID()
    var exerciseName: String
    var muscleGroup: String
    var setVMs: [TemplateExerciseSetVM] = []
}

// MARK: - PalestraView

struct PalestraView: View {
    @Binding var showSettings: Bool
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState

    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var selectedTab = 0
    @State private var editingTemplate: GymTemplateItem?
    @State private var editingExercise: GymExerciseItem?
    @State private var sessionDetail: GymSessionDetailItem?
    @State private var showReorderTemplates = false
    @State private var sessionToDelete: WorkoutSession? = nil

    private func startWorkout(_ template: WorkoutTemplate?) {
        appState.activeWorkoutSession?.stop()
        appState.activeWorkoutSession = ActiveWorkoutSession(template: template)
        appState.showWorkoutSheet = true
    }

    private var exercisesByGroup: [(group: String, exercises: [Exercise])] {
        Dictionary(grouping: exercises, by: \.muscleGroup)
            .map { (group: $0.key, exercises: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.group < $1.group }
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Palestra")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.txt)
                        Text("Allenamento & progressi")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.muted)
                    }
                    Spacer()
                    GearBtn { showSettings = true }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                Picker("", selection: $selectedTab) {
                    Text("Schede").tag(0)
                    Text("Esercizi").tag(1)
                    Text("Storico").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20).padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        switch selectedTab {
                        case 0: schedeTab
                        case 1: eserciziTab
                        default: storicoTab
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        )
        .sheet(item: $editingTemplate) { item in
            TemplateEditSheet(template: item.template)
        }
        .sheet(item: $editingExercise) { item in
            ExerciseEditSheet(exercise: item.exercise)
        }
        .sheet(item: $sessionDetail) { item in
            SessionDetailSheet(session: item.session)
        }
        .sheet(isPresented: $showReorderTemplates) {
            ReorderTemplatesSheet(templates: templates)
        }
        .confirmationDialog("Eliminare questo allenamento?", isPresented: Binding(
            get: { sessionToDelete != nil },
            set: { if !$0 { sessionToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Elimina", role: .destructive) {
                if let s = sessionToDelete {
                    context.delete(s)
                    try? context.save()
                    sessionToDelete = nil
                }
            }
            Button("Annulla", role: .cancel) { sessionToDelete = nil }
        }
    }

    // MARK: - Schede Tab

    private var schedeTab: some View {
        VStack(spacing: 12) {
            Button {
                startWorkout(nil)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Allenamento libero")
                }
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.gymBlue).cornerRadius(14)
            }
            .buttonStyle(.plain)

            if templates.isEmpty {
                gymEmptyState(icon: "list.bullet.clipboard", message: "Nessuna scheda.\nCreane una con +")
            } else {
                Button {
                    showReorderTemplates = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("Riordina")
                    }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.gymBlue)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
                VStack(spacing: 0) {
                    ForEach(templates) { tmpl in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tmpl.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.txt)
                                let exCount = tmpl.templateExercises.isEmpty ? tmpl.exerciseNames.count : tmpl.templateExercises.count
                                Text("\(exCount) esercizi")
                                    .font(.system(size: 12)).foregroundColor(.muted)
                            }
                            Spacer()
                            Button {
                                editingTemplate = GymTemplateItem(template: tmpl)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14)).foregroundColor(.muted).padding(10)
                            }
                            .buttonStyle(.plain)
                            Button {
                                startWorkout(tmpl)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14)).foregroundColor(.gymBlue).padding(10)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        if tmpl.persistentModelID != templates.last?.persistentModelID {
                            Rectangle().fill(Color.brd).frame(height: 0.5).padding(.leading, 16)
                        }
                    }
                }
                .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
            }

            Button {
                editingTemplate = GymTemplateItem(template: nil)
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Nuova scheda")
                }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.gymBlue)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.gymBlue.opacity(0.1)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gymBlue.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Esercizi Tab

    private var eserciziTab: some View {
        VStack(spacing: 12) {
            if exercises.isEmpty {
                gymEmptyState(icon: "dumbbell", message: "Nessun esercizio.\nAggiungi con +")
            } else {
                ForEach(exercisesByGroup, id: \.group) { group, exs in
                    VStack(spacing: 0) {
                        Text(group.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
                        ForEach(exs) { ex in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.system(size: 15, weight: .medium)).foregroundColor(.txt)
                                    if !ex.notes.isEmpty {
                                        Text(ex.notes)
                                            .font(.system(size: 12)).foregroundColor(.muted)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12)).foregroundColor(Color(hex: "444444"))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture { editingExercise = GymExerciseItem(exercise: ex) }
                            if ex.persistentModelID != exs.last?.persistentModelID {
                                Rectangle().fill(Color.brd).frame(height: 0.5).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
                }
            }

            Button {
                editingExercise = GymExerciseItem(exercise: nil)
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Nuovo esercizio")
                }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.gymGreen)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.gymGreen.opacity(0.1)).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gymGreen.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Storico Tab

    private var storicoTab: some View {
        Group {
            if sessions.isEmpty {
                gymEmptyState(icon: "calendar.badge.clock", message: "Nessun allenamento\nregistrato ancora")
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { sess in
                        HStack(spacing: 0) {
                            Button {
                                sessionDetail = GymSessionDetailItem(session: sess)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(sess.date.fullDisplay)
                                            .font(.system(size: 15, weight: .semibold)).foregroundColor(.txt)
                                        HStack(spacing: 6) {
                                            if !sess.templateName.isEmpty {
                                                Text(sess.templateName)
                                                    .font(.system(size: 12)).foregroundColor(.gymBlue)
                                            }
                                            Text("\(sess.entries.count) esercizi")
                                                .font(.system(size: 12)).foregroundColor(.muted)
                                            if sess.durationMinutes > 0 {
                                                Text("· \(sess.durationMinutes) min")
                                                    .font(.system(size: 12)).foregroundColor(.muted)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12)).foregroundColor(Color(hex: "444444"))
                                }
                                .padding(.leading, 16).padding(.trailing, 8).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            Button {
                                sessionToDelete = sess
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14)).foregroundColor(.gymOrange.opacity(0.7))
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                        }
                        if sess.persistentModelID != sessions.last?.persistentModelID {
                            Rectangle().fill(Color.brd).frame(height: 0.5)
                        }
                    }
                }
                .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
            }
        }
    }

    // MARK: - Helper

    private func gymEmptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40)).foregroundColor(.muted)
            Text(message)
                .font(.system(size: 14)).foregroundColor(.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

// MARK: - WorkoutSessionView

struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    var session: ActiveWorkoutSession

    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var showExercisePicker = false
    @State private var showCancelConfirm = false

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Elapsed timer
                        HStack(spacing: 8) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 14)).foregroundColor(.gymBlue)
                            Text(session.elapsedDisplay)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.gymBlue)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        if session.isResting { restTimerBanner }

                        if session.entryVMs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "dumbbell")
                                    .font(.system(size: 40)).foregroundColor(.muted)
                                Text("Nessun esercizio.\nAggiungi con il tasto +")
                                    .font(.system(size: 14)).foregroundColor(.muted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                        }

                        ForEach(session.entryVMs.indices, id: \.self) { i in
                            entryCard(at: i)
                        }

                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Aggiungi esercizio")
                            }
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.gymBlue)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.gymBlue.opacity(0.1)).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gymBlue.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20).padding(.bottom, 40)
                }
            )
            .navigationTitle(session.templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showCancelConfirm = true } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Termina") { finishWorkout() }
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.gymGreen)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fine") { hideKeyboard() }
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.acc)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear {
            guard !session.isInitialized else { return }
            session.isInitialized = true
            session.entryVMs = buildInitialEntries()
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet { ex in
                var entry = ActiveEntryVM(exerciseName: ex.name, muscleGroup: ex.muscleGroup)
                entry.sets = prefillSets(for: ex.name)
                session.entryVMs.append(entry)
            }
        }
        .confirmationDialog("Allenamento in corso", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Minimizza") { dismiss() }
            Button("Annulla allenamento", role: .destructive) {
                session.stop()
                appState.activeWorkoutSession = nil
                dismiss()
            }
            Button("Continua", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func entryCard(at i: Int) -> some View {
        if i < session.entryVMs.count {
            ActiveEntryCard(
                entry: Binding(get: { session.entryVMs[i] }, set: { session.entryVMs[i] = $0 }),
                onDeleteEntry: { deleteEntry(at: i) },
                onCompleteSet: { j in completeSet(entry: i, set: j) }
            )
        }
    }

    private func deleteEntry(at i: Int) {
        guard i < session.entryVMs.count else { return }
        withAnimation { session.entryVMs.remove(at: i) }
    }

    private func completeSet(entry i: Int, set j: Int) {
        guard i < session.entryVMs.count, j < session.entryVMs[i].sets.count else { return }
        session.entryVMs[i].sets[j].completed = true
        session.startRest(seconds: session.entryVMs[i].sets[j].restSeconds)
    }

    private var restTimerBanner: some View {
        HStack {
            Image(systemName: "timer")
                .font(.system(size: 16)).foregroundColor(.gymBlue)
            Text("Riposo: \(session.restSecondsLeft)s")
                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.txt)
            Spacer()
            Button("Salta") { session.skipRest() }
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.gymBlue)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.gymBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gymBlue.opacity(0.25), lineWidth: 1))
    }

    private func buildInitialEntries() -> [ActiveEntryVM] {
        guard let tmpl = session.template else { return [] }
        let sorted = tmpl.templateExercises.sorted { $0.orderIndex < $1.orderIndex }
        if !sorted.isEmpty {
            return sorted.map { te in
                var entry = ActiveEntryVM(exerciseName: te.exerciseName, muscleGroup: te.muscleGroup)
                entry.sets = prefillSets(for: te.exerciseName, templateExercise: te)
                return entry
            }
        }
        let exerciseMap = Dictionary(allExercises.map { ($0.name, $0) }, uniquingKeysWith: { f, _ in f })
        return tmpl.exerciseNames.map { name in
            let group = exerciseMap[name]?.muscleGroup ?? ""
            var entry = ActiveEntryVM(exerciseName: name, muscleGroup: group)
            entry.sets = prefillSets(for: name)
            return entry
        }
    }

    private func prefillSets(for exerciseName: String, templateExercise: TemplateExercise? = nil) -> [ActiveSetVM] {
        for sess in allSessions {
            if let lastEntry = sess.entries.first(where: { $0.exerciseName == exerciseName }) {
                let sorted = lastEntry.sets.sorted { $0.orderIndex < $1.orderIndex }
                if !sorted.isEmpty {
                    return sorted.map { s in
                        ActiveSetVM(reps: s.reps > 0 ? "\(s.reps)" : "",
                                    weight: s.weight > 0 ? s.weight.formatted1 : "",
                                    restSeconds: s.restSeconds)
                    }
                }
            }
        }
        if let te = templateExercise {
            let teSets = te.templateSets.sorted { $0.orderIndex < $1.orderIndex }
            if !teSets.isEmpty {
                return teSets.map { ts in
                    ActiveSetVM(reps: ts.reps > 0 ? "\(ts.reps)" : "",
                                weight: ts.weight > 0 ? ts.weight.formatted1 : "",
                                restSeconds: ts.restSeconds)
                }
            }
            return (0..<max(1, te.sets)).map { _ in
                ActiveSetVM(reps: te.reps > 0 ? "\(te.reps)" : "",
                            weight: te.weight > 0 ? te.weight.formatted1 : "",
                            restSeconds: te.restSeconds)
            }
        }
        let ex = allExercises.first { $0.name == exerciseName }
        let sets = ex?.defaultSets ?? 3
        let reps = ex?.defaultReps ?? 10
        let wkg  = ex?.defaultWeight ?? 0
        let rest = ex?.defaultRestSeconds ?? 90
        return (0..<sets).map { _ in
            ActiveSetVM(reps: reps > 0 ? "\(reps)" : "",
                        weight: wkg > 0 ? wkg.formatted1 : "",
                        restSeconds: rest)
        }
    }

    private func finishWorkout() {
        session.stop()
        let record = WorkoutSession(date: session.startTime, templateName: session.templateName)
        record.durationMinutes = max(1, Int(Date().timeIntervalSince(session.startTime) / 60))
        context.insert(record)
        for (i, eVM) in session.entryVMs.enumerated() {
            let entry = WorkoutEntry(exerciseName: eVM.exerciseName,
                                    exerciseMuscleGroup: eVM.muscleGroup, orderIndex: i)
            entry.session = record
            context.insert(entry)
            record.entries.append(entry)
            for (j, sVM) in eVM.sets.enumerated() {
                let reps = Int(sVM.reps) ?? 0
                let kg = Double(sVM.weight.replacingOccurrences(of: ",", with: ".")) ?? 0
                let ws = WorkoutSet(reps: reps, weight: kg, completed: sVM.completed,
                                   restSeconds: sVM.restSeconds, orderIndex: j)
                ws.entry = entry
                context.insert(ws)
                entry.sets.append(ws)
            }
        }
        let todayKey = session.startTime.dateKey
        let logDescriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dateKey == todayKey })
        if let log = (try? context.fetch(logDescriptor))?.first {
            if log.gymColor == .rest { log.gymColor = .green }
        } else {
            let log = DayLog(dateKey: todayKey)
            log.gymColor = .green
            context.insert(log)
        }
        try? context.save()
        appState.activeWorkoutSession = nil
        dismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - ActiveEntryCard

struct ActiveEntryCard: View {
    @Binding var entry: ActiveEntryVM
    let onDeleteEntry: () -> Void
    let onCompleteSet: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exerciseName)
                        .font(.system(size: 16, weight: .bold)).foregroundColor(.txt)
                    if !entry.muscleGroup.isEmpty {
                        Text(entry.muscleGroup)
                            .font(.system(size: 12)).foregroundColor(.muted)
                    }
                }
                Spacer()
                Button(action: onDeleteEntry) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20)).foregroundColor(Color(hex: "555555"))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("Serie").font(.system(size: 11, weight: .semibold)).foregroundColor(.muted).frame(width: 36, alignment: .leading)
                Spacer()
                Text("Kg").font(.system(size: 11, weight: .semibold)).foregroundColor(.muted).frame(width: 72, alignment: .center)
                Text("Reps").font(.system(size: 11, weight: .semibold)).foregroundColor(.muted).frame(width: 72, alignment: .center)
                Text("").frame(width: 36)
            }

            ForEach(entry.sets.indices, id: \.self) { j in
                if j < entry.sets.count {
                    ActiveSetRow(
                        set: Binding(get: { entry.sets[j] }, set: { entry.sets[j] = $0 }),
                        setNumber: j + 1,
                        onComplete: { onCompleteSet(j) },
                        onDelete: { entry.sets.remove(at: j) }
                    )
                }
            }

            Button {
                let last = entry.sets.last
                entry.sets.append(ActiveSetVM(
                    reps: last?.reps ?? "",
                    weight: last?.weight ?? "",
                    restSeconds: last?.restSeconds ?? 90
                ))
            } label: {
                Text("+ Aggiungi serie")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.gymBlue)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
    }
}

// MARK: - ActiveSetRow

struct ActiveSetRow: View {
    @Binding var set: ActiveSetVM
    let setNumber: Int
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(set.completed ? .gymGreen : .muted)
                .frame(width: 36, alignment: .leading)

            TextField("0", text: $set.weight)
                .keyboardType(.decimalPad)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(set.completed ? .gymGreen : .txt)
                .multilineTextAlignment(.center)
                .frame(width: 72)
                .padding(.vertical, 8)
                .background(
                    Color.white.opacity(set.completed ? 0.04 : 0.08),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            TextField("0", text: $set.reps)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(set.completed ? .gymGreen : .txt)
                .multilineTextAlignment(.center)
                .frame(width: 72)
                .padding(.vertical, 8)
                .background(
                    Color.white.opacity(set.completed ? 0.04 : 0.08),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            Button(action: onComplete) {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(set.completed ? .gymGreen : Color(hex: "555555"))
            }
            .buttonStyle(.plain)
            .frame(width: 36)
        }
        .opacity(set.completed ? 0.55 : 1.0)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
}

// MARK: - ExercisePickerSheet

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @State private var searchText = ""

    private var filtered: [Exercise] {
        searchText.isEmpty ? exercises : exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var byGroup: [(String, [Exercise])] {
        Dictionary(grouping: filtered, by: \.muscleGroup)
            .map { ($0.key, $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                List {
                    ForEach(byGroup, id: \.0) { group, exs in
                        Section(group) {
                            ForEach(exs) { ex in
                                Button {
                                    onSelect(ex)
                                    dismiss()
                                } label: {
                                    Text(ex.name)
                                        .foregroundColor(.txt)
                                        .font(.system(size: 15))
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Cerca esercizio")
            )
            .navigationTitle("Scegli Esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationBackground(Color.bg)
    }
}

// MARK: - TemplateEditSheet

struct TemplateEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let template: WorkoutTemplate?

    @State private var name = ""
    @State private var exerciseVMs: [TemplateExerciseVM] = []
    @State private var showPicker = false
    @State private var showReorderExercises = false

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        nameCard
                        if !exerciseVMs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    SectionLabel(text: "Esercizi (\(exerciseVMs.count))")
                                    Spacer()
                                    Button {
                                        showReorderExercises = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.arrow.down")
                                            Text("Riordina")
                                        }
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.gymBlue)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.leading, 4)
                                ForEach(exerciseVMs.indices, id: \.self) { i in
                                    templateExerciseCard(at: i)
                                }
                            }
                        }
                        addExerciseButton
                        PillButton(label: "Salva", disabled: name.trimmingCharacters(in: .whitespaces).isEmpty) { save() }
                    }
                    .padding(20).padding(.bottom, 40)
                }
            )
            .navigationTitle(template == nil ? "Nuova scheda" : "Modifica scheda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { loadTemplate() }
        .sheet(isPresented: $showPicker) {
            ExercisePickerSheet { ex in addExercise(ex) }
        }
        .sheet(isPresented: $showReorderExercises) {
            ExerciseReorderSheet(exerciseVMs: $exerciseVMs)
        }
    }

    private var nameCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Nome scheda").frame(maxWidth: .infinity, alignment: .leading)
                TextField("Es. Giorno A – Petto", text: $name)
                    .font(.system(size: 16, weight: .medium)).foregroundColor(.txt).tint(.acc2)
                    .padding(.vertical, 10).padding(.horizontal, 14)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var addExerciseButton: some View {
        Button { showPicker = true } label: {
            HStack {
                Image(systemName: "plus")
                Text("Aggiungi esercizio")
            }
            .font(.system(size: 14, weight: .semibold)).foregroundColor(.gymBlue)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.gymBlue.opacity(0.1)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gymBlue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func templateExerciseCard(at i: Int) -> some View {
        if i < exerciseVMs.count {
            TemplateExerciseCard(
                vm: Binding(get: { exerciseVMs[i] }, set: { exerciseVMs[i] = $0 }),
                index: i,
                onDelete: { removeExercise(at: i) }
            )
        }
    }

    private func removeExercise(at i: Int) {
        guard i < exerciseVMs.count else { return }
        withAnimation { exerciseVMs.remove(at: i) }
    }

    private func addExercise(_ ex: Exercise) {
        guard !exerciseVMs.contains(where: { $0.exerciseName == ex.name }) else { return }
        let count = max(1, ex.defaultSets)
        let setVMs = (0..<count).map { _ in
            TemplateExerciseSetVM(
                reps: ex.defaultReps > 0 ? "\(ex.defaultReps)" : "",
                weight: ex.defaultWeight > 0 ? ex.defaultWeight.formatted1 : "",
                restSeconds: ex.defaultRestSeconds
            )
        }
        exerciseVMs.append(TemplateExerciseVM(
            exerciseName: ex.name,
            muscleGroup: ex.muscleGroup,
            setVMs: setVMs
        ))
    }

    private func loadTemplate() {
        name = template?.name ?? ""
        let sorted = (template?.templateExercises ?? []).sorted { $0.orderIndex < $1.orderIndex }
        if !sorted.isEmpty {
            exerciseVMs = sorted.map { te in
                let teSets = te.templateSets.sorted { $0.orderIndex < $1.orderIndex }
                let setVMs: [TemplateExerciseSetVM]
                if !teSets.isEmpty {
                    setVMs = teSets.map { ts in
                        TemplateExerciseSetVM(
                            reps: ts.reps > 0 ? "\(ts.reps)" : "",
                            weight: ts.weight > 0 ? ts.weight.formatted1 : "",
                            restSeconds: ts.restSeconds
                        )
                    }
                } else {
                    setVMs = (0..<max(1, te.sets)).map { _ in
                        TemplateExerciseSetVM(
                            reps: te.reps > 0 ? "\(te.reps)" : "",
                            weight: te.weight > 0 ? te.weight.formatted1 : "",
                            restSeconds: te.restSeconds
                        )
                    }
                }
                return TemplateExerciseVM(exerciseName: te.exerciseName, muscleGroup: te.muscleGroup, setVMs: setVMs)
            }
        } else if let names = template?.exerciseNames, !names.isEmpty {
            let exMap = Dictionary(allExercises.map { ($0.name, $0) }, uniquingKeysWith: { f, _ in f })
            exerciseVMs = names.map { n in
                let ex = exMap[n]
                let count = max(1, ex?.defaultSets ?? 3)
                let setVMs = (0..<count).map { _ in
                    TemplateExerciseSetVM(
                        reps: (ex?.defaultReps ?? 10) > 0 ? "\(ex?.defaultReps ?? 10)" : "",
                        weight: (ex?.defaultWeight ?? 0) > 0 ? (ex?.defaultWeight ?? 0).formatted1 : "",
                        restSeconds: ex?.defaultRestSeconds ?? 90
                    )
                }
                return TemplateExerciseVM(exerciseName: n, muscleGroup: ex?.muscleGroup ?? "", setVMs: setVMs)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let tmpl: WorkoutTemplate
        if let existing = template {
            existing.name = trimmed
            for te in existing.templateExercises { context.delete(te) }
            existing.templateExercises = []
            tmpl = existing
        } else {
            let newTmpl = WorkoutTemplate(name: trimmed)
            context.insert(newTmpl)
            tmpl = newTmpl
        }
        for (i, vm) in exerciseVMs.enumerated() {
            let te = TemplateExercise(exerciseName: vm.exerciseName, muscleGroup: vm.muscleGroup, orderIndex: i)
            te.sets = vm.setVMs.count
            te.reps = Int(vm.setVMs.first?.reps ?? "") ?? 0
            te.weight = Double(vm.setVMs.first?.weight.replacingOccurrences(of: ",", with: ".") ?? "") ?? 0
            te.restSeconds = vm.setVMs.first?.restSeconds ?? 90
            te.template = tmpl
            context.insert(te)
            for (j, sVM) in vm.setVMs.enumerated() {
                let ts = TemplateExerciseSet(
                    reps: Int(sVM.reps) ?? 0,
                    weight: Double(sVM.weight.replacingOccurrences(of: ",", with: ".")) ?? 0,
                    restSeconds: sVM.restSeconds,
                    orderIndex: j
                )
                ts.templateExercise = te
                context.insert(ts)
                te.templateSets.append(ts)
            }
            tmpl.templateExercises.append(te)
        }
        tmpl.exerciseNames = exerciseVMs.map(\.exerciseName)
        try? context.save()
        dismiss()
    }
}

// MARK: - TemplateExerciseCard

struct TemplateExerciseCard: View {
    @Binding var vm: TemplateExerciseVM
    let index: Int
    let onDelete: () -> Void

    @State private var showDetail = false

    private var summary: String {
        let n = vm.setVMs.count
        guard n > 0 else { return "Nessuna serie" }
        let repsInts = vm.setVMs.compactMap { Int($0.reps) }
        var parts = ["\(n) serie"]
        if let minR = repsInts.min(), let maxR = repsInts.max() {
            parts.append(minR == maxR ? "\(minR) rep" : "\(minR)–\(maxR) rep")
        }
        let weights = vm.setVMs.compactMap { Double($0.weight.replacingOccurrences(of: ",", with: ".")) }.filter { $0 > 0 }
        if let minW = weights.min(), let maxW = weights.max() {
            parts.append(minW == maxW ? "\(minW.formatted1) kg" : "\(minW.formatted1)–\(maxW.formatted1) kg")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index + 1). \(vm.exerciseName)")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                    if !vm.muscleGroup.isEmpty {
                        Text(vm.muscleGroup).font(.system(size: 12)).foregroundColor(.muted)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20)).foregroundColor(.gymOrange.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(Color.brd).frame(height: 0.5)

            HStack {
                Text(summary)
                    .font(.system(size: 13)).foregroundColor(.muted)
                Spacer()
                Button("Modifica") { showDetail = true }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.gymBlue)
            }
        }
        .padding(16)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.04), lineWidth: 0.5))
        .sheet(isPresented: $showDetail) {
            TemplateExerciseDetailSheet(vm: $vm)
        }
    }
}

// MARK: - TemplateExerciseDetailSheet

struct TemplateExerciseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var vm: TemplateExerciseVM

    private let restOptions = [30, 45, 60, 90, 120, 150, 180, 240]
    private func restLabel(_ s: Int) -> String {
        s < 60 ? "\(s)s" : s % 60 == 0 ? "\(s/60) min" : "\(s/60):\(String(format: "%02d", s%60))"
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerRow
                        ForEach(vm.setVMs.indices, id: \.self) { i in
                            if i < vm.setVMs.count {
                                setRow(at: i)
                            }
                        }
                        addSetButton
                    }
                    .padding(.bottom, 40)
                }
            )
            .navigationTitle(vm.exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }.foregroundColor(.acc2)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear {
            if vm.setVMs.isEmpty {
                vm.setVMs.append(TemplateExerciseSetVM())
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("#")
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                .frame(width: 28)
            Text("Peso (kg)")
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                .frame(width: 80, alignment: .center)
            Text("Rep")
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
                .frame(width: 64, alignment: .center)
            Spacer()
            Text("Pausa")
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.muted)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    @ViewBuilder
    private func setRow(at i: Int) -> some View {
        HStack(spacing: 8) {
            Text("\(i + 1)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.muted)
                .frame(width: 28)

            TextField("0", text: Binding(
                get: { vm.setVMs[i].weight },
                set: { vm.setVMs[i].weight = $0 }
            ))
            .keyboardType(.decimalPad)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.txt)
            .multilineTextAlignment(.center)
            .frame(width: 80).padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            TextField("0", text: Binding(
                get: { vm.setVMs[i].reps },
                set: { vm.setVMs[i].reps = $0 }
            ))
            .keyboardType(.numberPad)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.txt)
            .multilineTextAlignment(.center)
            .frame(width: 64).padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            Spacer()

            Picker("", selection: Binding(
                get: { vm.setVMs[i].restSeconds },
                set: { vm.setVMs[i].restSeconds = $0 }
            )) {
                ForEach(restOptions, id: \.self) { Text(restLabel($0)).tag($0) }
            }
            .pickerStyle(.menu).tint(.gymBlue)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.card.opacity(0.6))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.brd).frame(height: 0.5).padding(.leading, 20)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { deleteSet(at: i) } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }

    private var addSetButton: some View {
        Button {
            let last = vm.setVMs.last
            vm.setVMs.append(TemplateExerciseSetVM(
                reps: last?.reps ?? "10",
                weight: last?.weight ?? "",
                restSeconds: last?.restSeconds ?? 90
            ))
        } label: {
            HStack {
                Image(systemName: "plus")
                Text("Aggiungi serie")
            }
            .font(.system(size: 14, weight: .semibold)).foregroundColor(.gymBlue)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.gymBlue.opacity(0.1)).cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gymBlue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20).padding(.top, 16)
    }

    private func deleteSet(at i: Int) {
        guard vm.setVMs.count > 1, i < vm.setVMs.count else { return }
        vm.setVMs.remove(at: i)
    }
}

// MARK: - ExerciseEditSheet

struct ExerciseEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise?

    @State private var name = ""
    @State private var muscleGroup = ""
    @State private var notes = ""
    @State private var defaultSets = 3
    @State private var defaultReps = 10
    @State private var defaultWeightStr = ""
    @State private var defaultRest = 90

    private let muscleGroups = [
        "Petto", "Schiena", "Spalle", "Bicipiti", "Tricipiti",
        "Quadricipiti", "Femorali", "Polpacci", "Adduttori", "Abduttori",
        "Addominali", "Core", "Cardio", "Altro"
    ]
    private let restOptions = [30, 45, 60, 90, 120, 150, 180, 240]
    private func restLabel(_ s: Int) -> String {
        s < 60 ? "\(s)s" : s % 60 == 0 ? "\(s/60) min" : "\(s/60):\(String(format: "%02d", s%60))"
    }

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Nome
                        HTCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(text: "Nome esercizio")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Es. Panca Piana", text: $name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.txt).tint(.acc2)
                                    .padding(.vertical, 10).padding(.horizontal, 14)
                                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Gruppo muscolare
                        HTCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(text: "Gruppo muscolare")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Picker("", selection: $muscleGroup) {
                                    Text("Seleziona").tag("")
                                    ForEach(muscleGroups, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .tint(.acc2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Valori predefiniti
                        HTCard {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionLabel(text: "Valori predefiniti")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                defaultStepperRow(label: "Serie", value: $defaultSets, range: 1...10)
                                Rectangle().fill(Color.brd).frame(height: 0.5)
                                defaultStepperRow(label: "Ripetizioni", value: $defaultReps, range: 1...50)
                                Rectangle().fill(Color.brd).frame(height: 0.5)

                                HStack {
                                    Text("Peso iniziale")
                                        .font(.system(size: 15, weight: .medium)).foregroundColor(.txt)
                                    Spacer()
                                    TextField("0", text: $defaultWeightStr)
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.gymBlue)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 72).padding(.vertical, 8).padding(.horizontal, 10)
                                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                                    Text("kg")
                                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.muted)
                                }
                                Rectangle().fill(Color.brd).frame(height: 0.5)

                                HStack {
                                    Text("Riposo")
                                        .font(.system(size: 15, weight: .medium)).foregroundColor(.txt)
                                    Spacer()
                                    Picker("", selection: $defaultRest) {
                                        ForEach(restOptions, id: \.self) { Text(restLabel($0)).tag($0) }
                                    }
                                    .pickerStyle(.menu).tint(.gymBlue)
                                }
                            }
                        }

                        // Note
                        HTCard {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(text: "Note (opzionale)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                TextField("Tecnica, varianti, attrezzatura...", text: $notes, axis: .vertical)
                                    .font(.system(size: 15))
                                    .foregroundColor(.txt).tint(.acc2)
                                    .lineLimit(3, reservesSpace: true)
                                    .padding(.vertical, 10).padding(.horizontal, 14)
                                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        PillButton(
                            label: "Salva",
                            disabled: name.trimmingCharacters(in: .whitespaces).isEmpty || muscleGroup.isEmpty
                        ) { save() }
                    }
                    .padding(20).padding(.bottom, 40)
                }
            )
            .navigationTitle(exercise == nil ? "Nuovo esercizio" : "Modifica esercizio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear {
            name = exercise?.name ?? ""
            muscleGroup = exercise?.muscleGroup ?? ""
            notes = exercise?.notes ?? ""
            defaultSets = exercise?.defaultSets ?? 3
            defaultReps = exercise?.defaultReps ?? 10
            let w = exercise?.defaultWeight ?? 0
            defaultWeightStr = w > 0 ? w.formatted1 : ""
            defaultRest = exercise?.defaultRestSeconds ?? 90
        }
    }

    @ViewBuilder
    private func defaultStepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(.txt)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 26)).foregroundColor(Color.gymBlue.opacity(0.85))
                }
                .buttonStyle(.plain)
                Text("\(value.wrappedValue)")
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.txt)
                    .frame(width: 28, alignment: .center)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26)).foregroundColor(Color.gymBlue.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let wkg = Double(defaultWeightStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        if let ex = exercise {
            ex.name = trimmed; ex.muscleGroup = muscleGroup; ex.notes = notes
            ex.defaultSets = defaultSets; ex.defaultReps = defaultReps
            ex.defaultWeight = wkg; ex.defaultRestSeconds = defaultRest
        } else {
            let ex = Exercise(name: trimmed, muscleGroup: muscleGroup, notes: notes)
            ex.defaultSets = defaultSets; ex.defaultReps = defaultReps
            ex.defaultWeight = wkg; ex.defaultRestSeconds = defaultRest
            context.insert(ex)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - ReorderTemplatesSheet

struct ReorderTemplatesSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let templates: [WorkoutTemplate]

    @State private var order: [WorkoutTemplate] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(order) { tmpl in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.muted)
                        Text(tmpl.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.txt)
                    }
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Ordina schede")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        for (i, tmpl) in order.enumerated() {
                            tmpl.sortOrder = i
                        }
                        try? context.save()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.acc2)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { order = templates }
    }
}

// MARK: - ExerciseReorderSheet

struct ExerciseReorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exerciseVMs: [TemplateExerciseVM]

    @State private var localOrder: [TemplateExerciseVM] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(localOrder) { vm in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.exerciseName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.txt)
                            if !vm.muscleGroup.isEmpty {
                                Text(vm.muscleGroup)
                                    .font(.system(size: 12))
                                    .foregroundColor(.muted)
                            }
                        }
                    }
                }
                .onMove { from, to in
                    localOrder.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color.bg)
            .navigationTitle("Ordina esercizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }.foregroundColor(.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        exerciseVMs = localOrder
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.acc2)
                }
            }
        }
        .presentationBackground(Color.bg)
        .onAppear { localOrder = exerciseVMs }
    }
}

// MARK: - SessionDetailSheet

struct SessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession

    var body: some View {
        NavigationStack {
            ZStack { Color.bg.ignoresSafeArea() }
            .overlay(
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        HTCard {
                            VStack(spacing: 6) {
                                HStack {
                                    Text(session.date.fullDisplay)
                                        .font(.system(size: 16, weight: .bold)).foregroundColor(.txt)
                                    Spacer()
                                    if session.durationMinutes > 0 {
                                        Text("\(session.durationMinutes) min")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.muted)
                                    }
                                }
                                if !session.templateName.isEmpty {
                                    Text(session.templateName)
                                        .font(.system(size: 13)).foregroundColor(.gymBlue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                let completed = session.entries.flatMap { $0.sets }.filter(\.completed).count
                                let total = session.entries.flatMap { $0.sets }.count
                                Text("\(session.entries.count) esercizi · \(completed)/\(total) serie")
                                    .font(.system(size: 12)).foregroundColor(.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        ForEach(session.entries.sorted { $0.orderIndex < $1.orderIndex }) { entry in
                            HTCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(entry.exerciseName)
                                            .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                                        Spacer()
                                        Text(entry.exerciseMuscleGroup)
                                            .font(.system(size: 12)).foregroundColor(.muted)
                                    }
                                    Divider().overlay(Color.brd)
                                    ForEach(entry.sets.sorted { $0.orderIndex < $1.orderIndex }) { ws in
                                        HStack {
                                            Text("Serie \(ws.orderIndex + 1)")
                                                .font(.system(size: 12)).foregroundColor(.muted)
                                            Spacer()
                                            Text(ws.weight > 0 ? "\(ws.weight.formatted1) kg" : "–")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(ws.completed ? .gymGreen : .muted)
                                            Text("×")
                                                .font(.system(size: 12)).foregroundColor(.muted)
                                            Text(ws.reps > 0 ? "\(ws.reps)" : "–")
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(ws.completed ? .gymGreen : .muted)
                                            Image(systemName: ws.completed ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(ws.completed ? .gymGreen : Color(hex: "555555"))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20).padding(.bottom, 40)
                }
            )
            .navigationTitle("Dettaglio allenamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }.foregroundColor(.acc2)
                }
            }
        }
        .presentationBackground(Color.bg)
    }
}
