import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:test/test.dart';

void main() {
  final guideline = GuidelineVersion(
    identifier: 'catalog-guideline',
    version: '2026.1',
    effectiveFrom: DateTime.utc(2026, 1, 1),
  );

  ConditionPack pack(String id, {String? title, Set<String>? symptoms}) {
    return ConditionPack(
      id: id,
      schemaVersion: 1,
      title: title ?? id,
      guideline: guideline,
      symptomKeys: symptoms ?? const {'pain'},
    );
  }

  group('ConditionCatalog', () {
    test('sorts deterministically and looks up ids case-insensitively', () {
      final catalog = ConditionCatalog([
        pack('zeta'),
        pack('Alpha'),
        pack('beta'),
      ]);

      expect(catalog.packs.map((item) => item.id), ['Alpha', 'beta', 'zeta']);
      expect(catalog.findById(' alpha ')?.id, 'Alpha');
      expect(catalog.findById('missing'), isNull);
    });

    test('rejects duplicate normalized ids', () {
      expect(
        () => ConditionCatalog([pack('alpha'), pack(' Alpha ')]),
        throwsA(isA<ConditionCatalogValidationException>()),
      );
    });

    test('rejects malformed definitions deterministically', () {
      expect(
        () => ConditionCatalog([pack(' ', title: 'Invalid')]),
        throwsA(isA<ConditionCatalogValidationException>()),
      );
      expect(
        () => ConditionCatalog([pack('no-title', title: ' ')]),
        throwsA(isA<ConditionCatalogValidationException>()),
      );
      expect(
        () => ConditionCatalog([pack('no-symptoms', symptoms: const {})]),
        throwsA(isA<ConditionCatalogValidationException>()),
      );
    });
  });
}
