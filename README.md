# Red Flag 🚩

Red Flag findet die Restaurants um deinen genauen Standort, liest die
Google-Bewertungen des Restaurants, das du besuchen möchtest, und sagt dir, ob
du dort essen kannst oder vorsichtig sein musst – gemessen an **deinen**
Red Flags.

## So funktioniert's

1. **Red Flags wählen** – beim ersten Start wählst du, was für dich ein No-Go
   ist: nicht sauber, Lebensmittelvergiftung, schlechter Service, Ungeziefer,
   verdorbenes Essen, unfreundliches Personal, lange Wartezeit, überteuert,
   schlechtes Essen, Allergien nicht ernst genommen – oder eigene Begriffe wie
   „laute Musik“. Ändern kannst du sie jederzeit oben rechts.
2. **Restaurant wählen** – die App liest deinen genauen GPS-Standort und
   listet die Restaurants im gewählten Umkreis (500 m bis 5 km), nächste zuerst.
3. **Ergebnis** – die App holt die Google-Bewertungen und prüft jede deiner
   Red Flags:
   - 🟢 **Hier kannst du essen** – keine deiner Red Flags gefunden.
   - 🟠 **Sei vorsichtig** – einzelne Hinweise, mit Zitaten aus den Bewertungen.
   - 🔴 **Lieber nicht** – ernste Hinweise auf eine kritische Red Flag
     (Lebensmittelvergiftung, Ungeziefer, verdorbenes Essen, Allergien).

   Jede Prüfung wird im **Verlauf** gespeichert.

## Aufbau

```
red-flag/
├── lib/                    Flutter-App
│   ├── main.dart           Start, anonyme Anmeldung, Weiterleitung
│   ├── red_flags.dart      Katalog der Red Flags (Texte, Icons)
│   ├── models.dart         Restaurant, Prüfergebnis
│   ├── screens/            Red Flags, Restaurants in der Nähe, Ergebnis, Verlauf
│   └── services/           Standort, Cloud Functions, Firestore
├── functions/              Firebase Cloud Functions (Node 22)
│   ├── index.js            nearbyRestaurants, checkRestaurant
│   ├── places.js           Google Places API (New)
│   ├── analysis.js         Auswertung der Bewertungen (KI oder Stichworte)
│   └── redFlags.js         Red Flags und ihre Stichworte (de/en)
├── firestore.rules         Jeder sieht nur seine eigenen Daten
└── firebase.json
```

Die API-Schlüssel liegen nur im Backend (Firebase Secrets), nie in der App.

**Auswertung:** Ist ein Anthropic-API-Schlüssel hinterlegt, liest Claude die
Bewertungen und versteht auch Umschreibungen („ich lag danach die ganze Nacht
flach“). Ohne Schlüssel – oder wenn der Aufruf scheitert – sucht die App nach
Stichworten in schlechten Bewertungen (unter 4 Sternen). Das Urteil folgt in
beiden Fällen derselben Regel.

**Grenze:** Google gibt pro Restaurant höchstens **5 Bewertungen** heraus (die
„relevantesten“). Die App sagt das bei jedem Ergebnis dazu – es ist eine
Einschätzung, keine Garantie.

## Einrichten

