import 'package:local_auth/local_auth.dart';

class AppLockService {
  AppLockService({LocalAuthentication? authentication})
      : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  Future<bool> canAuthenticate() async {
    return _authentication.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    if (!await canAuthenticate()) return false;

    return _authentication.authenticate(
      localizedReason: 'Unlock Cycle to view your private health data.',
      biometricOnly: false,
      sensitiveTransaction: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<void> cancel() async {
    await _authentication.stopAuthentication();
  }
}
