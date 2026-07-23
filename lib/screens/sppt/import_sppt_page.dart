import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../constants/app_colors.dart';
import '../../database/database_helper.dart';

/// Model sementara hasil parse spreadsheet sebelum disimpan ke DB
class _ImportItem {
  final String nop;
  final String nomorPetak; // diparsing dari NOP
  final String namaPemilik;
  bool dipilih;
  bool isUpdate;
  String namaLama;

  _ImportItem({
    required this.nop,
    required this.nomorPetak,
    required this.namaPemilik,
    this.dipilih = true,
    this.isUpdate = false,
    this.namaLama = '',
  });
}

class ImportSpptPage extends StatefulWidget {
  final String blokId;
  const ImportSpptPage({super.key, required this.blokId});

  @override
  State<ImportSpptPage> createState() => _ImportSpptPageState();
}

class _ImportSpptPageState extends State<ImportSpptPage> {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isProcessing = false;
  bool _isDone = false;
  String _statusText = '';
  String? _namaFile;
  List<_ImportItem> _items = [];
  Map<String, int> _importResult = {};

  // ─── Parse NOP → nomor petak (segmen ke-6) ───────────────────────────────
  String _parseNomorPetak(String nop) {
    final clean = nop.trim().replaceAll(RegExp(r'\s+'), '');
    final parts = clean.split('.');
    if (parts.length >= 6) {
      return int.tryParse(parts[5])?.toString() ?? parts[5];
    }
    return clean;
  }

  // ─── Normalisasi nilai cell (bisa String, int, double, null) ─────────────
  String _cellStr(dynamic val) {
    if (val == null) return '';
    if (val is String) return val.trim();
    if (val is int || val is double) return val.toString().trim();
    return val.toString().trim();
  }

  // ─── Pilih file & parse ───────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final ext = (file.extension ?? '').toLowerCase();

    setState(() {
      _isProcessing = true;
      _isDone = false;
      _items = [];
      _namaFile = file.name;
      _statusText = 'Membaca file...';
    });

