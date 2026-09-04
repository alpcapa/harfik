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

import '../config/env.dart';
import '../storage/local_save_store.dart' show abandonTimeout;
import '../storage/pending_queue_store.dart';
import '../util/platform.dart';
import '../util/uuid.dart';
import 'game_record.dart';

/// Bir oyunu beğenen kullanıcı — web `GameLiker` (`game_likers` RPC'si).
/// E-posta HİÇBİR ZAMAN dönmez (projenin genel ilkesi).
class GameLiker {
  final String userId;
  final String? displayName;
  final String? firstName;
  final String? avatarUrl;

  const GameLiker({
    required this.userId,
    required this.displayName,
    required this.firstName,
    required this.avatarUrl,
  });

  /// `Leaderboard`/`PlayerScoreCard`'daki aynı kısa kimlik kuralı — soyad
  /// hiç gösterilmez (web `likerName`; yedek metni orada da 'Oyuncu').
  String get shortName => (displayName?.isNotEmpty ?? false)
      ? displayName!
      : (firstName?.isNotEmpty ?? false)
          ? firstName!
          : 'Oyuncu';

  factory GameLiker.fromJson(Map<String, Object?> j) => GameLiker(
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String?,
        firstName: j['first_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
      );
}

/// Bitmiş bir Canlı oyunun DONDURULMUŞ sohbet satırı (`games.messages`) —
/// web `GameChatMessage`. `sender_user_id` bilerek YOK: bu snapshot girişli
/// herkese açık olduğundan (`games_select_authenticated`) kimliğe geri
/// bağlanmıyor; rozet eşlemesi renk indeksi üzerinden yapılır.
class GameChatMessage {
  final String name;
  final int colorIndex;
  final String message;
  final String createdAt;

  const GameChatMessage({
    required this.name,
    required this.colorIndex,
    required this.message,
    required this.createdAt,
  });