Du brauchst: [Flutter](https://docs.flutter.dev/get-started/install),
[Node.js 22](https://nodejs.org), die Firebase CLI (`npm i -g firebase-tools`)
und die FlutterFire CLI (`dart pub global activate flutterfire_cli`).

### 1. Firebase-Projekt anlegen

In der [Firebase Console](https://console.firebase.google.com) ein neues
Projekt erstellen (z. B. `red-flag`) und:

- **Authentication → Anmeldemethode → Anonym** aktivieren
- **Firestore Database** anlegen (Standort z. B. `eur3` oder `europe-west6`)
- Auf den **Blaze-Tarif** wechseln (für Cloud Functions und externe API-Aufrufe
  nötig; die kostenlosen Kontingente bleiben erhalten)

### 2. App mit Firebase verbinden

```bash
firebase login
flutterfire configure        # Projekt wählen, Android + iOS
```

Das ersetzt `lib/firebase_options.dart` und legt `google-services.json` bzw.
`GoogleService-Info.plist` an.

### 3. Google Places API einschalten

In der [Google Cloud Console](https://console.cloud.google.com) im selben
Projekt **Places API (New)** aktivieren und unter *APIs & Dienste →
Anmeldedaten* einen API-Schlüssel erstellen (am besten auf „Places API (New)“
beschränken).

### 4. Schlüssel hinterlegen und Backend deployen

```bash
firebase use --add                                   # dein Projekt wählen
firebase functions:secrets:set PLACES_API_KEY        # Google-Schlüssel
firebase functions:secrets:set ANTHROPIC_API_KEY     # Anthropic-Schlüssel, oder "none"
cd functions && npm install && cd ..
firebase deploy --only functions,firestore:rules
```

Den Anthropic-Schlüssel bekommst du unter
[console.anthropic.com](https://console.anthropic.com). Mit `none` läuft die
App nur mit der Stichwortsuche.

### 5. App starten

```bash
flutter run
```

## Online stellen (Web-App über GitHub)

Damit läuft Red Flag unter `https://<projekt-id>.web.app` im Browser, mit
GPS-Standort. Du brauchst dafür keinen eigenen Computer mit Flutter, nur ein
paar Klicks:

1. **Firebase-Projekt anlegen** auf
   [console.firebase.google.com](https://console.firebase.google.com) →
   „Projekt hinzufügen“, z. B. `red-flag`. Die **Projekt-ID** notieren
   (steht unter dem Namen, z. B. `red-flag-1a2b3`).
2. Im Projekt:
   - **Upgrade auf Blaze** (unten links; nötig für Cloud Functions, die
     Gratiskontingente bleiben).
   - **Build → Authentication → Jetzt starten → Anonym** aktivieren.
   - **Build → Firestore Database → Datenbank erstellen** (Standort
     `europe-west6`, Produktionsmodus).
3. **Places API einschalten:** in der
   [Google Cloud Console](https://console.cloud.google.com/apis/library/places.googleapis.com)
   dasselbe Projekt wählen → „Places API (New)“ aktivieren → *Anmeldedaten →
   API-Schlüssel erstellen* (beschränken auf „Places API (New)“).
4. **Dienstkonto für GitHub:** Google Cloud Console → *IAM & Verwaltung →
   Dienstkonten → Dienstkonto erstellen*, Rollen **Bearbeiter**,
   **Firebase Admin** und **Secret Manager Admin** → *Schlüssel → Schlüssel
   hinzufügen → JSON*. Die Datei wird heruntergeladen.
5. **In GitHub** (dein neues Repository → *Settings → Secrets and variables → Actions*):
   - Secret `REDFLAG_FIREBASE_SERVICE_ACCOUNT`: den ganzen Inhalt der
     JSON-Datei
   - Secret `REDFLAG_PLACES_API_KEY`: den Google-Schlüssel
   - Secret `REDFLAG_ANTHROPIC_API_KEY` (optional): Schlüssel von
     [console.anthropic.com](https://console.anthropic.com); ohne ihn prüft
     die App per Stichwortsuche
   - Variable `REDFLAG_PROJECT_ID`: die Projekt-ID aus Schritt 1
6. **Actions → „Deploy Red Flag“ → Run workflow.** Nach ein paar Minuten steht
   der Link in der Zusammenfassung des Laufs.

Der Workflow testet zuerst App und Backend, verbindet die Web-App mit dem
Projekt (`tool/write_firebase_options.mjs`), hinterlegt die Schlüssel als
Secrets der Cloud Functions und deployt Hosting, Functions und
Firestore-Regeln.

## Tests

```bash
flutter analyze && flutter test        # App
cd functions && npm run lint && npm test   # Backend
```

## Kosten (grob)

- Google Places: „Nearby Search“ und „Place Details“ mit Bewertungen kosten je
  nach Feldern einige Rappen pro Aufruf; Google gewährt ein monatliches
  Gratiskontingent.
- Claude (Modell `claude-opus-5-5`): eine Prüfung (5 Bewertungen) kostet
  typischerweise wenige Rappen.
