import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../database/database_helper.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyIsLoggedIn = 'is_logged_in';

  // ============ LOGIN ============

  Future<bool> login(String username, String password) async {
    final bool ok = await DatabaseHelper().login(username, password);
    if (ok) {
      await _storage.write(key: _keyIsLoggedIn, value: 'true');
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

  // ============ BIOMETRIK ============

  /// Cek apakah device mendukung biometrik (fingerprint / face ID)
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Login menggunakan biometrik (fingerprint / face ID)
  Future<bool> loginWithFingerprint() async {
    try {
      if (!await isBiometricAvailable()) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Gunakan sidik jari untuk masuk ke Gunpuy Ceria',
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
  /// Jika device tidak support, langsung izinkan (fallback)
  Future<bool> verifyForUnhide() async {
    try {
      if (!await isBiometricAvailable()) return true;
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
