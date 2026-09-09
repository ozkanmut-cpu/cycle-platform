import 'dart:async';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'vault_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CyclePatientApp(
      session: PatientVaultSession(),
      appLock: AppLockService(),
    ),
  );
}

class CyclePatientApp extends StatelessWidget {
  const CyclePatientApp({
    required this.session,
    required this.appLock,
    super.key,
  });

  final PatientVaultSession session;
  final AppLockService appLock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle',
      theme: ThemeData(useMaterial3: true),
      home: PatientHomePage(session: session, appLock: appLock),
    );
  }
}

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
    switch (state) {
      case AppLifecycleState.resumed:
        if (_privacyCovered) {
          unawaited(_authenticateAndOpen());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_protectAndLock());
    }
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

  Future<void> _logPeriodStart() async {
    final now = DateTime.now().toUtc();
    final event = HealthEvent(
      id: 'period-${now.microsecondsSinceEpoch}',
      subjectId: _subjectId,
      eventType: 'menstruation.period_start',
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

  Widget _buildActivity() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_events.isEmpty) {
      return const Center(child: Text('No entries yet. Use “Period started”.'));
    }

    return ListView.separated(
      itemCount: _events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = _events[index];
        return ListTile(
          leading: const Icon(Icons.water_drop_outlined),
          title: const Text('Period started'),
          subtitle: Text(event.temporal.observedAt.toLocal().toString()),
        );
      },
    );
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

    final content = Scaffold(
      appBar: AppBar(title: const Text('Cycle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _privacyCovered ? null : _logPeriodStart,
        icon: const Icon(Icons.add),
        label: const Text('Period started'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('Private, local-first reproductive health.'),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Encrypted local vault'),
                  subtitle: Text(vaultSummary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recent activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildActivity()),
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
