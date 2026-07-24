import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../database/database_helper.dart';
import '../../models/warga_model.dart';
import '../../utils/masking_helper.dart';
import '../../services/auth_service.dart';
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
  bool _isVerifying = false;
  final Set<int> _expandedIds = {};

  // Controller untuk Edit RT/RW
  final TextEditingController _rtEditCtrl = TextEditingController();
  final TextEditingController _rwEditCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAnggota();
  }

  @override
  void dispose() {
    _rtEditCtrl.dispose();
    _rwEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAnggota() async {
    final data = await _db.getAnggotaByNoKK(widget.noKK);
    if (mounted)
      setState(() {
        _anggota = data.map((m) => WargaModel.fromMap(m)).toList();
        _isLoading = false;
      });
  }

  Future<void> _toggleUnhide() async {
    if (_isUnhidden) {
      setState(() => _isUnhidden = false);
      return;
    }
    await _showVerifikasiSheet();
  }

  Future<void> _showVerifikasiSheet() async {
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _VerifikasiSheet(
        labelData: 'NIK dan No. KK',
        onVerify: () async {
          Navigator.pop(ctx);
          await _doVerify();
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  Future<void> _doVerify() async {
    setState(() => _isVerifying = true);
    final String? error = await _auth.verifyForUnhide();
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (error == null) {
      setState(() => _isUnhidden = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  /// Dialog Edit RT/RW — update semua anggota KK sekaligus
  Future<void> _showEditRTRW() async {
    if (_anggota.isEmpty) return;
    _rtEditCtrl.text = _anggota.first.rt;
    _rwEditCtrl.text = _anggota.first.rw;

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit RT / RW'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Perubahan RT/RW akan berlaku untuk semua ${_anggota.length} anggota KK ini.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _rtEditCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'RT', hintText: '01'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _rwEditCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'RW', hintText: '01'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate())
                  Navigator.pop(ctx, true);
              },
              child: const Text('Simpan')),
        ],
      ),
    );

    if (confirm == true) {
      await _db.updateRTRWByNoKK(
        widget.noKK,
        _rtEditCtrl.text.trim(),
        _rwEditCtrl.text.trim(),
      );
      _loadAnggota();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('RT/RW berhasil diperbarui untuk semua anggota'),
          backgroundColor: Colors.green,
        ));
    }
  }

  String _maskOrShow(String? value) =>
      _isUnhidden ? (value ?? '-') : MaskingHelper.mask(value);

  @override
  Widget build(BuildContext context) {
    final Map<String, int> kategoriCount = {};
    for (var w in _anggota) {
      kategoriCount[w.kategoriUsia] =
          (kategoriCount[w.kategoriUsia] ?? 0) + 1;
    }
    final String ringkasan =
        kategoriCount.entries.map((e) => '${e.value} ${e.key}').join(', ');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.namaKepala),
        actions: [
          // Tombol Edit RT/RW
          if (_anggota.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.location_on_outlined,
                  color: Colors.white, size: 22),
              tooltip: 'Edit RT/RW',
              onPressed: _showEditRTRW,
            ),
          // Tombol Show/Hide NIK
          if (_isVerifying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            TextButton.icon(
              onPressed: _toggleUnhide,
              icon: Icon(
                  _isUnhidden
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  color: Colors.white,
                  size: 18),
              label: Text(
                  _isUnhidden
                      ? AppStrings.btnHide
                      : AppStrings.btnUnhide,
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Tambah Anggota KK',
        onPressed: () async {
          // Kirim RT/RW dari anggota pertama sebagai default
          final String rt = _anggota.isNotEmpty ? _anggota.first.rt : '';
          final String rw = _anggota.isNotEmpty ? _anggota.first.rw : '';
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FormWargaPage(
                        defaultNoKK: widget.noKK,
                        defaultRt: rt,
                        defaultRw: rw,
                      )));
          _loadAnggota();
        },
        child: const Icon(Icons.person_add_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header KK
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('No. KK: ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                              Text(_maskOrShow(widget.noKK),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _isUnhidden
                                          ? AppColors.textPrimary
                                          : AppColors.masked,
                                      letterSpacing:
                                          _isUnhidden ? 0 : 1)),
                            ]),
                            if (_anggota.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              // RT/RW dengan tombol edit
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'RT ${_anggota.first.rt} / RW ${_anggota.first.rw}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _showEditRTRW,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.3)),
                                      ),
                                      child: const Row(children: [
                                        Icon(Icons.edit_rounded,
                                            size: 11,
                                            color: AppColors.primary),
                                        SizedBox(width: 3),
                                        Text('Edit',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_anggota.length} anggota  •  $ringkasan',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ]),
                    ),
                    const SizedBox(height: 16),
                    ..._anggota.map((warga) => _AnggotaAccordion(
                          warga: warga,
                          isUnhidden: _isUnhidden,
                          isExpanded: _expandedIds.contains(warga.id),
                          onToggle: () => setState(() {
                            if (_expandedIds.contains(warga.id)) {
                              _expandedIds.remove(warga.id);
                            } else {
                              _expandedIds.add(warga.id!);
                            }
                          }),
                          onEdit: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        FormWargaPage(warga: warga)));
                            _loadAnggota();
                          },
                          onDelete: () async {
                            final bool confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title:
                                        const Text('Hapus Data'),
                                    content: Text(
                                        'Hapus data ${warga.nama}?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator
                                              .pop(context, false),
                                          child: const Text('Batal')),
                                      TextButton(
                                          onPressed: () => Navigator
                                              .pop(context, true),
                                          child: const Text('Hapus',
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (confirm && warga.id != null) {
                              await _db.deleteWarga(warga.id!);
                              _loadAnggota();
                            }
                          },
                        )),
                  ]),
            ),
    );
  }
}

