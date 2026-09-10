enum SourceKind {
  patient,
  clinician,
  clinicalSystem,
  device,
  healthKit,
  healthConnect,
  wearableVendor,
  document,
  importedDocument,
  ai,
  algorithm,
  unknown,
}

class Provenance {
  const Provenance({
    required this.sourceKind,
    this.sourceName,
    this.sourceRecordId,
    this.deviceName,
    this.measurementMethod,
    this.sourceId,
    this.metadata,
  });

  final SourceKind sourceKind;
  final String? sourceName;
  final String? sourceRecordId;
  final String? deviceName;
  final String? measurementMethod;
  final String? sourceId;
  final Map<String, Object?>? metadata;
}
