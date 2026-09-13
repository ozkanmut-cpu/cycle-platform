import 'package:cycle_clinical_domain/cycle_clinical_domain.dart';
import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 1, 8);

  BleedingObservation observation({
    required String id,
    required int day,
    DataState state = DataState.yes,
    BleedingContext? context = BleedingContext.menstrual,
    BleedingFlow? flow = BleedingFlow.moderate,
    Set<BleedingFeature> features = const {},
    int hour = 0,
    String? sourceId,
  }) =>
      BleedingObservation(
        id: id,
        observedAt: start.add(Duration(days: day, hours: hour)),
        state: state,
        context: context,
        flow: flow,
        features: features,
        sourceId: sourceId,
      );

  test('exposes stable engine version metadata', () {
    const engine = BleedingIntelligenceEngine();
    expect(engine.schemaVersion, 1);
    expect(engine.catalogVersion, '2026.1');
    expect(
      () => const BleedingIntelligenceEngine(schemaVersion: 0).evaluate(
        BleedingEpisode(
          id: 'version-invalid',
          startedAt: start,
          observations: [observation(id: 'v1', day: 0)],
        ),
      ),
      throwsA(isA<BleedingIntelligenceValidationException>()),
    );
  });

  test('heavy and prolonged bleeding produces evidence-backed routing keys',
      () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-1',
        startedAt: start,
        endedAt: start.add(const Duration(days: 8)),
        observations: [
          observation(id: 'o1', day: 0, flow: BleedingFlow.heavy),
          observation(
            id: 'o2',
            day: 2,
            features: {BleedingFeature.floodingGushing},
          ),
        ],
      ),
    );

    expect(result.descriptors, contains(BleedingDescriptor.heavyFlow));
    expect(result.descriptors, contains(BleedingDescriptor.prolonged));
    expect(result.symptomKeys, contains('heavy menstrual bleeding'));
    expect(result.symptomKeys, contains('prolonged bleeding'));
    expect(result.evidenceObservationIds, ['o1', 'o2']);
  });

  test('derived output preserves deterministic evidence provenance', () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-provenance',
        startedAt: start,
        observations: [
          observation(
            id: 'later',
            day: 1,
            flow: BleedingFlow.light,
            sourceId: 'patient-quick-log',
          ),
          observation(
            id: 'earlier-b',
            day: 0,
            flow: BleedingFlow.heavy,
            sourceId: 'health-import',
          ),
          observation(
            id: 'earlier-a',
            day: 0,
            flow: BleedingFlow.heavy,
            sourceId: 'patient-quick-log',
          ),
        ],
      ),
    );

    expect(
      result.evidence.map((item) => item.observationId),
      ['earlier-a', 'earlier-b', 'later'],
    );
    expect(
      result.evidence.map((item) => item.sourceId),
      ['patient-quick-log', 'health-import', 'patient-quick-log'],
    );
  });

  test('context routing is symptom metadata, not a diagnosis', () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-2',
        startedAt: start,
        observations: [
          observation(
            id: 'postcoital',
            day: 0,
            context: BleedingContext.postcoital,
            flow: BleedingFlow.spotting,
          ),
          observation(
            id: 'postmenopausal',
            day: 1,
            context: BleedingContext.postmenopausal,
            flow: BleedingFlow.light,
          ),
        ],
      ),
    );

    expect(result.symptomKeys, contains('postcoital bleeding'));
    expect(result.symptomKeys, contains('postmenopausal bleeding'));
    expect(result.symptomKeys, contains('spotting'));
  });

  test('unknown and not-recorded remain missing and never become no bleeding',
      () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-3',
        startedAt: start,
        observations: [
          observation(
            id: 'unknown',
            day: 0,
            state: DataState.unknown,
            context: null,
            flow: null,
          ),
          observation(
            id: 'not-recorded',
            day: 1,
            state: DataState.notRecorded,
            context: null,
            flow: null,
          ),
        ],
      ),
    );

    expect(result.symptomKeys, isEmpty);
    expect(result.evidenceObservationIds, isEmpty);
    expect(result.missingInformation, contains('bleeding observation'));
    expect(result.descriptors, contains(BleedingDescriptor.incomplete));
  });

  test(
      'conflicting same-instant flow observations are surfaced deterministically',
      () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-4',
        startedAt: start,
        observations: [
          observation(id: 'heavy', day: 0, flow: BleedingFlow.heavy),
          observation(id: 'light', day: 0, flow: BleedingFlow.light),
        ],
      ),
    );

    expect(result.descriptors, contains(BleedingDescriptor.conflicting));
    expect(result.evidenceObservationIds, ['heavy', 'light']);
  });

  test('flow changing over time is not treated as a contradiction', () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-4b',
        startedAt: start,
        observations: [
          observation(id: 'heavy-first', day: 0, flow: BleedingFlow.heavy),
          observation(id: 'light-later', day: 1, flow: BleedingFlow.light),
        ],
      ),
    );

    expect(result.descriptors, isNot(contains(BleedingDescriptor.conflicting)));
  });

  test('incomplete recorded observation preserves missing fields', () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-5',
        startedAt: start,
        observations: [
          observation(id: 'partial', day: 0, context: null, flow: null),
        ],
      ),
    );

    expect(result.missingInformation,
        containsAll(['bleeding context', 'bleeding flow']));
    expect(result.descriptors, contains(BleedingDescriptor.incomplete));
  });

  test('bleeding result feeds existing symptom-first router', () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-routing',
        startedAt: start,
        observations: [
          observation(
            id: 'routing-heavy',
            day: 0,
            context: BleedingContext.intermenstrual,
            flow: BleedingFlow.heavy,
          ),
        ],
      ),
    );
    final routed = const SymptomFirstRouter().route(
      report: result.toSymptomReport(),
      packs: ConditionCatalog(conditionCatalogDefinitions).packs,
    );

    expect(routed.hasCandidates, isTrue);
    expect(
      routed.matches.map((match) => match.pack.id),
      contains('abnormal-uterine-bleeding'),
    );
    expect(routed.missingInformation, isEmpty);
  });

  test('missing bleeding fields remain missing through symptom routing', () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-missing-routing',
        startedAt: start,
        observations: [
          observation(id: 'partial-routing', day: 0, context: null, flow: null),
        ],
      ),
    );
    final routed = const SymptomFirstRouter().route(
      report: result.toSymptomReport(),
      packs: ConditionCatalog(conditionCatalogDefinitions).packs,
    );

    expect(routed.confidence, RoutingConfidence.insufficientInformation);
    expect(routed.matches, isEmpty);
    expect(
      routed.missingInformation,
      containsAll(['bleeding context', 'bleeding flow']),
    );
  });

  test('duplicate observation ids fail validation', () {
    expect(
      () => const BleedingIntelligenceEngine().evaluate(
        BleedingEpisode(
          id: 'episode-6',
          startedAt: start,
          observations: [
            observation(id: 'same', day: 0),
            observation(id: ' SAME ', day: 1),
          ],
        ),
      ),
      throwsA(isA<BleedingIntelligenceValidationException>()),
    );
  });

  test('empty provenance source id fails validation', () {
    expect(
      () => const BleedingIntelligenceEngine().evaluate(
        BleedingEpisode(
          id: 'episode-empty-source',
          startedAt: start,
          observations: [
            observation(id: 'source-empty', day: 0, sourceId: '   '),
          ],
        ),
      ),
      throwsA(isA<BleedingIntelligenceValidationException>()),
    );
  });

  test('observation outside episode fails validation', () {
    expect(
      () => const BleedingIntelligenceEngine().evaluate(
        BleedingEpisode(
          id: 'episode-window',
          startedAt: start,
          endedAt: start.add(const Duration(days: 1)),
          observations: [
            observation(id: 'too-late', day: 2),
          ],
        ),
      ),
      throwsA(isA<BleedingIntelligenceValidationException>()),
    );
  });

  test('unknown observation cannot carry inferred details', () {
    expect(
      () => const BleedingIntelligenceEngine().evaluate(
        BleedingEpisode(
          id: 'episode-7',
          startedAt: start,
          observations: [
            observation(
              id: 'unknown-details',
              day: 0,
              state: DataState.unknown,
              context: BleedingContext.menstrual,
              flow: BleedingFlow.light,
            ),
          ],
        ),
      ),
      throwsA(isA<BleedingIntelligenceValidationException>()),
    );
  });
}
