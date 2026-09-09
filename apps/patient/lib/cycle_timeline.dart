import 'package:cycle_core_domain/cycle_core_domain.dart';

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class CycleTimeline {
  const CycleTimeline(this.events);

  final List<HealthEvent> events;

  DateTime? latestPeriodStartOnOrBefore(DateTime date) {
    final day = _dateOnly(date);
    DateTime? latest;
    for (final event in events) {
      if (event.eventType != 'menstruation.period_start') continue;
      final observed = _dateOnly(event.temporal.observedAt);
      if (observed.isAfter(day)) continue;
      if (latest == null || observed.isAfter(latest)) latest = observed;
    }
    return latest;
  }

  int? cycleDayFor(DateTime date) {
    final day = _dateOnly(date);
    final start = latestPeriodStartOnOrBefore(day);
    if (start == null) return null;
    return day.difference(start).inDays + 1;
  }

  List<HealthEvent> eventsForDay(DateTime date) {
    final day = _dateOnly(date);
    final result = events
        .where((event) {
          return _dateOnly(event.temporal.observedAt) == day;
        })
        .toList(growable: false);
    result.sort(
      (a, b) => b.temporal.observedAt.compareTo(a.temporal.observedAt),
    );
    return result;
  }

  Map<DateTime, List<HealthEvent>> groupedByDay() {
    final result = <DateTime, List<HealthEvent>>{};
    for (final event in events) {
      final day = _dateOnly(event.temporal.observedAt);
      result.putIfAbsent(day, () => <HealthEvent>[]).add(event);
    }
    for (final dayEvents in result.values) {
      dayEvents.sort(
        (a, b) => b.temporal.observedAt.compareTo(a.temporal.observedAt),
      );
    }
    return result;
  }
}
