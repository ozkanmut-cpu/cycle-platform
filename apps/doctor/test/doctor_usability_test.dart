import 'dart:ui' show SemanticsAction;

import 'package:cycle_doctor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('doctor can move across the six safety-oriented snapshot views',
      (tester) async {
    await tester.pumpWidget(const CycleDoctorApp());

    for (final label in <String>[
      'What Changed',
      'What Matters',
      'Missing',
      'Uncertain',
      'Conflicts',
      'Open Loops',
    ]) {
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pump();
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('patient switching preserves review gate and patient scope',
      (tester) async {
    await tester.pumpWidget(const CycleDoctorApp());

    await tester.tap(find.text('Patient Three'));
    await tester.pump();

    expect(find.text('Patient Three'), findsWidgets);
    expect(find.textContaining('Structured clinical content for Patient Three'),
        findsOneWidget);
    expect(find.text('Doctor Review required for writes'), findsOneWidget);
    expect(
        find.textContaining('Patient One will be rendered here'), findsNothing);
  });

  testWidgets('primary doctor controls expose tappable semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const CycleDoctorApp());

    expect(
      tester.getSemantics(find.text('Patient Two')).getSemanticsData().actions &
              SemanticsAction.tap.index !=
          0,
      isTrue,
    );
    expect(
      tester
                  .getSemantics(find.widgetWithText(ChoiceChip, 'Missing'))
                  .getSemanticsData()
                  .actions &
              SemanticsAction.tap.index !=
          0,
      isTrue,
    );
    handle.dispose();
  });
}
