import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import '../../constants/app_colors.dart';
import '../../database/database_helper.dart';
import '../../models/warga_model.dart';

// ─── Model sementara hasil parse ─────────────────────────────────────────────
class _WargaImportItem {
  String noKK;
  String nama;
  String? nik;
  String tanggalLahir;
  String jenisKelamin;
  String rt;
  String rw;
  String? pendidikan;
  String? pekerjaan;
  bool dipilih;
  bool isUpdate;
  int? existingId;
  String? errorMsg;

  _WargaImportItem({
    required this.noKK,
    required this.nama,
    this.nik,
    required this.tanggalLahir,
    required this.jenisKelamin,
    required this.rt,
    required this.rw,
    this.pendidikan,
    this.pekerjaan,
    this.dipilih = true,
    this.isUpdate = false,
    this.existingId,
    this.errorMsg,
  });
}

// ─── Halaman Import ───────────────────────────────────────────────────────────
class ImportWargaPage extends StatefulWidget {
  const ImportWargaPage({super.key});
  @override
  State<ImportWargaPage> createState() => _ImportWargaPageState();
}

class _ImportWargaPageState extends State<ImportWargaPage> {
  final DatabaseHelper _db = DatabaseHelper();
  bool _isProcessing = false;
  bool _isDone = false;
  String _statusText = '';
  String? _namaFile;
  List<_WargaImportItem> _items = [];
  Map<String, int> _importResult = {};

  String _cellStr(dynamic val) {
    if (val == null) return '';
    if (val is String) return val.trim();
    return val.toString().trim();
  }

