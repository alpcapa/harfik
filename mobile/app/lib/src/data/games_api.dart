// Bitmiş oyun kayıtlarının sunucu tarafı — web `saveGame`/`logGameFinish`
// (src/lib/api.ts) + `saveGameDurable`/`flushPendingGames` (gameSync.ts)
// portu.
//
// Katmanlar:
// - `GamesGateway` — üç ağ çağrısının soyutlaması (insert / telemetri /
//   terk-edilme bildirimi). Gerçek uç `SupabaseGamesGateway` cihazda
//   doğrulanır; testler sahteyle TÜM dayanıklılık mantığını sınar.
// - `GamesRepo` — politika: dayanıklı gönderim (başarısızsa kuyruk),
//   kuyruk flush'ı, 23505 idempotency'si.
//
// Kuyruk deposu zaten var (`PendingQueueStore`, `finished-game` türü):
// istemci üretimli id (sunucudaki 23505 dedup'ıyla EŞLEŞİR), tür başına 300
// sınırı, okumada 7 günlük TTL.
import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/pending_queue_store.dart';
import '../util/uuid.dart';
import 'game_record.dart';

abstract class GamesGateway {
  /// Oturum açan kullanıcının id'si — yoksa null (misafir). Web
  /// `saveGame`'in `auth.getUser()` adımı ve `hasLocalSession()`
  /// kontrolünün ortak karşılığı; AĞA ÇIKMAZ (yerel oturum deposu).
  String? get currentUserId;

  /// `games` tablosuna satır ekler. Dönüş: sunucudaki satır id'si.
  /// Aynı `id` ikinci kez gönderilirse (kayıp yanıt sonrası tekrar deneme)
  /// unique violation'ı BAŞARI sayıp aynı id'yi döner, ama
  /// [alreadyExisted]'ı true yapar — çağıran bildirimi tekrar göndermesin.
  Future<({String id, bool alreadyExisted})> insertGame(
      Map<String, Object?> row, String userId);

  /// Anonim bitiş telemetrisi (`game_finishes`). Web'de olduğu gibi
  /// best-effort: hata yutulur, kuyruğa ALINMAZ.
  Future<void> logGameFinish({
    required String? userId,
    required int playerCount,
    required int durationSeconds,
    required bool multiSession,
    required bool endedBySurrender,
  });

  /// `notify-local-game-abandoned` Edge Function'ı — terk edilme cezasının
  /// (-2 k-lig) e-posta bildirimi. Fire-and-forget.
  Future<void> notifyLocalGameAbandoned(String gameId, int playerCount);
}

class SupabaseGamesGateway implements GamesGateway {
  final SupabaseClient client;
  SupabaseGamesGateway(this.client);

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Future<({String id, bool alreadyExisted})> insertGame(
      Map<String, Object?> row, String userId) async {
    try {
      final data = await client
          .from('games')
          .insert({...row, 'user_id': userId})
          .select('id')
          .single();
      return (id: data['id'] as String, alreadyExisted: false);
    } on PostgrestException catch (e) {
      // 23505 = unique violation: bu id zaten kaydedilmiş (kayıp yanıttan
      // sonra tekrar deneme). Web `saveGame` ile aynı: BAŞARI sayılır.
      if (e.code == '23505') {
        return (id: row['id'] as String, alreadyExisted: true);
      }
      rethrow;
    }
  }

  @override
  Future<void> logGameFinish({
    required String? userId,
    required int playerCount,
    required int durationSeconds,
    required bool multiSession,
    required bool endedBySurrender,
  }) async {
    await client.from('game_finishes').insert({
      'user_id': userId,
      'player_count': playerCount,
      'duration_seconds': durationSeconds,
      'multi_session': multiSession,
      'ended_by_surrender': endedBySurrender,
    });
  }

  @override
  Future<void> notifyLocalGameAbandoned(String gameId, int playerCount) async {
    await client.functions.invoke('notify-local-game-abandoned',
        body: {'game_id': gameId, 'player_count': playerCount});
  }
}

class GamesRepo {
  final GamesGateway gateway;
  final PendingQueueStore queue;
  final String Function() _newId;
  final DateTime Function() _now;

  GamesRepo(
    this.gateway,
    this.queue, {
    String Function()? newId,
    DateTime Function()? now,
  })  : _newId = newId ?? uuidV4,
        _now = now ?? DateTime.now;

  /// Normal biten bir oyunun kaydı — web'in oyun-bitti effect'i:
  /// `buildGameRecord(state, false)` + `saveGameDurable` + `logGameFinish`.
  /// 1. koltuk zaten teslim olmuşsa kayıt o an tutulmuştur, tekrar
  /// kaydedilmez (web'in `players[0].surrendered` koruması).
  Future<void> recordFinished(GameState state) async {
    if (state.players.isNotEmpty && state.players[0].surrendered) return;
    await logFinish(
      playerCount: state.players.length,
      durationSeconds: _durationSeconds(state, _now().millisecondsSinceEpoch),
      multiSession: state.multiSession,
      endedBySurrender: state.endReason == EndReason.surrender,
    );
    final record = buildGameRecord(state,
        surrendered: false, newId: _newId, now: _now);
    if (record != null) await saveDurable(record);
  }

