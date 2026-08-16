// Girişli kullanıcının devam eden YZ oyunları — web `local_game_saves`
// akışının portu (src/App.tsx: activeSaveIdRef + enqueueSaveWrite + autosave
// effect'i + refreshCloudSaves'in listeleme/temizlik kısmı + misafir kaydını
// hesaba taşıyan migration effect'i; src/lib/api.ts: listLocalGameSaves/
// upsertLocalGameSave/deleteLocalGameSave).
//
// Katmanlar:
// - `CloudSaveGateway` — satır verisine giden ince kapı. Gerçek uç Supabase
//   (`SupabaseCloudSaveGateway`, cihazda doğrulanır); testler bellek içi
//   sahteyle TÜM politika katmanını gerçek akışla sınar.
// - `CloudSaveRepo` — politika: tablonun TEK TableWriteQueue'su (PORT_BRIEF
//   §7 — web'deki DELETE→SELECT yarışının yapısal önlemi), satır ayrıştırma
//   ("parse, don't validate"; çözülemeyen satır SİLİNMEDEN atlanır — satır
//   web istemcisi için hâlâ geçerli olabilir), bitmiş/play-dışı satırların
//   fırsatçı temizliği, misafir kaydının hesaba taşınması.
// - `CloudGameSession` — bir GameController'ı sunucu kalıcılığına bağlar
//   (misafir tarafındaki GameSession'ın bulut eşleniği).
//
// 7 GÜNLÜK SÜPÜRME BU PARÇADA DEĞİL (bilinçli): web `refreshCloudSaves`
// süresi dolan satırı atomik "iddia edip" siler VE -2 cezalı bir teslim
// kaydı (`buildGameRecord` → `games`) üretir. `games` satırı üretimi
// (buildGameRecord portu) sonraki parçanın işi — satırı ceza üretmeden
// silmek cezayı YUTMAK olurdu. Bu yüzden süresi dolmuş satırlar listeye
// alınmaz ama sunucuda bırakılır: aynı hesabın web istemcisi (ya da bu
// tarafın sonraki parçası) süpürünce ceza doğru işler.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/game_controller.dart';
import '../game/local_game_repo.dart';
import '../storage/cloud_save_mirror_store.dart';
import '../storage/local_save_store.dart' show abandonTimeout;
import '../util/uuid.dart';
import 'write_queue.dart';

/// `local_game_saves` tablosundaki tek satır (web `LocalGameSave` tipi).
class CloudSave {
  final String id;
  final GameState state;
  final int updatedAtMs;
  const CloudSave({
    required this.id,
    required this.state,
    required this.updatedAtMs,
  });
}

/// 7 günü dolmuş ve bu cihaz tarafından ATOMİK olarak iddia edilip silinmiş
/// bir satır — çağıran bunu -2 cezalı teslim kaydına çevirir (web
/// refreshCloudSaves'in claim dalı).
class AbandonedCloudSave {
  final GameState state;

  /// Satırın son güncellenme anı — oyun süresi bundan ve `startedAt`'ten
  /// hesaplanır (web durationSeconds).
  final int updatedAtMs;
  const AbandonedCloudSave({required this.state, required this.updatedAtMs});
}

/// `list()` sonucu: devam eden kayıtlar + bu turda iddia edilen terkler.
class CloudSaveList {
  final List<CloudSave> saves;
  final List<AbandonedCloudSave> abandoned;
  const CloudSaveList(this.saves, this.abandoned);
}

/// Satır kapısı — Supabase'e giden üç sorgunun soyutlaması. Politika
/// (kuyruk, ayrıştırma, temizlik) BURADA DEĞİL, CloudSaveRepo'da yaşar.
abstract class CloudSaveGateway {
  /// Çağıranın satırları, `updated_at` azalan (web listLocalGameSaves).
  /// Her satır: `id`, `state` (Map), `updated_at` (ISO). Hata fırlatabilir —
  /// repo yakalar.
  Future<List<Map<String, Object?>>> list();

  Future<void> upsert(
      String id, String userId, Map<String, Object?> stateJson, int playerCount);

  Future<void> delete(String id);

