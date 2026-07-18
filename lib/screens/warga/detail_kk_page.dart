import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../database/database_helper.dart';
import '../../../models/warga_model.dart';
import '../../../utils/masking_helper.dart';
import '../../../services/auth_service.dart';
import 'form_warga_page.dart';

class DetailKKPage extends StatefulWidget {
  final String noKK;
  final String namaKepala;
  const DetailKKPage({super.key, required this.noKK, required this.namaKepala});
  @override
  State<DetailKKPage> createState() => _DetailKKPageState();
}

class _DetailKKPageState extends State<DetailKKPage> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _auth = AuthService();
  List<WargaModel> _anggota = [];
  bool _isLoading = true;
  bool _isUnhidden = false;
  Set<int> _expandedIds = {};

  @override
  void initState() { super.initState(); _loadAnggota(); }

  Future<void> _loadAnggota() async {
    final data = await _db.getAnggotaByNoKK(widget.noKK);
    if (mounted) setState(() { _anggota = data.map((m) => WargaModel.fromMap(m)).toList(); _isLoading = false; });
  }

  Future<void> _toggleUnhide() async {
    if (_isUnhidden) { setState(() => _isUnhidden = false); return; }
    final bool ok = await _auth.verifyForUnhide();
    if (ok && mounted) setState(() => _isUnhidden = true);
  }

  String _maskOrShow(String? value) => _isUnhidden ? (value ?? '-') : MaskingHelper.mask(value);

  @override
  Widget build(BuildContext context) {
    final Map<String, int> kategoriCount = {};
    for (var w in _anggota) kategoriCount[w.kategoriUsia] = (kategoriCount[w.kategoriUsia] ?? 0) + 1;
    final String ringkasan = kategoriCount.entries.map((e) => '${e.value} ${e.key}').join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.namaKepala),
        actions: [
          TextButton.icon(
            onPressed: _toggleUnhide,
            icon: Icon(_isUnhidden ? Icons.lock_open_rounded : Icons.lock_rounded, color: Colors.white, size: 18),
            label: Text(_isUnhidden ? AppStrings.btnHide : AppStrings.btnUnhide, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => FormWargaPage(defaultNoKK: widget.noKK)));
          _loadAnggota();
        },
        child: const Icon(Icons.person_add_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('No. KK: ', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(_maskOrShow(widget.noKK),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                              color: _isUnhidden ? AppColors.textPrimary : AppColors.masked,
                              letterSpacing: _isUnhidden ? 0 : 1)),
                    ]),
                    if (_anggota.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('RT ${_anggota.first.rt} / RW ${_anggota.first.rw}  \u2022  ${_anggota.length} anggota',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (ringkasan.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(ringkasan, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ]),
                ),
                const SizedBox(height: 16),
                ..._anggota.map((warga) => _AnggotaAccordion(
                  warga: warga, isUnhidden: _isUnhidden,
                  isExpanded: _expandedIds.contains(warga.id),
                  onToggle: () => setState(() {
                    if (_expandedIds.contains(warga.id)) _expandedIds.remove(warga.id);
                    else _expandedIds.add(warga.id!);
                  }),
                  onEdit: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => FormWargaPage(warga: warga)));
                    _loadAnggota();
                  },
                  onDelete: () async {
                    final bool confirm = await showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Hapus Data'),
                            content: Text('Hapus data ${warga.nama}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                              TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                            ],
                          )) ?? false;
                    if (confirm && warga.id != null) { await _db.deleteWarga(warga.id!); _loadAnggota(); }
                  },
                )),
              ]),
            ),
    );
  }
}

class _AnggotaAccordion extends StatelessWidget {
  final WargaModel warga;
  final bool isUnhidden, isExpanded;
  final VoidCallback onToggle, onEdit, onDelete;
  const _AnggotaAccordion({required this.warga, required this.isUnhidden, required this.isExpanded, required this.onToggle, required this.onEdit, required this.onDelete});

  String _mask(String? v) => isUnhidden ? (v ?? '-') : MaskingHelper.mask(v);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle, borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(warga.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Row(children: [
                  Text('${AppStrings.labelNIK} ', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(_mask(warga.nik), style: TextStyle(fontSize: 11,
                      color: isUnhidden ? AppColors.textPrimary : AppColors.masked,
                      fontWeight: FontWeight.w500, letterSpacing: isUnhidden ? 0 : 1)),
                ]),
              ])),
              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
            ]),
          ),
        ),
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.primarySurface))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              _row('Tanggal Lahir', '${warga.tanggalLahir} (${warga.umur} thn)'),
              _row('Kategori Usia', warga.kategoriUsia),
              _row('Jenis Kelamin', warga.jenisKelamin),
              _row('RT / RW', 'RT ${warga.rt} / RW ${warga.rw}'),
              if (warga.statusPendidikan != null && warga.statusPendidikan!.isNotEmpty) _row('Pendidikan', warga.statusPendidikan!),
              if (warga.pekerjaan != null && warga.pekerjaan!.isNotEmpty) _row('Pekerjaan', warga.pekerjaan!),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Edit', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                  label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
      const Text(': ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
    ]),
  );
}
