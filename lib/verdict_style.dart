import 'package:flutter/material.dart';

import 'models.dart';

/// Colour, icon and headline for each verdict, used wherever one is shown.
class VerdictStyle {
  const VerdictStyle(this.color, this.icon, this.title);

  final Color color;
  final IconData icon;
  final String title;

  static VerdictStyle of(Verdict verdict) => switch (verdict) {
    Verdict.ok => const VerdictStyle(
      Color(0xFF2E7D32),
      Icons.check_circle,
      'Hier kannst du essen',
    ),
    Verdict.caution => const VerdictStyle(
      Color(0xFFEF6C00),
      Icons.warning_amber_rounded,
      'Sei vorsichtig',
    ),
    Verdict.avoid => const VerdictStyle(
      Color(0xFFC62828),
      Icons.flag,
      'Lieber nicht',
    ),
    Verdict.unknown => const VerdictStyle(
      Color(0xFF616161),
      Icons.help_outline,
      'Keine Aussage möglich',
    ),
  };
}

const redFlagRed = Color(0xFFD32F2F);
