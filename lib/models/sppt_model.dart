class SpptModel {
  final int? id;
  final String nomorPetak;
  final String nop;
  final String namaPemilik;

  SpptModel({
    this.id,
    required this.nomorPetak,
    required this.nop,
    required this.namaPemilik,
  });

  factory SpptModel.fromMap(Map<String, dynamic> map) {
    return SpptModel(
      id: map['id'] as int?,
      nomorPetak: map['nomor_petak'] as String,
      nop: map['nop'] as String,
      namaPemilik: map['nama_pemilik'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nomor_petak': nomorPetak,
      'nop': nop,
      'nama_pemilik': namaPemilik,
    };
  }
}
