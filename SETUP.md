# FitnessApp — Setup in Xcode

App iOS nativa (SwiftUI + SwiftData) con widget, Live Activities e integrazione
Apple Health. Deployment target **iOS 26.2**.

## Struttura

I gruppi del progetto sono sincronizzati col filesystem: i file `.swift` aggiunti
nelle cartelle qui sotto entrano nel target automaticamente, senza toccare Xcode.

```
Shared/                      ← compilata in tutti e tre i target
├── CalorieLogic.swift       ← pasti, budget calorico, regolarita', inserimento rapido
├── GymLogic.swift           ← dischi del bilanciere e progressione del carico
├── GoalSafety.swift         ← controllo sul ritmo dell'obiettivo di peso
├── BreathingEngine.swift    ← respirazione guidata
├── TraceShape.swift         ← forme da seguire col dito
├── PausaTheme.swift         ← palette e componenti di "Un attimo"
├── PausaContent.swift       ← calcoli e curiosita'
├── PausaOpenIntent.swift    ← intent condiviso col controllo del Centro di Controllo
├── WatchBridge.swift        ← formato dei messaggi iPhone ↔ Watch
├── WidgetShared.swift       ← dati condivisi col widget
└── ColorHex.swift

FitnessApp/
├── FitnessAppApp.swift      ← entry point, ModelContainer, recupero store
├── Models.swift             ← modelli SwiftData + calcolo calorie bruciate
├── AppState.swift           ← stato globale, sessione di allenamento attiva
├── DesignSystem.swift       ← palette e componenti condivisi
├── HealthKitManager.swift   ← passi, calorie attive, battito (singleton)
├── RunTracker.swift         ← corsa GPS
├── JumpRopeTimer.swift      ← timer a round per il salto con la corda
├── BackupModels.swift       ← formato del file di backup (solo Codable)
├── PausaModels.swift        ← dati di "Un attimo", fuori dal backup
├── LiveActivityShared.swift ← attributi Live Activity (rispecchiati nel widget)
└── Views/                   ← una cartella per tutte le schermate

FitnessWidget/               ← widget, Live Activities, controllo Centro di Controllo
FitnessWatch/                ← app per Apple Watch
Tests/ · Scripts/            ← suite di logica, eseguibili con ./Scripts/test.sh
```

## App per Apple Watch

Target `FitnessWatch`, watchOS 26. Il codice sta in `FitnessWatch/`, i tipi
condivisi con l'iPhone in `Shared/`.

Come funziona: il database SwiftData vive sul telefono e l'orologio non lo vede.
L'iPhone pubblica un riassunto della giornata con `updateApplicationContext`,
che sostituisce il precedente e sopravvive allo spegnimento. L'orologio rimanda
le azioni con `sendMessage` e, se il telefono non risponde, con
`transferUserInfo`, che fa da coda affidabile. Al polso c'è aggiornamento
ottimistico: tocchi e il numero si muove subito, senza aspettare conferma.
L'orologio non tiene stato proprio, solo una cache dell'ultimo riassunto per
non aprirsi vuoto.

### Compilare

Con un target Watch incorporato **non si deve passare `-sdk`**: forzerebbe anche
il target watchOS a usare l'SDK iOS, e `WCSessionDelegate` ha requisiti diversi
fra le due piattaforme. Si usa solo `-destination`.

```bash
xcodebuild -scheme FitnessApp -destination 'generic/platform=iOS Simulator' build
```

```bash
xcodebuild -scheme FitnessWatch -destination 'generic/platform=watchOS Simulator' build
```

### Se il target sparisce

`./Scripts/add-watch-target.py` lo ricrea nel `.pbxproj`. Serve l'SDK watchOS
installato (Xcode → Settings → Components): senza, fallisce anche la build iOS.


## Integrazioni di sistema

