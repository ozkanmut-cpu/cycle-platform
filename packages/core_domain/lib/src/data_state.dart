enum DataState {
  yes,
  no,
  unknown,
  notRecorded,
  notApplicable,
}

enum ConfidenceClass {
  high,
  medium,
  low,
  contextual,
  unknown,
}

enum VerificationStatus {
  selfReported,
  deviceMeasured,
  documentExtracted,
  aiExtracted,
  clinicianVerified,
  clinicalSource,
  estimated,
}