  factory GameChatMessage.fromJson(Map<String, Object?> j) => GameChatMessage(
        name: j['name'] as String? ?? '',
        colorIndex: (j['colorIndex'] as num?)?.toInt() ?? 0,
        message: j['message'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

/// `games` tablosundaki bir satırın LİSTE görünümü — web `GameHistoryEntry`.
/// `board_snapshot` ve `messages` BİLEREK yok: satır başına birkaç KB
/// tuttuklarından liste sorgusunu şişirmesinler diye yalnızca kart
/// açılınca/rozete dokununca ayrıca çekilirler (web'in aynı kararı);
/// `messageCount` sunucuda üretilen sayaç sütunu, rozet kararı ona bakar.
class GameHistoryEntry {
  final String id;
  final String userId;
  final String createdAt; // ISO
  final int playerCount;
  final int playerScore;
  final int aiScore;
  final int? rank;
  final bool surrendered;

  /// Dolu ise Canlı (Arkadaşınla) oyun — kartta rozet ve zemin rengi buna
  /// göre değişir (web `online_game_id`).
  final String? onlineGameId;

  /// Final SIRALAMASINA göre dizili anlık görüntü; bu sütun eklenmeden
  /// önceki kayıtlarda boş (çağıran yedek satır üretir, web fallbackPlayers).
  final List<GamePlayerSnapshot> players;

  /// Bu oyunda kaç sohbet mesajı donduruldu. **10 Ağustos 2026'dan beri
  /// `games.message_count` kolonu istemci rollerinden KALDIRILDI** (bkz.
  /// `chat_count_participants_only`): "X ile Y şu oyunda N mesajlaştı" da bir
  /// üstveri ve rozet zaten yalnızca katılımcının açabildiği bir kontroldü.
  /// Değer artık `game_like_stats` toplu RPC'sinden geliyor ve
  /// katılımcı/admin değilsen 0 dönüyor → rozet hiç çizilmez. (Eski not:
  /// `games.message_count`, sunucuda
  /// üretilen sütun). >0 ise kartta sohbet rozeti çıkar. Yerel/YZ oyunlarda
  /// her zaman 0 — Oyun İçi Mesajlaşma yalnızca Canlı oyunlarda var.
  final int messageCount;

  /// İSTEĞİ YAPAN (görüntüleyen) kullanıcı bu oyunu beğendi mi — listelenen
  /// kişiden BAĞIMSIZ, böylece başkasının kartına bakarken de kalp kendi
  /// durumunu gösterir ve tıklanabilir kalır (web'in aynı kuralı).
  final bool likedByMe;

  /// Oyunu toplam kaç kullanıcı beğendi (`game_like_stats`).
  final int likeCount;

  /// Bu oyunun dondurulmuş hamle dökümü var mı (`games.moves is not null`) —
  /// hamle geçmişi ikonu YALNIZCA true iken çizilir (12 Ağustos 2026,
  /// kullanıcı "YZ oyunlarda içi boş geliyor" dedi). Döküm ~6.8 KB
  /// olduğundan liste sorgusuna girmiyor, karar `game_like_stats` toplu
  /// RPC'sinden geliyor (ek gidiş-dönüş yok).
  ///
  /// **Tür kontrolü DEĞİL:** kolon eklenmeden önce biten yerel oyunların
  /// dökümü kurtarılamıyor (bitmiş bir oyunun `moveHistory`'si hiçbir yerde
  /// saklanmıyor), Canlı oyunlar migration'da geriye dönük dolduruldu —
  /// yani bugün YZ kartlarının hepsi false, ama BUNDAN SONRA bitenler
  /// true olacak.
  final bool hasMoves;

  const GameHistoryEntry({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.playerCount,
    required this.playerScore,
    required this.aiScore,
    required this.rank,
    required this.surrendered,
    required this.onlineGameId,
    required this.players,
    this.messageCount = 0,
    this.likedByMe = false,
    this.likeCount = 0,
    this.hasMoves = false,
  });

  /// Beğeni durumunu değiştirilmiş bir kopya — hem `game_like_stats`
  /// birleştirmesi hem kalp dokunuşundaki İYİMSER güncelleme (ve hatada
  /// geri alma) bunu kullanır.
  GameHistoryEntry withLikes(
          {required bool likedByMe,
          required int likeCount,
          int? messageCount,
          bool? hasMoves}) =>
      GameHistoryEntry(
        id: id,
        userId: userId,
        createdAt: createdAt,
        playerCount: playerCount,
        playerScore: playerScore,
        aiScore: aiScore,
        rank: rank,
        surrendered: surrendered,
        onlineGameId: onlineGameId,
        players: players,
        messageCount: messageCount ?? this.messageCount,
        likedByMe: likedByMe,
        likeCount: likeCount,
        hasMoves: hasMoves ?? this.hasMoves,
      );

  /// Web `flipLike` — iyimser güncelleme; aynı çağrı geri almak için de
  /// kullanılır (kendisinin tersi).
  GameHistoryEntry flipLike() => withLikes(
        likedByMe: !likedByMe,
        likeCount: likeCount + (likedByMe ? -1 : 1),
      );

  factory GameHistoryEntry.fromJson(Map<String, Object?> j) => GameHistoryEntry(
        id: j['id'] as String,
        userId: j['user_id'] as String? ?? '',
        createdAt: j['created_at'] as String,
        playerCount: (j['player_count'] as num?)?.toInt() ?? 2,
        playerScore: (j['player_score'] as num?)?.toInt() ?? 0,
        aiScore: (j['ai_score'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt(),
        surrendered: j['surrendered'] == true,
        onlineGameId: j['online_game_id'] as String?,
        players: [
          for (final p in (j['players'] as List? ?? const []))
            GamePlayerSnapshot.fromJson((p as Map).cast<String, Object?>())
        ],
        messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
      );
}

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

  /// Anonim BAŞLANGIÇ telemetrisi (`game_starts`) — web `logGameStart`
  /// paritesi (ROADMAP #9, 21 Ağustos 2026). Admin panelindeki Kaynak
  /// Hunisi'nin "Başlayan" adımını besler.
  ///
  /// ⚠ `userId` YOK ve tabloda böyle bir kolon da YOK: `anon_id` ile hesap
  /// kimliğini aynı satırda birleştirmek gizlilik metnindeki "anonim kod
  /// hesabınızla asla eşleştirilmez" taahhüdünü bozardı.
  ///
  /// ⚠ Portun `anon_id`/`?ref=` damgası HENÜZ YOK (web'in
  /// `visitTracking.ts`inin karşılığı porta hiç girmedi), o yüzden ikisi de
  /// null gidiyor ve satır sunucuda 'bilinmiyor' kaynağına düşüyor — bu
  /// BİLİNÇLİ: 'direkt'e yazmak web'in gerçek doğrudan trafiğini şişirirdi.
  /// Port mağazaya çıkarken damgalama eklenirse burası da güncellenmeli.
  ///
  /// `is_guest` (22 Ağustos 2026) huninin "Başlayan" adımını misafire
  /// indiriyor. Bayrak PARAMETRE DEĞİL, gerçek uçta oturumdan okunuyor —
  /// webin aksine: orada `startLocalGame` TEK bir huni noktası ve `user`
  /// zaten elinde, portta ise iki ayrı ekran çağırıyor (Setup + oyun sonu
  /// "Tekrar Oyna") ve üçüncü bir çağrı yeri eklendiğinde birini atlamak
  /// sessizce eksik sayıma yol açardı.
  Future<void> logGameStart({required int playerCount});

  /// Anonim bitiş telemetrisi (`game_finishes`). Web'de olduğu gibi
  /// best-effort: hata yutulur, kuyruğa ALINMAZ.
  ///
  /// ⚠ `utm_source` null gidiyor — `logGameStart`ın aynı gerekçesi (portun
  /// `?ref=` damgası henüz yok), yani satır sunucuda 'bilinmiyor' kaynağına
  /// düşüyor. 'direkt' yazmak webin gerçek doğrudan trafiğini şişirirdi.
  ///
  /// [finishedAtMs]: bitişin gerçekten olduğu an. Verilmezse sunucunun
  /// `now()` varsayılanı kalır (normal bitişte doğrusu bu). ⚠ Terk-edilme
  /// yolunda ZORUNLU — bkz. `recordAbandoned`.
  Future<void> logGameFinish({
    required String? userId,
    required int playerCount,
    required int durationSeconds,
    required bool multiSession,
    required bool endedBySurrender,
    int? finishedAtMs,
  });

  /// `notify-local-game-abandoned` Edge Function'ı — terk edilme cezasının
  /// (-2 k-lig) e-posta bildirimi. Fire-and-forget.
  Future<void> notifyLocalGameAbandoned(String gameId, int playerCount);

  /// Oyun geçmişi sayfası — `board_snapshot` HARİÇ liste sütunları,
  /// `created_at` azalan. [playerCount] null ise filtre uygulanmaz
  /// ("Genel" sekmesinden açılan liste, web'in aynı davranışı).
  /// [onlineOnly] null: filtre yok. true: yalnızca Canlı, false: yalnızca
  /// yerel/YZ oyunları — "Son Oynadıklarım" listesi sekmesine göre süzüyor.
  Future<List<Map<String, Object?>>> listGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
    bool? onlineOnly,
  });

  /// "Favoriler" sekmesi — hedef kullanıcının SAHİP OLDUĞU değil BEĞENDİĞİ
  /// oyunlar (`list_liked_games` RPC'si; sahiplik fark etmez, sıralama
  /// beğenilme anına göre). RPC sunucu tarafında, aynı Canlı oyunun birden
  /// çok `games` satırı varsa hedefin KENDİ satırını tercih eder.
  Future<List<Map<String, Object?>>> listLikedGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
  });

