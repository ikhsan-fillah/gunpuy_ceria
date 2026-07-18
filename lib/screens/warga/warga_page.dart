import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../database/database_helper.dart';
import '../../../models/warga_model.dart';
import '../../../utils/masking_helper.dart';
import '../../../services/auth_service.dart';
import 'detail_kk_page.dart';
import 'form_warga_page.dart';

class WargaPage extends StatefulWidget {
  const WargaPage({super.key});
  @override
  State<WargaPage> createState() => _WargaPageState();
}

class _WargaPageState extends State<WargaPage> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _auth = AuthService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _listKK = [];
  List<Map<String, dynamic>> _filteredKK = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _db.getListKK();
    if (mounted) setState(() { _listKK = data; _filteredKK = data; _isLoading = false; });
  }

  void _onSearch() {
    final String q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredKK = _listKK.where((kk) =>
          (kk['nama_kepala_keluarga'] as String).toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Warga (${_listKK.length} KK)'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const FormWargaPage()));
          _loadData();
        },
        child: const Icon(Icons.person_add_rounded),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: AppStrings.wargaSearchHint,
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: AppColors.textSecondary), onPressed: () => _searchCtrl.clear())
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredKK.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.people_outline, size: 64, color: AppColors.primaryLight.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(_searchCtrl.text.isEmpty ? 'Belum ada data warga' : 'Tidak ditemukan',
                          style: const TextStyle(color: AppColors.textSecondary)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: _filteredKK.length,
                        itemBuilder: (context, index) {
                          final kk = _filteredKK[index];
                          return _KKCard(
                            kkData: kk,
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => DetailKKPage(noKK: kk['no_kk'], namaKepala: kk['nama_kepala_keluarga'])));
                              _loadData();
                            },
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _KKCard extends StatelessWidget {
  final Map<String, dynamic> kkData;
  final VoidCallback onTap;
  const _KKCard({required this.kkData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${kkData['nama_kepala_keluarga']} (Kepala KK)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              Text('${AppStrings.labelNoKK}: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(MaskingHelper.mask(kkData['no_kk']),
                  style: const TextStyle(fontSize: 12, color: AppColors.masked, fontWeight: FontWeight.w500, letterSpacing: 1)),
            ]),
            const SizedBox(height: 2),
            Text('RT ${kkData['rt']} / RW ${kkData['rw']}  \u2022  ${kkData['jumlah_anggota']} anggota',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
