class SpptModel {
  final int? id;
  final String blokId;   // '011' atau '013'
  final String nomorPetak;
  final String? nop;
  final String namaPemilik;

  SpptModel({
    this.id,
    required this.blokId,
    required this.nomorPetak,
    this.nop,
    required this.namaPemilik,
  });

  factory SpptModel.fromMap(Map<String, dynamic> map) {
    return SpptModel(
      id: map['id'] as int?,
      blokId: (map['blok_id'] as String?) ?? '013',
      nomorPetak: map['nomor_petak'] as String,
      nop: map['nop'] as String?,
      namaPemilik: map['nama_pemilik'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'blok_id': blokId,
      'nomor_petak': nomorPetak,
      'nop': nop ?? '',
      'nama_pemilik': namaPemilik,
    };
  }

  int get nomorPetakInt => int.tryParse(nomorPetak) ?? 0;
}
