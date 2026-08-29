// Depolama katmanının tek giriş kapısı — tüm store'lar tek DB bağlantısını
// ve tek enjekte saati paylaşır. Saat enjeksiyonu core'daki determinizm
// sözleşmesinin devamı: testler süreyi ileri sarabilir (7 günlük terk/TTL
// senaryoları gerçek beklemeden koşulur).
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'chat_read_store.dart';
import 'flags_store.dart';
import 'profile_cache_store.dart';
import 'cloud_save_mirror_store.dart';
import 'local_save_store.dart';
import 'pending_event_store.dart';
import 'pending_queue_store.dart';

class AppStorage {
  final Database db;
  final LocalSaveStore saves;
  /// Girişli kullanıcının bulut kayıtlarının offline aynası (Parça 38).
  final CloudSaveMirrorStore cloudMirror;

  /// Son başarılı bulut listesinin gösterim kopyası (Parça 43).
  final CloudSaveCacheStore cloudCache;

  /// Sunucuda silinmeyi bekleyen bulut kayıtları (Parça 46).
  final CloudSaveDeleteQueue cloudDeletes;
  final PendingQueueStore queue;
  final PendingEventStore events;
  final ChatReadStore chatRead;
  final FlagsStore flags;

  /// Girişli kullanıcının profilinin yerel kopyası — bağlantısızken hesabın
  /// e-postadan türetilmiş bir isme düşmemesi için (bkz. o dosyanın başlığı).
  final ProfileCacheStore profileCache;

  AppStorage._({
    required this.db,
    required this.saves,
    required this.cloudMirror,
    required this.cloudCache,
    required this.cloudDeletes,
    required this.queue,
    required this.events,
    required this.chatRead,
    required this.flags,
    required this.profileCache,
  });

  static Future<AppStorage> open({
    DatabaseFactory? factory,
    String? path,
    SharedPreferences? prefs,
    int Function()? nowMs,
  }) async {
    final now = nowMs ?? () => DateTime.now().millisecondsSinceEpoch;
    final db = await openAppDatabase(factory: factory, path: path);
    final p = prefs ?? await SharedPreferences.getInstance();
    return AppStorage._(
      db: db,
      saves: LocalSaveStore(db, now),
      cloudMirror: CloudSaveMirrorStore(db, now),
      cloudCache: CloudSaveCacheStore(db, now),
      cloudDeletes: CloudSaveDeleteQueue(db, now),
      queue: PendingQueueStore(db, now),
      events: PendingEventStore(db, now),
      chatRead: ChatReadStore(db),
      flags: FlagsStore(p),
      profileCache: ProfileCacheStore(p),
    );
  }

  Future<void> close() => db.close();
}
