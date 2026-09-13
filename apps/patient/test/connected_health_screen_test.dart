import 'package:cycle_patient/connected_health_screen.dart';
import 'package:cycle_patient/patient_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildApp(ConnectedHealthViewModel viewModel, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: PatientLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      PatientLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ConnectedHealthScreen(viewModel: viewModel),
  );
}

void main() {
  testWidgets('shows a non-diagnostic empty state', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const ConnectedHealthViewModel(
          sources: [
            ConnectedHealthSourceSummary(
              name: 'Health Connect',
              state: ConnectedHealthSourceState.available,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected Health'), findsWidgets);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(find.text('No connected health data yet.'), findsOneWidget);
  });

  testWidgets('keeps missing, stale and conflicting states explicit', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const ConnectedHealthViewModel(
          metrics: [
            ConnectedHealthMetricSummary(
              label: 'SpO2',
              state: ConnectedHealthMetricState.missing,
            ),
            ConnectedHealthMetricSummary(
              label: 'Weight',
              state: ConnectedHealthMetricState.stale,
              value: 72,
              unit: 'kg',
              sourceLabel: 'HealthKit',
            ),
            ConnectedHealthMetricSummary(
              label: 'Heart rate',
              state: ConnectedHealthMetricState.conflicting,
              sourceLabel: 'Health Connect + HealthKit',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data missing'), findsWidgets);
    expect(find.text('Data stale'), findsWidgets);
    expect(find.text('Sources conflict'), findsWidgets);
    expect(find.textContaining('Health Connect + HealthKit'), findsOneWidget);
    expect(find.text('72 kg'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('renders observed value and Turkish copy', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const ConnectedHealthViewModel(
          metrics: [
            ConnectedHealthMetricSummary(
              label: 'Dinlenik nabız',
              state: ConnectedHealthMetricState.observed,
              value: 62,
              unit: 'bpm',
              sourceLabel: 'Health Connect',
            ),
          ],
        ),
        locale: const Locale('tr'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bağlı Sağlık'), findsWidgets);
    expect(find.text('62 bpm'), findsOneWidget);
    expect(find.textContaining('Gözlendi'), findsOneWidget);
  });
}
