import 'package:local_auth/local_auth.dart';

import '../utils/logger.dart';

/// Why an unlock attempt ended.
enum UnlockResult { granted, denied, unavailable }

/// Guards the app behind the device's own authentication.
///
/// Deliberately stores no secret. The original brief forbids keeping
/// credentials in SQLite, and the way to honour that is not to hash a PIN of
/// our own but to have none: `local_auth` defers to the operating system, which
/// already holds the user's biometric and device credential and protects them
/// far better than an app can. Settings persists only *whether* the lock is on.
class AppLockService {
  AppLockService(this._auth);

  final LocalAuthentication _auth;

  /// Whether the device can authenticate at all — biometric enrolled, or a
  /// screen lock set. Drives whether the setting is offered or explained as
  /// unavailable.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (error) {
      AppLogger.w(
        'Lock support check failed: ${error.runtimeType}',
        name: 'LOCK',
      );
      return false;
    }
  }

  /// Whether a fingerprint or face is actually enrolled, as opposed to only a
  /// PIN or pattern.
  Future<bool> hasBiometrics() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (error) {
      AppLogger.w('Biometric check failed: ${error.runtimeType}', name: 'LOCK');
      return false;
    }
  }

  /// Prompts for authentication.
  ///
  /// [biometricOnly] false lets the device credential stand in, so a user whose
  /// fingerprint fails is not locked out of their own ledger.
  Future<UnlockResult> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.unavailable;

      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? UnlockResult.granted : UnlockResult.denied;
    } catch (error) {
      // Never log what was attempted, only that it failed.
      AppLogger.w('Authentication failed: ${error.runtimeType}', name: 'LOCK');
      return UnlockResult.unavailable;
    }
  }
}
