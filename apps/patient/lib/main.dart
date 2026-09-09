import 'package:flutter/material.dart';

void main() {
  runApp(const CyclePatientApp());
}

class CyclePatientApp extends StatelessWidget {
  const CyclePatientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cycle',
      theme: ThemeData(useMaterial3: true),
      home: const PatientHomePage(),
    );
  }
}

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('Private, local-first reproductive health.'),
              SizedBox(height: 24),
              Card(
                child: ListTile(
                  title: Text('Quick Log'),
                  subtitle: Text('Cycle and symptom logging will live here.'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
