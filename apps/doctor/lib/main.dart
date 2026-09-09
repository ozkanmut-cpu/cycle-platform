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

class DoctorHomePage extends StatelessWidget {
  const DoctorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle Doctor')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clinical Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              Text('What matters · What changed · Missing · Uncertain · Conflicts · Open loops'),
            ],
          ),
        ),
      ),
    );
  }
}
