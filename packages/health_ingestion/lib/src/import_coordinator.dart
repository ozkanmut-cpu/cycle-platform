import 'health_ingestion.dart';
import 'health_sync.dart';

class CoordinatedHealthImportResult {
  const CoordinatedHealthImportResult({
    required this.ingestion,
    required this.deletedSourceRecordIds,
    required this.cursor,
    required this.usedFullRefresh,
  });

  final HealthIngestionResult ingestion;
  final List<String> deletedSourceRecordIds;
  final HealthSyncCursor cursor;
  final bool usedFullRefresh;
}

class HealthImportCoordinator {
  const HealthImportCoordinator({
    required this.synchronizer,
    required this.pipeline,
  });

  final HealthSourceSynchronizer synchronizer;
  final HealthIngestionPipeline pipeline;

  Future<CoordinatedHealthImportResult> import({
    required HealthSourceSyncAdapter adapter,
    required DateTime now,
    HealthSyncCursor? previousCursor,
  }) async {
    final sync = await synchronizer.synchronize(
      adapter: adapter,
      now: now,
      previousCursor: previousCursor,
    );
    final ingestion = pipeline.ingest(
      sourcePlatform: adapter.sourcePlatform,
      records: sync.upserts,
      startedAt: now.toUtc(),
    );

    return CoordinatedHealthImportResult(
      ingestion: ingestion,
      deletedSourceRecordIds: sync.deletedSourceRecordIds,
      cursor: sync.cursor,
      usedFullRefresh: sync.usedFullRefresh,
    );
  }
}
