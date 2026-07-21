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
  bool isUpdate;
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
  // Segment ke-6 (index 5) = nomor urut petak
  String _parseNomorPetak(String nop) {
    final clean = nop.replaceAll(' ', '');
    final parts = clean.split('.');
    if (parts.length >= 6) {
      return int.tryParse(parts[5])?.toString() ?? parts[5];
    }
    return clean;
  }

  // ─── OCR ──────────────────────────────────────────────────────────────────
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

      // Cek duplikat di DB — by NOP (bukan nama)
      // 1 orang bisa punya banyak NOP, jadi duplikat = NOP yang sama
      for (final item in parsed) {
        final existing = await _db.getSPPTByNop(item.nop);
        if (existing != null) {
          final namaLama = existing['nama_pemilik'] as String;
          if (namaLama.trim().toUpperCase() !=
              item.namaPemilik.trim().toUpperCase()) {
            // NOP sama, nama berbeda → tandai sebagai update
            item.isUpdate = true;
            item.namaLama = namaLama;
          } else {
            // NOP sama, nama sama → skip (uncheck otomatis)
            item.dipilih = false;
          }
        }
        // NOP belum ada di DB → insert baru (dipilih = true default)
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
  //
  // Masalah OCR tabel:
  // 1. Nama kadang ada di baris yang sama dengan NOP (setelah tahun)
  // 2. Nama kadang terpotong ke baris berikutnya (OCR line-break di tengah nama)
  // 3. Satu orang bisa punya banyak NOP → duplikat by NOP, BUKAN by nama
  //
  // Strategi:
  // - Scan semua baris, cari NOP dengan regex
  // - Untuk setiap NOP, gabungkan teks dari baris yang sama + baris berikutnya
  //   selama baris berikutnya bukan NOP baru dan bukan header tabel
  // - Duplikat: cek by NOP saja
  List<_ScanItem> _parseOcrResult(String rawText) {
    final List<_ScanItem> result = [];

    final RegExp nopRegex = RegExp(
      r'(\d{2}[.\s]\d{2}[.\s]\d{3}[.\s]\d{3}[.\s]\d{3}[.\s]\d{4}[.\s]\d)',
    );

    // Regex header/footer tabel yang harus diabaikan
    final RegExp headerRegex = RegExp(
      r'^(No|NOP|Nama|Tahun|No\.|Blok|\d+\s*$)',
      caseSensitive: false,
    );

    final lines = rawText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final match = nopRegex.firstMatch(line);
      if (match == null) continue;

      // Normalisasi NOP: hapus spasi di antara digit-titik
      final String nopRaw = match.group(1)!;
      final String nop = nopRaw.replaceAll(RegExp(r'\s+'), '');
      final String nomorPetak = _parseNomorPetak(nop);

      // Hindari duplikat NOP dalam hasil scan ini
      if (result.any((e) => e.nop == nop)) continue;

      // ── Ekstrak nama ──────────────────────────────────────────────────────
      // Langkah 1: ambil sisa teks di baris yang sama setelah NOP
      String sisaBaris = line.substring(match.end).trim();
      // Hapus tahun (4 digit, misal 2026) di awal sisa
      sisaBaris = sisaBaris.replaceAll(RegExp(r'^\s*20\d{2}\s*'), '').trim();
      // Hapus karakter non-huruf di awal (misal nomor urut, pipe, bracket)
      sisaBaris = sisaBaris.replaceAll(RegExp(r'^[\d|\[\]{}\s]+'), '').trim();

      String nama = sisaBaris;

      // Langkah 2: jika nama di baris ini kosong atau sangat pendek,
      // lihat ke baris-baris berikutnya (selama bukan NOP baru / header)
      if (_isNamaTerlalupendek(nama)) {
        final StringBuffer buf = StringBuffer(nama);
        for (int j = i + 1; j <= i + 3 && j < lines.length; j++) {
          final nextLine = lines[j].trim();
          // Hentikan jika baris berikutnya adalah NOP baru
          if (nopRegex.hasMatch(nextLine)) break;
          // Hentikan jika baris berikutnya adalah header tabel
          if (headerRegex.hasMatch(nextLine)) break;
          // Hentikan jika baris berikutnya hanya angka (nomor urut)
          if (RegExp(r'^\d+$').hasMatch(nextLine)) break;

          final String kandidat = _bersihkanBaris(nextLine);
          if (kandidat.isNotEmpty) {
            buf.write(buf.isEmpty ? '' : ' ');
            buf.write(kandidat);
            // Jika sudah cukup panjang, berhenti
            if (buf.length >= 4) break;
          }
        }
        nama = buf.toString().trim();
      }

      // Langkah 3: jika nama masih terpotong (OCR pisah nama di 2 baris
      // tapi baris berikutnya ada lanjutan teks tanpa NOP baru)
      // → coba gabung sampai ketemu NOP berikutnya
      if (!_isNamaTerlalupendek(nama)) {
        // Nama sudah OK, tapi cek apakah baris berikutnya adalah
        // lanjutan nama (tidak ada angka, tidak ada NOP)
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1].trim();
          if (!nopRegex.hasMatch(nextLine) &&
              !headerRegex.hasMatch(nextLine) &&
              !RegExp(r'^\d+$').hasMatch(nextLine)) {
            final String lanjutan = _bersihkanBaris(nextLine);
            // Gabung hanya jika lanjutan adalah huruf saja (bukan angka)
            if (lanjutan.isNotEmpty &&
                lanjutan.contains(RegExp(r'[A-Za-z]')) &&
                !lanjutan.contains(RegExp(r'\d'))) {
              // Cek: apakah seperti sambungan nama (tidak ada titik / kata kunci)
              final bool bukan_header = !RegExp(
                r'(nop|nama|tahun|blok|no\.)',
                caseSensitive: false,
              ).hasMatch(lanjutan);
              if (bukan_header) {
                nama = '$nama $lanjutan'.trim();
              }
            }
          }
        }
      }

      // Bersihkan nama akhir
      nama = _normalizeNama(nama);
      if (nama.isEmpty) continue;

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

  bool _isNamaTerlalupendek(String s) => s.trim().length < 3;

  /// Bersihkan baris dari karakter aneh, sisakan huruf dan spasi
  String _bersihkanBaris(String line) {
    return line
        .replaceAll(RegExp(r'[|\[\]{}\\]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Normalisasi nama akhir:
  /// - Hapus angka di awal/akhir
  /// - Hapus karakter selain huruf, spasi, titik, tanda hubung
  /// - Uppercase
  String _normalizeNama(String nama) {
    String result = nama
        .replaceAll(RegExp(r'^[\d\s|.,-]+'), '') // hapus angka di awal
        .replaceAll(RegExp(r'[\d|]+$'), '')      // hapus angka di akhir
        .replaceAll(RegExp(r'[^A-Za-z\s.\-]'), '') // hanya huruf
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    // Abaikan jika hasil adalah header tabel
    if (RegExp(r'^(NOP|NAMA|TAHUN|BLOK|NO)\.?$').hasMatch(result)) return '';
    return result;
  }

  // ─── Import ke DB ─────────────────────────────────────────────────────────
  Future<void> _importData() async {
    final selected = _items
        .where((e) => e.dipilih)
        .map((e) => {
              'nop': e.nop,
              'nomor_petak': e.nomorPetak,
              'nama_pemilik': e.namaPemilik,
            })
        .toList();

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
                child: Column(children: [
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
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
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
                          _TipsItem('Foto tegak lurus, tidak miring'),
                          _TipsItem('Seluruh tabel masuk dalam frame'),
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
                    style: const TextStyle(fontSize: 13, color: Colors.red)),
                const SizedBox(height: 16),
              ],
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
    final int updateCount =
        _items.where((e) => e.dipilih && e.isUpdate).length;
    final int newCount = dipilihCount - updateCount;

    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.primarySurface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      Expanded(
          child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              onChanged: (v) => setState(() => item.dipilih = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                              fontSize: 11, color: Colors.orange)),
                    Text(item.nop,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),
            ),
          );
        },
      )),
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
            onPressed: dipilihCount == 0 ? null : _importData,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primaryLight,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon:
                const Icon(Icons.cloud_upload_rounded, color: Colors.white),
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
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
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
                    style:
                        TextStyle(color: AppColors.primary, fontSize: 14)),
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