  /// Mendukung: DD/MM/YYYY, D/M/YYYY, YYYY-MM-DD, DD-MM-YYYY, serial Excel
  String? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is int || raw is double) {
      try {
        final int serial = raw is int ? raw : (raw as double).toInt();
        final DateTime base = DateTime(1899, 12, 30);
        final DateTime date = base.add(Duration(days: serial));
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      } catch (_) {
        return null;
      }
    }
    final String s = raw.toString().trim();
    if (s.isEmpty) return null;

    final regSlash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    final mSlash = regSlash.firstMatch(s);
    if (mSlash != null) {
      return '${mSlash.group(3)}-${mSlash.group(2)!.padLeft(2, '0')}-${mSlash.group(1)!.padLeft(2, '0')}';
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;

    final regDash = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$');
    final mDash = regDash.firstMatch(s);
    if (mDash != null) {
      return '${mDash.group(3)}-${mDash.group(2)!.padLeft(2, '0')}-${mDash.group(1)!.padLeft(2, '0')}';
    }
    return null;
  }

  /// L / LAKI → 'Laki-laki' | P / PEREMPUAN → 'Perempuan'
  String? _parseJK(String raw) {
    final s = raw.trim().toUpperCase();
    if (s == 'L' || s.startsWith('LAKI')) return 'Laki-laki';
    if (s == 'P' || s.startsWith('PEREM')) return 'Perempuan';
    return null;
  }

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
      List<_WargaImportItem> parsed;
      if (ext == 'xlsx' || ext == 'xls') {
        parsed = _parseExcel(file.bytes!);
      } else if (ext == 'csv') {
        parsed = _parseCsv(String.fromCharCodes(file.bytes!));
      } else {
        throw Exception('Format tidak didukung');
      }

      // Cek duplikat di DB
      final allWarga = await _db.getAllWarga();
      for (final item in parsed) {
        if (item.errorMsg != null) continue;
        WargaModel? match;
        if (item.nik != null && item.nik!.isNotEmpty) {
          try {
            match = allWarga.firstWhere(
              (w) => w.nik != null && w.nik!.trim() == item.nik!.trim());
          } catch (_) {}
        }
        match ??= () {
          try {
            return allWarga.firstWhere((w) =>
                w.noKK == item.noKK &&
                w.nama.trim().toUpperCase() == item.nama.trim().toUpperCase());
          } catch (_) {
            return null;
          }
        }();
        if (match != null) {
          item.isUpdate = true;
          item.existingId = match.id;
        }
      }

      setState(() {
        _items = parsed;
        _isProcessing = false;
        _statusText = parsed.isEmpty
            ? 'Tidak ada data yang bisa dibaca. Pastikan format kolom sesuai template.'
            : '${parsed.length} baris berhasil dibaca.';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Gagal membaca file: $e';
      });
    }
  }

  Map<String, int> _detectColumns(List<String> headers) {
    final Map<String, int> idx = {};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toUpperCase().replaceAll(' ', '_');
      if (h.contains('NO_KK') || h == 'KK' || h.contains('NO.KK')) idx['no_kk'] = i;
      if (h == 'NAMA' || h.contains('NAMA_LENGKAP')) idx['nama'] = i;
      if (h.contains('NIK')) idx['nik'] = i;
      if (h.contains('TANGGAL') || h.contains('TGL') || h.contains('LAHIR')) idx['tanggal_lahir'] = i;
      if (h.contains('JENIS') || h.contains('KELAMIN') || h == 'JK' || h == 'L/P' || h == 'L_P') idx['jenis_kelamin'] = i;
      if (h == 'RT') idx['rt'] = i;
      if (h == 'RW') idx['rw'] = i;
      if (h.contains('PENDIDIKAN')) idx['pendidikan'] = i;
      if (h.contains('PEKERJAAN') || h.contains('KERJA')) idx['pekerjaan'] = i;
    }
    return idx;
  }

  _WargaImportItem _buildItem(List<String> cols, Map<String, int> idx, {dynamic rawTgl}) {
    String get(String key) {
      final i = idx[key];
      if (i == null || i >= cols.length) return '';
      return cols[i].trim();
    }

    final noKK = get('no_kk').replaceAll(RegExp(r'[^0-9]'), '');
    final nama = get('nama').toUpperCase();
    final nik = get('nik').replaceAll(RegExp(r'[^0-9]'), '');
    final tglRaw = rawTgl ?? get('tanggal_lahir');
    final jkRaw = get('jenis_kelamin');
    final rt = get('rt').replaceAll(RegExp(r'[^0-9]'), '').padLeft(2, '0');
    final rw = get('rw').replaceAll(RegExp(r'[^0-9]'), '').padLeft(2, '0');
    final pendidikan = get('pendidikan');
    final pekerjaan = get('pekerjaan');

    if (noKK.isEmpty) return _WargaImportItem(
        noKK: noKK, nama: nama, tanggalLahir: '', jenisKelamin: '', rt: rt, rw: rw,
        errorMsg: 'No. KK kosong', dipilih: false);
    if (nama.isEmpty) return _WargaImportItem(
        noKK: noKK, nama: '', tanggalLahir: '', jenisKelamin: '', rt: rt, rw: rw,
        errorMsg: 'Nama kosong', dipilih: false);

    final tgl = _parseDate(tglRaw);
    if (tgl == null) return _WargaImportItem(
        noKK: noKK, nama: nama, tanggalLahir: '', jenisKelamin: '', rt: rt, rw: rw,
        errorMsg: 'Format tanggal tidak dikenali: "${get('tanggal_lahir')}"', dipilih: false);

    final jk = _parseJK(jkRaw);
    if (jk == null) return _WargaImportItem(
        noKK: noKK, nama: nama, tanggalLahir: tgl, jenisKelamin: '', rt: rt, rw: rw,
        errorMsg: 'Jenis kelamin tidak dikenali: "$jkRaw" (gunakan L atau P)', dipilih: false);

    if (rt.replaceAll('0', '').isEmpty || rw.replaceAll('0', '').isEmpty) return _WargaImportItem(
        noKK: noKK, nama: nama, tanggalLahir: tgl, jenisKelamin: jk, rt: rt, rw: rw,
        errorMsg: 'RT/RW kosong', dipilih: false);

    return _WargaImportItem(
      noKK: noKK, nama: nama,
      nik: nik.isEmpty ? null : nik,
      tanggalLahir: tgl, jenisKelamin: jk, rt: rt, rw: rw,
      pendidikan: pendidikan.isEmpty ? null : pendidikan,
      pekerjaan: pekerjaan.isEmpty ? null : pekerjaan,
    );
  }

  List<_WargaImportItem> _parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]!;
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headers = rows[0].map((c) => _cellStr(c?.value)).toList();
    final idx = _detectColumns(headers);
    final tglIdx = idx['tanggal_lahir'];

    final result = <_WargaImportItem>[];
    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      final cols = row.map((c) => _cellStr(c?.value)).toList();
      if (cols.every((c) => c.isEmpty)) continue;
      final rawTgl = (tglIdx != null && tglIdx < row.length) ? row[tglIdx]?.value : null;
      result.add(_buildItem(cols, idx, rawTgl: rawTgl));
    }
    return result;
  }

  List<_WargaImportItem> _parseCsv(String raw) {
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final delimiter = lines[0].contains(';') ? ';' : ',';
    final headers = lines[0].split(delimiter).map((h) => h.replaceAll('"', '').trim()).toList();
    final idx = _detectColumns(headers);
    final result = <_WargaImportItem>[];
    for (int r = 1; r < lines.length; r++) {
      final cols = lines[r].split(delimiter).map((c) => c.replaceAll('"', '').trim()).toList();
      if (cols.every((c) => c.isEmpty)) continue;
      result.add(_buildItem(cols, idx));
    }
    return result;
  }

  Future<void> _importData() async {
    final selected = _items.where((e) => e.dipilih && e.errorMsg == null).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih minimal 1 data yang valid untuk diimport'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    setState(() { _isProcessing = true; _statusText = 'Menyimpan data...'; });
    int inserted = 0, updated = 0;
    for (final item in selected) {
      final map = WargaModel(
        id: item.existingId,
        noKK: item.noKK, nama: item.nama, nik: item.nik,
        tanggalLahir: item.tanggalLahir, jenisKelamin: item.jenisKelamin,
        rt: item.rt, rw: item.rw,
        statusPendidikan: item.pendidikan, pekerjaan: item.pekerjaan,
      ).toMap();
      if (item.isUpdate && item.existingId != null) {
        await _db.updateWarga(item.existingId!, map);
        updated++;
      } else {
        await _db.insertWarga(map);
        inserted++;
      }
    }
    setState(() {
      _isProcessing = false;
      _isDone = true;
      _importResult = {'inserted': inserted, 'updated': updated};
    });
  }

  @override
  Widget build(BuildContext context) {
    final validDipilih = _items.where((e) => e.dipilih && e.errorMsg == null).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Spreadsheet Warga'),
        actions: [
          if (_items.isNotEmpty && !_isDone)
            TextButton(
              onPressed: _isProcessing ? null : _importData,
              child: Text('Import ($validDipilih)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isProcessing ? _buildLoading()
          : _isDone ? _buildHasilImport()
          : _items.isEmpty ? _buildPilihFile()
          : _buildPreview(),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_statusText, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ]));

  Widget _buildPilihFile() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppColors.primarySurface, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Icon(Icons.people_rounded, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Import Data Warga',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Upload file Excel (.xlsx) atau CSV\nsesuai template yang sudah disediakan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryLight)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.table_rows_rounded, size: 15, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Kolom yang dibutuhkan:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ]),
                  const SizedBox(height: 8),
                  _ColInfo(label: 'no_kk', desc: 'Nomor KK (16 digit)', wajib: true),
                  _ColInfo(label: 'nama', desc: 'Nama lengkap', wajib: true),
                  _ColInfo(label: 'tanggal_lahir', desc: 'Format DD/MM/YYYY', wajib: true),
                  _ColInfo(label: 'jenis_kelamin', desc: 'L atau P', wajib: true),
                  _ColInfo(label: 'rt', desc: 'Nomor RT', wajib: true),
                  _ColInfo(label: 'rw', desc: 'Nomor RW', wajib: true),
                  _ColInfo(label: 'nik', desc: 'NIK 16 digit', wajib: false),
                  _ColInfo(label: 'pendidikan', desc: 'Contoh: SMA, SD', wajib: false),
                  _ColInfo(label: 'pekerjaan', desc: 'Contoh: Petani', wajib: false),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: const Text('Pilih File (.xlsx / .csv)',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      );

  Widget _buildPreview() {
    final dipilihCount = _items.where((e) => e.dipilih && e.errorMsg == null).length;
    final errorCount = _items.where((e) => e.errorMsg != null).length;
    final updateCount = _items.where((e) => e.dipilih && e.isUpdate && e.errorMsg == null).length;
    final Map<String, List<_WargaImportItem>> byKK = {};
    for (final item in _items) {
      byKK.putIfAbsent(item.noKK.isEmpty ? '(KK kosong)' : item.noKK, () => []).add(item);
    }
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.primarySurface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📄 $_namaFile',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('${_items.length} baris  •  ${byKK.length} KK',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Dipilih: $dipilihCount',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (updateCount > 0) ...[
              const Text('  •  '),
              Text('Update: $updateCount',
                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ],
            if (errorCount > 0) ...[
              const Text('  •  '),
              Text('Error: $errorCount',
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickFile,
            child: const Text('📂 Ganti file',
                style: TextStyle(fontSize: 12, color: AppColors.primary,
                    decoration: TextDecoration.underline)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: byKK.length,
          itemBuilder: (_, kkIdx) {
            final kkNo = byKK.keys.elementAt(kkIdx);
            final anggota = byKK[kkNo]!;
            final kkRT = anggota.first.rt;
            final kkRW = anggota.first.rw;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: AppColors.cardShadow, blurRadius: 4,
                      offset: const Offset(0, 2))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(children: [
                      const Icon(Icons.home_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('KK: $kkNo',
                                style: const TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('RT $kkRT / RW $kkRW  •  ${anggota.length} anggota',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ])),
                    ]),
                  ),
                  const Divider(height: 1, color: AppColors.primarySurface),
                  ...anggota.map((item) => _buildAnggotaTile(item)),
                ],
              ),
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: dipilihCount == 0 ? null : _importData,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primaryLight,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
            label: Text('Simpan $dipilihCount Data Terpilih',
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildAnggotaTile(_WargaImportItem item) {
    final bool hasError = item.errorMsg != null;
    return CheckboxListTile(
      value: hasError ? false : item.dipilih,
      onChanged: hasError ? null : (v) => setState(() => item.dipilih = v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: AppColors.primary,
      title: Row(children: [
        Expanded(
          child: Text(
            item.nama.isEmpty ? '(Nama kosong)' : item.nama,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: hasError ? Colors.red : AppColors.textPrimary),
          ),
        ),
        if (item.isUpdate && !hasError)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.orange.shade100, borderRadius: BorderRadius.circular(5)),
            child: const Text('UPDATE',
                style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        if (hasError)
          const Icon(Icons.error_rounded, color: Colors.red, size: 18),
      ]),
      subtitle: Text(
        hasError
            ? item.errorMsg!
            : '${item.tanggalLahir}  •  ${item.jenisKelamin}'
                '${item.nik != null ? '  •  NIK: ${item.nik}' : ''}',
        style: TextStyle(
            fontSize: 11, color: hasError ? Colors.red : AppColors.textSecondary),
      ),
    );
  }

  Widget _buildHasilImport() {
    final int ins = _importResult['inserted'] ?? 0;
    final int upd = _importResult['updated'] ?? 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF43A047), size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Import Selesai!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _ResultRow(icon: Icons.person_add_rounded, color: Colors.green,
              label: 'Data baru', value: ins),
          _ResultRow(icon: Icons.update_rounded, color: Colors.orange,
              label: 'Data diperbarui', value: upd),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Kembali ke Data Warga',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _isDone = false; _items = []; _namaFile = null; _statusText = '';
            }),
            child: const Text('Import File Lain',
                style: TextStyle(color: AppColors.primary, fontSize: 14)),
          ),
        ]),
      ),
    );
  }
}

// ──── Widget kecil ────────────────────────────────────────────────────────────
class _ColInfo extends StatelessWidget {
  final String label, desc;
  final bool wajib;
  const _ColInfo({required this.label, required this.desc, required this.wajib});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
                color: wajib ? AppColors.primary : AppColors.primaryLight,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: wajib ? AppColors.textPrimary : AppColors.textSecondary)),
          const SizedBox(width: 6),
          Text('— $desc',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (!wajib)
            const Text(' (opsional)',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      );
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  const _ResultRow({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
          Text('$value data',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}
