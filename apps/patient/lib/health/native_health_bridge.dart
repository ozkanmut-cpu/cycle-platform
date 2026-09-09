import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:flutter/services.dart';

class NativeHealthBridge {
  const NativeHealthBridge({
    MethodChannel channel = const MethodChannel('cycle.health/native'),
  }) : _channel = channel;

  final MethodChannel _channel;

  HealthConnectGateway get healthConnect =>
      _MethodChannelHealthConnectGateway(_channel);
  HealthKitGateway get healthKit => _MethodChannelHealthKitGateway(_channel);
}

class _MethodChannelHealthConnectGateway implements HealthConnectGateway {
  const _MethodChannelHealthConnectGateway(this.channel);

  final MethodChannel channel;

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async {
    final raw =
        await channel.invokeListMethod<String>(
          'healthConnect.grantedCategories',
        ) ??
        const <String>[];
    return _decodeCategories(raw);
  }

  @override
  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async {
    final rows =
        await channel.invokeListMethod<Object?>(
          'healthConnect.readRecords',
          _rangeArgs(from, to, categories),
        ) ??
        const <Object?>[];
    return _decodeRecords(rows, HealthSourcePlatform.healthConnect);
  }

  @override
  Future<String> createChangesToken({
    required Set<HealthDataCategory> categories,
  }) async {
    final token = await channel.invokeMethod<String>(
      'healthConnect.createChangesToken',
      {'categories': _encodeCategories(categories)},
    );
    if (token == null || token.isEmpty) {
      throw StateError('Health Connect did not return a changes token.');
    }
    return token;
  }

  @override
  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  }) async {
    final raw = await channel.invokeMapMethod<String, Object?>(
      'healthConnect.readChanges',
      {'token': token, 'categories': _encodeCategories(categories)},
    );
    if (raw == null)
      throw StateError('Health Connect returned no change page.');
    return _decodeHealthConnectPage(raw);
  }
}

class _MethodChannelHealthKitGateway implements HealthKitGateway {
  const _MethodChannelHealthKitGateway(this.channel);

  final MethodChannel channel;

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async {
    final raw =
        await channel.invokeListMethod<String>('healthKit.grantedCategories') ??
        const <String>[];
    return _decodeCategories(raw);
  }

  @override
  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async {
    final rows =
        await channel.invokeListMethod<Object?>(
          'healthKit.readRecords',
          _rangeArgs(from, to, categories),
        ) ??
        const <Object?>[];
    return _decodeRecords(rows, HealthSourcePlatform.healthKit);
  }

  @override
  Future<String> createAnchor({
    required Set<HealthDataCategory> categories,
  }) async {
    final anchor = await channel.invokeMethod<String>(
      'healthKit.createAnchor',
      {'categories': _encodeCategories(categories)},
    );
    if (anchor == null || anchor.isEmpty) {
      throw StateError('HealthKit did not return an anchor.');
    }
    return anchor;
  }

  @override
  Future<HealthKitAnchorPage> readAnchoredChanges({
    required String anchor,
    required Set<HealthDataCategory> categories,
  }) async {
    final raw = await channel.invokeMapMethod<String, Object?>(
      'healthKit.readAnchoredChanges',
      {'anchor': anchor, 'categories': _encodeCategories(categories)},
    );
    if (raw == null) throw StateError('HealthKit returned no anchored page.');

    final nextAnchor = raw['nextAnchor'];
    if (nextAnchor is! String || nextAnchor.isEmpty) {
      throw StateError('HealthKit returned an invalid next anchor.');
    }

    return HealthKitAnchorPage(
      upserts: _decodeRecords(
        (raw['upserts'] as List<Object?>?) ?? const <Object?>[],
        HealthSourcePlatform.healthKit,
      ),
      deletedSourceRecordIds: List<String>.unmodifiable(
        ((raw['deletedSourceRecordIds'] as List<Object?>?) ?? const <Object?>[])
            .whereType<String>(),
      ),
      nextAnchor: nextAnchor,
      hasMore: raw['hasMore'] == true,
      anchorInvalid: raw['anchorInvalid'] == true,
    );
  }
}

Map<String, Object?> _rangeArgs(
  DateTime from,
  DateTime to,
  Set<HealthDataCategory> categories,
) => {
  'fromEpochMillis': from.toUtc().millisecondsSinceEpoch,
  'toEpochMillis': to.toUtc().millisecondsSinceEpoch,
  'categories': _encodeCategories(categories),
};

List<String> _encodeCategories(Set<HealthDataCategory> categories) =>
    categories.map((category) => category.name).toList(growable: false);

Set<HealthDataCategory> _decodeCategories(Iterable<String> values) => values
    .map(
      (value) => HealthDataCategory.values.where((item) => item.name == value),
    )
    .where((matches) => matches.isNotEmpty)
    .map((matches) => matches.first)
    .toSet();

List<RawHealthRecord> _decodeRecords(
  List<Object?> rows,
  HealthSourcePlatform platform,
) => List<RawHealthRecord>.unmodifiable(
  rows.whereType<Map<Object?, Object?>>().map(
    (row) => _decodeRecord(row, platform),
  ),
);

RawHealthRecord _decodeRecord(
  Map<Object?, Object?> row,
  HealthSourcePlatform platform,
) {
  final sourceType = row['sourceType'];
  final sourceRecordId = row['sourceRecordId'];
  final observedAtMillis = row['observedAtEpochMillis'];
  if (sourceType is! String ||
      sourceRecordId is! String ||
      observedAtMillis is! num) {
    throw FormatException('Native health record is missing required fields.');
  }

  return RawHealthRecord(
    sourcePlatform: platform,
    sourceType: sourceType,
    sourceRecordId: sourceRecordId,
    observedAt: DateTime.fromMillisecondsSinceEpoch(
      observedAtMillis.toInt(),
      isUtc: true,
    ),
    value: row['value'],
    unit: row['unit'] as String?,
    sourceName: row['sourceName'] as String?,
    deviceName: row['deviceName'] as String?,
    metadata: Map<String, Object?>.unmodifiable(
      ((row['metadata'] as Map<Object?, Object?>?) ??
              const <Object?, Object?>{})
          .map((key, value) => MapEntry(key.toString(), value)),
    ),
  );
}

HealthSyncPage _decodeHealthConnectPage(Map<String, Object?> raw) {
  final nextToken = raw['nextToken'];
  if (nextToken is! String || nextToken.isEmpty) {
    throw StateError('Health Connect returned an invalid next token.');
  }

  final changes = <HealthSyncChange>[];
  for (final item in (raw['changes'] as List<Object?>?) ?? const <Object?>[]) {
    if (item is! Map<Object?, Object?>) continue;
    switch (item['kind']) {
      case 'upsert':
        final record = item['record'];
        if (record is Map<Object?, Object?>) {
          changes.add(
            HealthSyncChange.upsert(
              _decodeRecord(record, HealthSourcePlatform.healthConnect),
            ),
          );
        }
      case 'delete':
        final id = item['sourceRecordId'];
        if (id is String) changes.add(HealthSyncChange.delete(id));
    }
  }

  return HealthSyncPage(
    changes: List.unmodifiable(changes),
    nextToken: nextToken,
    hasMore: raw['hasMore'] == true,
    tokenExpired: raw['tokenExpired'] == true,
  );
}
