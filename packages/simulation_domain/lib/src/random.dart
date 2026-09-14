class DeterministicRandom {
  DeterministicRandom(int seed) : _state = seed & 0x7fffffff;

  int _state;

  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be greater than zero');
    }
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state % max;
  }

  bool nextBool() => nextInt(2) == 1;

  double nextDouble() => nextInt(0x7fffffff) / 0x7fffffff;
}
