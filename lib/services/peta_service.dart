import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class PetaService {
  static final PetaService _instance = PetaService._internal();
  factory PetaService() => _instance;
  PetaService._internal();

  static const String _keyPetaPath = 'peta_image_path';
  final ImagePicker _picker = ImagePicker();

  Future<String?> getSavedPetaPath() async {
    final prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString(_keyPetaPath);
    if (path != null && File(path).existsSync()) return path;
    return null;
  }

  Future<String?> pickAndSavePeta(
      {ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return null;

      final Directory appDir = await getApplicationDocumentsDirectory();

      // Hapus file lama supaya tidak menumpuk
      final prefs = await SharedPreferences.getInstance();
      final String? oldPath = prefs.getString(_keyPetaPath);
      if (oldPath != null) {
        final File oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }

      // Pakai timestamp di nama file supaya path SELALU baru
      // → Flutter Image.file cache otomatis ter-invalidate
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String destPath =
          p.join(appDir.path, 'peta_dusun_$timestamp.jpg');

      await File(picked.path).copy(destPath);
      await prefs.setString(_keyPetaPath, destPath);

      return destPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePeta() async {
    final String? path = await getSavedPetaPath();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPetaPath);
  }
}
