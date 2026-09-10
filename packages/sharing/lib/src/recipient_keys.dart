class RecipientKeyState {
  const RecipientKeyState({
    required this.ownerId,
    required this.recipientId,
    required this.keyEnvelopeId,
    required this.version,
    required this.createdAt,
    this.revokedAt,
  });

  final String ownerId;
  final String recipientId;
  final String keyEnvelopeId;
  final int version;
  final DateTime createdAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}

class RecipientKeyRegistry {
  RecipientKeyRegistry({Iterable<RecipientKeyState> initial = const []})
      : _states = List<RecipientKeyState>.of(initial);

  final List<RecipientKeyState> _states;

  RecipientKeyState? activeFor({
    required String ownerId,
    required String recipientId,
  }) {
    final matches = _states
        .where(
          (state) =>
              state.ownerId == ownerId &&
              state.recipientId == recipientId &&
              !state.isRevoked,
        )
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return matches.isEmpty ? null : matches.first;
  }

  void put(RecipientKeyState state) => _states.add(state);

  RecipientKeyState rotate({
    required String ownerId,
    required String recipientId,
    required String newKeyEnvelopeId,
    required DateTime at,
  }) {
    final active = activeFor(ownerId: ownerId, recipientId: recipientId);
    if (active != null) {
      _states.remove(active);
      _states.add(
        RecipientKeyState(
          ownerId: active.ownerId,
          recipientId: active.recipientId,
          keyEnvelopeId: active.keyEnvelopeId,
          version: active.version,
          createdAt: active.createdAt,
          revokedAt: at,
        ),
      );
    }
    final next = RecipientKeyState(
      ownerId: ownerId,
      recipientId: recipientId,
      keyEnvelopeId: newKeyEnvelopeId,
      version: (active?.version ?? 0) + 1,
      createdAt: at,
    );
    _states.add(next);
    return next;
  }

  List<RecipientKeyState> all() => List.unmodifiable(_states);
}