  /// Bir sayfadaki tüm oyunlar için toplam beğeni sayısı + çağıranın kendi
  /// beğeni durumu + katılımcı kapılı sohbet sayacı — TEK sorgu
  /// (`game_like_stats`; adı dar kalıyor ama kartın TÜM rozetlerini besliyor,
  /// bkz. `chat_count_participants_only` migration'ının gerekçesi).
  Future<List<Map<String, Object?>>> likeStats(List<String> gameIds);

  /// Beğeniyi tersine çevirir (`toggle_game_like`). Dönüş: yeni durum.
  Future<bool> toggleLike(String gameId);

  /// Oyunu beğenenler, en yeni önce (`game_likers`).
  Future<List<Map<String, Object?>>> likers(String gameId);

  /// Tek bir oyunun tahta anlık görüntüsü — kart açılınca lazy çekilir.
  Future<List<Map<String, Object?>>?> gameBoardSnapshot(String gameId);

  /// Bir oyunun dondurulmuş tam hamle dökümü — `gameBoardSnapshot` ile aynı
  /// lazy desen (liste sorgusuna girmez, satır başına ~7 KB).
  Future<List<Map<String, Object?>>?> gameMoves(String gameId);

  /// Bitmiş bir oyunun dondurulmuş sohbeti (`games.messages`) — rozete
  /// dokununca lazy çekilir, `gameBoardSnapshot` ile aynı desen.
  /// Dondurulmuş sohbet arşivi. `allowed` İÇERİKTEN ayrı taşınır ki UI
  /// "hiç mesaj yok" ile "görme yetkin yok"u ayırt edebilsin.
  Future<({bool allowed, List<Map<String, Object?>> messages})> gameMessages(
      String gameId);

