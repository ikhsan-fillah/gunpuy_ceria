class MaskingHelper {
  MaskingHelper._();

  /// Mask semua karakter kecuali 4 digit terakhir
  /// Contoh: '3401234567890001' → '●●●●●●●●●●●●0001'
  static String mask(String? value) {
    if (value == null || value.isEmpty) return '-';
    if (value.length <= 4) return '●' * value.length;
    final String visible = value.substring(value.length - 4);
    final String masked = '●' * (value.length - 4);
    return '$masked$visible';
  }

  /// Mask khusus NOP format: tampilkan hanya 4 digit terakhir
  static String maskNOP(String? value) => mask(value);
}
