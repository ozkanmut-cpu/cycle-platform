import 'package:cycle_core_domain/cycle_core_domain.dart';

enum HealthDataCategory {
  reproductive,
  vitals,
  sleep,
  activity,
  body,
  nutrition,
  wellness,
}

enum HealthSourcePlatform { healthConnect, healthKit, other }

class RawHealthRecord {
  const RawHealthRecord({
    required this.sourcePlatform,
    required this.sourceType,
    required this.sourceRecordId,
    required this.observedAt,
    required this.value,
    this.unit,
    this.sourceName,
    this.deviceName,
    this.metadata = const <String, Object?>{},
  });

  final HealthSourcePlatform sourcePlatform;
  final String sourceType;
  final String sourceRecordId;
  final DateTime observedAt;
  final Object? value;
  final String? unit;
  final String? sourceName;
  final String? deviceName;
  final Map<String, Object?> metadata;
}

class HealthTypeMapping {
  const HealthTypeMapping({
    required this.sourceType,
    required this.canonicalCode,
    required this.category,
    this.canonicalUnit,
  });

  final String sourceType;
  final String canonicalCode;
  final HealthDataCategory category;
  final String? canonicalUnit;
}

class NormalizedHealthRecord {
  const NormalizedHealthRecord({
    required this.source,
    required this.mapping,
    required this.normalizedValue,
    required this.normalizedUnit,
    required this.provenance,
  });

  final RawHealthRecord source;
  final HealthTypeMapping mapping;
  final Object? normalizedValue;
  final String? normalizedUnit;
  final Provenance provenance;

  String get deduplicationKey =>
      '${source.sourcePlatform.name}|${source.sourceRecordId}|${mapping.canonicalCode}';
}

abstract interface class UnitNormalizer {
  NormalizedValue normalize({
    required Object? value,
    required String? sourceUnit,
    required String? canonicalUnit,
  });
}

class NormalizedValue {
  const NormalizedValue(this.value, this.unit);

  final Object? value;
  final String? unit;
}

class BasicUnitNormalizer implements UnitNormalizer {
  const BasicUnitNormalizer();

  @override
  NormalizedValue normalize({
    required Object? value,
    required String? sourceUnit,
    required String? canonicalUnit,
  }) {
    if (value is! num || canonicalUnit == null || sourceUnit == null) {
      return NormalizedValue(value, canonicalUnit ?? sourceUnit);
    }

    final from = sourceUnit.toLowerCase();
    final to = canonicalUnit.toLowerCase();
    if (from == to) return NormalizedValue(value, canonicalUnit);

    if (from == 'lb' && to == 'kg') {
      return NormalizedValue(value.toDouble() * 0.45359237, canonicalUnit);
    }
    if (from == 'cm' && to == 'm') {
      return NormalizedValue(value.toDouble() / 100, canonicalUnit);
    }
    if (from == 'mg/dl' && to == 'mmol/l') {
      return NormalizedValue(value.toDouble() / 18.0, canonicalUnit);
    }

    return NormalizedValue(value, sourceUnit);
  }
}

abstract interface class ImportPermissionPolicy {
  bool canImport(HealthDataCategory category);
}

class AllowlistedImportPermissionPolicy implements ImportPermissionPolicy {
  AllowlistedImportPermissionPolicy(Set<HealthDataCategory> allowed)
      : _allowed = Set.unmodifiable(allowed);

  final Set<HealthDataCategory> _allowed;

  @override
  bool canImport(HealthDataCategory category) => _allowed.contains(category);
}

abstract interface class HealthDeduplicator {
  bool isDuplicate(NormalizedHealthRecord record);
}

class InMemoryHealthDeduplicator implements HealthDeduplicator {
  final Set<String> _seen = <String>{};

  @override
  bool isDuplicate(NormalizedHealthRecord record) {
    if (_seen.contains(record.deduplicationKey)) return true;
    _seen.add(record.deduplicationKey);
    return false;
  }
}

class ImportHistoryEntry {
  const ImportHistoryEntry({
    required this.sourcePlatform,
    required this.startedAt,
    required this.finishedAt,
    required this.imported,
    required this.skippedPermission,
    required this.skippedDuplicate,
    required this.unmapped,
  });

  final HealthSourcePlatform sourcePlatform;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int imported;
  final int skippedPermission;
  final int skippedDuplicate;
  final int unmapped;
}

class HealthIngestionResult {
  const HealthIngestionResult({
    required this.records,
    required this.history,
  });

  final List<NormalizedHealthRecord> records;
  final ImportHistoryEntry history;
}

