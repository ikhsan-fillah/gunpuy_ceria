import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';
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

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final List<BiometricType> biometrics =
          await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Login fingerprint — return null jika sukses, String jika error
  Future<String?> loginWithFingerprint() async {
    try {
      if (!await isBiometricAvailable()) {
        return 'Sidik jari tidak tersedia atau belum terdaftar di HP ini';
      }
      final bool ok = await _localAuth.authenticate(
        localizedReason: 'Gunakan sidik jari untuk masuk ke Gunpuy Ceria',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: false,
        ),
      );
      if (ok) {
        await _storage.write(key: _keyIsLoggedIn, value: 'true');
        return null;
      }
      return 'Autentikasi dibatalkan';
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable) {
        return 'Fitur biometrik tidak tersedia di HP ini';
      } else if (e.code == auth_error.notEnrolled) {
        return 'Belum ada sidik jari terdaftar. Daftarkan di Pengaturan > Keamanan';
      } else if (e.code == auth_error.lockedOut) {
        return 'Terlalu banyak percobaan gagal. Coba lagi sebentar';
      } else if (e.code == auth_error.permanentlyLockedOut) {
        return 'Sidik jari dikunci permanen. Gunakan PIN/password HP';
      } else if (e.code == auth_error.passcodeNotSet) {
        return 'Harap aktifkan kunci layar di Pengaturan terlebih dahulu';
      }
      return 'Error: ${e.message}';
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  /// Verifikasi untuk unhide data sensitif
  /// Return: null = sukses, String = pesan error
  Future<String?> verifyForUnhide() async {
    try {
      final bool deviceSupport = await _localAuth.isDeviceSupported();
      if (!deviceSupport) return null; // device lama, langsung izinkan

      final bool ok = await _localAuth.authenticate(
        localizedReason:
            'Verifikasi identitas untuk melihat data sensitif (NIK/NOP)',
        options: const AuthenticationOptions(
          biometricOnly: false, // bisa fallback ke PIN/password HP
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
      if (ok) return null; // sukses
      return 'Verifikasi dibatalkan';
    } on PlatformException catch (e) {
      if (e.code == auth_error.passcodeNotSet) {
        return 'Aktifkan kunci layar di Pengaturan terlebih dahulu';
      } else if (e.code == auth_error.lockedOut) {
        return 'Terlalu banyak percobaan. Coba lagi sebentar';
      } else if (e.code == auth_error.permanentlyLockedOut) {
        return 'Terkunci. Buka HP dengan PIN/password terlebih dahulu';
      }
      return null; // error lain, fallback izinkan
    } catch (_) {
      return null; // fallback
    }
  }
}
