import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// MARK: - Assistente AI (chat)
//
// Scrivi o fotografa cosa hai mangiato: l'assistente propone una voce con i
// valori, e Conferma apre l'inserimento al volo già compilato nel pasto giusto.
// Rifiuta toglie i pulsanti e la chat continua. La logica sta in FoodAssistant.swift.

struct AIAssistantView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject private var assistant: FoodAssistantSession
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context

    @State private var input = ""
    @State private var attached: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var hasKey = AIKeyStore.load() != nil
    @FocusState private var inputFocused: Bool

    private var trimmedInput: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool {
        hasKey && !assistant.isSending && (!trimmedInput.isEmpty || attached != nil)
    }

    var body: some View {
        ZStack { Color.bg.ignoresSafeArea() }
        .overlay(
            VStack(spacing: 0) {
                PageHeader("AI", subtitle: "Scrivi o fotografa cosa hai mangiato", showSettings: $showSettings)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            if !hasKey { keyCard }
                            if assistant.messages.isEmpty {
                                introCard
                            } else {
                                HStack {
                                    Spacer()
                                    Button("Nuova conversazione") { assistant.clear() }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.muted)
                                        .disabled(assistant.isSending)
                                }
                            }
                            ForEach(assistant.messages) { message in
                                messageRow(message).id(message.id)
                            }
                            if assistant.isSending {
                                thinkingRow.id("thinking")
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // Quando si apre la tastiera resta in vista l'ultimo messaggio.
                    .defaultScrollAnchor(.bottom, for: .sizeChanges)
                    .onChange(of: assistant.messages.count) { _, _ in scrollToBottom(proxy) }
                    .onChange(of: assistant.isSending) { _, _ in scrollToBottom(proxy) }
                }

                inputBar
            }
        )
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in loadPicked(item) }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in attached = image }
                .ignoresSafeArea()
        }
        .onAppear { hasKey = AIKeyStore.load() != nil }
        .onChange(of: showSettings) { _, isOpen in
            if !isOpen { hasKey = AIKeyStore.load() != nil }
        }
    }

    // ── Messaggi ──────────────────────────────────────────────────────────

    @ViewBuilder
    private func messageRow(_ message: AIChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                VStack(alignment: .trailing, spacing: 6) {
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 15)).foregroundColor(.black)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.acc, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        case .assistant:
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 15))
                            .foregroundColor(message.isError ? .gymOrange : .txt)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(message.isError ? Color.gymOrange.opacity(0.12) : Color.card,
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    if let proposal = message.proposal {
                        AIProposalCard(proposal: proposal,
                                       onConfirm: { confirm(message) },
                                       onDecline: { assistant.setProposalState(.declined, for: message.id) })
                    }
                }
                Spacer(minLength: 32)
            }
        }
    }

    private var thinkingRow: some View {
        HStack(spacing: 8) {
            ProgressView().tint(.muted)
            Text("Sto pensando…").font(.system(size: 13)).foregroundColor(.muted)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var introCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Come funziona")
                Text("Scrivi cosa hai mangiato, per esempio \"una banana non troppo grande a pranzo\", oppure manda una foto del piatto e, se vuoi, dimmi quanto era.")
                    .font(.system(size: 13)).foregroundColor(.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Se non dici il pasto lo deduco dall'ora: 8–12 colazione, 12–15 pranzo, 15–19 snack, 19–21 cena, poi snack. Cerco prima tra i tuoi alimenti e piatti (quelli salvati durante una conversazione li vedo dalla successiva).")
                    .font(.system(size: 13)).foregroundColor(.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var keyCard: some View {
        HTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill").foregroundColor(.gymOrange)
                    Text("Serve una chiave API di Anthropic")
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.txt)
                }
                Text("Inseriscila in Impostazioni › Assistente AI. Si crea su console.anthropic.com.")
                    .font(.system(size: 13)).foregroundColor(.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Apri impostazioni") { showSettings = true }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.acc)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // ── Barra di scrittura ────────────────────────────────────────────────

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = attached {
                HStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button { attached = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20)).foregroundColor(.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Togli la foto")
                    Spacer()
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button { showCamera = true } label: {
                        Label("Scatta una foto", systemImage: "camera")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    Button { showLibrary = true } label: {
                        Label("Scegli dalla libreria", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.txt)
                        .frame(width: 40, height: 40)
                        .background(Color.card, in: Circle())
                }
                .accessibilityLabel("Aggiungi una foto")

                TextField("Cosa hai mangiato?", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .foregroundColor(.txt).tint(.acc)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button { send() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canSend ? .black : .muted)
                        .frame(width: 40, height: 40)
                        .background(canSend ? Color.acc : Color.card, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Invia")
            }
        }
        .padding(.horizontal, 16).padding(.top, 8)
        // Con un allenamento in corso la barra "Riprendi" sta sopra il menu:
        // la barra di scrittura sale per non finirci sotto.
        .padding(.bottom, appState.activeWorkoutSession != nil ? 76 : 10)
        .background(Color.bg)
    }

    // ── Azioni ────────────────────────────────────────────────────────────

    private func send() {
        guard canSend else { return }
        assistant.send(text: trimmedInput, image: attached, context: context)
        input = ""
        attached = nil
        inputFocused = false
    }

    /// Porta al pasto giusto nel diario e apre l'inserimento al volo compilato.
    /// La proposta risulta aggiunta solo se lì si preme Aggiungi.
    private func confirm(_ message: AIChatMessage) {
        guard let proposal = message.proposal, proposal.state == .pending else { return }
        let id = message.id
        let session = assistant
        appState.onPendingQuickAddSaved = { [weak session] in
            session?.setProposalState(.accepted, for: id)
        }
        appState.pendingQuickAdd = proposal.prefill
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { @MainActor in
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                attached = image
            }
            pickerItem = nil
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if assistant.isSending {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = assistant.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Anteprima della proposta

struct AIProposalCard: View {
    let proposal: AIFoodProposal
    let onConfirm: () -> Void
    let onDecline: () -> Void

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(proposal.date) { return "oggi" }
        if cal.isDateInYesterday(proposal.date) { return "ieri" }
        return proposal.date.fullDisplay.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(proposal.name)
                    .font(.system(size: 16, weight: .bold)).foregroundColor(.txt)
                HStack(spacing: 5) {
                    Image(systemName: proposal.meal.icon).font(.system(size: 11))
                    Text("\(proposal.meal.rawValue) · \(dayLabel) · \(proposal.grams.smartFormat) g")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.muted)
            }

            // Una riga per alimento, con l'origine dei valori.
            VStack(alignment: .leading, spacing: 6) {
                ForEach(proposal.items) { item in
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.system(size: 13)).foregroundColor(.txt)
                            .lineLimit(1)
                        sourceBadge(item.source)
                        Spacer()
                        Text("\(item.grams.smartFormat) g · \(Int(item.kcal.rounded())) kcal")
                            .font(.system(size: 12, weight: .medium)).foregroundColor(.muted)
                    }
                }
            }

            Rectangle().fill(Color.brd).frame(height: 0.5)

            HStack(spacing: 0) {
                macro("Kcal", proposal.kcal, .ringRed, unit: "")
                macro("Prot.", proposal.protein, .ringGreen, unit: "g")
                macro("Carb.", proposal.carbs, .gymBlue, unit: "g")
                macro("Grassi", proposal.fat, .gymOrange, unit: "g")
            }

            switch proposal.state {
            case .pending:
                HStack(spacing: 10) {
                    Button(action: onDecline) {
                        Text("Rifiuta")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.txt)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button(action: onConfirm) {
                        Text("Conferma")
                            .font(.system(size: 15, weight: .bold)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.acc, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            case .accepted:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.gymGreen)
                    Text("Aggiunta a \(proposal.meal.rawValue.lowercased())")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.gymGreen)
                }
            case .declined:
                EmptyView()
            case .superseded:
                Text("Sostituita dalla proposta più recente")
                    .font(.system(size: 12)).foregroundColor(.muted)
            }
        }
        .padding(14)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.acc.opacity(proposal.state == .pending ? 0.35 : 0), lineWidth: 1))
        .opacity(proposal.state == .superseded ? 0.55 : 1)
    }

    private func sourceBadge(_ source: AIFoodItem.Source) -> some View {
        let (text, color): (String, Color) = {
            switch source {
            case .database: return ("database", .gymGreen)
            case .dish:     return ("tuo piatto", .gymBlue)
            case .estimate: return ("stima", .gymOrange)
            }
        }()
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func macro(_ label: String, _ value: Double, _ color: Color, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(unit.isEmpty ? "\(Int(value.rounded()))" : "\(value.smartFormat)\(unit)")
                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Fotocamera

/// Scatto con la fotocamera di sistema (la libreria usa PhotosPicker, che non
/// chiede permessi).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Impostazioni

/// Chiave API di Anthropic per l'assistente, salvata nel portachiavi.
struct AIKeySettingsCard: View {
    @State private var savedKey = AIKeyStore.load()
    @State private var input = ""
    @State private var saveFailed = false

    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        LimitGroup(title: "Assistente AI") {
            VStack(alignment: .leading, spacing: 10) {
                if let key = savedKey {
                    HStack {
                        Text("Chiave API salvata")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(hex: "cccccc"))
                        Spacer()
                        Text("…" + String(key.suffix(4)))
                            .font(.system(size: 14, design: .monospaced)).foregroundColor(.muted)
                    }
                    Button("Rimuovi chiave", role: .destructive) {
                        AIKeyStore.delete()
                        savedKey = AIKeyStore.load()
                    }
                    .font(.system(size: 14, weight: .semibold))
                } else {
                    SecureField("sk-ant-…", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.txt).tint(.acc)
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button("Salva chiave") {
                        saveFailed = !AIKeyStore.save(trimmed)
                        if !saveFailed { input = "" }
                        savedKey = AIKeyStore.load()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(trimmed.isEmpty ? .muted : .acc)
                    .disabled(trimmed.isEmpty)
                    if saveFailed {
                        Text("Salvataggio non riuscito. Riprova.")
                            .font(.system(size: 12)).foregroundColor(.gymOrange)
                    }
                }
                Text("""
                     La chiave si crea su console.anthropic.com › API Keys e resta solo su questo \
                     iPhone, nel portachiavi. Modello: Claude Opus 5.5. Ogni messaggio è addebitato \
                     sul tuo account API, separato dall'abbonamento Claude: di solito pochi centesimi. \
                     Con ogni messaggio vengono inviati ad Anthropic il testo, l'eventuale foto e \
                     l'elenco dei tuoi alimenti e piatti.
                     """)
                    .font(.system(size: 11)).foregroundColor(.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        }
    }
}