    try {
      List<_ImportItem> parsed = [];

      if (ext == 'xlsx' || ext == 'xls') {
        parsed = await _parseExcel(file.bytes!);
      } else if (ext == 'csv') {
        parsed = _parseCsv(String.fromCharCodes(file.bytes!));
      } else {
        throw Exception('Format file tidak didukung');
      }

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
            item.dipilih = false; // sama persis, skip
          }
        }
      }

      setState(() {
        _items = parsed;
        _isProcessing = false;
        _statusText = parsed.isEmpty
            ? 'Tidak ada data yang berhasil dibaca. Pastikan kolom NOP dan Nama tersedia.'
            : '${parsed.length} data berhasil dibaca dari file.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Gagal membaca file: $e';
      });
    }
  }

  // ─── Parse Excel (.xlsx / .xls) ───────────────────────────────────────────
  Future<List<_ImportItem>> _parseExcel(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final List<_ImportItem> result = [];

    // Ambil sheet pertama
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    final rows = sheet.rows;
    if (rows.isEmpty) return result;

    // Deteksi index kolom NOP dan Nama dari baris header (baris 0)
    int nopIdx = -1, namaIdx = -1;
    final header = rows[0];
    for (int i = 0; i < header.length; i++) {
      final h = _cellStr(header[i]?.value).toUpperCase();
      if (h.contains('NOP') || h.contains('NOMOR OBJEK')) nopIdx = i;
      if (h.contains('NAMA')) namaIdx = i;
    }

    // Fallback: kalau tidak ada header, asumsikan kolom 0=NOP, 1=Nama
    if (nopIdx == -1 && namaIdx == -1) {
      nopIdx = 0;
      namaIdx = 1;
    }
    if (nopIdx == -1) nopIdx = 0;
    if (namaIdx == -1) namaIdx = 1;

    // Parse baris data (skip header)
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.length <= nopIdx || row.length <= namaIdx) continue;

      final nop = _cellStr(row[nopIdx]?.value);
      final nama = _cellStr(row[namaIdx]?.value).toUpperCase();

      if (nop.isEmpty || nama.isEmpty) continue;
      // Validasi pola NOP minimal ada titik
      if (!nop.contains('.')) continue;

      final nomorPetak = _parseNomorPetak(nop);

      result.add(_ImportItem(
        nop: nop.replaceAll(RegExp(r'\s+'), ''),
        nomorPetak: nomorPetak,
        namaPemilik: nama,
      ));
    }

    result.sort((a, b) =>
        (int.tryParse(a.nomorPetak) ?? 0)
            .compareTo(int.tryParse(b.nomorPetak) ?? 0));
    return result;
  }

  // ─── Parse CSV ────────────────────────────────────────────────────────────
  List<_ImportItem> _parseCsv(String raw) {
    final List<_ImportItem> result = [];
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return result;

    // Deteksi delimiter: koma atau titik koma
    final delimiter = lines[0].contains(';') ? ';' : ',';

    // Deteksi header
    int nopIdx = -1, namaIdx = -1;
    final headerCols = lines[0].split(delimiter);
    for (int i = 0; i < headerCols.length; i++) {
      final h = headerCols[i].trim().toUpperCase().replaceAll('"', '');
      if (h.contains('NOP') || h.contains('NOMOR OBJEK')) nopIdx = i;
      if (h.contains('NAMA')) namaIdx = i;
    }
    if (nopIdx == -1 && namaIdx == -1) {
      nopIdx = 0;
      namaIdx = 1;
    }
    if (nopIdx == -1) nopIdx = 0;
    if (namaIdx == -1) namaIdx = 1;

    // Parse baris data
    for (int r = 1; r < lines.length; r++) {
      final cols = lines[r].split(delimiter);
      if (cols.length <= nopIdx || cols.length <= namaIdx) continue;

      final nop = cols[nopIdx].trim().replaceAll('"', '');
      final nama = cols[namaIdx].trim().replaceAll('"', '').toUpperCase();

      if (nop.isEmpty || nama.isEmpty) continue;
      if (!nop.contains('.')) continue;

      final nomorPetak = _parseNomorPetak(nop);
      result.add(_ImportItem(
        nop: nop.replaceAll(RegExp(r'\s+'), ''),
        nomorPetak: nomorPetak,
        namaPemilik: nama,
      ));
    }

    result.sort((a, b) =>
        (int.tryParse(a.nomorPetak) ?? 0)
            .compareTo(int.tryParse(b.nomorPetak) ?? 0));
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

    final result = await _db.importScanSPPT(selected, widget.blokId);

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
        title: Text('Import Spreadsheet — Blok ${widget.blokId}'),
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
                  ? _buildPilihFile()
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

  Widget _buildPilihFile() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Icon(Icons.table_chart_rounded,
                  size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Import Spreadsheet — Blok ${widget.blokId}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload file Excel (.xlsx) atau CSV (.csv) dari pak dukuh.\nSistem otomatis baca kolom NOP dan Nama.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              // Format info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primaryLight, width: 1)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 15, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('Format yang didukung:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ]),
                      const SizedBox(height: 8),
                      _FormatItem(
                          icon: Icons.grid_on_rounded,
                          text: '.xlsx / .xls — Excel / Google Sheets'),
                      _FormatItem(
                          icon: Icons.text_snippet_rounded,
                          text: '.csv — Comma Separated Values'),
                      const SizedBox(height: 8),
                      const Text(
                        'Kolom wajib: NOP dan Nama\n(nama kolom tidak case-sensitive, urutan bebas)',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
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
              onPressed: _pickFile,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: const Text('Pilih File (.xlsx / .csv)',
                  style: TextStyle(
                      color: Colors.white,
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
          Text('📄 $_namaFile',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('${_items.length} data berhasil dibaca',
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
          GestureDetector(
            onTap: _pickFile,
            child: const Text('📂 Ganti file',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    decoration: TextDecoration.underline)),
          ),
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
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
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
                    _namaFile = null;
                    _statusText = '';
                  });
                },
                child: const Text('Import File Lain',
                    style:
                        TextStyle(color: AppColors.primary, fontSize: 14)),
              ),
            ]),
      ),
    );
  }
}

// ──── Widget kecil ────────────────────────────────────────────────────────────

class _FormatItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FormatItem({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.primary),
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
