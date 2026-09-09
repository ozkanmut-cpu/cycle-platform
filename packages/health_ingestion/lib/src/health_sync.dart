import 'health_ingestion.dart';

enum HealthSyncChangeKind { upsert, delete }

class HealthSyncChange {
  const HealthSyncChange.upsert(this.record)
      : kind = HealthSyncChangeKind.upsert,
        deletedSourceRecordId = null;

  const HealthSyncChange.delete(this.deletedSourceRecordId)
      : kind = HealthSyncChangeKind.delete,
        record = null;

  final HealthSyncChangeKind kind;
  final RawHealthRecord? record;
  final String? deletedSourceRecordId;
}

class HealthSyncCursor {
  const HealthSyncCursor({
    required this.sourcePlatform,
    required this.token,
    required this.updatedAt,
  });

  final HealthSourcePlatform sourcePlatform;
  final String token;
  final DateTime updatedAt;
}

class HealthSyncPage {
  const HealthSyncPage({
    required this.changes,
    required this.nextToken,
    required this.hasMore,
    this.tokenExpired = false,
  });

  final List<HealthSyncChange> changes;
  final String? nextToken;
  final bool hasMore;
  final bool tokenExpired;
}

abstract interface class HealthSourceSyncAdapter {
  HealthSourcePlatform get sourcePlatform;

  Future<Set<HealthDataCategory>> grantedCategories();

  Future<List<RawHealthRecord>> readInitial({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  });

  Future<String> createChangeToken({
    required Set<HealthDataCategory> categories,
  });

  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  });
}

class HealthSourceSyncResult {
  const HealthSourceSyncResult({
    required this.upserts,
    required this.deletedSourceRecordIds,
    required this.cursor,
    required this.usedFullRefresh,
  });

  final List<RawHealthRecord> upserts;
  final List<String> deletedSourceRecordIds;
  final HealthSyncCursor cursor;
  final bool usedFullRefresh;
}

class HealthSourceSynchronizer {
  const HealthSourceSynchronizer(
      {this.initialLookback = const Duration(days: 30)});

  final Duration initialLookback;

  Future<HealthSourceSyncResult> synchronize({
    required HealthSourceSyncAdapter adapter,
    required DateTime now,
    HealthSyncCursor? previousCursor,
  }) async {
    final granted = await adapter.grantedCategories();
    if (granted.isEmpty) {
      final token = await adapter.createChangeToken(categories: granted);
      return HealthSourceSyncResult(
        upserts: const [],
        deletedSourceRecordIds: const [],
        cursor: HealthSyncCursor(
          sourcePlatform: adapter.sourcePlatform,
          token: token,
          updatedAt: now.toUtc(),
        ),
        usedFullRefresh: previousCursor == null,
      );
    }

    if (previousCursor == null ||
        previousCursor.sourcePlatform != adapter.sourcePlatform) {
      return _fullRefresh(adapter: adapter, granted: granted, now: now);
    }

    final upserts = <RawHealthRecord>[];
    final deletes = <String>[];
    var token = previousCursor.token;

    while (true) {
      final page = await adapter.readChanges(token: token, categories: granted);
      if (page.tokenExpired) {
        return _fullRefresh(adapter: adapter, granted: granted, now: now);
      }

      for (final change in page.changes) {
        switch (change.kind) {
          case HealthSyncChangeKind.upsert:
            final record = change.record;
            if (record != null) upserts.add(record);
            break;
          case HealthSyncChangeKind.delete:
            final id = change.deletedSourceRecordId;
            if (id != null) deletes.add(id);
            break;
        }
      }

      final nextToken = page.nextToken ?? token;
      if (page.hasMore && nextToken == token) {
        throw StateError(
          'Health sync source reported more pages without advancing its token.',
        );
      }
      token = nextToken;
      if (!page.hasMore) break;
    }

    return HealthSourceSyncResult(
      upserts: List.unmodifiable(upserts),
      deletedSourceRecordIds: List.unmodifiable(deletes),
      cursor: HealthSyncCursor(
        sourcePlatform: adapter.sourcePlatform,
        token: token,
        updatedAt: now.toUtc(),
      ),
      usedFullRefresh: false,
    );
  }

  Future<HealthSourceSyncResult> _fullRefresh({
    required HealthSourceSyncAdapter adapter,
    required Set<HealthDataCategory> granted,
    required DateTime now,
  }) async {
    final end = now.toUtc();
    final start = end.subtract(initialLookback);
    final records = await adapter.readInitial(
      from: start,
      to: end,
      categories: granted,
    );
    final token = await adapter.createChangeToken(categories: granted);

    return HealthSourceSyncResult(
      upserts: List.unmodifiable(records),
      deletedSourceRecordIds: const [],
      cursor: HealthSyncCursor(
        sourcePlatform: adapter.sourcePlatform,
        token: token,
        updatedAt: end,
      ),
      usedFullRefresh: true,
    );
  }
}
