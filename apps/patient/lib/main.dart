import 'dart:convert';

import 'package:cycle_core_domain/cycle_core_domain.dart';
import 'package:cycle_crypto/cycle_crypto.dart';
import 'package:cycle_secure_key_store/cycle_secure_key_store.dart';
import 'package:cycle_storage/cycle_storage.dart';
import 'package:cycle_storage_sqlcipher/cycle_storage_sqlcipher.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final keyStore = FlutterSecureKeyStore();
  final databaseKey = await keyStore.createKey(KeyPurpose.database);
  final database = await SqlCipherDatabase.openDefault(
    password: base64UrlEncode(databaseKey.wrappedKey),
  );
  final repository = SqlCipherHealthEventRepository(database);

  runApp(CyclePatientApp(repository: repository));
}

class CyclePatientApp extends StatelessWidget {
  const CyclePatientApp({required this.repository, super.key});

  final HealthEventRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle',
      theme: ThemeData(useMaterial3: true),
      home: PatientHomePage(repository: repository),
    );
  }
}

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({required this.repository, super.key});

  final HealthEventRepository repository;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  static const _subjectId = 'local-owner';
  bool _loading = true;
  List<HealthEvent> _events = const <HealthEvent>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final events = await widget.repository.query(subjectId: _subjectId);
    if (!mounted) return;
    setState(() {
      _events = events;
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

    await widget.repository.upsert(event);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logPeriodStart,
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
                  subtitle: Text(
                    _loading
                        ? 'Opening…'
                        : '${_events.length} local health event(s)',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recent activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _events.isEmpty
                        ? const Center(
                            child: Text('No entries yet. Use “Period started”.'),
                          )
                        : ListView.separated(
                            itemCount: _events.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final event = _events[index];
                              return ListTile(
                                leading: const Icon(Icons.water_drop_outlined),
                                title: const Text('Period started'),
                                subtitle: Text(
                                  event.temporal.observedAt.toLocal().toString(),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
