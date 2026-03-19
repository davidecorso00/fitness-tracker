# FitnessApp — Setup in Xcode

## Cosa c'è nella cartella `FitnessApp/` (target)

Tutti i file Swift sono già nella cartella giusta — Xcode li include automaticamente.

```
FitnessApp/
├── FitnessAppApp.swift       ← entry point (aggiornato)
├── ContentView.swift         ← tab bar + RootView (aggiornato)
├── Models.swift              ← SwiftData models
├── AppState.swift            ← stato globale
├── DesignSystem.swift        ← colori, componenti
├── HealthKitManager.swift    ← lettura passi
├── Views/
│   ├── TodayView.swift
│   ├── DiaryView.swift
│   ├── FoodsView.swift
│   ├── ChartsView.swift
│   └── LimitsView.swift
└── Assets.xcassets/
```

## Passi da fare in Xcode (una volta sola)

### 1. Aggiungi HealthKit capability
- Seleziona il target `FitnessApp`
- Tab **Signing & Capabilities**
- Clicca **+ Capability**
- Cerca e aggiungi **HealthKit**

### 2. Aggiungi NSHealthShareUsageDescription all'Info
- Target → **Info** tab
- Aggiungi chiave: `Privacy - Health Share Usage Description`
- Valore: `Legge i passi giornalieri dal tuo Apple Health per calcolare le calorie bruciate.`

Oppure copia il file `Info.plist` fornito nella cartella del target.

### 3. Abilita SwiftData (già nel progetto)
Nulla da fare — `modelContainer` è già configurato in `FitnessAppApp.swift`.

### 4. Build su iPhone fisico
HealthKit non funziona sul Simulator. Collega il tuo iPhone e lancia direttamente sul device.

## Funzionalità
- Navigazione giorni (frecce)
- Calorie rimanenti = 2255 − mangiato (surplus se sopra)
- 🔥 Bruciate = passi × 0.04 + 300 se allenamento
- Palestra: 4 colori + grigio riposo
- Passi sincronizzati da Apple Health
- Database alimenti con tutti i valori nutrizionali
- Grafici Swift Charts nativi (7g / 30g / 3m / tutto)
- Limiti tutti modificabili con tap
