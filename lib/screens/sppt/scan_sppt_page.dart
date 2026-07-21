import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../constants/app_colors.dart';
import '../../database/database_helper.dart';

/// Model sementara hasil parse OCR sebelum disimpan ke DB
class _ScanItem {
  final String nop;
  final String nomorPetak;
  final String namaPemilik;
  bool dipilih;
  bool isUpdate; // true jika data ini akan mengganti nama lama
  String namaLama;

  _ScanItem({
    required this.nop,
    required this.nomorPetak,
    required this.namaPemilik,
    this.dipilih = true,
    this.isUpdate = false,
    this.namaLama = '',
  });
}

class ScanSpptPage extends StatefulWidget {
  const ScanSpptPage({super.key});
  @override
  State<ScanSpptPage> createState() => _ScanSpptPageState();
}

class _ScanSpptPageState extends State<ScanSpptPage> {
  final DatabaseHelper _db = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool _isDone = false;
  String _statusText = '';
  File? _pickedImage;
  List<_ScanItem> _items = [];
  Map<String, int> _importResult = {};

  // ─── Parse NOP → nomor petak ──────────────────────────────────────────────
  // Format: 34.01.060.002.013.0001.0
  // Digit ke-6 (0001) = nomor urut petak di blok
  String _parseNomorPetak(String nop) {
    // Hapus semua spasi
    final clean = nop.replaceAll(' ', '');
    // Pecah berdasarkan titik
    final parts = clean.split('.');
    // Segment ke-6 (index 5) adalah nomor urut 4 digit → hilangkan leading zero
    if (parts.length >= 6) {
      return int.tryParse(parts[5])?.toString() ?? parts[5];
    }
    return clean;
  }

  // ─── OCR + Parse tabel ────────────────────────────────────────────────────
  Future<void> _scanGambar(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
    );
    if (picked == null) return;

    setState(() {
      _isProcessing = true;
      _isDone = false;
      _items = [];
      _pickedImage = File(picked.path);
      _statusText = 'Membaca teks dari gambar...';
    });

