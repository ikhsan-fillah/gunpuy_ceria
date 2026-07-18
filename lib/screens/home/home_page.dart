import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_strings.dart';
import '../../../database/database_helper.dart';
import '../../../services/auth_service.dart';
import '../../screens/login/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService();
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper().getDashboardSummary();
    if (mounted) setState(() { _summary = data; _isLoading = false; });
  }

  Future<void> _logout() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Keluar'),
            content: const Text('Yakin ingin keluar dari aplikasi?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Keluar',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ?? false;
    if (confirm) {
      await _auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    }
  }

  List<_UsiaStat> get _usiaStats {
    final int total = (_summary['total_warga'] ?? 0) as int;
    if (total == 0) return [];
    return [
      _UsiaStat(AppStrings.labelDewasa,   _summary['dewasa']    ?? 0, AppColors.chartDewasa,   total),
      _UsiaStat(AppStrings.labelRemaja,   _summary['remaja']    ?? 0, AppColors.chartRemaja,   total),
      _UsiaStat(AppStrings.labelAnakAnak, _summary['anak_anak'] ?? 0, AppColors.chartAnakAnak, total),
      _UsiaStat(AppStrings.labelLansia,   _summary['lansia']    ?? 0, AppColors.chartLansia,   total),
      _UsiaStat(AppStrings.labelBalita,   _summary['balita']    ?? 0, AppColors.chartBalita,   total),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSummary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(AppStrings.homeGreeting,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(width: 4),
                            const Text('\u{1F44B}', style: TextStyle(fontSize: 17)),
                          ]),
                          Text(AppStrings.homeSubGreeting,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _PrimaryCard(label: AppStrings.cardTotalKK,    value: '${_summary['total_kk']    ?? 0}')),
                      const SizedBox(width: 12),
                      Expanded(child: _PrimaryCard(label: AppStrings.cardTotalWarga, value: '${_summary['total_warga'] ?? 0}')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _SurfaceCard(label: AppStrings.cardLakiLaki,  value: '${_summary['laki_laki']  ?? 0}')),
                      const SizedBox(width: 12),
                      Expanded(child: _SurfaceCard(label: AppStrings.cardPerempuan, value: '${_summary['perempuan']  ?? 0}')),
                    ]),
                    const SizedBox(height: 20),
                    const Text(AppStrings.chartTitle,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: _usiaStats.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(16),
                              child: Text('Belum ada data warga', style: TextStyle(color: AppColors.textSecondary))))
                          : Row(children: [
                              SizedBox(
                                width: 130, height: 130,
                                child: PieChart(PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (event, response) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || response == null || response.touchedSection == null) {
                                          _touchedIndex = -1; return;
                                        }
                                        _touchedIndex = response.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  sections: _usiaStats.asMap().entries.map((entry) {
                                    final bool isTouched = entry.key == _touchedIndex;
                                    return PieChartSectionData(
                                      value: entry.value.count.toDouble(),
                                      color: entry.value.color,
                                      radius: isTouched ? 52 : 44,
                                      title: isTouched ? '${entry.value.pct.toStringAsFixed(0)}%' : '',
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    );
                                  }).toList(),
                                  centerSpaceRadius: 28,
                                  sectionsSpace: 2,
                                )),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _usiaStats.map((s) => _LegendItem(stat: s)).toList(),
                              )),
                            ]),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.map_rounded, color: AppColors.primaryLight),
                        const SizedBox(width: 10),
                        const Text('Total Objek SPPT Terdata',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const Spacer(),
                        Text('${_summary['total_sppt'] ?? 0}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(width: 4),
                        const Text('objek', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

class _UsiaStat {
  final String label; final int count; final Color color; final int total;
  _UsiaStat(this.label, this.count, this.color, this.total);
  double get pct => total > 0 ? count / total * 100 : 0;
}

class _PrimaryCard extends StatelessWidget {
  final String label, value;
  const _PrimaryCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
    ]),
  );
}

class _SurfaceCard extends StatelessWidget {
  final String label, value;
  const _SurfaceCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
    ]),
  );
}

class _LegendItem extends StatelessWidget {
  final _UsiaStat stat;
  const _LegendItem({required this.stat});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: stat.color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Expanded(child: Text('${stat.label} ${stat.pct.toStringAsFixed(0)}% (${stat.count})',
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
    ]),
  );
}
