import 'package:flutter/material.dart';

import 'patient_localizations.dart';

enum QuickLogKind {
  periodStart,
  flowLight,
  flowMedium,
  flowHeavy,
  cramps,
  headache,
  moodLow,
}

class QuickLogSelection {
  const QuickLogSelection({
    required this.kind,
    required this.eventType,
    this.value,
    this.unit,
    this.severity,
  });

  final QuickLogKind kind;
  final String eventType;
  final num? value;
  final String? unit;
  final int? severity;
}

const quickLogSelections = <QuickLogSelection>[
  QuickLogSelection(
    kind: QuickLogKind.periodStart,
    eventType: 'menstruation.period_start',
  ),
  QuickLogSelection(
    kind: QuickLogKind.flowLight,
    eventType: 'menstruation.flow',
    value: 1,
    unit: 'ordinal',
    severity: 1,
  ),
  QuickLogSelection(
    kind: QuickLogKind.flowMedium,
    eventType: 'menstruation.flow',
    value: 2,
    unit: 'ordinal',
    severity: 2,
  ),
  QuickLogSelection(
    kind: QuickLogKind.flowHeavy,
    eventType: 'menstruation.flow',
    value: 3,
    unit: 'ordinal',
    severity: 3,
  ),
  QuickLogSelection(kind: QuickLogKind.cramps, eventType: 'symptom.cramps'),
  QuickLogSelection(kind: QuickLogKind.headache, eventType: 'symptom.headache'),
  QuickLogSelection(kind: QuickLogKind.moodLow, eventType: 'symptom.mood_low'),
];

String quickLogLabel(PatientLocalizations strings, QuickLogKind kind) {
  return switch (kind) {
    QuickLogKind.periodStart => strings.periodStarted,
    QuickLogKind.flowLight => strings.lightFlow,
    QuickLogKind.flowMedium => strings.mediumFlow,
    QuickLogKind.flowHeavy => strings.heavyFlow,
    QuickLogKind.cramps => strings.cramps,
    QuickLogKind.headache => strings.headache,
    QuickLogKind.moodLow => strings.lowMood,
  };
}

Future<QuickLogSelection?> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet<QuickLogSelection>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final strings = PatientLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.quickLog,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(strings.quickLogHint),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickLogSelections
                  .map((selection) {
                    return ActionChip(
                      label: Text(quickLogLabel(strings, selection.kind)),
                      onPressed: () => Navigator.of(context).pop(selection),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      );
    },
  );
}
