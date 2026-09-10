import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:flutter/material.dart';

import 'cycle_timeline.dart';
import 'patient_localizations.dart';

class PatientTimelineView extends StatelessWidget {
  const PatientTimelineView({
    required this.events,
    required this.labelFor,
    required this.iconFor,
    super.key,
  });

  final List<HealthEvent> events;
  final String Function(HealthEvent event) labelFor;
  final IconData Function(HealthEvent event) iconFor;

  @override
  Widget build(BuildContext context) {
    final strings = PatientLocalizations.of(context);
    if (events.isEmpty) {
      return Center(child: Text(strings.nothingLogged));
    }

    final timeline = CycleTimeline(events);
    final grouped = timeline.groupedByDay().entries.toList(growable: false)
      ..sort((a, b) => b.key.compareTo(a.key));

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final day = grouped[index].key;
        final dayEvents = grouped[index].value;
        final cycleDay = timeline.cycleDayFor(day);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${day.day.toString().padLeft(2, '0')}.'
                    '${day.month.toString().padLeft(2, '0')}.${day.year}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (cycleDay != null) ...[
                    const SizedBox(width: 8),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(strings.cycleDay(cycleDay)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              ...dayEvents.map((event) {
                final observed = event.temporal.observedAt.toLocal();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(iconFor(event)),
                  title: Text(labelFor(event)),
                  subtitle: Text(
                    '${observed.hour.toString().padLeft(2, '0')}:'
                    '${observed.minute.toString().padLeft(2, '0')}',
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
