import 'package:cycle_security/cycle_security.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import 'patient_localizations.dart';

class AppLockService {
  AppLockService({
    LocalAuthentication? authentication,
    ReauthenticationPolicy policy = ReauthenticationPolicy.secureDefault,
  }) : _authentication = authentication ?? LocalAuthentication(),
       _policy = policy;

  final LocalAuthentication _authentication;
  final ReauthenticationPolicy _policy;
  bool _authInProgress = false;
  DateTime? _lastAuthenticatedAt;

  bool get authInProgress => _authInProgress;

  Future<bool> canAuthenticate() async {
    return _authentication.isDeviceSupported();
  }

  Future<bool> authenticate({
    LockSensitivity sensitivity = LockSensitivity.standard,
  }) async {
    final now = DateTime.now().toUtc();
    final requiresAuthentication = _policy.requiresAuthentication(
      now: now,
      lastAuthenticatedAt: _lastAuthenticatedAt,
      sensitivity: sensitivity,
    );
    if (!requiresAuthentication) return true;
    if (_authInProgress) return false;
    if (!await canAuthenticate()) return false;

    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final localizedReason = PatientLocalizations.forLocale(locale).unlockReason;

    _authInProgress = true;
    try {
      final authenticated = await _authentication.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated) {
        _lastAuthenticatedAt = DateTime.now().toUtc();
      }
      return authenticated;
    } finally {
      _authInProgress = false;
    }
  }

  void requireFreshAuthentication() {
    _lastAuthenticatedAt = null;
  }

  Future<void> cancel() async {
    if (!_authInProgress) return;
    await _authentication.stopAuthentication();
    _authInProgress = false;
  }
}
