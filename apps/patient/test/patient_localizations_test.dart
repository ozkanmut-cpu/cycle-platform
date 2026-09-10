import 'package:cycle_patient/patient_localizations.dart';
import 'package:cycle_patient/quick_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves Turkish variants and falls back to English', () {
    expect(
      PatientLocalizations.resolve(const Locale('tr', 'TR')),
      const Locale('tr'),
    );
    expect(
      PatientLocalizations.resolve(const Locale('en', 'GB')),
      const Locale('en'),
    );
    expect(
      PatientLocalizations.resolve(const Locale('de', 'DE')),
      const Locale('en'),
    );
    expect(PatientLocalizations.resolve(null), const Locale('en'));
  });

  test('parameterized strings preserve values in both languages', () {
    final en = PatientLocalizations.forLocale(const Locale('en'));
    final tr = PatientLocalizations.forLocale(const Locale('tr'));

    expect(en.cycleDay(7), 'Cycle day 7');
    expect(tr.cycleDay(7), 'Döngü günü 7');
    expect(en.loggedEventsCount(2), '2 logged events');
    expect(tr.loggedEventsCount(2), '2 kayıtlı olay');
  });

  testWidgets('Quick Log renders Turkish labels for Turkish locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: PatientLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          PatientLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showQuickLogSheet(context),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('Hızlı Kayıt'), findsOneWidget);
    expect(find.text('Adet başladı'), findsOneWidget);
    expect(find.text('Orta akış'), findsOneWidget);
    expect(find.text('Kramplar'), findsOneWidget);
    expect(find.text('Baş ağrısı'), findsOneWidget);
  });
}
