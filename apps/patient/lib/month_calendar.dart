import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:flutter/material.dart';

import 'cycle_timeline.dart';
import 'patient_localizations.dart';

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({required this.events, this.initialMonth, super.key});

  final List<HealthEvent> events;
  final DateTime? initialMonth;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _month;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _month = DateTime(initial.year, initial.month);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = PatientLocalizations.of(context);
    final timeline = CycleTimeline(widget.events);
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstDay.weekday - DateTime.monday;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: strings.previousMonth,
              onPressed: () => _moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: strings.nextMonth,
              onPressed: () => _moveMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final label in strings.weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: _buildCell(
                    context,
                    timeline,
                    strings,
                    row * 7 + column - leading + 1,
                    daysInMonth,
                  ),
                ),
            ],
          ),
        if (_selectedDay != null) ...[
          const SizedBox(height: 12),
          _SelectedDaySummary(day: _selectedDay!, timeline: timeline),
        ],
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    CycleTimeline timeline,
    PatientLocalizations strings,
    int dayNumber,
    int daysInMonth,
  ) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }

    final date = DateTime(_month.year, _month.month, dayNumber);
    final events = timeline.eventsForDay(date);
    final isSelected =
        _selectedDay != null &&
        _selectedDay!.year == date.year &&
        _selectedDay!.month == date.month &&
        _selectedDay!.day == date.day;

    return Semantics(
      button: true,
      label:
          '${date.year}-${date.month}-${date.day}, ${strings.eventsCount(events.length)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedDay = date),
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              if (events.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(
                    events.length.clamp(1, 3),
                    (_) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(Icons.circle, size: 5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({required this.day, required this.timeline});

  final DateTime day;
  final CycleTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final strings = PatientLocalizations.of(context);
    final events = timeline.eventsForDay(day);
    final cycleDay = timeline.cycleDayFor(day);
    final cycleText = cycleDay == null
        ? strings.cycleDayUnknown
        : strings.cycleDay(cycleDay);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(cycleText),
            const SizedBox(height: 8),
            Text(strings.loggedEventsCount(events.length)),
          ],
        ),
      ),
    );
  }
}
