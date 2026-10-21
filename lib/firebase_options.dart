// PLATZHALTER – wird ersetzt, sobald du `flutterfire configure` ausführst.
//
// Diese Datei verbindet die App mit deinem Firebase-Projekt. Sie wird von der
// FlutterFire CLI erzeugt und enthält die Schlüssel deines Projekts, darum
// steht hier noch nichts Echtes drin. Siehe README.md, Schritt 2.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase ist noch nicht eingerichtet. '
      'Führe `flutterfire configure` aus.',
    );
  }
}
