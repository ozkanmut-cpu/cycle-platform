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
  }) =>
      BleedingObservation(
        id: id,
        observedAt: start.add(Duration(days: day)),
        state: state,
        context: context,
        flow: flow,
        features: features,
      );

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

  test('conflicting recorded flow observations are surfaced deterministically',
      () {
    final result = const BleedingIntelligenceEngine().evaluate(
      BleedingEpisode(
        id: 'episode-4',
        startedAt: start,
        observations: [
          observation(id: 'heavy', day: 0, flow: BleedingFlow.heavy),
          observation(id: 'light', day: 1, flow: BleedingFlow.light),
        ],
      ),
    );

    expect(result.descriptors, contains(BleedingDescriptor.conflicting));
    expect(result.evidenceObservationIds, ['heavy', 'light']);
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
