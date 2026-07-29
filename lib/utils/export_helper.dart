import 'dart:io';
import 'package:excel/excel.dart';

class ExportHelper {
  // ─── Warga ──────────────────────────────────────────────────────────────────
  /// Simpan ke Downloads, return path file.
  /// Kolom: no_kk, nama, nik, tanggal_lahir, jenis_kelamin, rt, rw, pendidikan, pekerjaan
  static Future<String> exportWarga(List<Map<String, dynamic>> rows) async {
    final excel = Excel.createExcel();
    final sheet = excel['Data Warga'];
    excel.delete('Sheet1');

    _writeHeader(sheet, [
      'no_kk', 'nama', 'nik', 'tanggal_lahir',
      'jenis_kelamin', 'rt', 'rw', 'pendidikan', 'pekerjaan',
    ]);

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      _writeRow(sheet, r + 1, [
        row['no_kk']?.toString() ?? '',
        row['nama']?.toString() ?? '',
        row['nik']?.toString() ?? '',
        _isoToDDMMYYYY(row['tanggal_lahir']?.toString() ?? ''),
        _jkToLP(row['jenis_kelamin']?.toString() ?? ''),
        row['rt']?.toString() ?? '',
        row['rw']?.toString() ?? '',
        row['status_pendidikan']?.toString() ?? '',
        row['pekerjaan']?.toString() ?? '',
      ]);
    }

    sheet.setColumnWidth(0, 20);
    sheet.setColumnWidth(1, 28);
    sheet.setColumnWidth(2, 20);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);

    final now = DateTime.now();
    return _saveToDownloads(
        excel,
        'data_warga_${now.year}${_pad(now.month)}${_pad(now.day)}.xlsx');
  }

  // ─── SPPT ───────────────────────────────────────────────────────────────────
  /// Simpan ke Downloads, return path file.
  /// Kolom: nomor_petak, nop, nama_pemilik
  static Future<String> exportSPPT(
      List<Map<String, dynamic>> rows, String blokLabel) async {
    final excel = Excel.createExcel();
    final sheet = excel['SPPT $blokLabel'];
    excel.delete('Sheet1');

    _writeHeader(sheet, ['nomor_petak', 'nop', 'nama_pemilik']);

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      _writeRow(sheet, r + 1, [
        row['nomor_petak']?.toString() ?? '',
        row['nop']?.toString() ?? '',
        row['nama_pemilik']?.toString() ?? '',
      ]);
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 30);

    final now = DateTime.now();
    final safeName = blokLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return _saveToDownloads(
        excel,
        'sppt_${safeName}_${now.year}${_pad(now.month)}${_pad(now.day)}.xlsx');
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Simpan ke /storage/emulated/0/Download/ (folder Downloads bawaan Android).
  /// Tidak butuh permission WRITE_EXTERNAL_STORAGE di Android 10+ (scoped storage).
  static Future<String> _saveToDownloads(Excel excel, String fileName) async {
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal encode Excel');

    // Folder Downloads publik Android
    const downloadsPath = '/storage/emulated/0/Download';
    final dir = Directory(downloadsPath);
    if (!dir.existsSync()) {
      // Fallback ke external storage root jika path berbeda
      throw Exception('Folder Downloads tidak ditemukan di perangkat ini');
    }

    final file = File('$downloadsPath/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static void _writeHeader(Sheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  static void _writeRow(Sheet sheet, int rowIndex, List<String> values) {
    for (int c = 0; c < values.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex))
          .value = TextCellValue(values[c]);
    }
  }

  /// YYYY-MM-DD → DD/MM/YYYY
  static String _isoToDDMMYYYY(String iso) {
    if (iso.isEmpty) return '';
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  /// 'Laki-laki' → 'L', 'Perempuan' → 'P'
  static String _jkToLP(String jk) {
    if (jk.startsWith('L')) return 'L';
    if (jk.startsWith('P')) return 'P';
    return jk;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
