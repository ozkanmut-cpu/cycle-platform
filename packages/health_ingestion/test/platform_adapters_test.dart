import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  test('HealthKit adapter maps anchor changes to common sync changes',
      () async {
    final adapter = HealthKitSyncAdapter(_FakeHealthKitGateway());

    final page = await adapter.readChanges(
      token: 'anchor-1',
      categories: {HealthDataCategory.vitals},
    );

    expect(page.nextToken, 'anchor-2');
    expect(page.hasMore, isFalse);
    expect(page.tokenExpired, isFalse);
    expect(page.changes, hasLength(2));
    expect(page.changes.first.record?.sourceRecordId, 'hk-new');
    expect(page.changes.last.deletedSourceRecordId, 'hk-old');
  });

  test('HealthKit access scope preserves unknown and limited history',
      () async {
    final adapter = HealthKitSyncAdapter(_ScopedHealthKitGateway());

    final scope = await adapter.readAccessScope();
    final candidates = await adapter.grantedCategories();

    expect(candidates, {
      HealthDataCategory.vitals,
      HealthDataCategory.sleep,
    });
    expect(scope.requestStatusUnnecessaryCategories, {
      HealthDataCategory.vitals,
    });
    expect(scope.queryVisibleCategories, isEmpty);
    expect(scope.unknownCategories, {
      HealthDataCategory.vitals,
      HealthDataCategory.sleep,
    });
    expect(scope.hasLimitedHistory(HealthDataCategory.vitals), isTrue);
    expect(
      scope.earliestAuthorizedAt[HealthDataCategory.vitals],
      DateTime.utc(2026, 8, 11),
    );
  });

  test('Health Connect adapter delegates token sync to gateway', () async {
    final gateway = _FakeHealthConnectGateway();
    final adapter = HealthConnectSyncAdapter(gateway);

    final token = await adapter.createChangeToken(
      categories: {HealthDataCategory.vitals},
    );
    final page = await adapter.readChanges(
      token: token,
      categories: {HealthDataCategory.vitals},
    );

    expect(token, 'hc-token');
    expect(gateway.requestedToken, 'hc-token');
    expect(page.changes.single.record?.sourceRecordId, 'hc-new');
  });
}

RawHealthRecord _record(HealthSourcePlatform platform, String id) =>
    RawHealthRecord(
      sourcePlatform: platform,
      sourceType: 'heart_rate',
      sourceRecordId: id,
      observedAt: DateTime.utc(2026, 9, 9, 9),
      value: 70,
      unit: 'bpm',
    );

class _FakeHealthKitGateway implements HealthKitGateway {
  @override
  Future<String> createAnchor(
          {required Set<HealthDataCategory> categories}) async =>
      'anchor-1';

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async => {
        HealthDataCategory.vitals,
      };

  @override
  Future<HealthKitAnchorPage> readAnchoredChanges({
    required String anchor,
    required Set<HealthDataCategory> categories,
  }) async =>
      HealthKitAnchorPage(
        upserts: [_record(HealthSourcePlatform.healthKit, 'hk-new')],
        deletedSourceRecordIds: const ['hk-old'],
        nextAnchor: 'anchor-2',
        hasMore: false,
      );

  @override
  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async =>
      const [];
}

class _ScopedHealthKitGateway
    implements HealthKitGateway, HealthKitReadAccessGateway {
  @override
  Future<HealthKitReadAccessScope> readAccessScope() async =>
      HealthKitReadAccessScope(
        availableCategories: {
          HealthDataCategory.vitals,
          HealthDataCategory.sleep,
        },
        requestStatusUnnecessaryCategories: {
          HealthDataCategory.vitals,
        },
        queryVisibleCategories: const {},
        earliestAuthorizedAt: {
          HealthDataCategory.vitals: DateTime.utc(2026, 8, 11),
        },
      );

  @override
  Future<String> createAnchor(
          {required Set<HealthDataCategory> categories}) async =>
      'anchor-scoped';

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async =>
      throw StateError('Scoped gateway should not use legacy grant semantics.');

  @override
  Future<HealthKitAnchorPage> readAnchoredChanges({
    required String anchor,
    required Set<HealthDataCategory> categories,
  }) async =>
      const HealthKitAnchorPage(
        upserts: [],
        deletedSourceRecordIds: [],
        nextAnchor: 'anchor-scoped',
        hasMore: false,
      );

  @override
  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async =>
      const [];
}

class _FakeHealthConnectGateway implements HealthConnectGateway {
  String? requestedToken;

  @override
  Future<String> createChangesToken({
    required Set<HealthDataCategory> categories,
  }) async =>
      'hc-token';

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async => {
        HealthDataCategory.vitals,
      };

  @override
  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  }) async {
    requestedToken = token;
    return HealthSyncPage(
      changes: [
        HealthSyncChange.upsert(
          _record(HealthSourcePlatform.healthConnect, 'hc-new'),
        ),
      ],
      nextToken: token,
      hasMore: false,
    );
  }

  @override
  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async =>
      const [];
}
