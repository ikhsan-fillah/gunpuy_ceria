import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'data_warga_gunung_puyuh.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE warga (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_kk TEXT NOT NULL,
        nama TEXT NOT NULL,
        nik TEXT,
        tanggal_lahir TEXT NOT NULL,
        jenis_kelamin TEXT NOT NULL CHECK(jenis_kelamin IN ('Laki-laki','Perempuan')),
        rt TEXT NOT NULL,
        rw TEXT NOT NULL,
        status_pendidikan TEXT,
        pekerjaan TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('CREATE INDEX idx_warga_no_kk ON warga(no_kk)');
    await db.execute('CREATE INDEX idx_warga_nama ON warga(nama)');

    await db.execute('''
      CREATE TABLE sppt (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_petak TEXT NOT NULL UNIQUE,
        nop TEXT NOT NULL,
        nama_pemilik TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('CREATE INDEX idx_sppt_nama ON sppt(nama_pemilik)');

    await db.execute('''
      CREATE TABLE user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL
      )
    ''');

    final Map<String, String> seedUsers = {
      'kadus.dusun01': 'kadus123',
      'banu': 'banu1234',
      'ikhsan': 'ikhsan21',
    };
    for (final entry in seedUsers.entries) {
      await db.insert('user', {
        'username': entry.key,
        'password_hash': sha256.convert(utf8.encode(entry.value)).toString(),
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.insert('user', {
        'username': 'banu',
        'password_hash': sha256.convert(utf8.encode('banu1234')).toString(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 3) {
      await db.insert('user', {
        'username': 'ikhsan',
        'password_hash': sha256.convert(utf8.encode('ikhsan21')).toString(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ─────────── WARGA ───────────

  Future<int> insertWarga(Map<String, dynamic> warga) async {
    final db = await database;
    warga['created_at'] = DateTime.now().toIso8601String();
    warga['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('warga', warga);
  }

  Future<int> updateWarga(int id, Map<String, dynamic> warga) async {
    final db = await database;
    warga['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('warga', warga, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteWarga(int id) async {
    final db = await database;
    return await db.delete('warga', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getListKK() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT no_kk,
             MIN(nama) as nama_kepala_keluarga,
             rt, rw,
             COUNT(*) as jumlah_anggota
      FROM warga
      GROUP BY no_kk
      ORDER BY nama_kepala_keluarga ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAnggotaByNoKK(String noKK) async {
    final db = await database;
    return await db.query('warga', where: 'no_kk = ?', whereArgs: [noKK]);
  }

  Future<List<Map<String, dynamic>>> searchWargaByNama(String keyword) async {
    final db = await database;
    return await db.query('warga',
        where: 'nama LIKE ?', whereArgs: ['%$keyword%']);
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final db = await database;
    final totalKK =
        await db.rawQuery('SELECT COUNT(DISTINCT no_kk) as total FROM warga');
    final totalWarga =
        await db.rawQuery('SELECT COUNT(*) as total FROM warga');
    final lakiLaki = await db.rawQuery(
        "SELECT COUNT(*) as total FROM warga WHERE jenis_kelamin = 'Laki-laki'");
    final perempuan = await db.rawQuery(
        "SELECT COUNT(*) as total FROM warga WHERE jenis_kelamin = 'Perempuan'");
    final totalSPPT =
        await db.rawQuery('SELECT COUNT(*) as total FROM sppt');
    final semuaTgl = await db.query('warga', columns: ['tanggal_lahir']);

    int balita = 0, anakAnak = 0, remaja = 0, dewasa = 0, lansia = 0;
    final DateTime now = DateTime.now();
    for (var row in semuaTgl) {
      final DateTime tgl = DateTime.parse(row['tanggal_lahir'] as String);
      int umur = now.year - tgl.year;
      if (now.month < tgl.month ||
          (now.month == tgl.month && now.day < tgl.day)) umur--;
      if (umur <= 5) {
        balita++;
      } else if (umur <= 11) {
        anakAnak++;
      } else if (umur <= 17) {
        remaja++;
      } else if (umur <= 59) {
        dewasa++;
      } else {
        lansia++;
      }
    }

    return {
      'total_kk': totalKK.first['total'],
      'total_warga': totalWarga.first['total'],
      'laki_laki': lakiLaki.first['total'],
      'perempuan': perempuan.first['total'],
      'balita': balita,
      'anak_anak': anakAnak,
      'remaja': remaja,
      'dewasa': dewasa,
      'lansia': lansia,
      'total_sppt': totalSPPT.first['total'],
    };
  }

  // ─────────── SPPT ───────────

  Future<int> insertSPPT(Map<String, dynamic> sppt) async {
    final db = await database;
    sppt['created_at'] = DateTime.now().toIso8601String();
    sppt['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('sppt', sppt);
  }

  Future<int> updateSPPT(int id, Map<String, dynamic> sppt) async {
    final db = await database;
    sppt['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('sppt', sppt, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSPPT(int id) async {
    final db = await database;
    return await db.delete('sppt', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllSPPT(
      {String orderBy = 'nomor_petak ASC'}) async {
    final db = await database;
    return await db.query('sppt', orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> searchSPPTByNama(String keyword) async {
    final db = await database;
    return await db.query('sppt',
        where: 'nama_pemilik LIKE ?', whereArgs: ['%$keyword%']);
  }

  Future<List<Map<String, dynamic>>> searchSPPT(String keyword) async {
    final db = await database;
    return await db.query('sppt',
        where: 'nama_pemilik LIKE ? OR nop LIKE ?',
        whereArgs: ['%$keyword%', '%$keyword%']);
  }

  /// Cari satu record SPPT berdasarkan NOP
  Future<Map<String, dynamic>?> getSPPTByNop(String nop) async {
    final db = await database;
    final result =
        await db.query('sppt', where: 'nop = ?', whereArgs: [nop], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  /// Cari satu record SPPT berdasarkan nomor_petak
  Future<Map<String, dynamic>?> getSPPTByNomorPetak(String nomorPetak) async {
    final db = await database;
    final result = await db.query('sppt',
        where: 'nomor_petak = ?', whereArgs: [nomorPetak], limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  /// Import batch dari hasil scan OCR.
  /// Return: map berisi jumlah inserted, updated, skipped
  Future<Map<String, int>> importScanSPPT(
      List<Map<String, String>> items) async {
    final db = await database;
    int inserted = 0, updated = 0, skipped = 0;

    for (final item in items) {
      final String nop = item['nop']!;
      final String nama = item['nama_pemilik']!;
      final String nomorPetak = item['nomor_petak']!;

      final existing = await getSPPTByNop(nop);

      if (existing == null) {
        // Cek apakah nomor_petak sudah ada (dari input manual tanpa NOP)
        final existingByPetak = await getSPPTByNomorPetak(nomorPetak);
        if (existingByPetak == null) {
          await db.insert('sppt', {
            'nomor_petak': nomorPetak,
            'nop': nop,
            'nama_pemilik': nama,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          inserted++;
        } else {
          // Petak sudah ada tapi NOP belum, update NOP & nama
          await db.update(
            'sppt',
            {
              'nop': nop,
              'nama_pemilik': nama,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existingByPetak['id']],
          );
          updated++;
        }
      } else {
        final String namaLama = existing['nama_pemilik'] as String;
        if (namaLama.trim().toUpperCase() != nama.trim().toUpperCase()) {
          // Nama berbeda → update
          await db.update(
            'sppt',
            {
              'nama_pemilik': nama,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
          updated++;
        } else {
          skipped++;
        }
      }
    }

    return {'inserted': inserted, 'updated': updated, 'skipped': skipped};
  }

  // ─────────── USER ───────────

  Future<bool> login(String username, String password) async {
    final db = await database;
    final String hash = sha256.convert(utf8.encode(password)).toString();
    final result = await db.query('user',
        where: 'username = ? AND password_hash = ?',
        whereArgs: [username, hash]);
    return result.isNotEmpty;
  }

  Future<int> insertUser(String username, String password) async {
    final db = await database;
    return await db.insert(
        'user',
        {
          'username': username,
          'password_hash':
              sha256.convert(utf8.encode(password)).toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
