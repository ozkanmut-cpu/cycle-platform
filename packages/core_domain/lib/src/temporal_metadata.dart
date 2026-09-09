class TemporalMetadata {
  const TemporalMetadata({
    required this.observedAt,
    required this.recordedAt,
    this.importedAt,
    this.verifiedAt,
    this.validFrom,
    this.validTo,
    this.knownAt,
  });

  final DateTime observedAt;
  final DateTime recordedAt;
  final DateTime? importedAt;
  final DateTime? verifiedAt;
  final DateTime? validFrom;
  final DateTime? validTo;
  final DateTime? knownAt;

  bool get hasClosedValidityWindow => validFrom != null && validTo != null;
}
