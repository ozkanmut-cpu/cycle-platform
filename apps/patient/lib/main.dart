import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_lock.dart';
import 'patient_home.dart';
import 'patient_localizations.dart';
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
      supportedLocales: PatientLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        PatientLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) =>
          PatientLocalizations.resolve(locale),
      theme: ThemeData(useMaterial3: true),
      home: PatientHomePage(session: session, appLock: appLock),
    );
  }
}
