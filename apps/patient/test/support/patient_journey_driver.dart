import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PatientJourneyDriver {
  PatientJourneyDriver(this.tester);

  final WidgetTester tester;
  int actionCount = 0;
  int navigationCount = 0;
  int recoveryCount = 0;

  Future<void> tapText(String label) async {
    await tester.tap(find.text(label));
    actionCount += 1;
    await tester.pumpAndSettle();
  }

  Future<void> lifecycle(AppLifecycleState state) async {
    tester.binding.handleAppLifecycleStateChanged(state);
    actionCount += 1;
    await tester.pump();
  }

  void recordNavigation() => navigationCount += 1;

  void recordRecovery() => recoveryCount += 1;
}
