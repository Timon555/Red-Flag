import 'package:flutter/material.dart';

/// A red flag the user can pick. The [id]s must match
/// `functions/redFlags.js`, which holds the words each one is recognised by.
class RedFlag {
  const RedFlag(this.id, this.label, this.description, this.icon);

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

const redFlagCatalogue = <RedFlag>[
  RedFlag(
    'dirty',
    'Nicht sauber',
    'Schmutzige Tische, Toiletten oder Küche',
    Icons.cleaning_services_outlined,
  ),
  RedFlag(
    'food_poisoning',
    'Lebensmittelvergiftung',
    'Gäste wurden nach dem Essen krank',
    Icons.sick_outlined,
  ),
  RedFlag(
    'pests',
    'Ungeziefer',
    'Kakerlaken, Mäuse, Insekten',
    Icons.pest_control_outlined,
  ),
  RedFlag(
    'spoiled_food',
    'Verdorbenes Essen',
    'Schimmel, abgelaufen, nicht durchgegart',
    Icons.no_food_outlined,
  ),
  RedFlag(
    'bad_service',
    'Schlechter Service',
    'Vergessene oder falsche Bestellungen',
    Icons.room_service_outlined,
  ),
  RedFlag(
    'rude_staff',
    'Unfreundliches Personal',
    'Unhöflich oder respektlos',
    Icons.sentiment_very_dissatisfied_outlined,
  ),
  RedFlag(
    'long_wait',
    'Lange Wartezeit',
    'Ewig aufs Essen gewartet',
    Icons.hourglass_bottom,
  ),
  RedFlag(
    'overpriced',
    'Überteuert',
    'Preis-Leistung stimmt nicht',
    Icons.money_off_outlined,
  ),
  RedFlag(
    'bad_food',
    'Schlechtes Essen',
    'Kalt, fade, verbrannt',
    Icons.thumb_down_outlined,
  ),
  RedFlag(
    'allergies',
    'Allergien nicht ernst genommen',
    'Probleme mit Allergien oder Unverträglichkeiten',
    Icons.health_and_safety_outlined,
  ),
];

RedFlag? redFlagById(String id) {
  for (final flag in redFlagCatalogue) {
    if (flag.id == id) return flag;
  }
  return null;
}
