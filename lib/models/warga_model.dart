class WargaModel {
  final int? id;
  final String noKK;
  final String nama;
  final String? nik;
  final String tanggalLahir;
  final String jenisKelamin;
  final String rt;
  final String rw;
  final String? statusPendidikan;
  final String? pekerjaan;

  WargaModel({
    this.id,
    required this.noKK,
    required this.nama,
    this.nik,
    required this.tanggalLahir,
    required this.jenisKelamin,
    required this.rt,
    required this.rw,
    this.statusPendidikan,
    this.pekerjaan,
  });

  factory WargaModel.fromMap(Map<String, dynamic> map) {
    return WargaModel(
      id: map['id'] as int?,
      noKK: map['no_kk'] as String,
      nama: map['nama'] as String,
      nik: map['nik'] as String?,
      tanggalLahir: map['tanggal_lahir'] as String,
      jenisKelamin: map['jenis_kelamin'] as String,
      rt: map['rt'] as String,
      rw: map['rw'] as String,
      statusPendidikan: map['status_pendidikan'] as String?,
      pekerjaan: map['pekerjaan'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'no_kk': noKK,
      'nama': nama,
      if (nik != null) 'nik': nik,
      'tanggal_lahir': tanggalLahir,
      'jenis_kelamin': jenisKelamin,
      'rt': rt,
      'rw': rw,
      if (statusPendidikan != null) 'status_pendidikan': statusPendidikan,
      if (pekerjaan != null) 'pekerjaan': pekerjaan,
    };
  }

  int get umur {
    final DateTime tgl = DateTime.parse(tanggalLahir);
    final DateTime now = DateTime.now();
    int age = now.year - tgl.year;
    if (now.month < tgl.month ||
        (now.month == tgl.month && now.day < tgl.day)) age--;
    return age;
  }

  String get kategoriUsia {
    final int u = umur;
    if (u <= 5)  return 'Balita';
    if (u <= 11) return 'Anak-anak';
    if (u <= 17) return 'Remaja';
    if (u <= 59) return 'Dewasa';
    return 'Lansia';
  }
}
