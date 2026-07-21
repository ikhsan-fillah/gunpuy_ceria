import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../database/database_helper.dart';
import '../../models/sppt_model.dart';
import '../../utils/masking_helper.dart';
import '../../services/peta_service.dart';
import 'form_sppt_page.dart';

class SpptPage extends StatefulWidget {
  const SpptPage({super.key});
  @override
  State<SpptPage> createState() => _SpptPageState();
}

class _SpptPageState extends State<SpptPage> {
  final DatabaseHelper _db = DatabaseHelper();
  final PetaService _petaService = PetaService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<SpptModel> _allData = [], _filteredData = [];
  bool _isLoading = true, _isUnhidden = false;
  String _sortColumn = 'nomor_petak';
  bool _sortAscending = true;
  String? _petaImagePath;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPeta();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final raw = await _db.getAllSPPT(
        orderBy: '$_sortColumn ${_sortAscending ? 'ASC' : 'DESC'}');
    final data = raw.map((m) => SpptModel.fromMap(m)).toList();
    // Sort numerik berdasarkan nomor petak
    data.sort((a, b) => a.nomorPetakInt.compareTo(b.nomorPetakInt));
    if (mounted)
      setState(() {
        _allData = data;
        _filteredData = data;
        _isLoading = false;
      });
  }

  Future<void> _loadPeta() async {
    final String? path = await _petaService.getSavedPetaPath();
    if (mounted) setState(() => _petaImagePath = path);
  }

  void _onSearch() {
    final String q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredData = _allData
          .where((s) =>
              s.namaPemilik.toLowerCase().contains(q) ||
              (s.nop ?? '').toLowerCase().contains(q) ||
              s.nomorPetak.toLowerCase().contains(q))
          .toList();
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
    _loadData();
  }

  Future<void> _toggleUnhide() async {
    if (_isUnhidden) {
      setState(() => _isUnhidden = false);
      return;
    }
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.lock_open_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Tampilkan Data Sensitif'),
            ]),
            content: const Text(
                'NOP akan ditampilkan.\nPastikan tidak ada orang lain yang melihat layar.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Tampilkan')),
            ],
          ),
        ) ??
        false;
    if (confirm && mounted) setState(() => _isUnhidden = true);
  }

  Future<void> _pickPeta(ImageSource source) async {
    final String? path =
        await _petaService.pickAndSavePeta(source: source);
    if (path != null && mounted) setState(() => _petaImagePath = path);
  }

  void _showPetaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: AppColors.primary),
            title: const Text('Pilih dari Galeri'),
            onTap: () {
              Navigator.pop(context);
              _pickPeta(ImageSource.gallery);
            }),
        ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: AppColors.primary),
            title: const Text('Ambil Foto dengan Kamera'),
            onTap: () {
              Navigator.pop(context);
              _pickPeta(ImageSource.camera);
            }),
        if (_petaImagePath != null)
          ListTile(
              leading:
                  const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Hapus Peta',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _petaService.deletePeta();
                setState(() => _petaImagePath = null);
              }),
      ])),
    );
  }

  String _maskNOP(String? nop) {
    if (nop == null || nop.isEmpty) return '-';
    return _isUnhidden ? nop : MaskingHelper.maskNOP(nop);
  }

  Future<void> _deleteSppt(SpptModel sppt) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Hapus Data SPPT'),
            content: Text(
                'Hapus petak ${sppt.nomorPetak} (${sppt.namaPemilik})?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Hapus',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
    if (confirm && sppt.id != null) {
      await _db.deleteSPPT(sppt.id!);
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.spptTitle),
        actions: [
          // Hanya tampilkan tombol unhide jika ada data NOP
          if (_allData.any((s) => s.nop != null && s.nop!.isNotEmpty))
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
        onPressed: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const FormSpptPage()));
          _loadData();
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header peta
                      Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const _SectionHeader(
                                title: 'Peta Bidang Tanah',
                                subtitle: 'Kalurahan Srikayangan Blok 013'),
                            IconButton(
                                icon: const Icon(
                                    Icons.edit_rounded,
                                    color: AppColors.primaryLight,
                                    size: 20),
                                onPressed: _showPetaOptions),
                          ]),
                      const SizedBox(height: 10),

                      // Gambar peta
                      GestureDetector(
                        onTap: _petaImagePath != null
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => _PetaFullScreen(
                                          imagePath: _petaImagePath!,
                                          spptList: _allData,
                                          onPetakTap: (sppt) async {
                                            await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        FormSpptPage(
                                                            sppt: sppt)));
                                            _loadData();
                                          },
                                        )))
                            : null,
                        child: Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primaryLight,
                                width: 1.5),
                          ),
                          child: _petaImagePath != null
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  child: Stack(children: [
                                    Image.file(File(_petaImagePath!),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity),
                                    Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 8,
                                              vertical: 4),
                                          decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8)),
                                          child: const Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .zoom_in_rounded,
                                                    color: Colors.white,
                                                    size: 14),
                                                SizedBox(width: 4),
                                                Text('Tap untuk zoom',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.white,
                                                        fontSize: 11)),
                                              ]),
                                        )),
                                  ]))
                              : Center(
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.map_outlined,
                                            size: 52,
                                            color: AppColors.primaryLight
                                                .withOpacity(0.5)),
                                        const SizedBox(height: 8),
                                        const Text(
                                            'Belum ada gambar peta',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors
                                                    .textSecondary)),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: _showPetaOptions,
                                          style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color:
                                                      AppColors.primary)),
                                          icon: const Icon(
                                              Icons.upload_rounded,
                                              color: AppColors.primary,
                                              size: 18),
                                          label: const Text(
                                              'Upload Peta',
                                              style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 13)),
                                        ),
                                      ])),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(AppStrings.spptPetaNote,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 16),

                      // Legenda — urut numerik 1, 2, 3...
                      if (_allData.isNotEmpty) ...[
                        Text(AppStrings.spptLegendTitle,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        _buildLegenda(),
                        const SizedBox(height: 20),
                      ],

                      // Header tabel
                      _SectionHeader(
                          title: 'Data SPPT',
                          subtitle:
                              '${_allData.length} bidang tanah terdata'),
                      const SizedBox(height: 10),

                      // Search
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: AppStrings.spptSearchHint,
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.textSecondary),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: AppColors.textSecondary),
                                  onPressed: () => _searchCtrl.clear())
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _allData.isEmpty
                          ? Center(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 32),
                                  child: Column(children: [
                                    Icon(
                                        Icons
                                            .document_scanner_outlined,
                                        size: 48,
                                        color: AppColors.primaryLight
                                            .withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    const Text('Belum ada data SPPT',
                                        style: TextStyle(
                                            color:
                                                AppColors.textSecondary)),
                                  ])))
                          : _buildTabel(),
                      const SizedBox(height: 80),
                    ]),
              ),
            ),
    );
  }

  /// Legenda diurutkan numerik: 1, 2, 3, ..., 155
  Widget _buildLegenda() {
    // sudah terurut numerik dari _loadData
    final int mid = (_allData.length / 2).ceil();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    _allData.sublist(0, mid).map(_legendaItem).toList())),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _allData.length > mid
                    ? _allData.sublist(mid).map(_legendaItem).toList()
                    : [])),
      ]),
    );
  }

  Widget _legendaItem(SpptModel s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(s.nomorPetak,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 6),
          Expanded(
              child: Text(s.namaPemilik,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );

  Widget _buildTabel() {
    // Cek apakah ada data yang punya NOP
    final bool adaNOP = _allData.any((s) => s.nop != null && s.nop!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]),
      child: Column(children: [
        // Header tabel
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            const SizedBox(
                width: 36,
                child: Text('No.',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13))),
            Expanded(
                flex: 4,
                child: GestureDetector(
                    onTap: () => _onSort('nama_pemilik'),
                    child: Row(children: [
                      const Text('Nama Pemilik',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      const SizedBox(width: 4),
                      Icon(
                          _sortColumn == 'nama_pemilik'
                              ? (_sortAscending
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded)
                              : Icons.unfold_more_rounded,
                          color: Colors.white70,
                          size: 14),
                    ]))),
            if (adaNOP)
              Expanded(
                  flex: 3,
                  child: GestureDetector(
                      onTap: () => _onSort('nop'),
                      child: Row(children: [
                        const Text('NOP',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(width: 4),
                        Icon(
                            _sortColumn == 'nop'
                                ? (_sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded)
                                : Icons.unfold_more_rounded,
                            color: Colors.white70,
                            size: 14),
                      ]))),
            const SizedBox(width: 36),
          ]),
        ),

        // Baris data
        ..._filteredData.asMap().entries.map((entry) {
          final int idx = entry.key;
          final SpptModel s = entry.value;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: idx % 2 == 0 ? Colors.white : AppColors.background,
              borderRadius: idx == _filteredData.length - 1
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(10))
                  : null,
              border: const Border(
                  bottom: BorderSide(
                      color: AppColors.primarySurface, width: 0.5)),
            ),
            child: Row(children: [
              // Nomor petak di lingkaran
              SizedBox(
                width: 36,
                child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(s.nomorPetak,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold))),
              ),
              // Nama pemilik
              Expanded(
                  flex: 4,
                  child: Text(s.namaPemilik,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary))),
              // NOP (hanya tampil kalau ada data NOP)
              if (adaNOP)
                Expanded(
                    flex: 3,
                    child: Text(_maskNOP(s.nop),
                        style: TextStyle(
                            fontSize: 11,
                            color: _isUnhidden
                                ? AppColors.textPrimary
                                : AppColors.masked,
                            fontWeight: FontWeight.w500,
                            letterSpacing: _isUnhidden ? 0 : 0.5))),
              // Menu edit/hapus
              SizedBox(
                  width: 36,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary, size: 18),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FormSpptPage(sppt: s)));
                        _loadData();
                      } else if (value == 'delete') {
                        _deleteSppt(s);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit_rounded,
                                size: 16, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('Edit')
                          ])),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_rounded,
                                size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus',
                                style: TextStyle(color: Colors.red))
                          ])),
                    ],
                  )),
            ]),
          );
        }),
      ]),
    );
  }
}

class _PetaFullScreen extends StatelessWidget {
  final String imagePath;
  final List<SpptModel> spptList;
  final Function(SpptModel) onPetakTap;
  const _PetaFullScreen(
      {required this.imagePath,
      required this.spptList,
      required this.onPetakTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Peta Bidang Tanah'),
        actions: [
          IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context))
        ],
      ),
      body: PhotoView(
        imageProvider: FileImage(File(imagePath)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        backgroundDecoration:
            const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  const _SectionHeader({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]);
}
