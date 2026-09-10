import 'package:cycle_health_ingestion/cycle_health_ingestion.dart';
import 'package:cycle_patient/health/native_health_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cycle.health/native-test');
  const bridge = NativeHealthBridge(channel: channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Health Connect bridge decodes records and provenance inputs', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'healthConnect.readRecords') {
            return [
              {
                'sourceType': 'heart_rate',
                'sourceRecordId': 'hc-1',
                'observedAtEpochMillis': DateTime.utc(
                  2026,
                  9,
                  9,
                  10,
                ).millisecondsSinceEpoch,
                'value': 76,
                'unit': 'bpm',
                'sourceName': 'Health Connect',
                'deviceName': 'Watch',
                'metadata': {'origin': 'example.app'},
              },
            ];
          }
          return null;
        });

    final records = await bridge.healthConnect.readRecords(
      from: DateTime.utc(2026, 9, 9),
      to: DateTime.utc(2026, 9, 10),
      categories: {HealthDataCategory.vitals},
    );

    expect(records, hasLength(1));
    expect(records.single.sourcePlatform, HealthSourcePlatform.healthConnect);
    expect(records.single.sourceRecordId, 'hc-1');
    expect(records.single.metadata['origin'], 'example.app');
  });

  test(
    'Health Connect bridge decodes upserts deletes and cursor state',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'healthConnect.readChanges') {
              return {
                'nextToken': 'token-2',
                'hasMore': false,
                'tokenExpired': false,
                'changes': [
                  {
                    'kind': 'upsert',
                    'record': {
                      'sourceType': 'oxygen_saturation',
                      'sourceRecordId': 'spo2-new',
                      'observedAtEpochMillis': DateTime.utc(
                        2026,
                        9,
                        9,
                        10,
                      ).millisecondsSinceEpoch,
                      'value': 97,
                      'unit': '%',
                    },
                  },
                  {'kind': 'delete', 'sourceRecordId': 'spo2-old'},
                ],
              };
            }
            return null;
          });

      final page = await bridge.healthConnect.readChanges(
        token: 'token-1',
        categories: {HealthDataCategory.vitals},
      );

      expect(page.nextToken, 'token-2');
      expect(page.changes, hasLength(2));
      expect(page.changes.first.record?.sourceRecordId, 'spo2-new');
      expect(page.changes.last.deletedSourceRecordId, 'spo2-old');
    },
  );

  test('HealthKit bridge decodes limited-history scope without guessing denial',
      () async {
    final earliest = DateTime.utc(2026, 8, 11);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'healthKit.readAccessScope') {
            return {
              'availableCategories': ['vitals', 'sleep'],
              'requestStatusUnnecessaryCategories': ['vitals'],
              'queryVisibleCategories': ['sleep'],
              'earliestAuthorizedAtEpochMillis': {
                'vitals': earliest.millisecondsSinceEpoch,
              },
            };
          }
          return null;
        });

    final scope = await HealthKitSyncAdapter(bridge.healthKit).readAccessScope();

    expect(scope.availableCategories, {
      HealthDataCategory.vitals,
      HealthDataCategory.sleep,
    });
    expect(scope.requestStatusUnnecessaryCategories, {
      HealthDataCategory.vitals,
    });
    expect(scope.queryVisibleCategories, {HealthDataCategory.sleep});
    expect(scope.unknownCategories, {HealthDataCategory.vitals});
    expect(scope.earliestAuthorizedAt[HealthDataCategory.vitals], earliest);
  });

  test('HealthKit bridge fails closed when native scope is absent', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(
      () => HealthKitSyncAdapter(bridge.healthKit).readAccessScope(),
      throwsA(isA<StateError>()),
    );
  });

  test('bridge rejects missing native cursor', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(
      () => bridge.healthConnect.createChangesToken(
        categories: {HealthDataCategory.vitals},
      ),
      throwsA(isA<StateError>()),
    );
  });
}