  /// Oyunu herkese açık `/game/:id` linkiyle görülebilir işaretler
  /// (`set_game_shared`) — sahiplik gerektirmez, idempotent, geri
  /// alınamaz bir bayrak.
  Future<void> markShared(String gameId);

  /// Arşiv sohbetindeki sessize alma/rapor rozetleri
  /// (`chat_flags_for_finished_game`) — kimlik istemciye hiç gelmediğinden
  /// sunucu doğrudan RENK İNDEKSİ bazında cevap döner. Katılımcı olmayan
  /// (ör. başkasının beğendiği bir oyunu açan) boş liste alır.
  Future<List<Map<String, Object?>>> chatFlags(String onlineGameId);
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
  Future<void> logGameStart({required int playerCount}) async {
    await client.from('game_starts').insert({
      'anon_id': null,
      'player_count': playerCount,
      'utm_source': null,
      // Oturum KAPALIYSA misafir başlangıcı. Sunucu `is_guest is true`
      // filtreliyor, yani yanlışlıkla null göndermek satırı sessizce
      // saydırmaz — bu yüzden değer her zaman açıkça yazılıyor.
      'is_guest': client.auth.currentUser == null,
      // Sürüm dağılımı (`admin_app_version_breakdown`, 23 Ağustos 2026):
      // zorunlu güncelleme eşiğini yükseltmenin güvenli olup olmadığını
      // gösteren TEK veri. `platform` olmadan ios ile android aynı satıra
      // düşerdi; web NULL sürüm gönderiyor, yani sürümlü satır = app.
      'platform': currentPlatform,
      'app_version': appVersion,
    });
  }

  @override
  Future<void> logGameFinish({
    required String? userId,
    required int playerCount,
    required int durationSeconds,
    required bool multiSession,
    required bool endedBySurrender,
    int? finishedAtMs,
  }) async {
    await client.from('game_finishes').insert({
      'user_id': userId,
      'player_count': playerCount,
      'duration_seconds': durationSeconds,
      'multi_session': multiSession,
      'ended_by_surrender': endedBySurrender,
      if (finishedAtMs != null)
        'created_at': DateTime.fromMillisecondsSinceEpoch(finishedAtMs)
            .toUtc()
            .toIso8601String(),
      'utm_source': null,
    });
  }

