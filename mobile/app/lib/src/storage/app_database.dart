// Uygulama SQLite veritabanı — depolama katmanının tek şema/açılış noktası.
//
// Neden SQLite (localStorage'ın aksine): (1) ATOMİKLİK — mobilde dosya
// yazımları çökme anında yarım kalabilir, localStorage'ın tarayıcı nezaketi
// yok; transaction'lar bunu bedavaya çözer. (2) Kuyruklar (cap/TTL) gerçek
// satır semantiği ister. (3) "Tek blob her şeyi rehin alır" sınıfı hatalar
// tablo ayrımıyla yapısal olarak kapanır. Bkz. mobile/CLAUDE.md,
// "Depolama Katmanı".
//
// ŞEMA MİGRASYON KURALI: yükseltmeler ASLA yıkıcı olamaz (drop/delete yok);
// downgrade (uygulama geri alma) durumunda şemaya DOKUNULMAZ — okumalar
// kolon adıyla yapıldığından yeni/fazla kolon zararsızdır, payload
// seviyesindeki sürüm kontrolü (LocalSaveStore) bilinmeyen içeriği zaten
// karantinaya alır.
import 'package:sqflite/sqflite.dart';

import 'web_db.dart';

/// DB şema sürümü — tablo/kolon değişikliklerinde artır ve `_migrations`e
/// bir adım ekle. Payload sürümünden (kSavePayloadVersion) AYRI bir kavram.
const int kDbSchemaVersion = 2;

Future<void> _createV1(Database db) async {
  await db.execute('''
    create table local_saves(
      slot text primary key,
      payload_version integer not null,
      payload text not null,
      saved_at integer not null
    )''');
  // Karantina: bozuk/bilinmeyen kayıtlar SİLİNMEZ, buraya taşınır —
  // web'deki ErrorBoundary "kaydı sil ve yeniden yükle" kaçış kapağının
  // kayıpsız, otomatik karşılığı (PORT_BRIEF §7).
  await db.execute('''
    create table quarantined_saves(
      id integer primary key autoincrement,
      slot text not null,
      payload_version integer,
      payload text not null,
      reason text not null,
      quarantined_at integer not null
    )''');
  // Offline/misafir kuyrukları (web: kelimeki:pending-games / pending-feedback).
  await db.execute('''
    create table pending_queue(
      id text primary key,
      kind text not null,
      payload text not null,
      created_at integer not null
    )''');
  await db.execute(
      'create index idx_pending_queue_kind on pending_queue(kind, created_at)');
  // Tek seferlik oku-ve-temizle olayları (web: pending-abandoned-game,
  // pending-friend-invite-token).
  await db.execute('''
    create table pending_events(
      id integer primary key autoincrement,
      kind text not null,
      payload text not null,
      created_at integer not null
    )''');
  // Oyun başına son-okunan sohbet damgası (web: kelimeki:chat-last-read:<id>
  // — sınırsız dinamik anahtar prefs'e değil tabloya aittir).
  await db.execute('''
    create table chat_last_read(
      game_id text primary key,
      last_read_at integer not null
    )''');
}

/// Girişli kullanıcının devam eden YZ oyunlarının YEREL AYNASI — sunucudaki
/// `local_game_saves`e yazılamayan (offline/ağ hatası) state buraya düşer ve
/// bağlantı dönünce itilir. Girişli kullanıcı `local_saves`e BİLEREK
/// yazmıyor (mükerrer terk-edilme cezası önlemi, Parça 3a); bu ayrı tablo o
/// kuralı bozmadan offline dayanıklılığı veriyor — 7 günlük süpürme ve
/// `multiSession` işaretlemesi buraya HİÇ uygulanmaz, ikisi de bulut
/// tarafının kararıdır (bkz. Parça 38).
Future<void> _createPendingCloudSaves(Database db) async {
  await db.execute('''
    create table pending_cloud_saves(
      id text primary key,
      user_id text not null,
      payload_version integer not null,
      payload text not null,
      saved_at integer not null
    )''');
  await db.execute('create index idx_pending_cloud_saves_user '
      'on pending_cloud_saves(user_id, saved_at)');
}

/// Sürüm N-1 → N yükseltme adımları — her yeni sürüm buraya YALNIZCA
/// ekleyici (yıkıcı olmayan) bir adım koyar.
final Map<int, Future<void> Function(Database)> _migrations = {
  2: _createPendingCloudSaves,
};

Future<Database> openAppDatabase({
  DatabaseFactory? factory,
  String? path,
}) async {
  // WEB: sqflite'ın native platform kanalı tarayıcıda yok; `web_db.dart`
  // koşullu import'u orada WASM sqlite3 + IndexedDB fabrikasını döndürür.
  // Mobilde her zaman null döner → kod yolu bire bir eskisi gibi. Çağıran
  // kendi fabrikasını geçtiyse (tüm testler) hiç devreye girmez.
  final web = factory == null ? webDatabaseFactory() : null;
  final f = factory ?? web ?? databaseFactory;
  // ffi_web'de "veritabanı dizini" kavramı yok — ad doğrudan IndexedDB
  // anahtarı olur, getDatabasesPath() anlamsız.
  final dbPath = path ??
      (web != null ? 'kelimeki.db' : '${await f.getDatabasesPath()}/kelimeki.db');
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: kDbSchemaVersion,
      onCreate: (db, version) async {
        await _createV1(db);
        for (var v = 2; v <= version; v++) {
          await _migrations[v]!(db);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          final step = _migrations[v];
          if (step == null) {
            throw StateError('şema migrasyonu eksik: v$v');
          }
          await step(db);
        }
      },
      // Downgrade'de şemaya dokunma (varsayılan davranış fırlatmaktı) —
      // üstteki şema migrasyon kuralı.
      onDowngrade: (db, oldVersion, newVersion) async {},
    ),
  );
}
