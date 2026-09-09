enum SourceKind {
  patient,
  clinician,
  clinicalSystem,
  device,
  healthKit,
  healthConnect,
  wearableVendor,
  document,
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
  });

  final SourceKind sourceKind;
  final String? sourceName;
  final String? sourceRecordId;
  final String? deviceName;
  final String? measurementMethod;
}