class HealthIngestionPipeline {
  HealthIngestionPipeline({
    required Iterable<HealthTypeMapping> mappings,
    required this.permissionPolicy,
    HealthDeduplicator? deduplicator,
    UnitNormalizer? unitNormalizer,
  })  : _mappings = {
          for (final mapping in mappings) mapping.sourceType: mapping,
        },
        deduplicator = deduplicator ?? InMemoryHealthDeduplicator(),
        unitNormalizer = unitNormalizer ?? const BasicUnitNormalizer();

  final Map<String, HealthTypeMapping> _mappings;
  final ImportPermissionPolicy permissionPolicy;
  final HealthDeduplicator deduplicator;
  final UnitNormalizer unitNormalizer;

  HealthIngestionResult ingest({
    required HealthSourcePlatform sourcePlatform,
    required Iterable<RawHealthRecord> records,
    DateTime? startedAt,
  }) {
    final start = startedAt ?? DateTime.now().toUtc();
    final imported = <NormalizedHealthRecord>[];
    var skippedPermission = 0;
    var skippedDuplicate = 0;
    var unmapped = 0;

    for (final record in records) {
      final mapping = _mappings[record.sourceType];
      if (mapping == null) {
        unmapped++;
        continue;
      }
      if (!permissionPolicy.canImport(mapping.category)) {
        skippedPermission++;
        continue;
      }

      final normalized = unitNormalizer.normalize(
        value: record.value,
        sourceUnit: record.unit,
        canonicalUnit: mapping.canonicalUnit,
      );
      final canonical = NormalizedHealthRecord(
        source: record,
        mapping: mapping,
        normalizedValue: normalized.value,
        normalizedUnit: normalized.unit,
        provenance: Provenance(
          sourceKind: switch (sourcePlatform) {
            HealthSourcePlatform.healthConnect => SourceKind.healthConnect,
            HealthSourcePlatform.healthKit => SourceKind.healthKit,
            HealthSourcePlatform.other => SourceKind.device,
          },
          sourceName: record.sourceName,
          sourceRecordId: record.sourceRecordId,
          deviceName: record.deviceName,
        ),
      );

      if (deduplicator.isDuplicate(canonical)) {
        skippedDuplicate++;
        continue;
      }
      imported.add(canonical);
    }

    final finish = DateTime.now().toUtc();
    return HealthIngestionResult(
      records: List.unmodifiable(imported),
      history: ImportHistoryEntry(
        sourcePlatform: sourcePlatform,
        startedAt: start,
        finishedAt: finish,
        imported: imported.length,
        skippedPermission: skippedPermission,
        skippedDuplicate: skippedDuplicate,
        unmapped: unmapped,
      ),
    );
  }
}

const defaultHealthMappings = <HealthTypeMapping>[
  HealthTypeMapping(
    sourceType: 'menstruation_flow',
    canonicalCode: 'reproductive.menstruation.flow',
    category: HealthDataCategory.reproductive,
  ),
  HealthTypeMapping(
    sourceType: 'heart_rate',
    canonicalCode: 'vital.heart_rate',
    category: HealthDataCategory.vitals,
    canonicalUnit: 'bpm',
  ),
  HealthTypeMapping(
    sourceType: 'oxygen_saturation',
    canonicalCode: 'vital.oxygen_saturation',
    category: HealthDataCategory.vitals,
    canonicalUnit: '%',
  ),
  HealthTypeMapping(
    sourceType: 'sleep_session',
    canonicalCode: 'sleep.session',
    category: HealthDataCategory.sleep,
  ),
  HealthTypeMapping(
    sourceType: 'steps',
    canonicalCode: 'activity.steps',
    category: HealthDataCategory.activity,
    canonicalUnit: 'count',
  ),
  HealthTypeMapping(
    sourceType: 'weight',
    canonicalCode: 'body.weight',
    category: HealthDataCategory.body,
    canonicalUnit: 'kg',
  ),
  HealthTypeMapping(
    sourceType: 'height',
    canonicalCode: 'body.height',
    category: HealthDataCategory.body,
    canonicalUnit: 'm',
  ),
  HealthTypeMapping(
    sourceType: 'blood_glucose',
    canonicalCode: 'vital.blood_glucose',
    category: HealthDataCategory.vitals,
    canonicalUnit: 'mmol/L',
  ),
  HealthTypeMapping(
    sourceType: 'dietary_energy',
    canonicalCode: 'nutrition.energy',
    category: HealthDataCategory.nutrition,
    canonicalUnit: 'kcal',
  ),
  HealthTypeMapping(
    sourceType: 'mindfulness',
    canonicalCode: 'wellness.mindfulness',
    category: HealthDataCategory.wellness,
  ),
];
