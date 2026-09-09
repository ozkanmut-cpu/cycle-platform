import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:test/test.dart';

void main() {
  test('initial sync uses lookback and creates cursor', () async {
    final adapter = _FakeAdapter(
      initialRecords: [
        _record('initial-1'),
      ],
    );
    final synchronizer = HealthSourceSynchronizer(
      initialLookback: const Duration(days: 30),
    );
    final now = DateTime.utc(2026, 9, 9, 12);

    final result = await synchronizer.synchronize(
      adapter: adapter,
      now: now,
    );

    expect(result.usedFullRefresh, isTrue);
    expect(result.upserts.map((record) => record.sourceRecordId), ['initial-1']);
    expect(result.cursor.token, 'token-1');
    expect(adapter.lastInitialFrom, DateTime.utc(2026, 8, 10, 12));
    expect(adapter.lastInitialTo, now);
  });

  test('incremental sync consumes pages and preserves deletes', () async {
    final adapter = _FakeAdapter(
      changePages: [
        HealthSyncPage(
          changes: [HealthSyncChange.upsert(_record('new-1'))],
          nextToken: 'token-2',
          hasMore: true,
        ),
        const HealthSyncPage(
          changes: [HealthSyncChange.delete('old-1')],
          nextToken: 'token-3',
          hasMore: false,
        ),
      ],
    );
    final previous = HealthSyncCursor(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      token: 'token-1',
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    final result = await const HealthSourceSynchronizer().synchronize(
      adapter: adapter,
      now: DateTime.utc(2026, 9, 9, 12),
      previousCursor: previous,
    );

    expect(result.usedFullRefresh, isFalse);
    expect(result.upserts.map((record) => record.sourceRecordId), ['new-1']);
    expect(result.deletedSourceRecordIds, ['old-1']);
    expect(result.cursor.token, 'token-3');
    expect(adapter.requestedTokens, ['token-1', 'token-2']);
  });

  test('expired change token falls back to full refresh', () async {
    final adapter = _FakeAdapter(
      initialRecords: [_record('replacement')],
      changePages: const [
        HealthSyncPage(
          changes: [],
          nextToken: null,
          hasMore: false,
          tokenExpired: true,
        ),
      ],
    );
    final previous = HealthSyncCursor(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      token: 'expired-token',
      updatedAt: DateTime.utc(2026, 9, 1),
    );

    final result = await const HealthSourceSynchronizer().synchronize(
      adapter: adapter,
      now: DateTime.utc(2026, 9, 9, 12),
      previousCursor: previous,
    );

    expect(result.usedFullRefresh, isTrue);
    expect(result.upserts.single.sourceRecordId, 'replacement');
    expect(result.cursor.token, 'token-1');
  });
}

RawHealthRecord _record(String id) => RawHealthRecord(
      sourcePlatform: HealthSourcePlatform.healthConnect,
      sourceType: 'heart_rate',
      sourceRecordId: id,
      observedAt: DateTime.utc(2026, 9, 9, 9),
      value: 72,
      unit: 'bpm',
    );

class _FakeAdapter implements HealthSourceSyncAdapter {
  _FakeAdapter({
    this.initialRecords = const [],
    this.changePages = const [],
  });

  final List<RawHealthRecord> initialRecords;
  final List<HealthSyncPage> changePages;
  final List<String> requestedTokens = [];
  DateTime? lastInitialFrom;
  DateTime? lastInitialTo;
  var _pageIndex = 0;
  var _tokenCounter = 0;

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
  }) async {
    lastInitialFrom = from;
    lastInitialTo = to;
    return initialRecords;
  }

  @override
  Future<String> createChangeToken({
    required Set<HealthDataCategory> categories,
  }) async {
    _tokenCounter++;
    return 'token-$_tokenCounter';
  }

  @override
  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  }) async {
    requestedTokens.add(token);
    return changePages[_pageIndex++];
  }
}
