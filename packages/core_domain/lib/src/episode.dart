class Episode {
  const Episode({
    required this.id,
    required this.subjectId,
    required this.episodeType,
    required this.startedAt,
    required this.schemaVersion,
    this.endedAt,
    this.status = 'active',
    this.relatedEventIds = const <String>[],
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String subjectId;
  final String episodeType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final List<String> relatedEventIds;
  final Map<String, Object?> metadata;
  final int schemaVersion;

  bool get isOpen => endedAt == null && status == 'active';
}