  /// Süresi dolmuş bir satırı ATOMİK olarak "iddia edip" siler ve silinen
  /// satırın state'ini döner; satır o arada güncellendiyse (başka cihaz
  /// oynadı) ya da başka bir cihaz zaten iddia ettiyse null döner. Web
  /// `claimAbandonedLocalGameSave`: tek bir `.delete().eq(id)
  /// .lt(updated_at, cutoff).select('state')` sorgusu — satır kilidi
  /// sayesinde ayrı bir RPC/kilit gerekmez.
  Future<Map<String, Object?>?> claimAbandoned(String id, String cutoffIso);
}

class SupabaseCloudSaveGateway implements CloudSaveGateway {
  final SupabaseClient client;
  SupabaseCloudSaveGateway(this.client);

  @override
  Future<List<Map<String, Object?>>> list() async {
    final rows = await client
        .from('local_game_saves')
        .select('id, state, updated_at')
        .order('updated_at', ascending: false);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<void> upsert(String id, String userId,
      Map<String, Object?> stateJson, int playerCount) async {
    await client.from('local_game_saves').upsert({
      'id': id,
      'user_id': userId,
      'state': stateJson,
      'player_count': playerCount,
    });
  }

  @override
  Future<void> delete(String id) async {
    await client.from('local_game_saves').delete().eq('id', id);
  }

  @override
  Future<Map<String, Object?>?> claimAbandoned(
      String id, String cutoffIso) async {
    final rows = await client
        .from('local_game_saves')
        .delete()
        .eq('id', id)
        .lt('updated_at', cutoffIso)
        .select('state');
    if (rows.isEmpty) return null;
    final state = (rows.first as Map)['state'];
    return state is Map ? state.cast<String, Object?>() : null;
  }
}

class CloudSaveRepo {
  final CloudSaveGateway gateway;
  final int Function() _nowMs;

  /// local_game_saves'in TEK yazma kuyruğu (PORT_BRIEF §7) — upsert VE
  /// silme dahil her yazma buradan; her listeleme kuyruk boşalana kadar
  /// bekler (web enqueueSaveWrite + refreshCloudSaves'in `await
  /// saveChainRef` adımı).
  final TableWriteQueue _queue = TableWriteQueue();

  /// Offline yerel ayna (Parça 38) — null ise davranış eskisi gibi:
  /// sunucuya yazılamayan state DÜŞER. Üretimde her zaman verilir.
  /// `Future` çünkü depolama katmanı bootstrap'ta asenkron açılıyor ve bu
  /// repo (GamesRepo'nun aksine) senkron kuruluyor — ilk kullanımda çözülür.
  final Future<CloudSaveMirrorStore>? mirrorStore;

  Future<CloudSaveMirrorStore?> get _mirror async =>
      mirrorStore == null ? null : await mirrorStore;

  /// Son başarılı sunucu listesinin yerel kopyası (Parça 43) — YALNIZCA
  /// offline'da listeyi çizebilmek için. null ise offline davranış eskisi
  /// gibi: liste boş görünür (veri kaybı yok, ayna yine korur).
  final Future<CloudSaveCacheStore>? cacheStore;

  Future<CloudSaveCacheStore?> get _cache async =>
      cacheStore == null ? null : await cacheStore;

  /// Sunucuda silinmeyi bekleyen satırlar (Parça 46) — offline'da başarısız
  /// olan silme burada hatırlanır ve bir sonraki senkronda tekrar denenir.
  /// null ise davranış eskisi gibi: başarısız silme UNUTULUR ve sunucudaki
  /// bitmemiş kopya listeye geri gelir.
  final Future<CloudSaveDeleteQueue>? deleteQueue;

  Future<CloudSaveDeleteQueue?> get _deletes async =>
      deleteQueue == null ? null : await deleteQueue;

  Future<bool> _tryDeletes(
      Future<void> Function(CloudSaveDeleteQueue) op) async {
    try {
      final q = await _deletes;
      if (q == null) return false;
      await op(q);
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] silme kuyruğu erişilemedi: $e');
      return false;
    }
  }

