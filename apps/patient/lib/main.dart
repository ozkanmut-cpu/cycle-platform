import 'package:flutter/material.dart';

import 'app_lock.dart';
import 'patient_home.dart';
import 'vault_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CyclePatientApp(session: PatientVaultSession(), appLock: AppLockService()),
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