    try {
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final InputImage inputImage = InputImage.fromFilePath(picked.path);
      final RecognizedText recognized =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      setState(() => _statusText = 'Menganalisis data...');

      final List<_ScanItem> parsed = _parseOcrResult(recognized.text);

      // Cek duplikat di DB
      for (final item in parsed) {
        final existing = await _db.getSPPTByNop(item.nop);
        if (existing != null) {
          final namaLama = existing['nama_pemilik'] as String;
          if (namaLama.trim().toUpperCase() !=
              item.namaPemilik.trim().toUpperCase()) {
            item.isUpdate = true;
            item.namaLama = namaLama;
          } else {
            item.dipilih = false; // sama persis → uncheck otomatis
          }
        }
      }

      setState(() {
        _items = parsed;
        _isProcessing = false;
        _statusText = parsed.isEmpty
            ? 'Tidak ada data yang berhasil dibaca. Coba foto ulang dengan lebih jelas.'
            : '${parsed.length} data berhasil dibaca dari gambar.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Gagal membaca gambar: $e';
      });
    }
  }

  // ─── Parser hasil OCR ─────────────────────────────────────────────────────
  // Strategi: cari pola NOP (xx.xx.xxx.xxx.xxx.xxxx.x) lalu ambil
  // token nama di baris / blok yang sama atau berikutnya.
  List<_ScanItem> _parseOcrResult(String rawText) {
    final List<_ScanItem> result = [];

    // Regex NOP: digit.digit.digit.digit.digit.digit.digit
    // Contoh: 34.01.060.002.013.0001.0
    final RegExp nopRegex = RegExp(
      r'\b(\d{2}\.\d{2}\.\d{3}\.\d{3}\.\d{3}\.\d{4}\.\d)\b',
    );

    // Split per baris
    final lines = rawText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = nopRegex.firstMatch(line);
      if (match == null) continue;

      final String nop = match.group(1)!.replaceAll(' ', '');
      final String nomorPetak = _parseNomorPetak(nop);

      // Ambil nama dari baris yang sama (setelah NOP dan tahun)
      // atau baris berikutnya jika tidak ada
      String nama = _extractNama(line, nop) ??
          (i + 1 < lines.length ? _extractNamaFallback(lines[i + 1]) : null) ??
          '';

      nama = nama.trim();
      if (nama.isEmpty) continue;

      // Hindari duplikat NOP
      if (result.any((e) => e.nop == nop)) continue;

      result.add(_ScanItem(
        nop: nop,
        nomorPetak: nomorPetak,
        namaPemilik: nama,
      ));
    }

    // Urutkan berdasarkan nomor petak
    result.sort((a, b) =>
        (int.tryParse(a.nomorPetak) ?? 0)
            .compareTo(int.tryParse(b.nomorPetak) ?? 0));

    return result;
  }

  /// Ekstrak nama dari baris yang sama dengan NOP.
  /// Setelah NOP biasanya ada tahun (4 digit) lalu nama.
  String? _extractNama(String line, String nop) {
    // Hapus NOP dari baris
    String sisa = line.replaceAll(nop, '').trim();
    // Hapus angka nomor urut di awal (misal "1", "12")
    sisa = sisa.replaceAll(RegExp(r'^\d+\s*'), '');
    // Hapus tahun 4 digit (misal 2026)
    sisa = sisa.replaceAll(RegExp(r'\b20\d{2}\b'), '').trim();
    // Hapus karakter aneh
    sisa = sisa.replaceAll(RegExp(r'[|\[\]{}]'), '').trim();

    if (sisa.length >= 3 &&
        sisa.contains(RegExp(r'[A-Za-z]'))) {
      return sisa.toUpperCase();
    }
    return null;
  }

  /// Fallback: ambil nama dari baris berikutnya jika murni teks
  String? _extractNamaFallback(String line) {
    final clean = line
        .replaceAll(RegExp(r'\d'), '')
        .replaceAll(RegExp(r'[^A-Za-z\s]'), '')
        .trim();
    if (clean.length >= 3) return clean.toUpperCase();
    return null;
  }

  // ─── Import ke DB ─────────────────────────────────────────────────────────
  Future<void> _importData() async {
    final selected =
        _items.where((e) => e.dipilih).map((e) => {
          'nop': e.nop,
          'nomor_petak': e.nomorPetak,
          'nama_pemilik': e.namaPemilik,
        }).toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih minimal 1 data untuk diimport'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = 'Menyimpan data...';
    });

    final result = await _db.importScanSPPT(selected);

    setState(() {
      _isProcessing = false;
      _isDone = true;
      _importResult = result;
    });
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Import SPPT'),
        actions: [
          if (_items.isNotEmpty && !_isDone)
            TextButton(
              onPressed: _isProcessing ? null : _importData,
              child: Text(
                'Import (${_items.where((e) => e.dipilih).length})',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isProcessing
          ? _buildLoading()
          : _isDone
              ? _buildHasilImport()
              : _items.isEmpty
                  ? _buildPilihGambar()
                  : _buildPreview(),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusText,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ]),
      );

  Widget _buildPilihGambar() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                    children: [
                      const Icon(Icons.document_scanner_rounded,
                          size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Scan Data SPPT',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Foto atau upload tabel data SPPT dari pemerintah.\nSistem akan membaca NOP dan nama pemilik secara otomatis.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      // Tips foto yang baik
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.primaryLight, width: 1)),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.tips_and_updates_rounded,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('Tips agar hasil scan akurat:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                              ]),
                              SizedBox(height: 8),
                              _TipsItem('Pastikan pencahayaan cukup'),
                              _TipsItem(
                                  'Foto tegak lurus, tidak miring'),
                              _TipsItem(
                                  'Seluruh tabel masuk dalam frame'),
                              _TipsItem(
                                  'Resolusi gambar cukup jelas (tidak blur)'),
                            ]),
                      ),
                    ]),
              ),
              const SizedBox(height: 24),
              if (_statusText.isNotEmpty) ...[
                Text(_statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.red)),
                const SizedBox(height: 16),
              ],
              // Tombol pilih gambar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _scanGambar(ImageSource.gallery),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.photo_library_rounded,
                      color: Colors.white),
                  label: const Text('Pilih dari Galeri',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _scanGambar(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary),
                  label: const Text('Ambil Foto dengan Kamera',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
      );

  Widget _buildPreview() {
    final int dipilihCount = _items.where((e) => e.dipilih).length;
    final int updateCount = _items.where((e) => e.dipilih && e.isUpdate).length;
    final int newCount = dipilihCount - updateCount;

    return Column(children: [
      // Header ringkasan
      Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.primarySurface,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_items.length} data berhasil dibaca dari gambar',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Dipilih: $dipilihCount  •  Baru: $newCount  •  Update: $updateCount',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              // Scan ulang
              Row(children: [
                GestureDetector(
                  onTap: () => _scanGambar(ImageSource.gallery),
                  child: const Text('📁 Scan gambar lain',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline)),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _scanGambar(ImageSource.camera),
                  child: const Text('📷 Foto ulang',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ]),
      ),
      // Daftar item
      Expanded(
          child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _items.length,
        itemBuilder: (_, idx) {
          final item = _items[idx];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: CheckboxListTile(
              value: item.dipilih,
              onChanged: (v) =>
                  setState(() => item.dipilih = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: Row(children: [
                // Badge nomor petak
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    'No. ${item.nomorPetak}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.isUpdate)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('UPDATE',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(item.namaPemilik,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    if (item.isUpdate)
                      Text('Nama lama: ${item.namaLama}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange)),
                    Text(item.nop,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),
            ),
          );
        },
      )),
      // Tombol import
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, -2))
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                dipilihCount == 0 ? null : _importData,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primaryLight,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.cloud_upload_rounded,
                color: Colors.white),
            label: Text(
              'Simpan $dipilihCount Data Terpilih',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildHasilImport() {
    final int ins = _importResult['inserted'] ?? 0;
    final int upd = _importResult['updated'] ?? 0;
    final int skip = _importResult['skipped'] ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF43A047), size: 48),
              ),
              const SizedBox(height: 20),
              const Text('Import Selesai!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _ResultRow(
                  icon: Icons.add_circle_rounded,
                  color: Colors.green,
                  label: 'Data baru',
                  value: ins),
              _ResultRow(
                  icon: Icons.update_rounded,
                  color: Colors.orange,
                  label: 'Data diperbarui',
                  value: upd),
              _ResultRow(
                  icon: Icons.skip_next_rounded,
                  color: Colors.grey,
                  label: 'Dilewati (sama)',
                  value: skip),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize:
                          const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10))),
                  child: const Text('Kembali ke Data SPPT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isDone = false;
                    _items = [];
                    _pickedImage = null;
                    _statusText = '';
                  });
                },
                child: const Text('Scan Gambar Lagi',
                    style: TextStyle(
                        color: AppColors.primary, fontSize: 14)),
              ),
            ]),
      ),
    );
  }
}

// ──── Widget kecil ────────────────────────────────────────────────────────────

class _TipsItem extends StatelessWidget {
  final String text;
  const _TipsItem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  const _ResultRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary))),
          Text('$value data',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ]),
      );
}
