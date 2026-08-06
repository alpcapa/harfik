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

  CloudSaveRepo(this.gateway, {int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

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
  /// Ağ hatasında boş liste yerine null döner ki UI "hiç oyunun yok" ile
  /// "liste alınamadı"yı karıştırmasın.
  Future<CloudSaveList?> list() async {
    final List<Map<String, Object?>> rows;
    try {
      rows = await _queue.read(gateway.list);
    } catch (e) {
      debugPrint('[Kelimeki] cloud save listesi alınamadı: $e');
      return null;
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
      final GameState state;
      try {
        state = gameStateFromJson(rawState.cast<String, Object?>());
      } catch (e) {
        debugPrint('[Kelimeki] cloud save $id çözülemedi, atlandı: $e');
        continue;
      }
      if (state.phase != GamePhase.play || state.isGameOver) {
        unawaited(delete(id));
        continue;
      }
      final updatedAtMs = DateTime.parse(updatedAt).millisecondsSinceEpoch;
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
    return CloudSaveList(result, abandoned);
  }

  /// Bir oyunu sunucuya yazar. Web upsertLocalGameSave gibi hata YUTULUR
  /// (log + false) — autosave zinciri tek ağ hatasıyla çökmez, kuyruk da
  /// kilitlenmez (TableWriteQueue hatada durmuyor ama çağıranların çoğu
  /// fire-and-forget, fırlatan bir future "unhandled" olurdu).
  Future<bool> upsert(String id, String userId, GameState state) {
    return _queue.enqueue(() async {
      try {
        await gateway.upsert(
            id, userId, gameStateToJson(state), state.players.length);
        return true;
      } catch (e) {
        debugPrint('[Kelimeki] cloud save yazılamadı: $e');
        return false;
      }
    });
  }

  Future<void> delete(String id) {
    return _queue.enqueue(() async {
      try {
        await gateway.delete(id);
      } catch (e) {
        debugPrint('[Kelimeki] cloud save silinemedi: $e');
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
        unawaited(repo.delete(id));
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
      unawaited(repo.delete(id));
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
