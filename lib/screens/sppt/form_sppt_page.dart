import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../database/database_helper.dart';
import '../../../models/sppt_model.dart';

class FormSpptPage extends StatefulWidget {
  final SpptModel? sppt;
  const FormSpptPage({super.key, this.sppt});
  @override
  State<FormSpptPage> createState() => _FormSpptPageState();
}

class _FormSpptPageState extends State<FormSpptPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DatabaseHelper _db = DatabaseHelper();
  late TextEditingController _nomorPetakCtrl, _nopCtrl, _namaPemilikCtrl;
  bool _isSaving = false;
  bool get isEdit => widget.sppt != null;

  @override
  void initState() {
    super.initState();
    _nomorPetakCtrl  = TextEditingController(text: widget.sppt?.nomorPetak ?? '');
    _nopCtrl         = TextEditingController(text: widget.sppt?.nop ?? '');
    _namaPemilikCtrl = TextEditingController(text: widget.sppt?.namaPemilik ?? '');
  }

  @override
  void dispose() { _nomorPetakCtrl.dispose(); _nopCtrl.dispose(); _namaPemilikCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final data = SpptModel(id: widget.sppt?.id, nomorPetak: _nomorPetakCtrl.text.trim(), nop: _nopCtrl.text.trim(), namaPemilik: _namaPemilikCtrl.text.trim());
    try {
      if (isEdit) await _db.updateSPPT(widget.sppt!.id!, data.toMap());
      else await _db.insertSPPT(data.toMap());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nomor petak ${_nomorPetakCtrl.text} sudah digunakan'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _isSaving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Data SPPT' : 'Tambah Data SPPT')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryLight, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  isEdit ? 'Edit data petak ${widget.sppt?.nomorPetak}' : 'Data ini akan muncul di legenda peta dan tabel SPPT',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ]),
            ),
            const SizedBox(height: 20),
            _lbl(AppStrings.labelNomorPetak), const SizedBox(height: 6),
            TextFormField(
              controller: _nomorPetakCtrl, keyboardType: TextInputType.number, readOnly: isEdit,
              decoration: InputDecoration(hintText: 'Contoh: 1, 2, 3...', filled: true, fillColor: isEdit ? AppColors.primarySurface : Colors.white),
              validator: (v) => (v == null || v.isEmpty) ? 'Nomor petak wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _lbl(AppStrings.labelNOP), const SizedBox(height: 6),
            TextFormField(
              controller: _nopCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Nomor Objek Pajak (dari dokumen SPPT)'),
              validator: (v) => (v == null || v.isEmpty) ? 'NOP wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _lbl(AppStrings.labelNamaPemilik), const SizedBox(height: 6),
            TextFormField(
              controller: _namaPemilikCtrl, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nama sesuai dokumen SPPT'),
              validator: (v) => (v == null || v.isEmpty) ? 'Nama pemilik wajib diisi' : null,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Data SPPT', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary));
}
