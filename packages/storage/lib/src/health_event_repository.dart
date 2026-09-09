import 'package:cycle_core_domain/cycle_core_domain.dart';

abstract interface class HealthEventRepository {
  Future<void> upsert(HealthEvent event);

  Future<HealthEvent?> getById(String id);

  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  });

  Future<void> markDeleted({
    required String eventId,
    required DateTime deletedAt,
  });
}
