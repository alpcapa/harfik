// Kelime anlamları — asset'teki salt-okunur SQLite'tan tek satır okur.
//
// Web (src/data/meanings.ts) 6.5 MB'lık meanings.json'u fetch edip TAMAMINI
// RAM'de tutuyor; mobilde bu kabul edilemez (parse gecikmesi + kalıcı
// bellek). Asset build-time'da SQLite'a çevriliyor
// (scripts/generate-meanings-db.mjs) ve burada sorgu anında tek satır
// okunuyor — bkz. mobile/CLAUDE.md, "Üst Düzey Kararlar" #4.
//
// Asset'ler paket içinde yaşadığından doğrudan açılamaz: ilk kullanımda
// uygulamanın veritabanı dizinine BİR KEZ kopyalanır. "Kopya güncel mi"
// sorusu 5 MB'ı okumadan yanıtlanır — üretici script küçük bir sha256
// parmak izi asset'i de yazar, kopyanın yanındaki damgayla karşılaştırılır;
// tutmazsa (yeni sürümde sözlük değiştiyse) yeniden kopyalanır.
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:kelimeki_core/kelimeki_core.dart' show trLower;
import 'package:sqflite/sqflite.dart';

import 'meaning_entry.dart';

const String meaningsAssetPath = 'assets/dictionary/meanings.db';
const String meaningsStampAssetPath = 'assets/dictionary/meanings.db.sha256';

class MeaningStore {
  final AssetBundle _bundle;

  /// TEMBEL çözülür: global `databaseFactory` yapılandırılmadan (ffi testleri)
  /// bu nesne kurulabilmeli — kurucuda okumak "databaseFactory not
  /// initialized" ile patlıyordu (anlam deposunu hiç kullanmayan testler
  /// bile düşüyordu).
  final DatabaseFactory? _factory;

  /// Kopyanın yaşayacağı dizin — testler geçici bir dizin verir.
  final Future<String> Function() _dbDir;

  Database? _db;
  Future<Database?>? _opening;

  MeaningStore({
    required AssetBundle bundle,
    DatabaseFactory? factory,
    Future<String> Function()? dbDir,
  })  : _bundle = bundle,
        _factory = factory,
        _dbDir = dbDir ?? getDatabasesPath;

  /// Bir kelimenin anlamı; yoksa (ya da asset açılamazsa) null.
  /// Sorgu anahtarı web'le aynı normalizasyondan geçer (trLower).
  Future<MeaningEntry?> lookup(String word) async {
    final db = await _ensureOpen();
    if (db == null) return null;
    final rows = await db.query(
      'meanings',
      columns: ['pos', 'meanings'],
      where: 'word = ?',
      whereArgs: [trLower(word)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeaningEntry.fromRow(rows.first);
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    _opening = null;
    await db?.close();
  }

  Future<Database?> _ensureOpen() {
    final db = _db;
    if (db != null) return Future.value(db);
    return _opening ??= _open();
  }

  Future<Database?> _open() async {
    try {
      final dir = await _dbDir();
      await Directory(dir).create(recursive: true);
      // Düz birleştirme yeterli: bu kod yalnızca iOS/Android'de (ve Linux
      // testlerinde) koşuyor. `package:path` yalnızca bunun için doğrudan
      // bağımlılık olarak eklenmişti — pubspec.lock'u manifest'le çelişkiye
      // düşürdüğü için geri alındı (bu ortamın Flutter SDK'sı eski, lock
      // yeniden üretilemiyor).
      final dbPath = '$dir/meanings.db';
      final stampPath = '$dir/meanings.db.sha256';

      final assetStamp =
          (await _bundle.loadString(meaningsStampAssetPath)).trim();
      final stampFile = File(stampPath);
      final dbFile = File(dbPath);
      final localStamp =
          stampFile.existsSync() ? stampFile.readAsStringSync().trim() : null;

      if (!dbFile.existsSync() || localStamp != assetStamp) {
        // Yalnızca ilk açılışta (ya da sözlük güncellendiğinde) 5 MB okunur.
        final bytes = await _bundle.load(meaningsAssetPath);
        await dbFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
        await stampFile.writeAsString(assetStamp, flush: true);
      }
      final db = await (_factory ?? databaseFactory).openDatabase(
        dbPath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      _db = db;
      return db;
    } catch (e) {
      // Anlam gösterimi oyunun çalışması için kritik değil — asset/dosya
      // sorununda modal "anlam bulunamadı" der, oyun akışı bozulmaz.
      _opening = null;
      return null;
    }
  }
}