// ───── Bottom Sheet Verifikasi ─────────────────────────────────────────────
class _VerifikasiSheet extends StatelessWidget {
  final String labelData;
  final VoidCallback onVerify;
  final VoidCallback onCancel;
  const _VerifikasiSheet(
      {required this.labelData,
      required this.onVerify,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
              color: AppColors.primarySurface, shape: BoxShape.circle),
          child: const Icon(Icons.fingerprint_rounded,
              color: AppColors.primary, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Verifikasi Diperlukan',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Gunakan sidik jari atau PIN HP untuk\nmenampilkan $labelData yang tersembunyi',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onVerify,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.fingerprint_rounded,
                color: Colors.white, size: 22),
            label: const Text('Verifikasi Sekarang',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onCancel,
            child: const Text('Batal',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}

// ───── Accordion Anggota ────────────────────────────────────────────────────
class _AnggotaAccordion extends StatelessWidget {
  final WargaModel warga;
  final bool isUnhidden, isExpanded;
  final VoidCallback onToggle, onEdit, onDelete;
  const _AnggotaAccordion(
      {required this.warga,
      required this.isUnhidden,
      required this.isExpanded,
      required this.onToggle,
      required this.onEdit,
      required this.onDelete});

  String _mask(String? v) =>
      isUnhidden ? (v ?? '-') : MaskingHelper.mask(v);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(warga.nama,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text('${AppStrings.labelNIK} ',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      Text(_mask(warga.nik),
                          style: TextStyle(
                              fontSize: 11,
                              color: isUnhidden
                                  ? AppColors.textPrimary
                                  : AppColors.masked,
                              fontWeight: FontWeight.w500,
                              letterSpacing: isUnhidden ? 0 : 1)),
                    ]),
                  ])),
              Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary),
            ]),
          ),
        ),
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.primarySurface))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _row('Tanggal Lahir',
                      '${warga.tanggalLahir} (${warga.umur} thn)'),
                  _row('Kategori Usia', warga.kategoriUsia),
                  _row('Jenis Kelamin', warga.jenisKelamin),
                  if (warga.statusPendidikan != null &&
                      warga.statusPendidikan!.isNotEmpty)
                    _row('Pendidikan', warga.statusPendidikan!),
                  if (warga.pekerjaan != null &&
                      warga.pekerjaan!.isNotEmpty)
                    _row('Pekerjaan', warga.pekerjaan!),
                  const SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onEdit,
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6)),
                          icon: const Icon(Icons.edit_rounded,
                              size: 16, color: AppColors.primary),
                          label: const Text('Edit',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6)),
                          icon: const Icon(Icons.delete_rounded,
                              size: 16, color: Colors.red),
                          label: const Text('Hapus',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 12)),
                        ),
                      ]),
                ]),
          ),
      ]),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary))),
          const Text(': ',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary))),
        ]),
      );
}
