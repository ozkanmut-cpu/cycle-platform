import 'package:local_auth/local_auth.dart';

class AppLockService {
  AppLockService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;
  bool _authInProgress = false;

  bool get authInProgress => _authInProgress;

  Future<bool> canAuthenticate() async {
    return _authentication.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    if (_authInProgress) return false;
    if (!await canAuthenticate()) return false;

    _authInProgress = true;
    try {
      return await _authentication.authenticate(
        localizedReason: 'Unlock Cycle to view your private health data.',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> cancel() async {
    if (!_authInProgress) return;
    await _authentication.stopAuthentication();
    _authInProgress = false;
  }
}
