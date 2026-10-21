import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_flag/models.dart';
import 'package:red_flag/red_flags.dart';
import 'package:red_flag/screens/check_screen.dart';
import 'package:red_flag/screens/red_flags_screen.dart';
import 'package:red_flag/services/profile_service.dart';

void main() {
  test('a check result survives the trip from the function', () {
    final result = CheckResult.fromMap({
      'placeId': 'abc',
      'name': 'Pizzeria Test',
      'address': 'Bahnhofstrasse 1',
      'verdict': 'avoid',
      'summary': 'Lieber nicht.',
      'engine': 'claude',
      'reviewCount': 5,
      'rating': 4.1,
      'ratingCount': 230,
      'flags': [
        {
          'id': 'food_poisoning',
          'label': 'Lebensmittelvergiftung',
          'status': 'serious',
          'note': 'Ein Gast wurde krank.',
          'evidence': [
            {
              'quote': 'Mir war die ganze Nacht übel.',
              'rating': 1,
              'when': 'vor 1 Woche',
            },
          ],
        },
        {
          'id': 'dirty',
          'label': 'Nicht sauber',
          'status': 'clear',
          'note': '',
          'evidence': [],
        },
      ],
    });
    expect(result.verdict, Verdict.avoid);
    expect(result.flags.first.status, FlagStatus.serious);
    expect(result.flags.first.evidence.single.rating, 1);
    expect(result.flags.last.status, FlagStatus.clear);
  });

  test('an unknown verdict does not crash the app', () {
    expect(
      CheckResult.fromMap({'verdict': 'something new'}).verdict,
      Verdict.unknown,
    );
  });

  testWidgets('the save button waits until a flag is picked', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RedFlagsScreen(initial: RedFlagProfile(), firstRun: true),
      ),
    );
    expect(find.text(redFlagCatalogue.first.label), findsOneWidget);

    FilledButton saveButton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveButton().onPressed, isNull);

    await tester.tap(find.text(redFlagCatalogue.first.label));
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('a verdict shows the quotes behind it', (tester) async {
    final result = CheckResult.fromMap({
      'name': 'Pizzeria Test',
      'verdict': 'caution',
      'summary': 'Sei vorsichtig.',
      'reviewCount': 5,
      'flags': [
        {
          'id': 'rude_staff',
          'label': 'Unfreundliches Personal',
          'status': 'mentioned',
          'note': 'Eine Bewertung.',
          'evidence': [
            {'quote': 'Der Kellner war frech.', 'rating': 2, 'when': ''},
          ],
        },
      ],
    });
    await tester.pumpWidget(MaterialApp(home: CheckScreen(result: result)));
    await tester.pump();
    expect(find.text('Sei vorsichtig'), findsOneWidget);
    expect(find.text('«Der Kellner war frech.»'), findsOneWidget);
  });
}
