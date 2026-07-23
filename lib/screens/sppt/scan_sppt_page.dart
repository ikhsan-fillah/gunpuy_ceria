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
      for (final item in parsed) {
        final existing = await _db.getSPPTByNop(item.nop);
        if (existing != null) {
          final namaLama = existing['nama_pemilik'] as String;
          if (namaLama.trim().toUpperCase() !=
              item.namaPemilik.trim().toUpperCase()) {
            item.isUpdate = true;
            item.namaLama = namaLama;
          } else {
            item.dipilih = false;
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
  //
  // Pola tabel SPPT:
  //   [No] | [NOP 34.01.060.002.013.XXXX.X] | [Tahun] | [Nama Pemilik] | [Alamat]
  //
  // Masalah umum OCR:
  //   1. Nama pendek (JUNI, KINAH) dianggap kosong oleh threshold lama
  //   2. Nama bergelar (DRS. H. GONDO SUHADYO, M.SI) tersebar di 2 baris
  //   3. Kolom alamat (DK KARA...) ikut terbaca sebagai bagian nama
  //   4. Titik/koma di nama gelar ikut dihapus
  //
  // Strategi baru:
  //   - Setelah NOP + tahun, ambil token hingga terdeteksi pola alamat (DK, KP, JL, dll)
  //   - Jika nama di baris sama kosong, lihat baris berikutnya (max 2 baris)
  //   - Gabung baris lanjutan selama bukan NOP baru / bukan pola alamat
  //   - Threshold nama diturunkan: minimal 2 karakter huruf

  // Pola awalan alamat yang umum di data SPPT Jawa
  static final RegExp _alamatPrefixRegex = RegExp(
    r'\b(DK|RT|RW|KP|KM|JL|JLN|DESA|DUSUN|KEL|KELURAHAN|GG|GANG|BLOK|PERUM|PERENG|GAMPINGAN|SUMUR|TEBING|SECANG|KRADENON|KARANG)\b',
    caseSensitive: false,
  );

  // NOP regex — toleran terhadap spasi di antara segmen
  static final RegExp _nopRegex = RegExp(
    r'(\d{2}[.\s]\d{2}[.\s]\d{3}[.\s]\d{3}[.\s]\d{3}[.\s]\d{4}[.\s]\d)',
  );

  // Pola header/footer tabel
  static final RegExp _headerRegex = RegExp(
    r'^\s*(No\.?|NOP|Nama\s+Pemilik|Tahun|Blok|Total|Ketetapan|PBB)\s*$',
    caseSensitive: false,
  );

  // Pola baris yang hanya angka (nomor urut)
  static final RegExp _nomorUrut = RegExp(r'^\d{1,4}$');

  List<_ScanItem> _parseOcrResult(String rawText) {
    final List<_ScanItem> result = [];
    final lines = rawText.split('\n').map((l) => l.trim()).toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final match = _nopRegex.firstMatch(line);
      if (match == null) continue;

      // Normalisasi NOP
      final String nop =
          match.group(1)!.replaceAll(RegExp(r'\s+'), '');
      final String nomorPetak = _parseNomorPetak(nop);

      // Skip duplikat NOP dalam hasil scan
      if (result.any((e) => e.nop == nop)) continue;

      // ── Step 1: Ambil sisa baris setelah NOP ───────────────────────────
      String sisaBaris = line.substring(match.end).trim();

      // Hapus tahun 4 digit di awal (misal "2026")
      sisaBaris =
          sisaBaris.replaceFirst(RegExp(r'^\s*20\d{2}\s*'), '').trim();

      // Hapus nomor urut / pipe / bracket di awal
      sisaBaris =
          sisaBaris.replaceFirst(RegExp(r'^[\d\s|.\[\]{}]+'), '').trim();

      // Potong di kolom alamat (ambil hanya sebelum pola alamat)
      sisaBaris = _potongSebelumAlamat(sisaBaris);

      String nama = sisaBaris.trim();

      // ── Step 2: Jika nama di baris ini kosong/tidak ada huruf,
      //           lihat baris berikutnya ───────────────────────────────────
      if (!_mengandungHurufCukup(nama)) {
        for (int j = i + 1; j <= i + 2 && j < lines.length; j++) {
          final next = lines[j];
          if (_nopRegex.hasMatch(next)) break;
          if (_headerRegex.hasMatch(next)) break;
          if (_nomorUrut.hasMatch(next)) break;

          final kandidat = _potongSebelumAlamat(next).trim();
          if (_mengandungHurufCukup(kandidat)) {
            nama = kandidat;
            break;
          }
        }
      }

      // ── Step 3: Cek apakah baris berikutnya adalah lanjutan nama
      //           (kasus nama 2 baris: DRS. H. GONDO SUHADYO / M.SI) ──────
      if (_mengandungHurufCukup(nama)) {
        for (int j = i + 1; j <= i + 2 && j < lines.length; j++) {
          final next = lines[j];
          if (_nopRegex.hasMatch(next)) break;
          if (_headerRegex.hasMatch(next)) break;
          if (_nomorUrut.hasMatch(next)) break;

          final lanjutan = _potongSebelumAlamat(next).trim();

          // Lanjutan valid: mengandung huruf, tidak ada angka banyak,
          // dan tidak terlihat seperti baris NOP / header baru
          if (_mengandungHurufCukup(lanjutan) &&
              !lanjutan.contains(RegExp(r'\d{4}')) &&
              !_alamatPrefixRegex.hasMatch(lanjutan)) {
            // Hanya gabung jika lanjutan ini pendek (kemungkinan gelar/suffix)
            // atau nama saat ini masih pendek
            if (lanjutan.split(' ').length <= 4 || nama.split(' ').length <= 2) {
              nama = '$nama $lanjutan'.trim();
              break;
            }
          }
        }
      }

      // ── Step 4: Normalisasi nama akhir ────────────────────────────────
      nama = _normalizeNama(nama);
      if (nama.isEmpty) continue;

      result.add(_ScanItem(
        nop: nop,
        nomorPetak: nomorPetak,
        namaPemilik: nama,
      ));
    }

    result.sort((a, b) =>
        (int.tryParse(a.nomorPetak) ?? 0)
            .compareTo(int.tryParse(b.nomorPetak) ?? 0));

    return result;
  }

  /// Potong string di titik kemunculan pola alamat pertama.
  /// Contoh: "GIMAN DK GUNUNGSARI" → "GIMAN"
  String _potongSebelumAlamat(String s) {
    final m = _alamatPrefixRegex.firstMatch(s);
    if (m == null) return s;
    // Hanya potong jika pola alamat bukan di awal baris
    // (supaya baris yang MEMANG isinya alamat tidak jadi nama kosong)
    if (m.start == 0) return '';
    return s.substring(0, m.start).trim();
  }

  /// Cek apakah string mengandung minimal 2 huruf berurutan
  bool _mengandungHurufCukup(String s) {
    return RegExp(r'[A-Za-z]{2,}').hasMatch(s.trim());
  }

  /// Normalisasi nama akhir:
  /// - Pertahankan titik dan koma (untuk gelar: DRS., H., M.SI)
  /// - Hapus angka di awal/akhir
  /// - Uppercase
  String _normalizeNama(String nama) {
    // Hapus angka di awal (nomor urut yang nyempil)
    String r = nama.replaceFirst(RegExp(r'^[\d\s|]+'), '');
    // Hapus karakter aneh selain huruf, spasi, titik, koma, tanda hubung, apostrof
    r = r.replaceAll(RegExp(r"[^\w\s.,\-']"), '');
    // Hapus angka di akhir
    r = r.replaceAll(RegExp(r'[\d]+$'), '');
    // Normalisasi spasi
    r = r.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
    // Buang jika hasil adalah kata header tabel saja
    if (RegExp(r'^(NOP|NAMA|TAHUN|BLOK|NO|TOTAL|KETETAPAN|PBB)\.?$')
        .hasMatch(r)) return '';
    // Minimal 2 huruf
    if (!RegExp(r'[A-Z]{2}').hasMatch(r)) return '';
    return r;
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
