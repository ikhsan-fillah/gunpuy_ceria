import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class PetaService {
  static final PetaService _instance = PetaService._internal();
  factory PetaService() => _instance;
  PetaService._internal();

  /// Key SharedPreferences dibuat per-blok agar tidak saling timpa
  String _keyFor(String blokId) => 'peta_image_path_$blokId';

  final ImagePicker _picker = ImagePicker();

  Future<String?> getSavedPetaPath(String blokId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString(_keyFor(blokId));
    if (path != null && File(path).existsSync()) return path;
    return null;
  }

  Future<String?> pickAndSavePeta(
      {required String blokId,
      ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null) return null;

      final Directory appDir = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();

      // Hapus file lama blok ini supaya tidak menumpuk
      final String? oldPath = prefs.getString(_keyFor(blokId));
      if (oldPath != null) {
        final File oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }

      // Timestamp + blokId di nama file agar unik & cache ter-invalidate
      final String ts = DateTime.now().millisecondsSinceEpoch.toString();
      final String destPath =
          p.join(appDir.path, 'peta_blok_${blokId}_$ts.jpg');

      await File(picked.path).copy(destPath);
      await prefs.setString(_keyFor(blokId), destPath);

      return destPath;
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePeta(String blokId) async {
    final String? path = await getSavedPetaPath(blokId);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(blokId));
  }
}