  CloudSaveRepo(this.gateway,
      {int Function()? nowMs,
      this.mirrorStore,
      this.cacheStore,
      this.deleteQueue})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Depolama katmanına yapılan HER erişim buradan geçer. Gerekçe (10 Ağustos
  /// 2026, kullanıcı cihaz testinde buldu): depo açılamadığında (web
  /// derlemesinde sqflite'ın wasm/js dosyaları offline inemiyor; native'de
  /// disk dolu/bozulma) `await _mirror` FIRLIYOR. Ayna yazması `upsert`in
  /// ilk satırı ve `try`ın DIŞINDAYDI, çağrı da `unawaited` — yani hamle
  /// hem sunucuya hem aynaya yazılamıyor ve hata sessizce yutuluyordu.
  /// Ayna veri kaybını ÖNLEMEK için var; kendisi bir kayıp yoluna
  /// dönüşemez. Artık her erişim izole: başarısızlık loglanır, çağıran
  /// akış devam eder.
  Future<bool> _tryMirror(
      Future<void> Function(CloudSaveMirrorStore) op) async {
    try {
      final m = await _mirror;
      if (m == null) return false;
      await op(m);
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] yerel ayna erişilemedi: $e');
      return false;
    }
  }

  Future<bool> _tryCache(Future<void> Function(CloudSaveCacheStore) op) async {
    try {
      final c = await _cache;
      if (c == null) return false;
      await op(c);
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] bulut liste önbelleği erişilemedi: $e');
      return false;
    }
  }

  /// Bekleyen tüm yazmalar çözülene kadar (test/senkron noktaları için).
  Future<void> get idle => _queue.idle;

  /// Devam eden oyunların listesi + bu turda iddia edilen terkler. Web
  /// refreshCloudSaves'in birebir eşleniği:
  /// - bitmiş/play-dışı satır fırsatçı temizlenir, listeye girmez;
  /// - 7 günü dolmuş satır ATOMİK olarak iddia edilip silinir ve
  ///   `abandoned` listesine düşer (çağıran -2 cezalı teslim kaydına
  ///   çevirir); başka bir cihaz aynı anda iddia ettiyse claim null döner
  ///   ve satır sessizce atlanır — ceza İKİ KEZ uygulanamaz;
  /// - çözülemeyen satır atlanır, sunucuda DURUR (web'de bu dal yok çünkü
  ///   TS ayrıştırmaz; "parse, don't validate" mobil disiplini — satır bir
  ///   web oyunu için geçerli olabilir, mobilin silme/karantina hakkı yok).
  /// Ağ hatasında `_offlineList`e düşer (Parça 43): son başarılı listenin
  /// yerel önbelleği + ayna bindirmesi. Önbellek de ayna da yoksa (ör.
  /// misafir/ilk açılış) yine null döner ki UI "hiç oyunun yok" ile "liste
  /// alınamadı"yı karıştırmasın.
  /// [userId] verilirse yerel ayna listeye BİNDİRİLİR (Parça 38): aynası
  /// sunucudakinden yeniyse (offline oynanmış) aynanın state'i gösterilir,
  /// yalnızca aynada var olan oyunlar (tamamen offline açılmış) da listeye
  /// eklenir. Bindirme, terk-edilme kararından ÖNCE uygulanır — aksi halde
  /// dün offline oynanmış bir oyun, sunucudaki satırı 7 günden eski diye
  /// haksız yere -2 cezasıyla süpürülürdü.
  Future<CloudSaveList?> list({String? userId}) async {
    final Map<String, MirroredSave> mirrored = {};
    if (userId != null) {
      await _tryMirror((m) async {
        for (final x in await m.pending(userId)) {
          mirrored[x.id] = x;
        }
      });
    }
    final List<Map<String, Object?>> rows;
    try {
      rows = await _queue.read(gateway.list);
    } catch (e) {
      debugPrint('[Kelimeki] cloud save listesi alınamadı: $e');
      return _offlineList(userId, mirrored);
    }
    final cutoffMs = _nowMs() - abandonTimeout.inMilliseconds;
    final cutoffIso =
        DateTime.fromMillisecondsSinceEpoch(cutoffMs, isUtc: true)
            .toIso8601String();
    final result = <CloudSave>[];
    final abandoned = <AbandonedCloudSave>[];
    for (final row in rows) {
      final id = row['id'] as String?;
      final rawState = row['state'];
      final updatedAt = row['updated_at'] as String?;
      if (id == null || rawState is! Map || updatedAt == null) continue;
      GameState state;
      try {
        state = gameStateFromJson(rawState.cast<String, Object?>());
      } catch (e) {
        debugPrint('[Kelimeki] cloud save $id çözülemedi, atlandı: $e');
        continue;
      }
      if (state.phase != GamePhase.play || state.isGameOver) {
        unawaited(delete(id, userId: userId));
        continue;
      }
      var updatedAtMs = DateTime.parse(updatedAt).millisecondsSinceEpoch;
      // Ayna bindirmesi: offline oynanan hamleler sunucudakinden yenidir.
      final mine = mirrored.remove(id);
      if (mine != null && mine.savedAtMs > updatedAtMs) {
        state = mine.state;
        updatedAtMs = mine.savedAtMs;
      }
      if (updatedAtMs > cutoffMs) {
        result.add(CloudSave(id: id, state: state, updatedAtMs: updatedAtMs));
        continue;
      }
      // Süresi dolmuş — iddia et. Claim de kuyruktan geçer (bir silme).
      Map<String, Object?>? claimed;
      try {
        claimed = await _queue
            .enqueue(() => gateway.claimAbandoned(id, cutoffIso));
      } catch (e) {
        debugPrint('[Kelimeki] terk edilmiş kayıt iddia edilemedi: $e');
        continue;
      }
      if (claimed == null) continue; // başka cihaz aldı ya da yeniden oynandı
      // Ayna da gitmeli: aksi halde satır silindikten sonra bir sonraki
      // açılışta "yalnızca aynada var" sanılıp oyun DİRİLİR — hem ceza
      // yazılmış hem oyun devam ediyor olurdu.
      await _tryMirror((m) => m.remove(id));
      try {
        abandoned.add(AbandonedCloudSave(
          state: gameStateFromJson(claimed),
          updatedAtMs: updatedAtMs,
        ));
      } catch (e) {
        // Satır silindi ama state çözülemedi — ceza uydurulamaz.
        debugPrint('[Kelimeki] iddia edilen kayıt çözülemedi: $e');
      }
    }
    // Sunucunun HİÇ görmediği oyunlar (tamamen offline açılmış) — yalnızca
    // aynada varlar. 7 gün kuralı bunlara da işler: sunucu satırı olmadığı
    // için `claimAbandoned`la iddia edilecek bir şey yok, ama ayna zaten
    // CİHAZA ÖZEL (başka bir cihazda kopyası olamaz), dolayısıyla yarış da
    // yok — doğrudan cezaya çevirip aynayı siliyoruz.
    for (final m in mirrored.values) {
      if (m.state.phase != GamePhase.play || m.state.isGameOver) {
        await _tryMirror((x) => x.remove(m.id));
        continue;
      }
      if (m.savedAtMs > cutoffMs) {
        result.add(
            CloudSave(id: m.id, state: m.state, updatedAtMs: m.savedAtMs));
        continue;
      }
      abandoned.add(
          AbandonedCloudSave(state: m.state, updatedAtMs: m.savedAtMs));
      await _tryMirror((x) => x.remove(m.id));
    }
    result.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    // Offline'da listeyi çizebilmek için son BAŞARILI sonucu sakla. Sunucu
    // satırlarını değil BİRLEŞTİRİLMİŞ sonucu yazıyoruz — "en son bilinen
    // doğru liste" tam olarak bu; ayna bindirmesi zaten uygulanmış oluyor.
    if (userId != null) {
      await _tryCache((c) => c.replaceAll(
            userId,
            [
              for (final s in result)
                (id: s.id, state: s.state, updatedAtMs: s.updatedAtMs)
            ],
          ));
    }
    return CloudSaveList(result, abandoned);
  }

  /// Sunucuya ulaşılamadığında liste: son başarılı önbellek + ayna
  /// bindirmesi (Parça 43 — kullanıcı uçak modunda Setup'a dönünce oyunu
  /// listede GÖREMİYORDU; veri güvendeydi ama "kayboldu" gibi duruyordu).
  ///
  /// **Yalnızca aynayı göstermek YETMEZ:** o zaman offline oynanmamış
  /// diğer oyunlar listeden düşerdi — bir sorunu başkasıyla değişmiş
  /// olurduk. Önbellek ayrıca o oyunlara offline devam edebilmeyi de
  /// sağlıyor (state elimizde).
  ///
  /// **Bu dalda CEZA HİÇ uygulanmaz** (`abandoned` her zaman boş): 7 günü
  /// dolmuş bir satırın gerçekten terk edilip edilmediği sunucuyla
  /// doğrulanmadan bilinemez (başka bir cihaz oynamış olabilir), ve
  /// `claimAbandoned`ın yarış koruması offline'da çalışamaz. Süresi geçmiş
  /// satırlar listeye de ALINMAZ — kullanıcıyı, bir sonraki çevrimiçi
  /// listelemede silinecek bir oyuna devam ettirmeyelim.
  Future<CloudSaveList?> _offlineList(
      String? userId, Map<String, MirroredSave> mirrored) async {
    if (userId == null) return null;
    final byId = <String, MirroredSave>{};
    final cached = await _tryCache((c) async {
      for (final row in await c.read(userId)) {
        byId[row.id] = row;
      }
    });
    if (!cached && mirrored.isEmpty) return null;
    // Ayna KOŞULSUZ kazanır — sunucu satırıyla karşılaştırmadaki (yukarı)
    // `savedAtMs >` korumasının burada karşılığı yok ve olmamalı: orada
    // ayna BAŞKA bir cihazın yazdığı satırdan eski olabilir, burada ise
    // karşı taraf BU cihazın kendi önbelleği. Bekleyen bir ayna, tanımı
    // gereği "son başarılı yazmadan sonra yapılan ve sunucuya ulaşmayan"
    // değişikliktir; damgalar eşit olsa bile (aynı tick) ayna doğrudur.
    for (final m in mirrored.values) {
      byId[m.id] = m;
    }
    final cutoffMs = _nowMs() - abandonTimeout.inMilliseconds;
    final result = <CloudSave>[];
    for (final s in byId.values) {
      if (s.state.phase != GamePhase.play || s.state.isGameOver) continue;
      if (s.savedAtMs <= cutoffMs) continue;
      result.add(
          CloudSave(id: s.id, state: s.state, updatedAtMs: s.savedAtMs));
    }
    result.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return CloudSaveList(result, const []);
  }

  /// Bir oyunu sunucuya yazar. Web upsertLocalGameSave gibi hata YUTULUR
  /// (log + false) — autosave zinciri tek ağ hatasıyla çökmez, kuyruk da
  /// kilitlenmez (TableWriteQueue hatada durmuyor ama çağıranların çoğu
  /// fire-and-forget, fırlatan bir future "unhandled" olurdu).
  Future<bool> upsert(String id, String userId, GameState state) {
    return _queue.enqueue(() async {
      // ÖNCE yerel ayna: yerel yazma her zaman başarılı olduğundan, sunucu
      // erişilemese bile hamle kaybolmaz (Parça 38 — offline oynanan
      // hamleler sessizce düşüyordu). Sunucuya yazılınca ayna silinir, yani
      // normal (online) akışta tablo hep boş kalır.
      final mirrored = await _tryMirror((m) => m.put(id, userId, state));
      try {
        await gateway.upsert(
            id, userId, gameStateToJson(state), state.players.length);
      } catch (e) {
        if (mirrored) {
          debugPrint(
              '[Kelimeki] cloud save yazılamadı, yerel aynada bekliyor: $e');
        } else {
          // İkisi de başarısız — bu state HİÇBİR YERDE yok. Sessizce
          // yutmak, kullanıcının hamlesini kaybettiğini fark etmemesi
          // demek (10 Ağustos 2026'da tam bu yaşandı).
          debugPrint('[Kelimeki] KAYIP: ne sunucuya ne aynaya yazılabildi: $e');
        }
        return false;
      }
      await _tryMirror((m) => m.remove(id));
      return true;
    });
  }

  /// Sunucuya yazılamamış aynaları iter — uygulama açılışında/`_syncCloud`ta,
  /// listeleme YAPILMADAN ÖNCE çağrılır ki liste zaten güncel satırları
  /// görsün. Başarılı olan ayna silinir, olmayan bir sonraki tura kalır.
  /// Dönüş: gerçekten sunucuya yazılan kayıt sayısı.
  Future<int> flushMirrored(String userId) async {
    final pending = <MirroredSave>[];
    final ok = await _tryMirror((m) async {
      pending.addAll(await m.pending(userId));
    });
    if (!ok) return 0;
    final cutoffMs = _nowMs() - abandonTimeout.inMilliseconds;
    var sent = 0;
    for (final p in pending) {
      // Süresi DOLMUŞ aynayı itme: sunucu `updated_at`i bugüne çekerdi ve
      // 7 gün kuralı sessizce atlatılırdı (kullanıcı 9 Ağustos 2026'da tam
      // bu senaryoyu sordu: "oyunu açıp interneti kapatıp 10 gün sonra
      // dönersem?"). Böyle bir ayna `list()`e bırakılır; orada son
      // etkinlik anı max(sunucu, ayna) olarak değerlendirilip ceza
      // uygulanır ve ayna temizlenir.
      if (p.savedAtMs <= cutoffMs) continue;
      if (await upsert(p.id, userId, p.state)) sent++;
    }
    // Bekleyen SİLMELER de burada denenir (Parça 46) — yazmalardan SONRA,
    // çünkü silme aynayı zaten temizliyor; listeden ÖNCE, çünkü aksi halde
    // liste birazdan silinecek satırı bir kez daha gösterirdi.
    final ids = <String>[];
    await _tryDeletes((q) async => ids.addAll(await q.pending(userId)));
    for (final id in ids) {
      await delete(id, userId: userId);
    }
    return sent;
  }

  /// Sunucuya itilmeyi bekleyen ayna sayısı — Setup'ın teşhis satırı için
  /// (10 Ağustos 2026). "Hamlelerim kayboldu" tipi bir şikayette depo
  /// çalışıyor mu / ayna birikmiş mi sorusunu cihazda görünür kılıyor;
  /// bu olmadan aynı sınıf sorun ancak tahminle tartışılabiliyordu.
  ///
  /// Depoya ULAŞILAMAZSA **-1** döner, 0 DEĞİL (16 Ağustos 2026): ilk
  /// sürümde ikisi de 0'a düşüyordu, yani cihazdaki "bekleyen 0" hem
  /// "gerçekten bekleyen yok" hem "sayacı okuyamadım" anlamına
  /// gelebiliyordu — teşhis için var olan bir gösterge tam da teşhis
  /// gereken anda belirsizdi. Çağıran bunu ayrı göstermeli.
  Future<int> pendingMirrorCount(String userId) async {
    // Ayna HİÇ yapılandırılmamışsa (üretimde olmaz; testler/önizlemeler)
    // bekleyen de olamaz — bu "okuyamadım" DEĞİL, bilinen bir 0.
    if (mirrorStore == null) return 0;
    var n = 0;
    final ok =
        await _tryMirror((m) async => n = (await m.pending(userId)).length);
    return ok ? n : -1;
  }

  /// Bu id için AYNADA bekleyen (sunucuya yazılamamış) state — çağıranın
  /// elindeki satırdan GERÇEKTEN yeniyse. Yoksa null.
  ///
  /// **Neden var (16 Ağustos 2026, kullanıcı cihaz testinde buldu):** Setup
  /// listesi bir anlık görüntüdür; oyundan çıkıldıktan sonra tazelenmesi
  /// `flushMirrored`+`list()` zincirini bekler ve uçak modunda o zincirdeki
  /// ağ çağrıları saniyelerce zaman aşımına oynar. O pencerede kullanıcı
  /// AYNI satıra tekrar dokunursa oyunu BAYAT state'le açıyorduk; üstelik
  /// `CloudGameSession` kurulur kurulmaz o bayat state'i aynaya geri
  /// yazdığından (kurucudaki `_onChange()`) offline oynanan hamleler
  /// KALICI olarak siliniyordu — kullanıcının gördüğü "ilk haline geri
  /// dönüyor" tam olarak buydu.
  ///
  /// Karşılaştırma `list()`in online dalındaki kuralın AYNISI
  /// (`mine.savedAtMs > updatedAtMs`), bilerek: taze bir listede satır
  /// zaten aynadan gelmiş olur (damgalar eşit → null döner, gereksiz
  /// yeniden yükleme yok), başka bir cihazın yazdığı DAHA YENİ sunucu
  /// satırını da eski bir aynayla ezmez.
  Future<GameState?> newerPendingState(
      String id, String userId, int knownUpdatedAtMs) async {
    MirroredSave? found;
    await _tryMirror((m) async {
      for (final x in await m.pending(userId)) {
        if (x.id == id) found = x;
      }
    });
    final f = found;
    if (f == null || f.savedAtMs <= knownUpdatedAtMs) return null;
    return f.state;
  }

  /// [userId] verilirse, silme başarısız olduğunda kalıcı kuyruğa yazılır ve
  /// bir sonraki senkronda tekrar denenir (Parça 46). Verilmezse eski
  /// davranış: başarısız silme unutulur.
  Future<void> delete(String id, {String? userId}) {
    return _queue.enqueue(() async {
      // Ayna her durumda gider: satır silinmek isteniyorsa bekleyen bir
      // yazmanın onu sonradan diriltmesi istenmiyor. Önbellek de (Parça 43)
      // — aksi halde silme offline yapıldığında oyun listede görünmeye
      // devam ederdi (bir sonraki başarılı listeleme düzeltirdi ama arada
      // "sildim, hâlâ duruyor" gibi görünürdü).
      await _tryMirror((m) => m.remove(id));
      await _tryCache((c) => c.remove(id));
      try {
        await gateway.delete(id);
        await _tryDeletes((q) => q.remove(id));
      } catch (e) {
        debugPrint('[Kelimeki] cloud save silinemedi, kuyruğa alındı: $e');
        // Silinemedi: HATIRLA. Aksi halde sunucudaki (bitmemiş) eski kopya
        // bir sonraki listede "devam eden oyun" olarak geri geliyordu.
        if (userId != null) await _tryDeletes((q) => q.add(id, userId));
      }
    });
  }

  /// Misafirin tekil kaydını hesaba taşır — web'in migration effect'i
  /// (App.tsx `migratingSavedGameRef`). Kurallar birebir:
  /// - 1. oyuncunun adı hesap adıyla değiştirilir ("Sıra: Misafir" kalıcı
  ///   kalmasın — 1 Ağustos 2026 web düzeltmesi). Çağıran `accountName`'i
  ///   profil YÜKLENDİKTEN sonra vermeli (web `profileLoading` beklemesi).
  /// - Yerel kayıt YALNIZCA sunucuya yazıldığı doğrulanınca silinir; ağ
  ///   hatasında olduğu gibi kalır, sonraki denemede tekrar taşınır.
  /// - Süresi dolmuş kayıt loadSave'de zaten olaya dönüşür, taşınmaz.
  /// Dönüş: bir kayıt gerçekten taşındı mı.
  Future<bool> migrateGuestSave({
    required LocalGameRepo guestRepo,
    required String userId,
    required String? accountName,
  }) async {
    final state = await guestRepo.loadSave();
    if (state == null) return false;
    var toUpload = state;
    final p0 = state.players.isNotEmpty ? state.players[0] : null;
    if (accountName != null &&
        p0 != null &&
        !p0.isAI &&
        p0.name != accountName) {
      // GameState alanları final — isim düzeltmesi kanonik JSON üzerinden
      // (yaz → oyuncu adını değiştir → geri ayrıştır; parse yolu aynı
      // "tamamen geçerli ya da fırlatır" garantisini korur).
      final j = gameStateToJson(state);
      ((j['players'] as List).first as Map)['name'] = accountName;
      toUpload = gameStateFromJson(j.cast<String, Object?>());
    }
    final ok = await upsert(uuidV4(), userId, toUpload);
    if (!ok) {
      debugPrint('[Kelimeki] Misafir oyunu hesaba taşınamadı, tekrar denenecek.');
      return false;
    }
    await guestRepo.clearSave();
    return true;
  }
}

