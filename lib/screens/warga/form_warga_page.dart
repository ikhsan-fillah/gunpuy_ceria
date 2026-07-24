import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../database/database_helper.dart';
import '../../../models/warga_model.dart';

/// FormWargaPage dipakai untuk 3 skenario:
/// 1. Buat KK baru (warga=null, defaultNoKK=null) → tampilkan No.KK + RT/RW
/// 2. Tambah anggota ke KK yang ada (warga=null, defaultNoKK=xxx) → RT/RW auto-fill, hidden
/// 3. Edit anggota (warga!=null) → RT/RW readonly (diubah via Edit RT/RW di header KK)
class FormWargaPage extends StatefulWidget {
  final WargaModel? warga;
  final String? defaultNoKK;
  final String? defaultRt;
  final String? defaultRw;
  const FormWargaPage({
    super.key,
    this.warga,
    this.defaultNoKK,
    this.defaultRt,
    this.defaultRw,
  });
  @override
  State<FormWargaPage> createState() => _FormWargaPageState();
}

class _FormWargaPageState extends State<FormWargaPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();
  late TextEditingController _noKKCtrl, _namaCtrl, _nikCtrl,
      _tglLahirCtrl, _rtCtrl, _rwCtrl, _pendidikanCtrl, _pekerjaanCtrl;
  String _jenisKelamin = 'Laki-laki';
  bool _isSaving = false;

  bool get isEdit => widget.warga != null;
  /// KK baru = tidak ada defaultNoKK dan tidak sedang edit
  bool get isKKBaru => widget.defaultNoKK == null && !isEdit;
  /// Tambah anggota ke KK yang sudah ada
  bool get isTambahAnggota => widget.defaultNoKK != null && !isEdit;

  @override
  void initState() {
    super.initState();
    final w = widget.warga;
    _noKKCtrl       = TextEditingController(text: w?.noKK ?? widget.defaultNoKK ?? '');
    _namaCtrl       = TextEditingController(text: w?.nama ?? '');
    _nikCtrl        = TextEditingController(text: w?.nik ?? '');
    _tglLahirCtrl   = TextEditingController(text: w?.tanggalLahir ?? '');
    _rtCtrl         = TextEditingController(text: w?.rt ?? widget.defaultRt ?? '');
    _rwCtrl         = TextEditingController(text: w?.rw ?? widget.defaultRw ?? '');
    _pendidikanCtrl = TextEditingController(text: w?.statusPendidikan ?? '');
    _pekerjaanCtrl  = TextEditingController(text: w?.pekerjaan ?? '');
    if (w != null) _jenisKelamin = w.jenisKelamin;
  }

  @override
  void dispose() {
    for (var c in [_noKKCtrl, _namaCtrl, _nikCtrl, _tglLahirCtrl,
        _rtCtrl, _rwCtrl, _pendidikanCtrl, _pekerjaanCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tglLahirCtrl.text.isNotEmpty
          ? DateTime.tryParse(_tglLahirCtrl.text) ?? DateTime(2000)
          : DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary)),
          child: child!),
    );
    if (picked != null)
      setState(() => _tglLahirCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final data = WargaModel(
      id: widget.warga?.id,
      noKK: _noKKCtrl.text.trim(),
      nama: _namaCtrl.text.trim(),
      nik: _nikCtrl.text.trim().isEmpty ? null : _nikCtrl.text.trim(),
      tanggalLahir: _tglLahirCtrl.text.trim(),
      jenisKelamin: _jenisKelamin,
      rt: _rtCtrl.text.trim(),
      rw: _rwCtrl.text.trim(),
      statusPendidikan: _pendidikanCtrl.text.trim().isEmpty
          ? null
          : _pendidikanCtrl.text.trim(),
      pekerjaan: _pekerjaanCtrl.text.trim().isEmpty
          ? null
          : _pekerjaanCtrl.text.trim(),
    );
    if (isEdit) {
      await _db.updateWarga(widget.warga!.id!, data.toMap());
    } else {
      await _db.insertWarga(data.toMap());
    }
    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title;
    if (isEdit) {
      title = 'Edit Data Warga';
    } else if (isKKBaru) {
      title = 'Tambah KK Baru';
    } else {
      title = 'Tambah Anggota KK';
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── No. KK ──────────────────────────────────────────────────────
            _sec('Data Keluarga'),
            _field(_noKKCtrl, AppStrings.labelNoKK,
                'Contoh: 3401234567890001', true,
                keyboardType: TextInputType.number,
                readOnly: isTambahAnggota || isEdit),

            // ── RT / RW — hanya tampil saat KK baru atau edit ───────────────
            if (isKKBaru || isEdit) ...[
              const SizedBox(height: 12),
              _sec('Alamat KK'),
              // Info kecil
              if (isKKBaru)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'RT/RW berlaku untuk seluruh anggota KK ini. Bisa diubah di halaman detail KK.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ]),
                ),
              Row(children: [
                Expanded(
                    child: _field(_rtCtrl, 'RT', 'Contoh: 01', true,
                        keyboardType: TextInputType.number,
                        readOnly: isEdit)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field(_rwCtrl, 'RW', 'Contoh: 01', true,
                        keyboardType: TextInputType.number,
                        readOnly: isEdit)),
              ]),
              if (isEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Untuk mengubah RT/RW, gunakan tombol "Edit RT/RW" di halaman KK.',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
            ],

            // ── Data Pribadi ─────────────────────────────────────────────────
            const SizedBox(height: 12),
            _sec('Data Pribadi'),
            _field(_namaCtrl, AppStrings.labelNama,
                'Nama lengkap sesuai KTP', true),
            const SizedBox(height: 12),
            _field(_nikCtrl, '${AppStrings.labelNIK} (Opsional)',
                'NIK 16 digit', false,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),

            Text(AppStrings.labelTanggalLahir,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tglLahirCtrl,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                  hintText: 'Pilih tanggal lahir',
                  suffixIcon: Icon(Icons.calendar_today_rounded,
                      color: AppColors.textSecondary)),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Tanggal lahir wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            Text(AppStrings.labelJenisKelamin,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                  child: _RadioOption(
                      label: 'Laki-laki',
                      value: 'Laki-laki',
                      groupValue: _jenisKelamin,
                      onChanged: (v) =>
                          setState(() => _jenisKelamin = v!))),
              Expanded(
                  child: _RadioOption(
                      label: 'Perempuan',
                      value: 'Perempuan',
                      groupValue: _jenisKelamin,
                      onChanged: (v) =>
                          setState(() => _jenisKelamin = v!))),
            ]),

            // ── Data Tambahan ────────────────────────────────────────────────
            const SizedBox(height: 12),
            _sec('Data Tambahan (Opsional)'),
            _field(_pendidikanCtrl, AppStrings.labelPendidikan,
                'Contoh: S1, SMA, SD', false),
            const SizedBox(height: 12),
            _field(_pekerjaanCtrl, AppStrings.labelPekerjaan,
                'Contoh: Petani, PNS', false),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        isEdit
                            ? 'Simpan Perubahan'
                            : isKKBaru
                                ? 'Buat KK & Tambah Anggota Pertama'
                                : 'Tambah Anggota',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(t,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryLight,
              letterSpacing: 0.5)));

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    bool required, {
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hint,
          filled: readOnly,
          fillColor: readOnly ? AppColors.primarySurface : null,
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? '$label wajib diisi' : null
            : null,
      ),
    ]);
  }
}

class _RadioOption extends StatelessWidget {
  final String label, value, groupValue;
  final ValueChanged<String?> onChanged;
  const _RadioOption(
      {required this.label,
      required this.value,
      required this.groupValue,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: groupValue == value
              ? AppColors.primarySurface
              : Colors.white,
          border: Border.all(
              color: groupValue == value
                  ? AppColors.primary
                  : AppColors.primaryLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: groupValue == value
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: groupValue == value
                      ? FontWeight.w600
                      : FontWeight.normal)),
        ]),
      ),
    );
  }
}
