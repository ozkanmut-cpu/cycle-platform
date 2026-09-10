import 'package:cycle_clinical_copilot/cycle_clinical_copilot.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const CycleDoctorApp());
}

class CycleDoctorApp extends StatelessWidget {
  const CycleDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle Doctor',
      theme: ThemeData(useMaterial3: true),
      home: const DoctorHomePage(),
    );
  }
}

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key});

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
  static const _patients = <DoctorPatient>[
    DoctorPatient(id: 'patient-1', displayName: 'Patient One'),
    DoctorPatient(id: 'patient-2', displayName: 'Patient Two'),
    DoctorPatient(id: 'patient-3', displayName: 'Patient Three'),
  ];

  int _selectedPatient = 0;
  SnapshotSectionKind _section = SnapshotSectionKind.whatMatters;

  DoctorPatient get _patient => _patients[_selectedPatient];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cycle Doctor'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('Doctor Review required for writes')),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: _PatientRail(
                patients: _patients,
                selectedIndex: _selectedPatient,
                onSelected: (index) => setState(() => _selectedPatient = index),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _patient.displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Clinical Snapshot · evidence-linked, review-gated workspace',
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SnapshotSectionKind.values
                          .map(
                            (section) => ChoiceChip(
                              label: Text(_label(section)),
                              selected: _section == section,
                              onSelected: (_) =>
                                  setState(() => _section = section),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _ClinicalWorkspace(
                        patient: _patient,
                        section: _section,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientRail extends StatelessWidget {
  const _PatientRail({
    required this.patients,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DoctorPatient> patients;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Patients',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final patient = patients[index];
              return ListTile(
                selected: index == selectedIndex,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(patient.displayName),
                subtitle: Text(patient.id),
                onTap: () => onSelected(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClinicalWorkspace extends StatelessWidget {
  const _ClinicalWorkspace({required this.patient, required this.section});

  final DoctorPatient patient;
  final SnapshotSectionKind section;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Panel(
          title: _label(section),
          child: Text(
            'Structured clinical content for ${patient.displayName} will be rendered here from the canonical record and evidence graph.',
          ),
        ),
        const SizedBox(height: 16),
        const _Panel(
          title: 'Clinical Compression + Evidence Graph',
          child: Text(
            'Every compressed statement retains evidence identifiers and can be traced back to canonical events or preserved source documents.',
          ),
        ),
        const SizedBox(height: 16),
        const _Panel(
          title: 'Clinical Reasoning Workspace',
          child: Text(
            'Clinician notes, treatment-trial hooks and clinical-question protocols remain patient-scoped and evidence-linked.',
          ),
        ),
        const SizedBox(height: 16),
        const _Panel(
          title: 'Clinical Copilot',
          child: Text(
            'Natural-language record search is routed to safe structured queries. AI outputs carry provenance, evidence links and an audit record. No autonomous clinical write is permitted.',
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _label(SnapshotSectionKind kind) {
  switch (kind) {
    case SnapshotSectionKind.whatChanged:
      return 'What Changed';
    case SnapshotSectionKind.whatMatters:
      return 'What Matters';
    case SnapshotSectionKind.missing:
      return 'Missing';
    case SnapshotSectionKind.uncertain:
      return 'Uncertain';
    case SnapshotSectionKind.conflicts:
      return 'Conflicts';
    case SnapshotSectionKind.openLoops:
      return 'Open Loops';
  }
}
