import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
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
    _nomorPetakCtrl =
        TextEditingController(text: widget.sppt?.nomorPetak ?? '');
    _nopCtrl = TextEditingController(text: widget.sppt?.nop ?? '');
    _namaPemilikCtrl =
        TextEditingController(text: widget.sppt?.namaPemilik ?? '');
  }

  @override
  void dispose() {
    _nomorPetakCtrl.dispose();
    _nopCtrl.dispose();
    _namaPemilikCtrl.dispose();
    super.dispose();
  }

  Widget _lbl(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

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
        title: Text(
            isEdit ? 'Edit Data SPPT' : 'Tambah SPPT — Blok ${widget.blokId}'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Simpan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryLight,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Edit data petak ${widget.sppt?.nomorPetak} — Blok ${widget.blokId}'
                            : 'Data ini akan muncul di legenda peta dan tabel SPPT Blok ${widget.blokId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _lbl('Nomor Petak'),
              const SizedBox(height: 6),
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
              _lbl('Nama Pemilik'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _namaPemilikCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nama pemilik bidang tanah',
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Nama pemilik wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),
              _lbl('NOP (Opsional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nopCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Nomor Objek Pajak - boleh dikosongkan',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    isEdit ? 'Simpan Perubahan' : 'Simpan Data',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