/// Bir GameController'ı sunucu kalıcılığına bağlar — misafir tarafındaki
/// `GameSession`'ın bulut eşleniği (web autosave effect'inin girişli dalı):
///
/// - Autosave: oyun `play` fazında ve bitmemişken her değişimde, 600ms
///   debounce ile (web'le aynı süre/gerekçe — taş seçmek dahil her dispatch
///   ağ isteği atmasın). Satır id'si İLK değişimde tembelce üretilir (web
///   activeSaveIdRef), sunucudan devam edilen oyunda `resumeSaveId` ile
///   dışarıdan verilir ki aynı satır güncellenmeye devam etsin.
/// - Oyun bitince satır silinir, bekleyen debounce iptal edilir (gecikmeli
///   bir upsert silinen satırı diriltmesin — web'in aynı sıralaması).
/// - Bilinçli çıkışta (`end`): turnCount<2 ise satır İZ BIRAKMADAN silinir
///   (web handleLogoClick'in 1 Ağustos 2026 kuralı); >=2 ise satır listede
///   kalır ve bekleyen debounce HEMEN flush edilir. Bu flush web'den küçük
///   bilinçli bir sapma: web çıkışta bekleyen debounce'u İPTAL eder (son
///   ≤600ms'lik değişiklik bir sonraki autosave'e kalır — pratikte son
///   flush'tan sonraki hamle kaybolabilir); mobilde uygulamayı kapatma daha
///   sık/sert olduğundan en güncel state aynı satıra yazılır — şema/anlam
///   farkı yok, yalnızca daha taze veri.
class CloudGameSession {
  final GameController controller;
  final CloudSaveRepo repo;
  final String userId;
  final Duration debounce;

