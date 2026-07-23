import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'sppt_page.dart';

/// Halaman pilih Blok sebelum masuk ke data SPPT.
/// Blok 11 → blok_id = '011'
/// Blok 13 → blok_id = '013'
class SpptBlokPickerPage extends StatelessWidget {
  const SpptBlokPickerPage({super.key});

  void _pilihBlok(BuildContext context, String blokId, String label) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpptPage(blokId: blokId, blokLabel: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Blok SPPT')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Blok',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Data SPPT dipisah per blok. Pilih blok yang ingin ditampilkan.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            _BlokCard(
              blokId: '011',
              label: 'Blok 11',
              subtitle: 'Srikayangan Blok 011',
              icon: Icons.grid_3x3_rounded,
              color: const Color(0xFF1565C0),
              onTap: () => _pilihBlok(context, '011', 'Blok 11'),
            ),
            const SizedBox(height: 16),
            _BlokCard(
              blokId: '013',
              label: 'Blok 13',
              subtitle: 'Srikayangan Blok 013',
              icon: Icons.grid_4x4_rounded,
              color: AppColors.primary,
              onTap: () => _pilihBlok(context, '013', 'Blok 13'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlokCard extends StatelessWidget {
  final String blokId;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BlokCard({
    required this.blokId,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 18),
        ]),
      ),
    );
  }
}
