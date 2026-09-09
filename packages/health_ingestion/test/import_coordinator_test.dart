import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  test('coordinator normalizes upserts and preserves delete tombstones', () async {
    final adapter = _CoordinatorAdapter();
    final coordinator = HealthImportCoordinator(
      synchronizer: const HealthSourceSynchronizer(),
      pipeline: HealthIngestionPipeline(
        mappings: defaultHealthMappings,
        permissionPolicy: AllowlistedImportPermissionPolicy({
          HealthDataCategory.vitals,
        }),
      ),
    );
    final previous = HealthSyncCursor(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      token: 'token-1',
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    final result = await coordinator.import(
      adapter: adapter,
      now: DateTime.utc(2026, 9, 9, 12),
      previousCursor: previous,
    );

    expect(result.usedFullRefresh, isFalse);
    expect(result.ingestion.records, hasLength(1));
    expect(result.ingestion.records.single.mapping.canonicalCode, 'vital.heart_rate');
    expect(result.deletedSourceRecordIds, ['old-heart-rate']);
    expect(result.cursor.token, 'token-2');
  });
}

class _CoordinatorAdapter implements HealthSourceSyncAdapter {
  @override
  HealthSourcePlatform get sourcePlatform => HealthSourcePlatform.healthConnect;

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async => {
        HealthDataCategory.vitals,
      };

  @override
  Future<List<RawHealthRecord>> readInitial({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async =>
      const [];

  @override
  Future<String> createChangeToken({
    required Set<HealthDataCategory> categories,
  }) async =>
      'token-1';

  @override
  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  }) async =>
      HealthSyncPage(
        changes: [
          HealthSyncChange.upsert(
            RawHealthRecord(
              sourcePlatform: HealthSourcePlatform.healthConnect,
              sourceType: 'heart_rate',
              sourceRecordId: 'new-heart-rate',
              observedAt: DateTime.utc(2026, 9, 9, 10),
              value: 74,
              unit: 'bpm',
            ),
          ),
          const HealthSyncChange.delete('old-heart-rate'),
        ],
        nextToken: 'token-2',
        hasMore: false,
      );
}
