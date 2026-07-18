import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyUsername        = 'username';
  static const String _keyIsLoggedIn      = 'is_logged_in';
  static const String _keyFingerprintEnabled = 'fingerprint_enabled';

  // ============ LOGIN ============

  Future<bool> login(String username, String password) async {
    final bool ok = await DatabaseHelper().login(username, password);
    if (ok) {
      await _storage.write(key: _keyUsername, value: username);
      await _storage.write(key: _keyIsLoggedIn, value: 'true');
      await _storage.write(key: _keyFingerprintEnabled, value: 'true');
    }
    return ok;
  }

  Future<void> logout() async {
    await _storage.delete(key: _keyIsLoggedIn);
  }

  Future<bool> isLoggedIn() async {
    final String? val = await _storage.read(key: _keyIsLoggedIn);
    return val == 'true';
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: _keyUsername);
  }

  // ============ FINGERPRINT ============

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFingerprintEnabled() async {
    final String? val =
        await _storage.read(key: _keyFingerprintEnabled);
    return val == 'true';
  }

  Future<bool> loginWithFingerprint() async {
    try {
      final bool available = await isBiometricAvailable();
      if (!available) return false;
      final bool enabled = await isFingerprintEnabled();
      if (!enabled) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Gunakan sidik jari untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Verifikasi biometrik untuk membuka data sensitif (unhide NOP/NIK)
  Future<bool> verifyForUnhide() async {
    try {
      final bool available = await isBiometricAvailable();
      if (!available) return true; // fallback: izinkan jika device tidak support

      return await _localAuth.authenticate(
        localizedReason: 'Verifikasi untuk melihat data sensitif',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