  String? _saveId;
  Timer? _timer;
  GameState? _pending;
  bool _detached = false;

  CloudGameSession(
    this.controller,
    this.repo,
    this.userId, {
    String? resumeSaveId,
    this.debounce = const Duration(milliseconds: 600),
  }) : _saveId = resumeSaveId {
    controller.addListener(_onChange);
    _onChange(); // restore edilmiş oyun dahil mevcut state hemen kuyruklanır
  }

  /// O an sunucuda güncellenen satırın id'si (test/teşhis).
  String? get saveId => _saveId;

  void _onChange() {
    if (_detached) return;
    final s = controller.state;
    if (s.phase == GamePhase.play && !s.isGameOver) {
      _saveId ??= uuidV4();
      _pending = s;
      _timer?.cancel();
      _timer = Timer(debounce, _flush);
    } else if (s.isGameOver) {
      _cancelPending();
      final id = _saveId;
      if (id != null) {
        _saveId = null;
        unawaited(repo.delete(id, userId: userId));
      }
    }
  }

  void _flush() {
    _timer = null;
    final s = _pending;
    final id = _saveId;
    _pending = null;
    if (s == null || id == null) return;
    unawaited(repo.upsert(id, userId, s));
  }

  void _cancelPending() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  /// Bilinçli çıkış (logo/YENİ OYUN ile ekrandan ayrılma). Dönen future tüm
  /// bekleyen sunucu yazmaları bitince çözülür.
  Future<void> end() {
    final s = controller.state;
    // detach timer'ı iptal eder ama `_pending`e dokunmaz — bekleyen yazma
    // kararı ÖNCE alınır (ilk sürümde `_timer != null` detach'ten SONRA
    // kontrol ediliyordu ve flush hiç çalışmıyordu; test yakaladı).
    final hadPendingWrite = _timer != null;
    detach();
    if (s.phase == GamePhase.play &&
        !s.isGameOver &&
        s.turnCount < 2 &&
        _saveId != null) {
      // Hiç oynanmamış oyun: bekleyen upsert iptal, satır hemen silinir
      // (web handleLogoClick — debounce iptali silmeden ÖNCE, aynı sıra).
      _pending = null;
      final id = _saveId!;
      _saveId = null;
      unawaited(repo.delete(id, userId: userId));
    } else if (hadPendingWrite) {
      _flush(); // en güncel state'i aynı satıra hemen yaz (üstteki not)
    }
    return repo.idle;
  }

  void detach() {
    if (_detached) return;
    _detached = true;
    _timer?.cancel();
    _timer = null;
    controller.removeListener(_onChange);
  }
}
