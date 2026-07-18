import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../database/database_helper.dart';
import '../../../models/warga_model.dart';

class FormWargaPage extends StatefulWidget {
  final WargaModel? warga;
  final String? defaultNoKK;
  const FormWargaPage({super.key, this.warga, this.defaultNoKK});
  @override
  State<FormWargaPage> createState() => _FormWargaPageState();
}

class _FormWargaPageState extends State<FormWargaPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();
  late TextEditingController _noKKCtrl, _namaCtrl, _nikCtrl, _tglLahirCtrl, _rtCtrl, _rwCtrl, _pendidikanCtrl, _pekerjaanCtrl;
  String _jenisKelamin = 'Laki-laki';
  bool _isSaving = false;
  bool get isEdit => widget.warga != null;

  @override
  void initState() {
    super.initState();
    final w = widget.warga;
    _noKKCtrl      = TextEditingController(text: w?.noKK ?? widget.defaultNoKK ?? '');
    _namaCtrl      = TextEditingController(text: w?.nama ?? '');
    _nikCtrl       = TextEditingController(text: w?.nik ?? '');
    _tglLahirCtrl  = TextEditingController(text: w?.tanggalLahir ?? '');
    _rtCtrl        = TextEditingController(text: w?.rt ?? '');
    _rwCtrl        = TextEditingController(text: w?.rw ?? '');
    _pendidikanCtrl = TextEditingController(text: w?.statusPendidikan ?? '');
    _pekerjaanCtrl  = TextEditingController(text: w?.pekerjaan ?? '');
    if (w != null) _jenisKelamin = w.jenisKelamin;
  }

  @override
  void dispose() {
    for (var c in [_noKKCtrl, _namaCtrl, _nikCtrl, _tglLahirCtrl, _rtCtrl, _rwCtrl, _pendidikanCtrl, _pekerjaanCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tglLahirCtrl.text.isNotEmpty ? DateTime.tryParse(_tglLahirCtrl.text) ?? DateTime(2000) : DateTime(2000),
      firstDate: DateTime(1900), lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
    );
    if (picked != null) setState(() => _tglLahirCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final data = WargaModel(
      id: widget.warga?.id, noKK: _noKKCtrl.text.trim(), nama: _namaCtrl.text.trim(),
      nik: _nikCtrl.text.trim().isEmpty ? null : _nikCtrl.text.trim(),
      tanggalLahir: _tglLahirCtrl.text.trim(), jenisKelamin: _jenisKelamin,
      rt: _rtCtrl.text.trim(), rw: _rwCtrl.text.trim(),
      statusPendidikan: _pendidikanCtrl.text.trim().isEmpty ? null : _pendidikanCtrl.text.trim(),
      pekerjaan: _pekerjaanCtrl.text.trim().isEmpty ? null : _pekerjaanCtrl.text.trim(),
    );
    if (isEdit) {
      await _db.updateWarga(widget.warga!.id!, data.toMap());
    } else {
      await _db.insertWarga(data.toMap());
    }
    if (mounted) { setState(() => _isSaving = false); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Data Warga' : 'Tambah Data Warga')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sec('Data Keluarga'),
            _field(_noKKCtrl, AppStrings.labelNoKK, 'Contoh: 3401234567890001', true, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _sec('Data Pribadi'),
            _field(_namaCtrl, AppStrings.labelNama, 'Nama lengkap sesuai KTP', true),
            const SizedBox(height: 12),
            _field(_nikCtrl, '${AppStrings.labelNIK} (Opsional)', 'NIK 16 digit', false, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            Text(AppStrings.labelTanggalLahir, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _tglLahirCtrl, readOnly: true, onTap: _pickDate,
              decoration: const InputDecoration(hintText: 'Pilih tanggal lahir', suffixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary)),
              validator: (v) => (v == null || v.isEmpty) ? 'Tanggal lahir wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Text(AppStrings.labelJenisKelamin, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _RadioOption(label: 'Laki-laki', value: 'Laki-laki', groupValue: _jenisKelamin, onChanged: (v) => setState(() => _jenisKelamin = v!))),
              Expanded(child: _RadioOption(label: 'Perempuan', value: 'Perempuan', groupValue: _jenisKelamin, onChanged: (v) => setState(() => _jenisKelamin = v!))),
            ]),
            const SizedBox(height: 12),
            _sec('Alamat'),
            Row(children: [
              Expanded(child: _field(_rtCtrl, 'RT', 'Contoh: 01', true, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field(_rwCtrl, 'RW', 'Contoh: 01', true, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            _sec('Data Tambahan (Opsional)'),
            _field(_pendidikanCtrl, AppStrings.labelPendidikan, 'Contoh: S1, SMA, SD', false),
            const SizedBox(height: 12),
            _field(_pekerjaanCtrl, AppStrings.labelPekerjaan, 'Contoh: Petani, PNS', false),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Data', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryLight, letterSpacing: 0.5)));

  Widget _field(TextEditingController ctrl, String label, String hint, bool required, {TextInputType keyboardType = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl, keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hint),
        validator: required ? (v) => (v == null || v.isEmpty) ? '$label wajib diisi' : null : null,
      ),
    ]);
  }
}

class _RadioOption extends StatelessWidget {
  final String label, value, groupValue;
  final ValueChanged<String?> onChanged;
  const _RadioOption({required this.label, required this.value, required this.groupValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: groupValue == value ? AppColors.primarySurface : Colors.white,
          border: Border.all(color: groupValue == value ? AppColors.primary : AppColors.primaryLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Radio<String>(value: value, groupValue: groupValue, onChanged: onChanged, activeColor: AppColors.primary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          Text(label, style: TextStyle(fontSize: 13,
              color: groupValue == value ? AppColors.primary : AppColors.textSecondary,
              fontWeight: groupValue == value ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }
}
