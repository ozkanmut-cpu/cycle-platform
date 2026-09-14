class SimulationClock {
  SimulationClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  DateTime get now => _now;

  void advance(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    _now = _now.add(duration);
  }

  void moveTo(DateTime target) {
    final normalized = target.toUtc();
    if (normalized.isBefore(_now)) {
      throw StateError('Simulation clock cannot move backwards.');
    }
    _now = normalized;
  }
}