  /// 7 günü dolup terk edilmiş bir oyunun gecikmeli teslim kaydı — web
  /// refreshCloudSaves'in claim dalı ve takePendingAbandonedGame akışının
  /// ORTAK karşılığı. [endedAtMs]: kaydın son yazılma/güncellenme anı
  /// (süre bundan hesaplanır — web `updated_at - startedAt`).
  ///
  /// YALNIZCA gerçekten başlamış (turnCount >= 2) oyunlar ceza alır; hiç
  /// oynanmamış kayıt ne -2 ne telemetri üretir (web'in aynı eşiği).
  Future<void> recordAbandoned(GameState state, {required int endedAtMs}) async {
    if (state.turnCount < 2) return;
    await logFinish(
      playerCount: state.players.length,
      durationSeconds: _durationSeconds(state, endedAtMs),
      multiSession: state.multiSession,
      endedBySurrender: true,
    );
    final record = buildGameRecord(state,
        surrendered: true, surrenderingIndex: 0, newId: _newId, now: _now);
    if (record != null) await saveDurable(record);
  }

  static int _durationSeconds(GameState state, int endedAtMs) {
    final started = DateTime.tryParse(state.startedAt)?.millisecondsSinceEpoch;
    if (started == null) return 0;
    final s = ((endedAtMs - started) / 1000).round();
    return s < 0 ? 0 : s;
  }

  /// Web `saveGameDurable`: önce hemen göndermeyi dener; olmazsa
  /// (misafir/offline/ağ hatası) kuyruğa alır — kişi bu cihazda 7 gün
  /// içinde giriş yaparsa `flushPending` hepsini o hesaba aktarır.
  Future<void> saveDurable(NewGameRecord record) async {
    if (await _trySend(record)) return;
    await queue.enqueue(
      kind: finishedGameKind,
      id: record.id,
      payload: record.toJson(),
    );
  }

  /// Kuyruktaki bekleyen kayıtları göndermeyi dener. Bu cihazda oturum
  /// yoksa AĞA HİÇ DOKUNMADAN çıkar (web `hasLocalSession` kısayolu) —
  /// kuyruk kişi giriş yapana kadar sessizce bekler. Dönüş: gönderilen
  /// kayıt sayısı.
  Future<int> flushPending() async {
    if (_flushing) return 0;
    if (gateway.currentUserId == null) return 0;
    final entries = await queue.readAll(finishedGameKind); // TTL burada uygulanır
    if (entries.isEmpty) return 0;
    _flushing = true;
    var sent = 0;
    try {
      for (final e in entries) {
        final NewGameRecord record;
        try {
          record = NewGameRecord.fromJson(e.payload);
        } catch (err) {
          // Çözülemeyen kayıt sonsuza dek kuyruğu tıkamasın — düşür.
          debugPrint('[Kelimeki] bozuk kuyruk kaydı düşürüldü: $err');
          await queue.remove(e.id);
          continue;
        }
        if (await _trySend(record)) {
          await queue.remove(e.id);
          sent++;
        }
        // Başarısızsa kayıt kuyrukta KALIR (sonraki flush'ta tekrar denenir).
      }
    } finally {
      _flushing = false;
    }
    return sent;
  }

  bool _flushing = false;

  Future<bool> _trySend(NewGameRecord record) async {
    final userId = gateway.currentUserId;
    if (userId == null) return false; // misafir — kuyrukta beklesin
    try {
      final res = await gateway.insertGame(record.toJson(), userId);
      // Terk-edilme cezası bildirimi YALNIZCA gerçek ilk insert'te
      // (web: 23505 dalında çağrılmıyor ki kuyruktan tekrar denenen bir
      // kayıt aynı kişiye mükerrer "-2 puan" maili göndermesin).
      if (record.surrendered && !res.alreadyExisted) {
        unawaited(gateway
            .notifyLocalGameAbandoned(res.id, record.playerCount)
            .catchError((Object e) =>
                debugPrint('[Kelimeki] terk bildirimi gönderilemedi: $e')));
      }
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] oyun kaydı gönderilemedi: $e');
      return false;
    }
  }

  /// Anonim bitiş telemetrisi — web gibi best-effort (kuyruğa alınmaz;
  /// bir kerelik ağ hatasında sayaç satırı kaybolur, kabul edilmiş bir
  /// davranış: kök CLAUDE.md, `game_finishes` rollout notu).
  Future<void> logFinish({
    required int playerCount,
    required int durationSeconds,
    required bool multiSession,
    required bool endedBySurrender,
  }) async {
    try {
      await gateway.logGameFinish(
        userId: gateway.currentUserId,
        playerCount: playerCount,
        durationSeconds: durationSeconds,
        multiSession: multiSession,
        endedBySurrender: endedBySurrender,
      );
    } catch (e) {
      debugPrint('[Kelimeki] logGameFinish hatası: $e');
    }
  }
}
