import SwiftUI
import SwiftData
import PhotosUI

// Quello che si prepara a mente fredda: frasi, attività, foto, piani se-allora.
// Si compila quando si sta bene, si usa quando non si sta bene.

struct PausaLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PausaFrase.ordine) private var frasi: [PausaFrase]
    @Query private var attivita: [PausaAttivita]
    @Query private var foto: [PausaFoto]
    @Query private var piani: [PausaPiano]

    @State private var sezione = 0
    @State private var nuovaFrase = ""
    @State private var nuovaAttivita = ""
    @State private var pickerFoto: [PhotosPickerItem] = []
    @State private var confermaCancella = false

    var body: some View {
        NavigationStack {
            ZStack {
                Pausa.background
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("", selection: $sezione) {
                            Text("Frasi").tag(0)
                            Text("Attività").tag(1)
                            Text("Foto").tag(2)
                            Text("Piani").tag(3)
                        }
                        .pickerStyle(.segmented)

                        switch sezione {
                        case 0: sezioneFrasi
                        case 1: sezioneAttivita
                        case 2: sezioneFoto
                        default: sezionePiani
                        }

                        aiuto
                        cancellazione
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Un attimo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }.foregroundStyle(Pausa.seafoam)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(Pausa.bgDeep)
    }

    // MARK: - Frasi

    private var sezioneFrasi: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scrivi le frasi che vorresti sentirti dire in un momento difficile. Con parole tue: quelle degli altri funzionano poco.")
                .font(.system(size: 13))
                .foregroundStyle(Pausa.inkSoft)

            ForEach(frasi) { f in
                PausaCard(accent: Pausa.mauve) {
                    HStack {
                        Text(f.testo)
                            .font(Pausa.serif(16))
                            .foregroundStyle(Pausa.ink)
                        Spacer(minLength: 8)
                        elimina { context.delete(f); try? context.save() }
                    }
                }
            }

            aggiungi(testo: $nuovaFrase, placeholder: "Una frase tua…") {
                let t = nuovaFrase.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return }
                context.insert(PausaFrase(testo: t, ordine: frasi.count))
                try? context.save()
                nuovaFrase = ""
            }
        }
    }

    // MARK: - Attività

    private var sezioneAttivita: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aggiungi qualcosa che potrebbe funzionare. Non serve che sia una buona idea.")
                .font(.system(size: 13))
                .foregroundStyle(Pausa.inkSoft)

            ForEach(attivita) { a in
                PausaCard(accent: Pausa.sand) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.testo)
                                .font(.system(size: 15))
                                .foregroundStyle(Pausa.ink)
                            if a.cambiaAmbiente {
                                Text("porta fuori")
                                    .font(Pausa.mono(10))
                                    .foregroundStyle(Pausa.sand)
                            }
                        }
                        Spacer(minLength: 8)
                        elimina { context.delete(a); try? context.save() }
                    }
                }
            }

            aggiungi(testo: $nuovaAttivita, placeholder: "Un'altra cosa da fare…") {
                let t = nuovaAttivita.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { return }
                context.insert(PausaAttivita(testo: t))
                try? context.save()
                nuovaAttivita = ""
            }
        }
    }

    // MARK: - Foto

    private var sezioneFoto: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Foto che ti fanno stare bene: persone, posti, ricordi. Restano sul telefono e non escono da qui.")
                .font(.system(size: 13))
                .foregroundStyle(Pausa.inkSoft)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(foto) { f in
                    if let img = UIImage(data: f.dati) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Button {
                                context.delete(f); try? context.save()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Pausa.ink)
                                    .frame(width: 20, height: 20)
                                    .background(Pausa.bgDeep.opacity(0.75), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                    }
                }

                PhotosPicker(selection: $pickerFoto, maxSelectionCount: 10, matching: .images) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Pausa.cardLine, style: .init(lineWidth: 1, dash: [4, 4]))
                        .frame(height: 100)
                        .overlay(Image(systemName: "plus").foregroundStyle(Pausa.inkFaint))
                }
            }
            .onChange(of: pickerFoto) { _, nuovi in
                Task { await importa(nuovi) }
            }
        }
    }

    /// Ridimensiona prima di salvare: una foto piena da 12 megapixel nel
    /// database non serve a niente e lo appesantisce.
    private func importa(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else { continue }
            let maxLato: CGFloat = 1000
            let scala = min(1, maxLato / max(img.size.width, img.size.height))
            let nuovaSize = CGSize(width: img.size.width * scala, height: img.size.height * scala)
            let render = UIGraphicsImageRenderer(size: nuovaSize)
            let ridotta = render.image { _ in img.draw(in: CGRect(origin: .zero, size: nuovaSize)) }
            guard let jpeg = ridotta.jpegData(compressionQuality: 0.72) else { continue }
            context.insert(PausaFoto(dati: jpeg))
        }
        try? context.save()
        pickerFoto = []
    }

    // MARK: - Piani

    @State private var nuovoSe = ""
    @State private var nuovoAllora = ""

    private var sezionePiani: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cosa fai quando succede. Deciderlo adesso è più facile che deciderlo dopo.")
                .font(.system(size: 13))
                .foregroundStyle(Pausa.inkSoft)

            ForEach(piani) { p in
                PausaCard(accent: Pausa.seafoam) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Se \(p.se)")
                                .font(.system(size: 14))
                                .foregroundStyle(Pausa.inkSoft)
                            Text("allora \(p.allora)")
                                .font(Pausa.serif(16))
                                .foregroundStyle(Pausa.ink)
                        }
                        Spacer(minLength: 8)
                        elimina { context.delete(p); try? context.save() }
                    }
                }
            }

            VStack(spacing: 8) {
                campo($nuovoSe, "Se sono le 22 e sono solo in cucina…")
                campo($nuovoAllora, "…allora esco e faccio il giro dell'isolato")

                if !nuovoAllora.isEmpty, sembraNegativo(nuovoAllora) {
                    Text("Prova a scrivere cosa fai, non cosa eviti. Funziona meglio.")
                        .font(.system(size: 12))
                        .foregroundStyle(Pausa.sand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                PausaButton(title: "Aggiungi", tint: Pausa.seafoam) {
                    let s = nuovoSe.trimmingCharacters(in: .whitespaces)
                    let a = nuovoAllora.trimmingCharacters(in: .whitespaces)
                    guard !s.isEmpty, !a.isEmpty else { return }
                    context.insert(PausaPiano(se: s, allora: a))
                    try? context.save()
                    nuovoSe = ""; nuovoAllora = ""
                }
            }
        }
    }

    /// Un "allora" scritto in negativo ("non mangio") funziona meno di uno
    /// scritto come azione. Suggerimento, non blocco.
    private func sembraNegativo(_ t: String) -> Bool {
        let l = t.lowercased()
        return l.hasPrefix("non ") || l.contains(" non ")
    }

    // MARK: - Aiuto

    private var aiuto: some View {
        PausaCard(accent: Pausa.cardLine) {
            VStack(alignment: .leading, spacing: 8) {
                PausaEyebrow(text: "Se vuoi parlarne con qualcuno")
                Text("Questa app non è una cura e non sostituisce nessuno.")
                    .font(.system(size: 14))
                    .foregroundStyle(Pausa.ink)
                Text("SOS Disturbi Alimentari — 800 180 969, gratuito e anonimo, anche se non sai se è abbastanza grave.\nIn Svizzera: 143, oppure il tuo medico di base.")
                    .font(.system(size: 13))
                    .foregroundStyle(Pausa.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Cancellazione

    private var cancellazione: some View {
        VStack(spacing: 6) {
            Button("Cancella tutto quello che c'è qui") { confermaCancella = true }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Pausa.mauve)
            Text("Le frasi, le foto, le note, i piani. Solo di questa sezione, subito.")
                .font(.system(size: 11))
                .foregroundStyle(Pausa.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
        .confirmationDialog("Cancellare tutto?", isPresented: $confermaCancella, titleVisibility: .visible) {
            Button("Cancella", role: .destructive) {
                PausaSeed.cancellaTutto(context: context)
            }
            Button("Annulla", role: .cancel) {}
        }
    }

    // MARK: - Pezzi riusabili

    private func elimina(_ azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Pausa.inkFaint)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }

    private func campo(_ binding: Binding<String>, _ placeholder: String) -> some View {
        TextField(placeholder, text: binding, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(Pausa.ink)
            .tint(Pausa.seafoam)
            .padding(12)
            .background(Pausa.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Pausa.cardLine, lineWidth: 1))
    }

    private func aggiungi(testo: Binding<String>, placeholder: String,
                          azione: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            campo(testo, placeholder)
            Button(action: azione) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Pausa.ink)
                    .frame(width: 46, height: 46)
                    .background(Pausa.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Dopo un episodio

/// Non chiede cosa è stato mangiato, non chiede quante calorie, non chiede
/// un voto. Constata, nasconde i numeri per un giorno e indica il prossimo pasto.
struct DopoEpisodioView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nota = ""
    @State private var salvato = false

    var body: some View {
        NavigationStack {
            ZStack {
                Pausa.background
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("È finita. Adesso è solo dopo.")
                            .font(Pausa.serif(24))
                            .foregroundStyle(Pausa.ink)

                        Text("Il piano non cambia. Riprendi dal prossimo pasto.")
                            .font(.system(size: 15))
                            .foregroundStyle(Pausa.inkSoft)

                        PausaCard(accent: Pausa.seafoam) {
                            VStack(alignment: .leading, spacing: 6) {
                                PausaEyebrow(text: "Per oggi e domani")
                                Text("I numeri restano nascosti. Puoi rimetterli quando vuoi.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Pausa.ink)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            PausaEyebrow(text: "Se vuoi, scrivi cosa stava succedendo")
                            Text("Resta sul telefono, non va da nessuna parte.")
                                .font(.system(size: 12))
                                .foregroundStyle(Pausa.inkFaint)
                            TextField("", text: $nota, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                                .font(.system(size: 15))
                                .foregroundStyle(Pausa.ink)
                                .tint(Pausa.seafoam)
                                .padding(12)
                                .background(Pausa.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        PausaButton(title: salvato ? "Fatto" : "Segna che è successo",
                                    tint: Pausa.seafoam) {
                            context.insert(PausaMarker(nota: nota.trimmingCharacters(in: .whitespaces)))
                            try? context.save()
                            SoftMode.accendiDopoEpisodio()
                            salvato = true
                            dismiss()
                        }
                    }
                    .padding(22)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }.foregroundStyle(Pausa.inkFaint)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(Pausa.bgDeep)
    }
}
