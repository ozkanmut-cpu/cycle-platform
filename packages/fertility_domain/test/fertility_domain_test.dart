import 'package:cycle_fertility_domain/cycle_fertility_domain.dart';
import 'package:test/test.dart';

void main() {
  final provenance = DomainProvenance(
    sourceId: 'manual',
    recordedAt: DateTime.utc(2026, 9, 10),
  );

  group('fertility domain', () {
    test('sexual activity does not infer contraception from missing data', () {
      final event = SexualActivityEvent(
        id: 'sex-1',
        occurredAt: DateTime.utc(2026, 9, 1),
        provenance: provenance,
      );

      expect(event.contraceptionUsed, isNull);
      expect(event.userMarkedConceptionRelevant, isFalse);
    });

    test(
      'conception exposure references activity without asserting conception',
      () {
        final exposure = ConceptionExposureEvent(
          id: 'exp-1',
          sexualActivityEventId: 'sex-1',
          occurredAt: DateTime.utc(2026, 9, 1),
          provenance: provenance,
        );

        expect(exposure.sexualActivityEventId, 'sex-1');
        expect(exposure.id, isNotEmpty);
      },
    );

    test('fertility confidence is insufficient with no evidence', () {
      const model = FertilityConfidenceModel();
      final assessment = model.assess(
        bbt: const [],
        lh: const [],
        mucus: const [],
      );

      expect(
        assessment.confidence,
        FertilityConfidence.insufficientInformation,
      );
      expect(assessment.evidence, isEmpty);
      expect(assessment.missingInformation, {'bbt', 'lh', 'mucus'});
    });

    test('fertility confidence rises only with explicit evidence types', () {
      const model = FertilityConfidenceModel();
      final bbt = BasalBodyTemperatureObservation(
        celsius: 36.6,
        observedAt: DateTime.utc(2026, 9, 8),
        provenance: provenance,
      );
      final lh = LhObservation(
        observedAt: DateTime.utc(2026, 9, 9),
        provenance: provenance,
        positive: true,
      );
      final mucus = CervicalMucusObservation(
        quality: CervicalMucusQuality.eggWhite,
        observedAt: DateTime.utc(2026, 9, 9),
        provenance: provenance,
      );

      final low = model.assess(bbt: [bbt], lh: const [], mucus: const []);
      final medium = model.assess(bbt: [bbt], lh: [lh], mucus: const []);
      final high = model.assess(bbt: [bbt], lh: [lh], mucus: [mucus]);

      expect(low.confidence, FertilityConfidence.low);
      expect(medium.confidence, FertilityConfidence.medium);
      expect(high.confidence, FertilityConfidence.high);
      expect(high.missingInformation, isEmpty);
    });

    test(
      'pregnancy episode keeps dating provenance and active state explicit',
      () {
        final dating = PregnancyDating(
          estimatedStartDate: DateTime.utc(2026, 8, 1),
          basis: 'lmp',
          provenance: provenance,
        );
        final episode = PregnancyEpisode(
          id: 'preg-1',
          startedAt: DateTime.utc(2026, 8, 1),
          dating: dating,
        );

        expect(episode.isActive, isTrue);
        expect(episode.dating.basis, 'lmp');
        expect(episode.dating.provenance.sourceId, 'manual');
      },
    );

    test('postpartum episode links to pregnancy episode explicitly', () {
      final postpartum = PostpartumEpisode(
        id: 'post-1',
        pregnancyEpisodeId: 'preg-1',
        startedAt: DateTime.utc(2027, 5, 1),
      );

      expect(postpartum.pregnancyEpisodeId, 'preg-1');
      expect(postpartum.isActive, isTrue);
    });

    test('safety disposition vocabulary contains no treatment decision', () {
      expect(
        PregnancySafetyDisposition.values.map((value) => value.name),
        ['informational', 'reviewRecommended', 'urgentReviewRecommended'],
      );
    });
  });
}