- **Siri e Shortcuts** — `FitnessAppIntents.swift` espone: registra acqua,
  calorie rimaste, registra peso, ripeti un pasto di ieri. Gli intent girano nel
  processo dell'app e riusano il `ModelContainer` condiviso via `IntentStore`.
- **Deep link** — schema `dcfitness://` (`sommario`, `cibo`, `acqua`, `palestra`,
  `cardio`), gestito in `RootView.onOpenURL`. Il widget medio ci collega le
  singole righe.
  > Non usare `fitnessapp://`: è già rivendicato dall'app Fitness di Apple e i
  > tap finirebbero lì.
- **Scrittura su Apple Health** — allenamenti e peso, regolabile da Impostazioni
  → Apple Health. Le calorie degli allenamenti sono escluse di default: l'app
  legge l'energia attiva da Health per calcolare le calorie bruciate, quindi
  riscriverci le proprie stime gonfierebbe il totale.

## Capability richieste sul target FitnessApp

1. **HealthKit**, con l'opzione **Background Delivery** attiva.
   L'entitlement corrispondente è già in `FitnessApp/FitnessApp.entitlements`:
   `com.apple.developer.healthkit` e `com.apple.developer.healthkit.background-delivery`.
   Senza il secondo, `enableBackgroundDelivery` fallisce e i passi non si
   aggiornano quando l'app è chiusa.
2. **App Groups** con `group.davideCorso.FitnessApp` (condiviso con il widget).
3. **Push Notifications** non serve: le Live Activity sono aggiornate in locale.

Le chiavi di privacy (Health, posizione, fotocamera) e `NSSupportsLiveActivities`
sono già in `Info.plist`.

> Dopo aver aggiunto l'entitlement di background delivery il profilo di
> provisioning va rigenerato: con il signing automatico basta riaprire il
> progetto in Xcode e ricollegare il device.

## Build

HealthKit, GPS e Live Activities non funzionano nel Simulator: per provarli
serve un iPhone fisico.

```bash
xcodebuild -scheme FitnessApp -destination 'generic/platform=iOS Simulator' build
```

## Funzionalità

- **Sommario** — anelli calorie/proteine/passi, macro, peso, acqua, palestra, sport
- **Cibo** — diario per pasto, database alimenti, piatti componibili, scanner barcode
  (OpenFoodFacts), inserimento al volo
- **Farmacia** — dosi per fascia oraria o orario preciso, promemoria giornalieri
- **Palestra** — schede, esercizi per gruppo muscolare, sessione live con timer di
  recupero su Dynamic Island, storico
- **Cardio** — corsa GPS con percorso, passo, split al km, battito dal Watch e cicli
  tipo 4×4 norvegese; salto con la corda con timer a round
- **Grafici** — panoramica per area con drill-down e periodo selezionabile
- **Predizioni** — proiezione del peso sul ritmo degli ultimi 30 giorni
- **Risultati** — totali cumulativi dalla data di inizio

## Calcolo delle calorie

Un'unica implementazione in `Models.swift`:

```
totale = BMR (Mifflin-St Jeor) × 1.2 + movimento
movimento = energia attiva di Health (o passi × 0.04) + bonus palestra 150 + sport
```

Corsa e salto con la corda salvano anche una `SportEntry` con `autoTracked = true`.
Quando Apple Health fornisce l'energia attiva, quell'attività è già conteggiata lì e
le entry `autoTracked` vengono escluse per non contarla due volte; senza dati Health
restano incluse, perché sono la stima migliore disponibile.

## Backup

`Impostazioni → Esporta dati` salva **tutto** in un JSON (formato versione 6):
alimenti, diario, giorni, piatti, schede, esercizi, allenamenti, corse, sessioni con
la corda, sport, acqua, farmacia (farmaci, dosi e log) e tutti gli obiettivi.
Dopo export e import viene mostrato il riepilogo di quanti elementi sono passati.

Il formato sta in `BackupModels.swift`, separato da SwiftData: i campi aggiunti dopo
la v5 sono opzionali, quindi i backup vecchi restano leggibili.
