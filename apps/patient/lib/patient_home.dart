import 'dart:async';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'cycle_timeline.dart';
import 'month_calendar.dart';
import 'patient_localizations.dart';
import 'quick_log.dart';
import 'timeline_view.dart';
import 'vault_session.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({
    required this.session,
    required this.appLock,
    super.key,
  });

  final PatientVaultSession session;
  final AppLockService appLock;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with WidgetsBindingObserver {
  static const _subjectId = 'local-owner';
  static const _actorId = 'patient:self';

  bool _loading = true;
  bool _privacyCovered = true;
  bool _unlockFailed = false;
  bool _sessionInitialized = false;
  List<HealthEvent> _events = const <HealthEvent>[];
  VaultState _vaultState = VaultState.uninitialized;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_authenticateAndOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.appLock.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_privacyCovered && !widget.appLock.authInProgress) {
        unawaited(_authenticateAndOpen());
      }
      return;
    }

    if (state == AppLifecycleState.inactive && widget.appLock.authInProgress) {
      return;
    }

    unawaited(_protectAndLock());
  }

  Future<void> _protectAndLock() async {
    if (mounted) {
      setState(() {
        _privacyCovered = true;
        _unlockFailed = false;
        _vaultState = VaultState.locked;
      });
    }
    await widget.appLock.cancel();
    if (_sessionInitialized) {
      await widget.session.lock();
    }
  }

  Future<void> _authenticateAndOpen() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _privacyCovered = true;
        _unlockFailed = false;
      });
    }

    final authenticated = await widget.appLock.authenticate();
    if (!authenticated) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _unlockFailed = true;
      });
      return;
    }

    if (!_sessionInitialized) {
      await widget.session.initialize();
      _sessionInitialized = true;
    } else {
      await widget.session.unlock();
    }

    await _reload();
    if (!mounted) return;
    setState(() {
      _privacyCovered = false;
      _unlockFailed = false;
    });
  }

  Future<void> _reload() async {
    final events = await widget.session.repository.query(subjectId: _subjectId);
    final vaultState = await widget.session.state();
    if (!mounted) return;
    setState(() {
      _events = events;
      _vaultState = vaultState;
      _loading = false;
    });
  }

  Future<void> _openQuickLog() async {
    final selection = await showQuickLogSheet(context);
    if (selection == null || !mounted) return;
    await _logSelection(selection);
  }

  Future<void> _openCalendar() async {
    if (_privacyCovered) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: MonthCalendar(events: _events),
          ),
        );
      },
    );
  }

  Future<void> _logSelection(QuickLogSelection selection) async {
    final now = DateTime.now().toUtc();
    final event = HealthEvent(
      id: 'event-${now.microsecondsSinceEpoch}',
      subjectId: _subjectId,
      eventType: selection.eventType,
      value: selection.value,
      unit: selection.unit,
      severity: selection.severity,
      dataState: DataState.yes,
      temporal: TemporalMetadata(
        observedAt: now,
        recordedAt: now,
        knownAt: now,
      ),
      provenance: const Provenance(sourceKind: SourceKind.patient),
      verificationStatus: VerificationStatus.selfReported,
      confidence: ConfidenceClass.high,
      privacyClass: 'reproductive',
      schemaVersion: 1,
    );

    await widget.session.repository.upsert(event);
    await widget.session.auditLog.append(
      AuditEvent.now(
        action: AuditAction.created,
        actorId: _actorId,
        subjectType: 'health_event',
        subjectId: event.id,
        metadata: <String, Object?>{
          'ownerSubjectId': _subjectId,
          'eventType': event.eventType,
          'source': event.provenance.sourceKind.name,
        },
      ),
    );
    await _reload();
  }

  String _eventLabel(PatientLocalizations strings, HealthEvent event) {
    switch (event.eventType) {
      case 'menstruation.period_start':
        return strings.periodStarted;
      case 'menstruation.flow':
        return switch (event.severity) {
          1 => strings.lightFlow,
          2 => strings.mediumFlow,
          3 => strings.heavyFlow,
          _ => strings.flow,
        };
      case 'symptom.cramps':
        return strings.cramps;
      case 'symptom.headache':
        return strings.headache;
      case 'symptom.mood_low':
        return strings.lowMood;
      default:
        return event.eventType;
    }
  }

  IconData _eventIcon(HealthEvent event) {
    if (event.eventType.startsWith('menstruation.')) {
      return Icons.water_drop_outlined;
    }
    return Icons.favorite_border;
  }

  Widget _buildPrivateCover(PatientLocalizations strings) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 42),
            const SizedBox(height: 12),
            Text(strings.appTitle, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              _unlockFailed
                  ? strings.authenticationRequired
                  : strings.privateDataLocked,
              textAlign: TextAlign.center,
            ),
            if (_unlockFailed) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _authenticateAndOpen,
                icon: const Icon(Icons.fingerprint),
                label: Text(strings.unlock),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = PatientLocalizations.of(context);
    final vaultSummary = _loading
        ? strings.opening
        : strings.vaultSummary(_events.length, _vaultState.name);
    final timeline = CycleTimeline(_events);
    final cycleDay = timeline.cycleDayFor(DateTime.now());

    final content = Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: strings.calendar,
            onPressed: _privacyCovered ? null : _openCalendar,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _privacyCovered ? null : _openQuickLog,
        icon: const Icon(Icons.add),
        label: Text(strings.log),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.today,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(strings.todayHint),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    cycleDay == null
                        ? strings.cycleDayUnknown
                        : strings.cycleDay(cycleDay),
                  ),
                  subtitle: Text(
                    cycleDay == null
                        ? strings.logPeriodStartHint
                        : strings.latestPeriodStartHint,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _privacyCovered ? null : _openCalendar,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(strings.quickLog),
                  subtitle: Text(strings.quickLogCardHint),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _privacyCovered ? null : _openQuickLog,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(strings.encryptedLocalVault),
                  subtitle: Text(vaultSummary),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                strings.timeline,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : PatientTimelineView(
                        events: _events,
                        labelFor: (event) => _eventLabel(strings, event),
                        iconFor: _eventIcon,
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (_privacyCovered) _buildPrivateCover(strings),
      ],
    );
  }
}
