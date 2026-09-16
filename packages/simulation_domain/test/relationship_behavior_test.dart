import 'package:cycle_simulation_domain/simulation_domain.dart';
import 'package:test/test.dart';

void main() {
  group('relationship behavior core model', () {
    RelationshipBehaviorScenario build({
      String id = 'signal.safe.explicit',
      int schemaVersion = relationshipBehaviorSchemaVersion,
      DateTime? at,
      String ownerId = 'patient-1',
      String recipientId = 'partner-1',
    }) =>
        RelationshipBehaviorScenario(
          id: id,
          schemaVersion: schemaVersion,
          seed: 20260916,
          at: at ?? DateTime.utc(2026, 9, 16, 9),
          ownerId: ownerId,
          recipientId: recipientId,
          family: RelationshipBehaviorScenarioFamily.signalProjection,
          expectedFacts: const <String, Object?>{
            'selectedSignalId': 'signal-explicit',
          },
          riskTags: const <String>{'precedence'},
          safeControl: true,
        );
    test('validates identity schema and UTC boundaries', () {
      expect(() => build(id: '  '), throwsArgumentError);
      expect(
        () => build(schemaVersion: relationshipBehaviorSchemaVersion + 1),
        throwsArgumentError,
      );
      expect(() => build(at: DateTime(2026, 9, 16)), throwsArgumentError);
      expect(
        () => build(ownerId: 'same', recipientId: 'same'),
        throwsArgumentError,
      );
    });

    test('scenario round trip preserves deterministic metadata', () {
      final scenario = build();
      expect(
        RelationshipBehaviorScenario.fromJson(scenario.toJson()).toJson(),
        scenario.toJson(),
      );
    });

    test('report sorts results and round trips byte stably', () {
      RelationshipBehaviorResult result(String id) =>
          RelationshipBehaviorResult(
            scenarioId: id,
            family: RelationshipBehaviorScenarioFamily.signalProjection,
            passed: true,
            reasonCode: 'contract_satisfied',
            severity: InvariantSeverity.s2,
            evaluatedAt: DateTime.utc(2026, 9, 16, 9),
            evidence: const <String, Object?>{'ok': true},
          );
      final report = RelationshipBehaviorReport(
        seed: 20260916,
        results: <RelationshipBehaviorResult>[result('z'), result('a')],
        coverage: const RelationshipBehaviorCoverage.empty(),
      );
      final roundTrip = RelationshipBehaviorReport.fromJson(report.toJson());
      expect(report.results.map((item) => item.scenarioId), <String>['a', 'z']);
      expect(roundTrip.toNormalizedJson(), report.toNormalizedJson());
      expect(roundTrip.syntheticEvidenceOnly, isTrue);
    });

    test('suite reports mismatch and malformed input fail closed', () {
      final scenario = build();
      final mismatch = RelationshipBehaviorSuite(
        observer: const _StaticObserver(
          RelationshipBehaviorObservation(
            facts: <String, Object?>{'selectedSignalId': 'wrong'},
          ),
        ),
      ).run(
          seed: 20260916, scenarios: <RelationshipBehaviorScenario>[scenario]);
      expect(mismatch.passed, isFalse);
      expect(mismatch.results.single.reasonCode, 'contract_mismatch');

      final malformed = RelationshipBehaviorSuite(
        observer: const _ThrowingObserver(),
      ).run(
        seed: 20260916,
        scenarios: <RelationshipBehaviorScenario>[scenario],
      );
      expect(malformed.passed, isFalse);
      expect(malformed.results.single.reasonCode, 'malformed_input');
      expect(malformed.coverage.malformedInputFailures, 1);
    });
  });
  group('production observer A-E', () {
    const observer = ProductionRelationshipBehaviorObserver();

    test('explicit signal wins and wrong recipient does not project', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final explicit = _scenario(
        id: 'signal-explicit',
        family: RelationshipBehaviorScenarioFamily.signalProjection,
        payload: <String, Object?>{
          'operation': 'signals',
          'signals': <Object?>[
            _signal('derived', 'derived', at, version: 5),
            _signal('explicit', 'explicit', at, version: 1),
          ],
          'grants': <Object?>[
            _grant('relationship.signal.love', 'view', 'fullyShared', at)
          ],
        },
      );
      expect(observer.observe(explicit).facts['selectedSignalIds'],
          <String>['explicit']);

      final wrong = _scenario(
        id: 'signal-wrong-recipient',
        family: RelationshipBehaviorScenarioFamily.signalProjection,
        recipientId: 'partner-2',
        payload: explicit.payload,
      );
      expect(observer.observe(wrong).facts['projectedSignalIds'], isEmpty);
    });

    test('situation engine maps space and suppresses low-value moment', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final scenario = _scenario(
        id: 'situation-space',
        family: RelationshipBehaviorScenarioFamily.situation,
        payload: <String, Object?>{
          'roomSignals': <Object?>[
            <String, Object?>{
              'id': 'room-space',
              'kind': 'needsSpace',
              'createdAt': at.toIso8601String(),
              'priority': 3,
            },
          ],
          'grants': <Object?>[
            _grant('relationship.room.needsSpace', 'relationshipIntelligence',
                'engineOnly', at)
          ],
          'microMoments': <Object?>[
            <String, Object?>{
              'id': 'low',
              'action': 'checkIn',
              'informationValue': 0.1,
              'userBurden': 0.9
            },
          ],
        },
      );
      final facts = observer.observe(scenario).facts;
      expect(facts['roomAction'], 'giveSpace');
      expect(facts['weather'], 'quiet');
      expect(facts['microMomentSurfaced'], false);
    });

    test('engine-only memory never exposes raw value', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final scenario = _scenario(
        id: 'memory-engine-only',
        family: RelationshipBehaviorScenarioFamily.memoryContext,
        payload: <String, Object?>{
          'operation': 'memory',
          'memories': <Object?>[
            <String, Object?>{
              'id': 'memory-1',
              'kind': 'favorite',
              'key': 'drink',
              'value': 'tea',
              'createdAt': at.toIso8601String(),
              'visibility': 'engineOnly'
            },
          ],
          'grants': <Object?>[
            _grant(
                'relationship.memory.favorite.drink', 'view', 'fullyShared', at)
          ],
        },
      );
      expect(
          observer.observe(scenario).facts['memoryRawValues'], <Object?>[null]);
    });

    test('novelty returns empty instead of invented fallback', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final scenario = _scenario(
        id: 'novelty-empty',
        family: RelationshipBehaviorScenarioFamily.novelty,
        payload: <String, Object?>{
          'dna': <String, Object?>{
            'dontSuggestTags': <String>['blocked']
          },
          'candidates': <Object?>[
            <String, Object?>{
              'id': 'n1',
              'category': 'date',
              'title': 'Blocked',
              'tags': <String>['blocked'],
              'cost': 0,
              'durationMinutes': 10,
              'energy': 'low',
              'setting': 'home'
            },
          ],
          'grants': <Object?>[
            _grant('relationship.novelty.date', 'relationshipIntelligence',
                'engineOnly', at)
          ],
        },
      );
      expect(observer.observe(scenario).facts['suggestionIds'], isEmpty);
    });

    test('partner coordinator fails closed for same actor scope', () {
      final scenario = _scenario(
        id: 'home-wrong-scope',
        family: RelationshipBehaviorScenarioFamily.partnerHome,
        payload: const <String, Object?>{'forceSameActorScope': true},
      );
      expect(observer.observe(scenario).facts['homeBuildFailedClosed'], true);
    });
  });
  _registerProductionObserverFITests();
  _registerCanonicalRelationshipBehaviorTests();
  _registerRelationshipBehaviorSmokeCliTests();
}

