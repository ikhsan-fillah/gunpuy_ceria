import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'form_sppt_page.dart';
import 'scan_sppt_page.dart';
import 'import_sppt_page.dart';

/// Halaman pilihan cara tambah data SPPT:
/// 1. Input Manual (form)
/// 2. Scan OCR (foto dokumen)
/// 3. Import Spreadsheet (.xlsx / .csv)
class AddSpptPage extends StatelessWidget {
  final String blokId;
  final String blokLabel;
  const AddSpptPage({
    super.key,
    required this.blokId,
    required this.blokLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Data SPPT — $blokLabel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih cara pengisian data SPPT $blokLabel',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Card 1: Input Manual ──
            _PilihanCard(
              icon: Icons.edit_note_rounded,
              color: AppColors.primary,
              title: 'Input Manual',
              subtitle:
                  'Isi satu per satu: nomor petak, nama pemilik, dan NOP',
              badge: null,
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FormSpptPage(blokId: blokId),
                  ),
                );
                if (result != false && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            const SizedBox(height: 16),

            // ── Divider label ──
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('atau import sekaligus',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),

            // ── Card 2: Import Spreadsheet ──
            _PilihanCard(
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF1B7F4A),
              title: 'Import Spreadsheet',
              subtitle:
                  'Upload file Excel (.xlsx) atau CSV dari pak dukuh — lebih akurat',
              badge: 'REKOMEN',
              badgeColor: const Color(0xFF1B7F4A),
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ImportSpptPage(blokId: blokId),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            const SizedBox(height: 16),

            // ── Card 3: Scan OCR ──
            _PilihanCard(
              icon: Icons.document_scanner_rounded,
              color: const Color(0xFF0277BD),
              title: 'Scan Dokumen (OCR)',
              subtitle:
                  'Foto tabel dokumen fisik dari pak dukuh, data dibaca otomatis',
              badge: null,
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScanSpptPage(blokId: blokId),
                  ),
                );
                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PilihanCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _PilihanCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor ?? color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(badge!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ]),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF757575))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ]),
        ),
      ),
    );
  }
}
