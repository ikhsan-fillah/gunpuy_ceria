class SpptModel {
  final int? id;
  final String nomorPetak;
  final String? nop; // opsional
  final String namaPemilik;

  SpptModel({
    this.id,
    required this.nomorPetak,
    this.nop, // opsional, tidak required
    required this.namaPemilik,
  });

  factory SpptModel.fromMap(Map<String, dynamic> map) {
    return SpptModel(
      id: map['id'] as int?,
      nomorPetak: map['nomor_petak'] as String,
      nop: map['nop'] as String?,
      namaPemilik: map['nama_pemilik'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nomor_petak': nomorPetak,
      'nop': nop ?? '',
      'nama_pemilik': namaPemilik,
    };
  }

  // Nomor petak sebagai int untuk sorting numerik
  int get nomorPetakInt => int.tryParse(nomorPetak) ?? 0;
}