class _ThrowingObserver extends RelationshipBehaviorObserver {
  const _ThrowingObserver();

  @override
  RelationshipBehaviorObservation observe(
    RelationshipBehaviorScenario scenario,
  ) =>
      throw ArgumentError('synthetic malformed observer input');
}

class _StaticObserver extends RelationshipBehaviorObserver {
  const _StaticObserver(this.observation);
  final RelationshipBehaviorObservation observation;
  @override
  RelationshipBehaviorObservation observe(
          RelationshipBehaviorScenario scenario) =>
      observation;
}

RelationshipBehaviorScenario _scenario({
  required String id,
  required RelationshipBehaviorScenarioFamily family,
  String ownerId = 'patient-1',
  String recipientId = 'partner-1',
  Map<String, Object?> payload = const <String, Object?>{},
}) =>
    RelationshipBehaviorScenario(
      id: id,
      schemaVersion: relationshipBehaviorSchemaVersion,
      seed: 20260916,
      at: DateTime.utc(2026, 9, 16, 9),
      ownerId: ownerId,
      recipientId: recipientId,
      family: family,
      expectedFacts: const <String, Object?>{},
      riskTags: const <String>{},
      payload: payload,
    );

Map<String, Object?> _signal(
  String id,
  String origin,
  DateTime at, {
  int version = 1,
}) =>
    <String, Object?>{
      'id': id,
      'kind': 'love',
      'origin': origin,
      'createdAt': at.toIso8601String(),
      'version': version,
    };

