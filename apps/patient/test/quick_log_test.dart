import 'package:cycle_patient/quick_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Quick Log exposes simple one-tap choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showQuickLogSheet(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Quick Log'), findsOneWidget);
    expect(find.text('Period started'), findsOneWidget);
    expect(find.text('Medium flow'), findsOneWidget);
    expect(find.text('Cramps'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
  });

  test('flow choices map to canonical menstruation events', () {
    final flowChoices = quickLogSelections.where(
      (selection) => selection.eventType == 'menstruation.flow',
    );

    expect(flowChoices.length, 3);
    expect(flowChoices.map((selection) => selection.severity), <int?>[1, 2, 3]);
  });
}
