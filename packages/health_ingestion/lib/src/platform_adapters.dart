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

class HealthKitReadAccessScope {
  const HealthKitReadAccessScope({
    required this.availableCategories,
    required this.requestStatusUnnecessaryCategories,
    required this.queryVisibleCategories,
    this.earliestAuthorizedAt = const <HealthDataCategory, DateTime>{},
  });

  final Set<HealthDataCategory> availableCategories;

  /// Categories for which HealthKit says presenting another authorization
  /// sheet is unnecessary. This is deliberately not treated as a read grant.
  final Set<HealthDataCategory> requestStatusUnnecessaryCategories;

  /// Categories for which the app has actually observed readable samples in
  /// the current query context. Empty means unknown/no visible samples, not No.
  final Set<HealthDataCategory> queryVisibleCategories;

  /// A date is present only when HealthKit positively identifies limited
  /// history for that category. Absence is not evidence of denial or full
  /// access.
  final Map<HealthDataCategory, DateTime> earliestAuthorizedAt;

  Set<HealthDataCategory> get queryCandidateCategories => availableCategories;

  Set<HealthDataCategory> get unknownCategories =>
      availableCategories.difference(queryVisibleCategories);

  bool hasLimitedHistory(HealthDataCategory category) =>
      earliestAuthorizedAt.containsKey(category);
}

abstract interface class HealthKitReadAccessGateway {
  Future<HealthKitReadAccessScope> readAccessScope();
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
  /// Legacy query-candidate API. HealthKit cannot expose definitive read-grant
  /// state, so implementations must not infer denial from an empty query.
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

  Future<HealthKitReadAccessScope> readAccessScope() async {
    final current = gateway;
    if (current is HealthKitReadAccessGateway) {
      return (current as HealthKitReadAccessGateway).readAccessScope();
    }

    // Backward compatibility for the current native bridge. Its legacy
    // `grantedCategories` method is backed by HealthKit request-status and
    // therefore cannot prove read authorization. Reinterpret those values as
    // request-status hints while keeping every supported category queryable.
    final requestStatusHints = await gateway.grantedCategories();
    return HealthKitReadAccessScope(
      availableCategories: Set<HealthDataCategory>.unmodifiable(
        HealthDataCategory.values,
      ),
      requestStatusUnnecessaryCategories: Set.unmodifiable(requestStatusHints),
      queryVisibleCategories: const <HealthDataCategory>{},
    );
  }

  @override
  Future<Set<HealthDataCategory>> grantedCategories() async =>
      (await readAccessScope()).queryCandidateCategories;

  @override
  Future<List<RawHealthRecord>> readInitial({
    required DateTime from,
    required DateTime to,
    required Set<HealthDataCategory> categories,
  }) async {
    final scope = await readAccessScope();
    final output = <RawHealthRecord>[];

    for (final category in categories) {
      final boundary = scope.earliestAuthorizedAt[category];
      final effectiveFrom =
          boundary != null && boundary.isAfter(from) ? boundary : from;
      if (!effectiveFrom.isBefore(to)) continue;

      output.addAll(
        await gateway.readRecords(
          from: effectiveFrom,
          to: to,
          categories: {category},
        ),
      );
    }

    return List<RawHealthRecord>.unmodifiable(output);
  }

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
        for (final id in page.deletedSourceRecordIds)
          HealthSyncChange.delete(id),
      ],
      nextToken: page.nextAnchor,
      hasMore: page.hasMore,
      tokenExpired: page.anchorInvalid,
    );
  }
}
