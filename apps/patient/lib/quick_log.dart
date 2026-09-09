import 'package:flutter/material.dart';

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
    required this.label,
    required this.eventType,
    this.value,
    this.unit,
    this.severity,
  });

  final QuickLogKind kind;
  final String label;
  final String eventType;
  final num? value;
  final String? unit;
  final int? severity;
}

const quickLogSelections = <QuickLogSelection>[
  QuickLogSelection(
    kind: QuickLogKind.periodStart,
    label: 'Period started',
    eventType: 'menstruation.period_start',
  ),
  QuickLogSelection(
    kind: QuickLogKind.flowLight,
    label: 'Light flow',
    eventType: 'menstruation.flow',
    value: 1,
    unit: 'ordinal',
    severity: 1,
  ),
  QuickLogSelection(
    kind: QuickLogKind.flowMedium,
    label: 'Medium flow',
    eventType: 'menstruation.flow',
    value: 2,
    unit: 'ordinal',
    severity: 2,
  ),
  QuickLogSelection(
    kind: QuickLogKind.flowHeavy,
    label: 'Heavy flow',
    eventType: 'menstruation.flow',
    value: 3,
    unit: 'ordinal',
    severity: 3,
  ),
  QuickLogSelection(
    kind: QuickLogKind.cramps,
    label: 'Cramps',
    eventType: 'symptom.cramps',
  ),
  QuickLogSelection(
    kind: QuickLogKind.headache,
    label: 'Headache',
    eventType: 'symptom.headache',
  ),
  QuickLogSelection(
    kind: QuickLogKind.moodLow,
    label: 'Low mood',
    eventType: 'symptom.mood_low',
  ),
];

Future<QuickLogSelection?> showQuickLogSheet(BuildContext context) {
  return showModalBottomSheet<QuickLogSelection>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Log',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('Tap once. You can add details later if you want.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickLogSelections.map((selection) {
                return ActionChip(
                  label: Text(selection.label),
                  onPressed: () => Navigator.of(context).pop(selection),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      );
    },
  );
}
