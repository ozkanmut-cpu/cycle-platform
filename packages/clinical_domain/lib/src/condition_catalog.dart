import 'condition_pack.dart';

class ConditionCatalogValidationException implements Exception {
  const ConditionCatalogValidationException(this.message);

  final String message;

  @override
  String toString() => 'ConditionCatalogValidationException: $message';
}

class ConditionCatalog {
  ConditionCatalog(Iterable<ConditionPack> packs)
      : _packs = List.unmodifiable(_validateAndSort(packs));

  final List<ConditionPack> _packs;

  List<ConditionPack> get packs => _packs;

  int get length => _packs.length;

  ConditionPack? findById(String id) {
    final normalized = _normalizeId(id);
    if (normalized.isEmpty) return null;
    for (final pack in _packs) {
      if (_normalizeId(pack.id) == normalized) return pack;
    }
    return null;
  }

  static List<ConditionPack> _validateAndSort(Iterable<ConditionPack> packs) {
    final result = <ConditionPack>[];
    final ids = <String>{};

    for (final pack in packs) {
      final normalizedId = _normalizeId(pack.id);
      if (normalizedId.isEmpty) {
        throw const ConditionCatalogValidationException(
          'Condition id must not be empty.',
        );
      }
      if (pack.schemaVersion <= 0) {
        throw ConditionCatalogValidationException(
          'Condition "$normalizedId" must have schemaVersion > 0.',
        );
      }
      if (pack.title.trim().isEmpty) {
        throw ConditionCatalogValidationException(
          'Condition "$normalizedId" must have a non-empty title.',
        );
      }
      if (pack.guideline.identifier.trim().isEmpty ||
          pack.guideline.version.trim().isEmpty) {
        throw ConditionCatalogValidationException(
          'Condition "$normalizedId" must have guideline identifier and version.',
        );
      }
      if (pack.symptomKeys
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .isEmpty) {
        throw ConditionCatalogValidationException(
          'Condition "$normalizedId" must define at least one symptom key.',
        );
      }
      if (!ids.add(normalizedId)) {
        throw ConditionCatalogValidationException(
          'Duplicate condition id: "$normalizedId".',
        );
      }
      result.add(pack);
    }

    result.sort((a, b) => _normalizeId(a.id).compareTo(_normalizeId(b.id)));
    return result;
  }

  static String _normalizeId(String value) => value.trim().toLowerCase();
}
