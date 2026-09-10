import 'package:cycle_core_domain/cycle_core_domain.dart';

enum MissingnessKind {
  present,
  explicitNo,
  unknown,
  notRecorded,
  notApplicable,
  absent,
}

class MissingnessEngine {
  const MissingnessEngine();

  MissingnessKind classify(HealthEvent? event) {
    if (event == null) return MissingnessKind.absent;
    return switch (event.dataState) {
      DataState.no => MissingnessKind.explicitNo,
      DataState.unknown => MissingnessKind.unknown,
      DataState.notRecorded => MissingnessKind.notRecorded,
      DataState.notApplicable => MissingnessKind.notApplicable,
      DataState.yes || null => MissingnessKind.present,
    };
  }

  bool isUnknownLike(HealthEvent? event) {
    final kind = classify(event);
    return kind == MissingnessKind.absent ||
        kind == MissingnessKind.unknown ||
        kind == MissingnessKind.notRecorded;
  }
}