  @override
  Future<void> notifyLocalGameAbandoned(String gameId, int playerCount) async {
    await client.functions.invoke('notify-local-game-abandoned',
        body: {'game_id': gameId, 'player_count': playerCount});
  }

  /// Web ile AYNI sütun listesi (board_snapshot/messages yok — bkz.
  /// GameHistoryEntry).
  static const _listCols =
      'id, user_id, created_at, player_count, players, player_score, '
      'ai_score, rank, surrendered, online_game_id';

  @override
  Future<List<Map<String, Object?>>> listGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
    bool? onlineOnly,
  }) async {
    var q = client.from('games').select(_listCols).eq('user_id', userId);
    if (playerCount != null) q = q.eq('player_count', playerCount);
    if (onlineOnly == true) {
      q = q.not('online_game_id', 'is', null);
    } else if (onlineOnly == false) {
      q = q.isFilter('online_game_id', null);
    }
    // Web `range(offset, offset + limit)` — bir FAZLA satır ister ki
    // "daha var mı" ekstra bir count sorgusu olmadan anlaşılsın.
    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit);
    return [for (final r in rows) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<List<Map<String, Object?>>> listLikedGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
  }) async {
    // RPC'nin kendisi `p_limit`'i olduğu gibi uyguluyor; "bir fazla satır"
    // hilesi burada da geçerli olsun diye limit+1 isteniyor (web aynen böyle).
    final rows = await client.rpc('list_liked_games', params: {
      'p_user_id': userId,
      'p_player_count': playerCount,
      'p_offset': offset,
      'p_limit': limit + 1,
    });
    return [for (final r in (rows as List)) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<List<Map<String, Object?>>> likeStats(List<String> gameIds) async {
    final rows =
        await client.rpc('game_like_stats', params: {'p_game_ids': gameIds});
    return [for (final r in (rows as List)) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<bool> toggleLike(String gameId) async {
    final res =
        await client.rpc('toggle_game_like', params: {'p_game_id': gameId});
    return res == true;
  }

  @override
  Future<List<Map<String, Object?>>> likers(String gameId) async {
    final rows = await client.rpc('game_likers', params: {'p_game_id': gameId});
    return [for (final r in (rows as List)) (r as Map).cast<String, Object?>()];
  }

  @override
  Future<List<Map<String, Object?>>?> gameBoardSnapshot(String gameId) async {
    final row = await client
        .from('games')
        .select('board_snapshot')
        .eq('id', gameId)
        .maybeSingle();
    final snap = row?['board_snapshot'];
    if (snap is! List) return null;
    return [for (final t in snap) (t as Map).cast<String, Object?>()];
  }

  @override
  Future<List<Map<String, Object?>>?> gameMoves(String gameId) async {
    final row = await client
        .from('games')
        .select('moves')
        .eq('id', gameId)
        .maybeSingle();
    final moves = row?['moves'];
    if (moves is! List) return null;
    return [for (final m in moves) (m as Map).cast<String, Object?>()];
  }

  /// 10 Ağustos 2026'dan beri `games.messages` DOĞRUDAN OKUNAMIYOR: o kolon
  /// istemci rollerinden kaldırıldı (`game_chat_archive_participants_only`
  /// migration'ı), çünkü `games`in SELECT politikası satır sahipliğine değil
  /// yalnızca "oturum var mı"ya bakıyor — k-lig → oyuncu kartı → "Tüm
  /// Oyunlar" zincirinden başkasının yazışmaları okunabiliyordu. Okuma artık
  /// katılımcı/admin kapılı `game_chat_archive` RPC'sinden geçiyor.
  @override
  Future<({bool allowed, List<Map<String, Object?>> messages})> gameMessages(
      String gameId) async {
    final res =
        await client.rpc('game_chat_archive', params: {'p_game_id': gameId});
    final row = res is Map ? res.cast<String, Object?>() : null;
    final msgs = row?['messages'];
    return (
      allowed: row?['allowed'] == true,
      messages: msgs is List
          ? [for (final m in msgs) (m as Map).cast<String, Object?>()]
          : const <Map<String, Object?>>[],
    );
  }

  @override
  Future<void> markShared(String gameId) async {
    await client.rpc('set_game_shared', params: {'p_game_id': gameId});
  }

  @override
  Future<List<Map<String, Object?>>> chatFlags(String onlineGameId) async {
    final rows = await client.rpc('chat_flags_for_finished_game',
        params: {'p_online_game_id': onlineGameId});
    return [for (final r in (rows as List)) (r as Map).cast<String, Object?>()];
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
    final record =
        buildGameRecord(state, surrendered: false, newId: _newId, now: _now);
    if (record != null) await saveDurable(record);
  }

  /// 7 günü dolup terk edilmiş bir oyunun gecikmeli teslim kaydı — web
  /// refreshCloudSaves'in claim dalı ve takePendingAbandonedGame akışının
  /// ORTAK karşılığı. [endedAtMs]: kaydın son yazılma/güncellenme anı
  /// (süre bundan hesaplanır — web `updated_at - startedAt`).
  ///
  /// YALNIZCA gerçekten başlamış (turnCount >= 2) oyunlar ceza alır; hiç
  /// oynanmamış kayıt ne -2 ne telemetri üretir (web'in aynı eşiği).
  Future<void> recordAbandoned(GameState state,
      {required int endedAtMs}) async {
    if (state.turnCount < 2) return;
    // Terk anı = son etkinlik + 7 gün. Bu metodun KOŞTUĞU an DEĞİL: buraya
    // ancak kullanıcı uygulamayı yeniden açınca geliniyor ve o an haftalar
    // sonra olabilir. Damgalanmazsa bir haftalık terkler "bugün"e yazılır
    // (4 Eylül 2026, web ikizinde sahada görüldü: bir kullanıcının 19 kaydı
    // tek bir saniyeye düştü, panelde "dün 38 teslim" diye göründü).
    final finishedAtMs = endedAtMs + abandonTimeout.inMilliseconds;
    await logFinish(
      playerCount: state.players.length,
      durationSeconds: _durationSeconds(state, endedAtMs),
      multiSession: state.multiSession,
      endedBySurrender: true,
      finishedAtMs: finishedAtMs,
    );
    final record = buildGameRecord(state,
        surrendered: true,
        surrenderingIndex: 0,
        newId: _newId,
        now: _now,
        finishedAtMs: finishedAtMs);
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
    final entries =
        await queue.readAll(finishedGameKind); // TTL burada uygulanır
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

  /// Oyun geçmişi sayfası. Dönüş: o sayfanın satırları + daha var mı.
  /// Ağ hatasında boş sayfa + hasMore=false (web ile aynı: liste sessizce
  /// boş kalır, çağıran "yükleniyor"da asılı kalmaz).
  /// [favoritesOnly] true iken liste artık hedefin SAHİP OLDUĞU değil
  /// BEĞENDİĞİ oyunlardır (web'in aynı ayrımı) — kendi oyunu da başkasının
  /// oyunu da olabilir, sıralama beğenilme anına göredir.
  /// `failed`: sorgu HATA verdi (boş sonuç DEĞİL). Ayrım kullanıcıya
  /// görünür — boş liste "Henüz kayıtlı bir oyunun yok." demek, hata ise
  /// bunu demek YANLIŞ bilgi olur (çevrimdışı açan kullanıcı oyunlarının
  /// silindiğini sanır). Aynı ayrım `friends_api`/`stats_api`'de `null`
  /// dönüşüyle yapılıyor; burada sayfalama alanları da taşındığından
  /// bayrak tercih edildi (13 Ağustos 2026 denetimi, Parça 89).
  Future<({List<GameHistoryEntry> games, bool hasMore, bool failed})> history({
    required String userId,
    required int? playerCount,
    required int offset,
    int limit = 20,
    bool favoritesOnly = false,
    bool? onlineOnly,
  }) async {
    try {
      final rows = favoritesOnly
          ? await gateway.listLikedGames(
              userId: userId,
              playerCount: playerCount,
              offset: offset,
              limit: limit)
          : await gateway.listGames(
              userId: userId,
              playerCount: playerCount,
              offset: offset,
              limit: limit,
              onlineOnly: onlineOnly);
      final hasMore = rows.length > limit;
      final page = hasMore ? rows.sublist(0, limit) : rows;
      var games = [for (final r in page) GameHistoryEntry.fromJson(r)];
      games = await _mergeLikeStats(games);
      return (games: games, hasMore: hasMore, failed: false);
    } catch (e) {
      debugPrint('[Kelimeki] oyun geçmişi alınamadı: $e');
      return (games: const <GameHistoryEntry>[], hasMore: false, failed: true);
    }
  }

  /// Sayfadaki tüm oyunların beğeni sayısı + kendi beğeni durumu TEK
  /// sorguda (web `fetchMyGames`'in ikinci adımı). Misafirde hiç sorulmaz
  /// (beğeni oturum gerektirir); hata listeyi DÜŞÜRMEZ — kartlar beğenisiz
  /// gösterilir, çünkü geçmişin kendisi zaten elde.
  Future<List<GameHistoryEntry>> _mergeLikeStats(
      List<GameHistoryEntry> games) async {
    if (games.isEmpty || gateway.currentUserId == null) return games;
    try {
      final rows = await gateway.likeStats([for (final g in games) g.id]);
      final byId = <String, ({int count, bool mine, int msgs, bool moves})>{};
      for (final r in rows) {
        byId[r['game_id'] as String] = (
          count: (r['like_count'] as num?)?.toInt() ?? 0,
          mine: r['liked_by_me'] == true,
          msgs: (r['message_count'] as num?)?.toInt() ?? 0,
          moves: r['has_moves'] == true,
        );
      }
      return [
        for (final g in games)
          g.withLikes(
            likedByMe: byId[g.id]?.mine ?? false,
            likeCount: byId[g.id]?.count ?? 0,
            messageCount: byId[g.id]?.msgs ?? 0,
            hasMoves: byId[g.id]?.moves ?? false,
          )
      ];
    } catch (e) {
      debugPrint('[Kelimeki] beğeni sayıları alınamadı: $e');
      return games;
    }
  }

  /// Beğeniyi tersine çevirir. Web'le aynı sözleşme: başarısızsa `null`
  /// döner ve ÇAĞIRAN iyimser güncellemeyi geri alır (repo state tutmaz).
  Future<bool?> toggleLike(String gameId) async {
    try {
      return await gateway.toggleLike(gameId);
    } catch (e) {
      debugPrint('[Kelimeki] beğeni değiştirilemedi: $e');
      return null;
    }
  }

  /// Oyunu paylaşılabilir işaretler. Başarısızsa `false` — çağıran o
  /// durumda linksiz paylaşır (web `markGameShared` ile aynı sözleşme:
  /// link olmadan paylaşmak, hiç paylaşmamaktan iyi).
  Future<bool> markShared(String gameId) async {
    try {
      await gateway.markShared(gameId);
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] oyun paylaşıma açılamadı: $e');
      return false;
    }
  }

  /// Beğenenler listesi — hata durumunda boş liste (web davranışı).
  Future<List<GameLiker>> likers(String gameId) async {
    try {
      final rows = await gateway.likers(gameId);
      return [for (final r in rows) GameLiker.fromJson(r)];
    } catch (e) {
      debugPrint('[Kelimeki] beğenenler alınamadı: $e');
      return const [];
    }
  }

  /// Bitmiş bir oyunun dondurulmuş sohbeti. Yerel/YZ oyunlarında her zaman
  /// boş (mesajlaşma yalnızca Canlı oyunlarda var).
  Future<({bool allowed, List<GameChatMessage> messages})> messages(
      String gameId) async {
    try {
      final res = await gateway.gameMessages(gameId);
      return (
        allowed: res.allowed,
        messages: [for (final r in res.messages) GameChatMessage.fromJson(r)],
      );
    } catch (e) {
      debugPrint('[Kelimeki] sohbet kaydı alınamadı: $e');
      // Ağ/parse hatası bir YETKİ sorunu değil — kullanıcıya yanlışlıkla
      // "yetkin yok" demeyelim, boş liste göster.
      return (allowed: true, messages: const <GameChatMessage>[]);
    }
  }

  /// Arşiv sohbetindeki rozetler, renk indeksi bazında.
  Future<({Set<int> muted, Set<int> reported})> chatFlags(
      String onlineGameId) async {
    try {
      final rows = await gateway.chatFlags(onlineGameId);
      final muted = <int>{};
      final reported = <int>{};
      for (final r in rows) {
        final ci = (r['color_index'] as num?)?.toInt();
        if (ci == null) continue;
        if (r['muted'] == true) muted.add(ci);
        if (r['reported'] == true) reported.add(ci);
      }
      return (muted: muted, reported: reported);
    } catch (e) {
      debugPrint('[Kelimeki] sohbet rozetleri alınamadı: $e');
      return (muted: <int>{}, reported: <int>{});
    }
  }

  /// Tek oyunun tahtası — null: kayıt yok/eski kayıt (bu sütun eklenmeden
  /// önce oynanmış) ya da ağ hatası; çağıran üçünü de aynı "tahta
  /// görüntüsü kaydedilmemiş" hâlinde gösterir (web davranışı).
  Future<List<BoardSnapshotTile>?> boardSnapshot(String gameId) async {
    try {
      final rows = await gateway.gameBoardSnapshot(gameId);
      if (rows == null) return null;
      return [for (final r in rows) BoardSnapshotTile.fromJson(r)];
    } catch (e) {
      debugPrint('[Kelimeki] tahta görüntüsü alınamadı: $e');
      return null;
    }
  }

  /// Tek oyunun hamle dökümü.
  ///
  /// İki başarısızlık BİLİNÇLİ olarak ayrı taşınıyor (`boardSnapshot`'ın
  /// ikisini de `null`a çeken davranışından sapıyor, web'in aynı ayrımı):
  /// `ok:false` ağ/parse hatası, `ok:true` + `moves:null` ise "bu oyunda
  /// hamle dökümü hiç kaydedilmemiş" (kolon eklenmeden önce biten yerel
  /// oyun). Çevrimdışı bir kullanıcıya "kaydedilmemiş" demek yanlış olurdu —
  /// veri sunucuda duruyor, yalnızca ulaşılamıyor.
  Future<({bool ok, List<HistoryEntry>? moves})> moves(String gameId) async {
    try {
      final rows = await gateway.gameMoves(gameId);
      if (rows == null) return (ok: true, moves: null);
      return (ok: true, moves: [for (final r in rows) HistoryEntry.fromJson(r)]);
    } catch (e) {
      debugPrint('[Kelimeki] hamle geçmişi alınamadı: $e');
      return (ok: false, moves: null);
    }
  }

  /// Oyun BAŞLANGICI sayaç satırı (`game_starts`) — `logFinish`in kardeşi,
  /// aynı best-effort duruş: hata yalnızca loglanır, oyunu ASLA etkilemez.
  Future<void> logStart({required int playerCount}) async {
    try {
      await gateway.logGameStart(playerCount: playerCount);
    } catch (e) {
      debugPrint('[Kelimeki] logGameStart hatası: $e');
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
    int? finishedAtMs,
  }) async {
    try {
      await gateway.logGameFinish(
        userId: gateway.currentUserId,
        playerCount: playerCount,
        durationSeconds: durationSeconds,
        multiSession: multiSession,
        endedBySurrender: endedBySurrender,
        finishedAtMs: finishedAtMs,
      );
    } catch (e) {
      debugPrint('[Kelimeki] logGameFinish hatası: $e');
    }
  }
}