Map<String, Object?> _grant(
  String category,
  String capability,
  String visibility,
  DateTime at,
) =>
    <String, Object?>{
      'id': 'grant-$category-$capability',
      'ownerId': 'patient-1',
      'recipientId': 'partner-1',
      'category': category,
      'capabilities': <String>[capability],
      'visibility': visibility,
      'createdAt': at.subtract(const Duration(minutes: 1)).toIso8601String(),
      'version': 1,
    };

void _registerProductionObserverFITests() {
  group('production observer F-I', () {
    const observer = ProductionRelationshipBehaviorObserver();

    test('notification privacy and content capabilities come from production',
        () {
      final at = DateTime.utc(2026, 9, 16, 9);
      RelationshipBehaviorScenario build(
        String id, {
        String kind = 'relationship',
        String mode = 'generic',
        bool unlocked = true,
        List<Object?>? grants,
      }) =>
          _scenario(
            id: id,
            family: RelationshipBehaviorScenarioFamily.notification,
            payload: <String, Object?>{
              'kind': kind,
              'mode': mode,
              'deviceUnlocked': unlocked,
              'category': 'relationship.update',
              'categoryLabel': 'Partner',
              'detail': 'private detail',
              'grants': grants ??
                  <Object?>[
                    _grant('relationship.update', 'notify', 'engineOnly', at),
                  ],
            },
          );
      final generic = observer.observe(build('notification-generic')).facts;
      expect(generic['notificationPresented'], true);
      expect(generic['notificationRedacted'], true);

      final locked = observer
          .observe(
            build('notification-locked',
                mode: 'detailedWhenUnlocked', unlocked: false),
          )
          .facts;
      expect(locked['notificationBody'], 'You have a private partner update.');

      final intimacyMissing = observer
          .observe(
            build('notification-intimacy-missing', kind: 'intimacy'),
          )
          .facts;
      expect(intimacyMissing['notificationPresented'], false);
    });

    test('Playful Engine preserves truth and reuses Phase 8 truth gate', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final scenario = _scenario(
        id: 'playful-truth',
        family: RelationshipBehaviorScenarioFamily.playful,
        payload: <String, Object?>{
          'category': 'health',
          'companionText': 'Warm companion',
          'tone': 'warm',
          'truthText': 'Synthetic clinical truth',
          'truthSeverity': 'informational',
          'grants': <Object?>[
            _grant('relationship.playful.health', 'playful', 'engineOnly', at),
          ],
        },
      );
      final facts = observer.observe(scenario).facts;
      expect(facts['truthFirst'], true);
      expect(facts['phase8TruthGatePassed'], true);
      expect(facts['playfulApplied'], true);
    });

    test('spicy Playful output requires intimacy capability', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final scenario = _scenario(
        id: 'playful-spicy-missing-intimacy',
        family: RelationshipBehaviorScenarioFamily.playful,
        payload: <String, Object?>{
          'category': 'date',
          'companionText': 'Spicy companion',
          'tone': 'spicy',
          'grants': <Object?>[
            _grant('relationship.playful.date', 'playful', 'engineOnly', at),
          ],
        },
      );
      expect(observer.observe(scenario).facts['playfulApplied'], false);
    });

    test('long-term intimacy preference alone never becomes consent', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final scenario = _intimacyScenario(
        id: 'intimacy-preference-only',
        at: at,
        willingness: const <Object?>[],
      );
      expect(
          observer.observe(scenario).facts['intimacyDecisionKinds'], isEmpty);
    });

    test('mutual yes is time-limited and hard boundary blocks it', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final mutual = _intimacyScenario(
        id: 'intimacy-mutual-yes',
        at: at,
        willingness: <Object?>[
          _willingness('wa', 'patient-1', 'partner-1', 'yes', at),
          _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
        ],
      );
      expect(
        observer.observe(mutual).facts['intimacyDecisionKinds'],
        <String>['mutuallyWilling'],
      );

      final blocked = _intimacyScenario(
        id: 'intimacy-hard-boundary',
        at: at,
        willingness: <Object?>[
          _willingness('wa', 'patient-1', 'partner-1', 'yes', at),
          _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
        ],
        boundaries: <Object?>[
          <String, Object?>{
            'id': 'boundary-a',
            'ownerId': 'patient-1',
            'partnerId': 'partner-1',
            'category': 'touch',
            'optionKey': 'kiss',
            'blocked': true,
            'createdAt':
                at.subtract(const Duration(minutes: 1)).toIso8601String(),
          },
        ],
      );
      expect(observer.observe(blocked).facts['intimacyDecisionKinds'], isEmpty);
    });

    test('ask-first and missing reverse intimacy permission fail safely', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final askFirst = _intimacyScenario(
        id: 'intimacy-ask-first',
        at: at,
        willingness: <Object?>[
          _willingness('wa', 'patient-1', 'partner-1', 'askFirst', at),
          _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
        ],
      );
      expect(
        observer.observe(askFirst).facts['intimacyDecisionKinds'],
        <String>['askFirst'],
      );

      final oneDirection = _intimacyScenario(
        id: 'intimacy-one-direction-permission',
        at: at,
        willingness: <Object?>[
          _willingness('wa', 'patient-1', 'partner-1', 'yes', at),
          _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
        ],
        grants: <Object?>[
          _grantDirectional(
            'relationship.intimacy.touch',
            'intimacy',
            'engineOnly',
            at,
            ownerId: 'patient-1',
            recipientId: 'partner-1',
          ),
        ],
      );
      expect(observer.observe(oneDirection).facts['intimacyDecisionKinds'],
          isEmpty);
    });

    test(
        'no notTonight maybe and cooldown preserve production intimacy semantics',
        () {
      final at = DateTime.utc(2026, 9, 16, 9);
      for (final value in <String>['no', 'notTonight']) {
        final scenario = _intimacyScenario(
          id: 'intimacy-$value',
          at: at,
          willingness: <Object?>[
            _willingness('wa', 'patient-1', 'partner-1', value, at),
            _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
          ],
        );
        expect(
            observer.observe(scenario).facts['intimacyDecisionKinds'], isEmpty);
      }

      final maybe = _intimacyScenario(
        id: 'intimacy-maybe',
        at: at,
        willingness: <Object?>[
          _willingness('wa', 'patient-1', 'partner-1', 'maybe', at),
          _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
        ],
      );
      expect(observer.observe(maybe).facts['intimacyDecisionKinds'],
          <String>['askFirst']);

      final cooldownWillingness = <Object?>[
        _willingness('wa', 'patient-1', 'partner-1', 'yes', at)
          ..['cooldownUntil'] =
              at.add(const Duration(minutes: 5)).toIso8601String(),
        _willingness('wb', 'partner-1', 'patient-1', 'yes', at),
      ];
      final cooldown = _intimacyScenario(
        id: 'intimacy-cooldown',
        at: at,
        willingness: cooldownWillingness,
      );
      expect(
          observer.observe(cooldown).facts['intimacyDecisionKinds'], isEmpty);
    });

    test('notification content capabilities remain independent', () {
      final at = DateTime.utc(2026, 9, 16, 9);
      final all = _scenario(
        id: 'notification-playful-intimacy',
        family: RelationshipBehaviorScenarioFamily.notification,
        payload: <String, Object?>{
          'kind': 'playfulIntimacy',
          'mode': 'detailedWhenUnlocked',
          'deviceUnlocked': true,
          'category': 'relationship.update',
          'categoryLabel': 'Partner',
          'detail': 'private detail',
          'grants': <Object?>[
            _grant('relationship.update', 'notify', 'engineOnly', at),
            _grant('relationship.update', 'playful', 'engineOnly', at),
            _grant('relationship.update', 'intimacy', 'engineOnly', at),
          ],
        },
      );
      final facts = observer.observe(all).facts;
      expect(facts['notificationPresented'], true);
      expect(facts['notificationRedacted'], false);
      expect(facts['notificationBody'], 'private detail');
    });

    test('presets expand deterministically and custom remains empty', () {
      final categories = <String>['sleep', 'cycle'];
      final preset = _scenario(
        id: 'preset-minimal',
        family: RelationshipBehaviorScenarioFamily.preset,
        payload: <String, Object?>{
          'preset': 'minimal',
          'categories': categories,
        },
      );
      final facts = observer.observe(preset).facts;
      expect(facts['presetCategories'], <String>['cycle', 'sleep']);
      expect(facts['presetGrantIds'], <String>[
        'rel-patient-1-partner-1-cycle-minimal-v1',
        'rel-patient-1-partner-1-sleep-minimal-v1',
      ]);

      final custom = _scenario(
        id: 'preset-custom',
        family: RelationshipBehaviorScenarioFamily.preset,
        payload: <String, Object?>{
          'preset': 'custom',
          'categories': categories,
        },
      );
      expect(observer.observe(custom).facts['presetGrantIds'], isEmpty);
    });
  });
}

