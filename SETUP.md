# FitnessApp — Setup in Xcode

App iOS nativa (SwiftUI + SwiftData) con widget, Live Activities e integrazione
Apple Health. Deployment target **iOS 26.2**.

## Struttura

I gruppi del progetto sono sincronizzati col filesystem: i file `.swift` aggiunti
nelle cartelle qui sotto entrano nel target automaticamente, senza toccare Xcode.

```
Shared/                      ← tipi usati da più target (iOS e watchOS)
├── CalorieLogic.swift       ← pasti, budget calorico, inserimento rapido
└── WatchBridge.swift        ← formato dei messaggi iPhone ↔ Watch

FitnessApp/
├── FitnessAppApp.swift      ← entry point, ModelContainer, recupero store
├── Models.swift             ← modelli SwiftData + calcolo calorie bruciate
├── AppState.swift           ← stato globale, sessione di allenamento attiva
├── DesignSystem.swift       ← palette e componenti condivisi
├── HealthKitManager.swift   ← passi, calorie attive, battito (singleton)
├── RunTracker.swift         ← corsa GPS
├── JumpRopeTimer.swift      ← timer a round per il salto con la corda
├── BackupModels.swift       ← formato del file di backup (solo Codable)
├── WidgetShared.swift       ← dati condivisi col widget (target membership doppia)
├── LiveActivityShared.swift ← attributi Live Activity (rispecchiati nel widget)
└── Views/                   ← una cartella per tutte le schermate

FitnessWidget/               ← widget home/lock screen + Live Activities
FitnessWatch/                ← app per Apple Watch (target non ancora nel progetto)
```

## App per Apple Watch

Il codice è pronto (`FitnessWatch/`), ma **il target non è nel progetto Xcode**:
aggiungerlo richiede l'SDK watchOS, che su questo Mac non è installato. Con un
target watch incorporato e l'SDK mancante, anche la build iOS fallisce — quindi
il target va aggiunto solo dopo aver installato la piattaforma.

1. Xcode → Settings → Components → installa **watchOS**
2. `./Scripts/add-watch-target.py`
3. `xcodebuild -scheme FitnessWatch -destination 'generic/platform=watchOS Simulator' build`

In alternativa al passo 2, in Xcode: File → New → Target → Watch App, nome
`FitnessWatch`, poi elimina i file generati e aggiungi al target le cartelle
`FitnessWatch/` e `Shared/`.

Come funziona: il database SwiftData resta sul telefono. L'iPhone pubblica un
riassunto della giornata con `updateApplicationContext`, l'orologio rimanda le
azioni con `sendMessage` e, se il telefono non risponde, con `transferUserInfo`
che fa da coda affidabile. L'orologio non tiene stato proprio, solo una cache
dell'ultimo riassunto per non aprirsi vuoto.

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
