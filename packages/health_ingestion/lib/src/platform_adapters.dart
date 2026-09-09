import 'health_ingestion.dart';
import 'health_sync.dart';

abstract interface class HealthConnectGateway {
  Future<Set<HealthDataCategory>> grantedCategories();

  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  });

  Future<String> createChangesToken({
    required Set<HealthDataCategory> categories,
  });

  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  });
}

class HealthConnectSyncAdapter implements HealthSourceSyncAdapter {
  const HealthConnectSyncAdapter(this.gateway);

  final HealthConnectGateway gateway;

  @override
  HealthSourcePlatform get sourcePlatform => HealthSourcePlatform.healthConnect;

  @override
  Future<Set<HealthDataCategory>> grantedCategories() =>
      gateway.grantedCategories();

  @override
  Future<List<RawHealthRecord>> readInitial({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) =>
      gateway.readRecords(from: from, to: to, categories: categories);

  @override
  Future<String> createChangeToken({
    required Set<HealthDataCategory> categories,
  }) =>
      gateway.createChangesToken(categories: categories);

  @override
  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  }) =>
      gateway.readChanges(token: token, categories: categories);
}

class HealthKitAnchorPage {
  const HealthKitAnchorPage({
    required this.upserts,
    required this.deletedSourceRecordIds,
    required this.nextAnchor,
    required this.hasMore,
    this.anchorInvalid = false,
  });

  final List<RawHealthRecord> upserts;
  final List<String> deletedSourceRecordIds;
  final String nextAnchor;
  final bool hasMore;
  final bool anchorInvalid;
}

abstract interface class HealthKitGateway {
  Future<Set<HealthDataCategory>> grantedCategories();

  Future<List<RawHealthRecord>> readRecords({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  });

  Future<String> createAnchor({
    required Set<HealthDataCategory> categories,
  });

  Future<HealthKitAnchorPage> readAnchoredChanges({
    required String anchor,
    required Set<HealthDataCategory> categories,
  });
}

class HealthKitSyncAdapter implements HealthSourceSyncAdapter {
  const HealthKitSyncAdapter(this.gateway);

  final HealthKitGateway gateway;

  @override
  HealthSourcePlatform get sourcePlatform => HealthSourcePlatform.healthKit;

  @override
  Future<Set<HealthDataCategory>> grantedCategories() =>
      gateway.grantedCategories();

  @override
  Future<List<RawHealthRecord>> readInitial({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) =>
      gateway.readRecords(from: from, to: to, categories: categories);

  @override
  Future<String> createChangeToken({
    required Set<HealthDataCategory> categories,
  }) =>
      gateway.createAnchor(categories: categories);

  @override
  Future<HealthSyncPage> readChanges({
    required String token,
    required Set<HealthDataCategory> categories,
  }) async {
    final page = await gateway.readAnchoredChanges(
      anchor: token,
      categories: categories,
    );

    return HealthSyncPage(
      changes: [
        for (final record in page.upserts) HealthSyncChange.upsert(record),
        for (final id in page.deletedSourceRecordIds) HealthSyncChange.delete(id),
      ],
      nextToken: page.nextAnchor,
      hasMore: page.hasMore,
      tokenExpired: page.anchorInvalid,
    );
  }
}