Map<String, Object?> _grantDirectional(
  String category,
  String capability,
  String visibility,
  DateTime at, {
  required String ownerId,
  required String recipientId,
}) =>
    <String, Object?>{
      'id': 'grant-$ownerId-$recipientId-$category-$capability',
      'ownerId': ownerId,
      'recipientId': recipientId,
      'category': category,
      'capabilities': <String>[capability],
      'visibility': visibility,
      'createdAt': at.subtract(const Duration(minutes: 1)).toIso8601String(),
      'version': 1,
    };

Map<String, Object?> _preference(
  String id,
  String ownerId,
  String partnerId,
  DateTime at,
) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'partnerId': partnerId,
      'category': 'touch',
      'optionKey': 'kiss',
      'level': 'interested',
      'createdAt': at.subtract(const Duration(hours: 1)).toIso8601String(),
      'version': 1,
    };

Map<String, Object?> _willingness(
  String id,
  String ownerId,
  String partnerId,
  String willingness,
  DateTime at,
) =>
    <String, Object?>{
      'id': id,
      'ownerId': ownerId,
      'partnerId': partnerId,
      'category': 'touch',
      'optionKey': 'kiss',
      'willingness': willingness,
      'createdAt': at.subtract(const Duration(minutes: 1)).toIso8601String(),
      'expiresAt': at.add(const Duration(minutes: 30)).toIso8601String(),
      'version': 1,
    };

