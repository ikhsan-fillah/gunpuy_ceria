import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'form_warga_page.dart';
import 'import_warga_page.dart';

class AddWargaPage extends StatelessWidget {
  const AddWargaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Data Warga')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih cara input data warga:',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Input Manual
            _OptionCard(
              icon: Icons.edit_note_rounded,
              iconColor: AppColors.primary,
              title: 'Input Manual',
              subtitle: 'Tambah 1 KK baru dengan mengisi form secara manual.',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FormWargaPage()),
                );
                if (result == true && context.mounted) Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 12),

            // Import Spreadsheet
            _OptionCard(
              icon: Icons.table_chart_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'Import Spreadsheet',
              badge: 'REKOMEN',
              subtitle:
                  'Upload file Excel (.xlsx) atau CSV berisi banyak data warga sekaligus.',
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportWargaPage()),
                );
                if (result == true && context.mounted) Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 24),

            // Info template
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_rounded, color: Color(0xFFF9A825), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Template CSV tersedia di assets/template_data_warga.csv. '
                      'Buka dengan Excel atau Google Sheets, isi data warga, lalu import ke aplikasi.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF795548)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? badge;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon, required this.iconColor, required this.title,
    this.badge, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
