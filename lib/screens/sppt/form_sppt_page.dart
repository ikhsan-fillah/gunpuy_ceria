import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../database/database_helper.dart';
import '../../models/sppt_model.dart';

class FormSpptPage extends StatefulWidget {
  final String blokId;
  final SpptModel? sppt;
  const FormSpptPage({super.key, required this.blokId, this.sppt});
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
  void dispose() {
    _nomorPetakCtrl.dispose();
    _nopCtrl.dispose();
    _namaPemilikCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final data = SpptModel(
      id: widget.sppt?.id,
      blokId: widget.blokId,
      nomorPetak: _nomorPetakCtrl.text.trim(),
      nop: _nopCtrl.text.trim().isEmpty ? null : _nopCtrl.text.trim(),
      namaPemilik: _namaPemilikCtrl.text.trim(),
    );
    try {
      if (isEdit) {
        await _db.updateSPPT(widget.sppt!.id!, data.toMap());
      } else {
        await _db.insertSPPT(data.toMap());
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Nomor petak ${_nomorPetakCtrl.text} sudah digunakan di blok ini'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit
              ? 'Edit Data SPPT'
              : 'Tambah SPPT — Blok ${widget.blokId}')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primaryLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  isEdit
                      ? 'Edit data petak ${widget.sppt?.nomorPetak} — Blok ${widget.blokId}'
                      : 'Data ini akan muncul di legenda peta dan tabel SPPT Blok ${widget.blokId}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                )),
              ]),
            ),
            const SizedBox(height: 20),
            _lbl('Nomor Petak'), const SizedBox(height: 6),
            TextFormField(
              controller: _nomorPetakCtrl,
              keyboardType: TextInputType.number,
              readOnly: isEdit,
              decoration: InputDecoration(
                hintText: 'Nomor sesuai peta (contoh: 1, 13, 70)',
                filled: true,
                fillColor: isEdit ? AppColors.primarySurface : Colors.white,
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Nomor petak wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _lbl('Nama Pemilik'), const SizedBox(height: 6),
            TextFormField(
              controller: _namaPemilikCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  hintText: 'Nama pemilik bidang tanah'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Nama pemilik wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _lbl('NOP (Opsional)'), const SizedBox(height: 6),
            TextFormField(
              controller: _nopCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Nomor Objek Pajak — boleh dikoso