RelationshipBehaviorScenario _intimacyScenario({
  required String id,
  required DateTime at,
  required List<Object?> willingness,
  List<Object?> boundaries = const <Object?>[],
  List<Object?>? grants,
}) =>
    _scenario(
      id: id,
      family: RelationshipBehaviorScenarioFamily.intimacy,
      payload: <String, Object?>{
        'preferences': <Object?>[
          _preference('pa', 'patient-1', 'partner-1', at),
          _preference('pb', 'partner-1', 'patient-1', at),
        ],
        'willingness': willingness,
        'boundaries': boundaries,
        'grants': grants ??
            <Object?>[
              _grantDirectional(
                'relationship.intimacy.touch',
                'intimacy',
                'engineOnly',
                at,
                ownerId: 'patient-1',
                recipientId: 'partner-1',
              ),
              _grantDirectional(
                'relationship.intimacy.touch',
                'intimacy',
                'engineOnly',
                at,
                ownerId: 'partner-1',
                recipientId: 'patient-1',
              ),
            ],
      },
    );

void _registerCanonicalRelationshipBehaviorTests() {
  group('canonical relationship behavior smoke', () {
    test('same seed is byte stable and covers all mandatory dimensions', () {
      final first = runProductionRelationshipBehaviorSmoke(20260916);
      final second = runProductionRelationshipBehaviorSmoke(20260916);

      expect(first.passed, isTrue);
      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(first.syntheticEvidenceOnly, isTrue);
      expect(first.coverage.malformedInputFailures, 0);
      expect(
        first.coverage.families.keys.toSet(),
        containsAll(
            RelationshipBehaviorScenarioFamily.values.map((e) => e.name)),
      );
      for (final tag in <String>{
        'scope',
        'lifecycle',
        'permission',
        'visibility',
        'notificationPrivacy',
        'consent',
        'ordering',
        'suppression',
        'noFallback',
        'clinicalTruth',
        'phase8Reuse',
        'phase9Reuse',
      }) {
        expect(first.coverage.riskTags[tag], greaterThan(0), reason: tag);
      }
      expect(first.coverage.phase8ReuseCount, greaterThan(0));
      expect(first.coverage.phase9ReuseCount, greaterThan(0));
      final ids = buildCanonicalRelationshipBehaviorScenarios(20260916)
          .map((item) => item.id)
          .toList();
      expect(ids.toSet().length, ids.length);
    });

    test('canonical matrix covers reviewed acceptance boundaries', () {
      final ids = buildCanonicalRelationshipBehaviorScenarios(20260916)
          .map((item) => item.id)
          .toSet();
      expect(
        ids,
        containsAll(<String>[
          'signal.lifecycle.expired',
          'signal.supersession.version',
          'memory.context.engine-only',
          'novelty.constraints-and-ranking',
          'partner-home.authorized-surfaces',
          'notification.category-only',
        ]),
      );
    });

    test('mandatory coverage gaps fail with coverage_gap reason', () {
      final scenario = _scenario(
        id: 'only-one-family',
        family: RelationshipBehaviorScenarioFamily.signalProjection,
      );
      final report = RelationshipBehaviorSuite(
        observer: const _StaticObserver(RelationshipBehaviorObservation()),
      ).run(
        seed: 20260916,
        scenarios: <RelationshipBehaviorScenario>[scenario],
        requireMandatoryCoverage: true,
      );

      expect(report.passed, isFalse);
      expect(report.results.any((item) => item.reasonCode == 'coverage_gap'),
          isTrue);
    });
  });
}

void _registerRelationshipBehaviorSmokeCliTests() {
  group('production smoke CLI', () {
    test('production smoke evidence is deterministic and synthetic only', () {
      final first = runProductionRelationshipBehaviorSmoke(20260916);
      final second = runProductionRelationshipBehaviorSmoke(20260916);
      expect(first.passed, isTrue);
      expect(first.syntheticEvidenceOnly, isTrue);
      expect(first.toNormalizedJson(), second.toNormalizedJson());
      expect(first.coverage.malformedInputFailures, 0);
    });
  });
}
