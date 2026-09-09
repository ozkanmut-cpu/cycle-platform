import 'data_state.dart';
import 'provenance.dart';
import 'temporal_metadata.dart';

class Observation {
  const Observation({
    required this.id,
    required this.subjectId,
    required this.code,
    required this.temporal,
    required this.provenance,
    required this.confidence,
    this.value,
    this.unit,
    this.dataState,
    this.referenceRangeLow,
    this.referenceRangeHigh,
    this.referenceRangeText,
    this.sourceRecordId,
  });

  final String id;
  final String subjectId;
  final String code;
  final num? value;
  final String? unit;
  final DataState? dataState;
  final num? referenceRangeLow;
  final num? referenceRangeHigh;
  final String? referenceRangeText;
  final TemporalMetadata temporal;
  final Provenance provenance;
  final ConfidenceClass confidence;
  final String? sourceRecordId;
}
