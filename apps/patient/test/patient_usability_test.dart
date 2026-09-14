import 'package:cycle_patient/connected_health_screen.dart';
import 'package:cycle_patient/patient_localizations.dart';
import 'package:cycle_patient/quick_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localized(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: PatientLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    PatientLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: child,
);

void main() {
  testWidgets('quick log is understandable without opening advanced detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () => showQuickLogSheet(context),
                child: const Text('Start log'),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Start log'));
    await tester.pumpAndSettle();

    expect(find.text('Quick Log'), findsOneWidget);
    expect(
      find.text('Tap once. You can add details later if you want.'),
      findsOneWidget,
    );
    expect(find.text('Period started'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
  });

  testWidgets(
    'connected health empty state explains absence instead of inventing zero',
    (tester) async {
      await tester.pumpWidget(
        _localized(
          const ConnectedHealthScreen(viewModel: ConnectedHealthViewModel()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No connected health data yet.'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    },
  );

  testWidgets('conflicting connected-health data stays visibly conflicting', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        const ConnectedHealthScreen(
          viewModel: ConnectedHealthViewModel(
            metrics: <ConnectedHealthMetricSummary>[
              ConnectedHealthMetricSummary(
                label: 'SpO2',
                state: ConnectedHealthMetricState.conflicting,
                sourceLabel: 'Health Connect + HealthKit',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sources conflict'), findsWidgets);
    expect(find.textContaining('Health Connect + HealthKit'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
