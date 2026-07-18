import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../services/auth_service.dart';
import '../main_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  bool _isLoading = false;
  bool _obscure = true;
  bool _showFingerprint = false;

  @override
  void initState() {
    super.initState();
    _checkFingerprint();
  }

  Future<void> _checkFingerprint() async {
    final bool available = await _auth.isBiometricAvailable();
    final bool enabled   = await _auth.isFingerprintEnabled();
    if (mounted) setState(() => _showFingerprint = available && enabled);
  }

  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final bool ok = await _auth.login(
      _userCtrl.text.trim(),
      _passCtrl.text,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username atau password salah'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loginWithFingerprint() async {
    final bool ok = await _auth.loginWithFingerprint();
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                // Logo / ikon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    AppStrings.appName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Pendataan Dusun Gunung Puyuh',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Field username
                const Text('Username',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                      hintText: 'Masukkan username'),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Username wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),

                // Field password
                const Text('Password',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'Masukkan password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Password wajib diisi'
                      : null,
                ),
                const SizedBox(height: 28),

                // Tombol login
                ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithPassword,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Masuk',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                ),

                // Tombol fingerprint
                if (_showFingerprint) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: _loginWithFingerprint,
                      icon: const Icon(Icons.fingerprint_rounded,
                          color: AppColors.primary, size: 28),
                      label: const Text(
                        'Masuk dengan Sidik Jari',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
