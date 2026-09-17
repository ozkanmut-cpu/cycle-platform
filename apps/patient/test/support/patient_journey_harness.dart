import 'dart:collection';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_patient/app_lock.dart';
import 'package:cycle_patient/patient_home.dart';
import 'package:cycle_patient/patient_localizations.dart';
import 'package:cycle_patient/vault_session.dart';
import 'package:cycle_security/cycle_security.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class MutablePatientJourneyClock {
  MutablePatientJourneyClock(this.current);

  DateTime current;

  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}

class JourneyHealthEventRepository implements HealthEventRepository {
  JourneyHealthEventRepository(Iterable<HealthEvent> seed)
    : events = List<HealthEvent>.of(seed);

  final List<HealthEvent> events;
  final Set<String> _deletedIds = <String>{};

  @override
  Future<void> upsert(HealthEvent event) async {
    final index = events.indexWhere((existing) => existing.id == event.id);
    if (index == -1) {
      events.add(event);
    } else {
      events[index] = event;
    }
  }

  @override
  Future<HealthEvent?> getById(String id) async {
    if (_deletedIds.contains(id)) return null;
    for (final event in events) {
      if (event.id == id) return event;
    }
    return null;
  }

  @override
  Future<List<HealthEvent>> query({
    required String subjectId,
    String? eventType,
    DateTime? from,
    DateTime? to,
    bool includeSuperseded = false,
  }) async {
    final supersededIds = events
        .map((candidate) => candidate.supersedesEventId)
        .whereType<String>()
        .toSet();
    return events.where((event) {
      if (_deletedIds.contains(event.id)) return false;
      if (event.subjectId != subjectId) return false;
      if (eventType != null && event.eventType != eventType) return false;
      if (from != null && event.temporal.observedAt.isBefore(from)) {
        return false;
      }
      if (to != null && event.temporal.observedAt.isAfter(to)) return false;
      if (!includeSuperseded && supersededIds.contains(event.id)) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> markDeleted({
    required String eventId,
    required DateTime deletedAt,
  }) async => _deletedIds.add(eventId);
}

class JourneyAuditLogRepository implements AuditLogRepository {
  final List<AuditEvent> events = <AuditEvent>[];

  @override
  Future<void> append(AuditEvent event) async => events.add(event);

  @override
  Future<List<AuditEvent>> listForSubject(
    String subjectId, {
    int limit = 200,
  }) async => events
      .where((event) => event.subjectId == subjectId)
      .take(limit)
      .toList();
}

class JourneyPatientVaultSession extends PatientVaultSession {
  JourneyPatientVaultSession(this.journeyRepository, this.journeyAuditLog);

  final JourneyHealthEventRepository journeyRepository;
  final JourneyAuditLogRepository journeyAuditLog;
  VaultState _state = VaultState.uninitialized;
  int initializeCalls = 0;
  int unlockCalls = 0;
  int lockCalls = 0;

  @override
  HealthEventRepository get repository => journeyRepository;

  @override
  AuditLogRepository get auditLog => journeyAuditLog;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    _state = VaultState.unlocked;
  }

  @override
  Future<void> unlock() async {
    unlockCalls += 1;
    _state = VaultState.unlocked;
  }

  @override
  Future<void> lock() async {
    lockCalls += 1;
    _state = VaultState.locked;
  }

  @override
  Future<VaultState> state() async => _state;
}

class QueuedJourneyAppLock extends AppLockService {
  QueuedJourneyAppLock(Iterable<bool> outcomes)
    : _outcomes = ListQueue<bool>.of(outcomes);

  final ListQueue<bool> _outcomes;
  int authenticateCalls = 0;
  int cancelCalls = 0;

  @override
  bool get authInProgress => false;

  @override
  Future<bool> authenticate({
    LockSensitivity sensitivity = LockSensitivity.standard,
  }) async {
    authenticateCalls += 1;
    if (_outcomes.isEmpty) {
      throw StateError('No queued authentication outcome.');
    }
    return _outcomes.removeFirst();
  }

  @override
  Future<void> cancel() async => cancelCalls += 1;
}

Widget buildPatientJourneyApp({
  required Widget home,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: PatientLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    PatientLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

Future<void> clearPatientJourneyWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

class PatientJourneyHarness {
  PatientJourneyHarness({
    required DateTime virtualNow,
    required Iterable<HealthEvent> events,
    required Iterable<bool> authenticationOutcomes,
  }) {
    if (!virtualNow.isUtc) {
      throw ArgumentError.value(virtualNow, 'virtualNow', 'must be UTC');
    }
    clock = MutablePatientJourneyClock(virtualNow);
    repository = JourneyHealthEventRepository(events);
    audit = JourneyAuditLogRepository();
    session = JourneyPatientVaultSession(repository, audit);
    appLock = QueuedJourneyAppLock(authenticationOutcomes);
  }

  late final MutablePatientJourneyClock clock;
  late final JourneyHealthEventRepository repository;
  late final JourneyAuditLogRepository audit;
  late final JourneyPatientVaultSession session;
  late final QueuedJourneyAppLock appLock;

  Future<void> pumpHome(WidgetTester tester) async {
    if (tester.binding.lifecycleState != AppLifecycleState.resumed) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await tester.pumpWidget(
      buildPatientJourneyApp(
        home: PatientHomePage(
          session: session,
          appLock: appLock,
          now: clock.now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
