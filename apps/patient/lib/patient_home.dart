import 'dart:async';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'cycle_timeline.dart';
import 'month_calendar.dart';
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

  String _eventLabel(HealthEvent event) {
    switch (event.eventType) {
      case 'menstruation.period_start':
        return 'Period started';
      case 'menstruation.flow':
        return switch (event.severity) {
          1 => 'Light flow',
          2 => 'Medium flow',
          3 => 'Heavy flow',
          _ => 'Flow',
        };
      case 'symptom.cramps':
        return 'Cramps';
      case 'symptom.headache':
        return 'Headache';
      case 'symptom.mood_low':
        return 'Low mood';
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

  Widget _buildPrivateCover() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 42),
            const SizedBox(height: 12),
            const Text('Cycle', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              _unlockFailed
                  ? 'Authentication is required to open private health data.'
                  : 'Private health data is locked.',
              textAlign: TextAlign.center,
            ),
            if (_unlockFailed) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _authenticateAndOpen,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vaultSummary = _loading
        ? 'Opening…'
        : '${_events.length} local health event(s) · ${_vaultState.name}';
    final timeline = CycleTimeline(_events);
    final cycleDay = timeline.cycleDayFor(DateTime.now());

    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Cycle'),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            onPressed: _privacyCovered ? null : _openCalendar,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _privacyCovered ? null : _openQuickLog,
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text('Only log what matters. Cycle keeps the rest quiet.'),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    cycleDay == null ? 'Cycle day unknown' : 'Cycle day $cycleDay',
                  ),
                  subtitle: Text(
                    cycleDay == null
                        ? 'Log a period start when it happens.'
                        : 'Based on your latest logged period start.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _privacyCovered ? null : _openCalendar,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Quick Log'),
                  subtitle: const Text('Period, flow or a symptom in one tap'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _privacyCovered ? null : _openQuickLog,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Encrypted local vault'),
                  subtitle: Text(vaultSummary),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Timeline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : PatientTimelineView(
                        events: _events,
                        labelFor: _eventLabel,
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
      children: [content, if (_privacyCovered) _buildPrivateCover()],
    );
  }
}
