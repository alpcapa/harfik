// Canlı oyun davet/kabul veri katmanı — web `src/lib/api.ts`'in
// `listMyOnlineGames`/`createOnlineGame`/`respondToGameInvite`/
// `fetchOnlineGameTurns`/`fetchOnlineGameGlances`/
// `checkOnlineGameTurnTimeout`/`checkInviteExpiry`/`subscribeMyOnlineGames`
// bölümünün portu (GamesRepo'daki gateway/repo bölünmesiyle). Oynanış
// (submit_move + state senkronu) `online_api.dart`ta — o dosya Canlı oyun
// tahtası parçasında büyüyecek.
//
// Web'den taşınan sözleşmeler:
// - `create_online_game` başarılı dönünce `notify-game-invite` Edge
//   Function'ı fire-and-forget çağrılır (davetliye e-posta; hata yalnız
//   loglanır — davet zaten sunucuda açıldı).
// - "Hafif süpürme" deseni: süresi ZATEN dolmuş bir sıra/davet görülürse
//   `check_turn_timeout`/`check_invite_expiry` tetiklenip liste bir kez
//   daha çekilir — asılı kalmış oyun, liste her açıldığında kendiliğinden
//   çözülür (cron yok; kök CLAUDE.md "Canlı Oyun — Faz 3.6").
// - Realtime aboneliği ÜÇ tabloda: online_games + game_invites (davet
//   akışı) + online_game_states (sıra geçişi — web 4 Ağustos dersi: hamle
//   online_games'e dokunmaz, yalnız state değişir). Tüketici 300ms
//   debounce'lamalı (web kuralı).
// - Liste hatası web'in `[]`'i yerine null döner (StatsRepo kararı — UI
//   eski listeyi korur, yanlış "hiç oyunun yok" göstermez).
import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kelimeki_core/kelimeki_core.dart'
    show HistoryEntry, LostShare, OnlineGameStatePublic, Tile, WordScore;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/game_list_order.dart';

import 'error_reporter.dart';
import 'online_api.dart';
import '../util/offline_notice.dart';
import '../util/platform.dart';
import '../util/uuid.dart';

enum OnlineGameStatus { pending, active, finished, abandoned }

OnlineGameStatus onlineStatusFromDb(String? v) => switch (v) {
      'active' => OnlineGameStatus.active,
      'finished' => OnlineGameStatus.finished,
      'abandoned' => OnlineGameStatus.abandoned,
      _ => OnlineGameStatus.pending,
    };

/// Web `OnlineGameSlot` — human koltuklar sunucu tarafında isim/avatar/
/// ilişki/davet-durumuyla zenginleştirilir; `relation=='self'` çağıranın
/// kendi koltuğu.
class OnlineSlot {
  final bool isAi;
  final String? userId;
  final String? name;
  final String? avatarUrl;
  final String? relation; // 'self' | 'accepted' | 'pending_*' | null
  final String? inviteStatus; // 'pending' | 'accepted' | 'declined' | null

  const OnlineSlot.ai()
      : isAi = true,
        userId = null,
        name = null,
        avatarUrl = null,
        relation = null,
        inviteStatus = null;

  const OnlineSlot.human({
    required this.userId,
    this.name,
    this.avatarUrl,
    this.relation,
    this.inviteStatus,
  }) : isAi = false;

  factory OnlineSlot.fromJson(Map<String, Object?> m) {
    if (m['type'] == 'ai') return const OnlineSlot.ai();
    return OnlineSlot.human(
      userId: m['user_id'] as String?,
      name: m['name'] as String?,
      avatarUrl: m['avatar_url'] as String?,
      relation: m['relation'] as String?,
      inviteStatus: m['invite_status'] as String?,
    );
  }
}

/// Web `OnlineGame` (`list_my_online_games` satırı).
class OnlineGame {
  final String id;

  /// Kurucunun `user_id`'si — **NULL OLABİLİR** (26 Ağustos 2026).
  ///
  /// `online_games.created_by` 25 Ağustos'ta `on delete cascade`'ten
  /// `on delete set null`'a çevrildi (hesap silme kaskadı, bkz.
  /// `docs/decisions/account-deletion.md`): kurucusu hesabını silmiş bir
  /// oyun SİLİNMEZ — öteki oyuncuların kaydı korunsun diye kolon NULL'a
  /// düşer. Bu alan o gün `String` olarak kaldığı için `fromJson` gerçek
  /// bir cihazda fırlattı ve [OnlineGamesRepo.load] hatayı yutup null
  /// döndürdüğünden ÜÇ alt sekme birden "Oyunların şu an yüklenemedi."
  /// gösterdi — hiçbir oyun bozuk olmadığı hâlde. Tüketiciler zaten
  /// null'a hazırdı (`creatorSlot?.name ?? 'Bir arkadaşın'`); yanlış olan
  /// yalnızca tipti.
  final String? createdBy;
  final int playerCount;
  final OnlineGameStatus status;
  final List<OnlineSlot> slots;
  final String createdAt;
  final String myRole; // 'creator' | 'invitee'
  final String? myInviteStatus;
  final String? myInviteId;

  const OnlineGame({
    required this.id,
    required this.createdBy,
    required this.playerCount,
    required this.status,
    required this.slots,
    required this.createdAt,
    required this.myRole,
    this.myInviteStatus,
    this.myInviteId,
  });

  factory OnlineGame.fromJson(Map<String, Object?> m) => OnlineGame(
        id: m['id'] as String,
        createdBy: m['created_by'] as String?,
        playerCount: (m['player_count'] as num).toInt(),
        status: onlineStatusFromDb(m['status'] as String?),
        slots: [
          for (final s in (m['slots'] as List? ?? const []))
            OnlineSlot.fromJson((s as Map).cast<String, Object?>()),
        ],
        createdAt: m['created_at'] as String,
        myRole: m['my_role'] as String,
        myInviteStatus: m['my_invite_status'] as String?,
        myInviteId: m['my_invite_id'] as String?,
      );

  /// Web `mySlotIndex` — çağıranın kendi koltuğu (`relation=='self'`).
  int get mySlotIndex => slots.indexWhere((s) => !s.isAi && s.relation == 'self');

  /// Kurucunun koltuğu — kurucu hesabını sildiyse (`createdBy == null`)
  /// null döner. `userId == createdBy` karşılaştırması NULL GÜVENLİ
  /// olmalı: iki taraf da null olabildiğinden çıplak eşitlik, kurucusu
  /// silinmiş bir oyunda rastgele bir koltuğu "kurucu" ilan ederdi.
  OnlineSlot? get creatorSlot {
    if (createdBy == null) return null;
    for (final s in slots) {
      if (!s.isAi && s.userId == createdBy) return s;
    }
    return null;
  }
}

/// Yeni oyun kurulumundaki koltuk isteği (web istemci tarafı `slots`).
class NewGameSlot {
  final String? humanUserId; // null = YZ koltuğu
  const NewGameSlot.human(String this.humanUserId);
  const NewGameSlot.ai() : humanUserId = null;

  Map<String, Object?> toJson() => humanUserId == null
      ? const {'type': 'ai'}
      : {'type': 'human', 'user_id': humanUserId};
}

class OnlineGamesSnapshot {
  final List<OnlineGame> games;

  /// gameId → sırası gelen koltuk indeksi (yalnızca aktif oyunlar).
  final Map<String, int> turns;

  /// gameId → sıradaki oyuncunun zaman aşımı son tarihi (ISO) — null olabilir.
  final Map<String, String?> deadlines;

  /// gameId → koltuk sırasıyla anlık puanlar (`online_game_states.players[]
  /// .score`) — kartın avatar şeridinin altındaki puan satırı (6 Eylül 2026,
  /// web `OnlineGameGlance.scores`). `deadlines` ile AYNI satırdan, tek
  /// istekle geliyor (`gateway.deadlines` seçimine `players` eklendi).
  final Map<String, List<int>> scores;

  const OnlineGamesSnapshot(this.games, this.turns, this.deadlines,
      [this.scores = const {}]);
}

/// `online_game_states.players` jsonb'sinden koltuk sırasıyla puanlar.
/// Eksik/bozuk eleman 0 sayılır (web `typeof p.score === 'number' ? … : 0`).
List<int> scoresFromPlayersJson(Object? players) => [
      if (players is List)
        for (final p in players)
          p is Map && p['score'] is num ? (p['score'] as num).toInt() : 0,
    ];

/// `online_game_moves` satırı (web OnlineMoveRow) — oynanış ekranının hamle
/// geçmişi ve "son hamle" mesajı bu satırlardan türetilir.
class OnlineMoveRow {
  final int turn;
  final int playerIndex;

  /// 'play' | 'pass' | 'exchange' | 'surrender'
  final String action;
  final List<String> words;
  final List<WordScore>? wordScores;
  final int points;
  final List<LostShare> lostShares;
  final int tileCount;
  final int finishJokerCount;
  final bool bingo;

  const OnlineMoveRow({
    required this.turn,
    required this.playerIndex,
    required this.action,
    required this.words,
    this.wordScores,
    required this.points,
    required this.lostShares,
    required this.tileCount,
    required this.finishJokerCount,
    required this.bingo,
  });

  factory OnlineMoveRow.fromJson(Map<String, Object?> m) => OnlineMoveRow(
        turn: (m['turn'] as num).toInt(),
        playerIndex: (m['player_index'] as num).toInt(),
        action: m['action'] as String? ?? 'play',
        words: [for (final w in (m['words'] as List? ?? const [])) w as String],
        wordScores: m['word_scores'] == null
            ? null
            : [
                for (final w in m['word_scores'] as List)
                  WordScore.fromJson((w as Map).cast<String, Object?>()),
              ],
        points: (m['points'] as num?)?.toInt() ?? 0,
        lostShares: [
          for (final s in (m['lost_shares'] as List? ?? const []))
            LostShare.fromJson((s as Map).cast<String, Object?>()),
        ],
        tileCount: (m['tile_count'] as num?)?.toInt() ?? 0,
        finishJokerCount: (m['finish_joker_count'] as num?)?.toInt() ?? 0,
        bingo: m['bingo'] as bool? ?? false,
      );
}

/// `online_game_moves` satırlarını `GameState.moveHistory` şekline çevirir —
/// web `buildMoveHistory`'nin birebir portu (reducer'ın `appendMoveHistory`
/// deseniyle aynı: bölge vergisi payları AYRI birer `invasionFrom` satırı
/// olarak eklenir, MoveHistoryModal bunları kart olarak göstermez ama
/// toplam puana katar).
List<HistoryEntry> buildMoveHistory(List<OnlineMoveRow> rows) {
  final entries = <HistoryEntry>[];
  for (final row in rows) {
    entries.add(HistoryEntry(
      turn: row.turn,
      player: row.playerIndex,
      words: row.words,
      points: row.points,
      wordScores: row.wordScores,
      finishJokerCount:
          row.finishJokerCount != 0 ? row.finishJokerCount : null,
      bingo: row.bingo,
      action: row.action != 'play' ? row.action : null,
      tileCount: row.action == 'exchange' ? row.tileCount : null,
      lostShares: row.lostShares.isNotEmpty ? row.lostShares : null,
    ));
    for (final s in row.lostShares) {
      entries.add(HistoryEntry(
        turn: row.turn,
        player: s.to,
        words: row.words,
        points: s.amount,
        invasionFrom: row.playerIndex,
      ));
    }
  }
  return entries;
}

/// Tek bir Canlı oyunun oynanış verisi — üçü BİRLİKTE çekilir (web
/// `refresh()`'in Promise.all'ı): sunucu state'i, YALNIZCA çağıranın kendi
/// rafı (`get_my_online_rack` — rakibin rafı hiçbir istemciye gitmez) ve
/// hamle geçmişi.
class OnlineGameSnapshot {
  final OnlineGameStatePublic state;
  final List<Tile> myRack;
  final List<OnlineMoveRow> moves;
  const OnlineGameSnapshot(this.state, this.myRack, this.moves);
}

abstract class OnlineGamesGateway {
  Future<List<Map<String, Object?>>> listMine();
  Future<String> create(int playerCount, List<Map<String, Object?>> slots);
  Future<void> notifyGameInvite(String gameId);
  Future<void> respondInvite(String inviteId, bool accept);
  Future<List<Map<String, Object?>>> turns(List<String> gameIds);
  Future<List<Map<String, Object?>>> deadlines(List<String> gameIds);
  Future<void> checkTurnTimeout(String gameId);
  Future<void> checkInviteExpiry(String gameId);

  /// BİTMİŞ bir oyunun ham `slots` dizisi — oyun geçmişindeki "Tekrar
  /// Oyna" rövanş kadrosunu buradan kuruyor. Web `fetchFinishedGameSlots`
  /// ikizi. Erişim yoksa ya da satır gitmişse `null`.
  Future<List<Map<String, Object?>>?> finishedGameSlots(String onlineGameId);

  /// Bitişini GÖRMEDİĞİM Canlı oyunlarımın `games.id`'leri (3 Eylül 2026).
  /// Web `fetchUnseenFinishedGames` ikizi.
  Future<List<String>> unseenFinishedGames();

  /// Biten Canlı oyun(lar)ı "gördüm" işaretler. [onlineGameId] verilirse
  /// yalnızca o oyun (bitiş modalı gösterildi), verilmezse görülmemiş
  /// TÜM oyunlar ("Son Oynananlar" sekmesi ziyaret edildi).
  Future<void> markFinishesSeen({String? onlineGameId});

  /// online_games + game_invites + online_game_states değişikliklerini
  /// dinler; dönüş aboneliği kapatır. Debounce ÇAĞIRANIN işi (web kuralı).
  ///
  /// [onResubscribe] kanal KOPUP yeniden bağlandığında çağrılır — ilk
  /// bağlanma sayılmaz. Kopuk bir kanal olay YAYINLAMAZ ve kopukken olanları
  /// sonradan oynatMAZ (web'in 28 Temmuz dersi: kaçırılan olay KALICI
  /// kayıptır), yani ağ geri geldiğinde listeyi tazeleyecek sinyal budur.
  void Function() subscribe(void Function() onChange,
      {void Function()? onResubscribe});

  // ── Oynanış (tek oyun) ──────────────────────────────────────────────────
  Future<Map<String, Object?>?> gameState(String gameId);
  Future<List<Map<String, Object?>>> myRack(String gameId);
  Future<List<Map<String, Object?>>> moves(String gameId);

  /// `play-ai-turn` Edge Function'ı — YZ'nin hamlesi TAMAMEN sunucuda
  /// hesaplanır (rafı hiçbir istemciye gitmez, web güvenlik kararı).
  Future<void> triggerAiTurn(String gameId);

  /// Bu oyunda ÇAĞIRANIN hangi istemciden oynadığını kaydeder
  /// (`online_game_clients`, oyun+kullanıcı başına tek satır, upsert).
  /// Yerelde platformu `games.platform` taşıyor ama Canlı'da o satırı SUNUCU
  /// yazdığından istemcinin kim olduğu oraya hiç ulaşmıyor — mobil lansmanı
  /// ölçülebilsin diye ayrı bir tabloya, oyun açılırken bir kez yazılır.
  /// Web `setOnlineGamePlatform` ile aynı sözleşme.
  Future<void> setPlatform(String gameId, String platform);

  Future<void> submitMove({
    required String gameId,
    required String action,
    List<Map<String, Object?>>? placements,
    List<String>? exchangeLetters,
    List<String> words,
    List<Map<String, Object?>>? wordScores,
    int basePoints,
    List<Map<String, Object?>> lostShares,
  });

  /// Yalnızca BU oyunun `online_game_states` satırını dinler.
  void Function() subscribeGame(String gameId, void Function() onChange);
}

class SupabaseOnlineGamesGateway implements OnlineGamesGateway {
  final SupabaseClient client;
  late final OnlineApi _moves = OnlineApi(client);
  SupabaseOnlineGamesGateway(this.client);

  List<Map<String, Object?>> _rows(dynamic data) => [
        for (final r in (data as List? ?? const []))
          (r as Map).cast<String, Object?>()
      ];

  @override
  Future<List<Map<String, Object?>>> listMine() async =>
      _rows(await client.rpc('list_my_online_games'));

  @override
  Future<List<String>> unseenFinishedGames() async {
    // `returns setof uuid` → düz dizi.
    final data = await client.rpc('unseen_finished_online_games');
    return [for (final r in (data as List? ?? const [])) r as String];
  }

  @override
  Future<void> markFinishesSeen({String? onlineGameId}) async {
    await client.rpc('mark_game_finishes_seen',
        params: {'p_online_game_id': onlineGameId});
  }

  @override
  Future<List<Map<String, Object?>>?> finishedGameSlots(
      String onlineGameId) async {
    // RLS (`online_games_select_party`) kapıyı zaten tutuyor: yalnızca oyunu
    // KURAN ya da davet edilmiş olan okuyabilir. Kabul edilmiş davet
    // satırları silinmediğinden davet edilen taraf da rövanş açabiliyor.
    final row = await client
        .from('online_games')
        .select('slots')
        .eq('id', onlineGameId)
        .maybeSingle();
    if (row == null) return null;
    final raw = row['slots'] as List?;
    if (raw == null || raw.isEmpty) return null;
    return [
      for (final s in raw) (s as Map).cast<String, Object?>(),
    ];
  }

  @override
  Future<String> create(
      int playerCount, List<Map<String, Object?>> slots) async {
    final id = await client.rpc('create_online_game', params: {
      'p_player_count': playerCount,
      'p_slots': slots,
    });
    return id as String;
  }

  @override
  Future<void> notifyGameInvite(String gameId) async {
    await client.functions
        .invoke('notify-game-invite', body: {'online_game_id': gameId});
  }

  @override
  Future<void> respondInvite(String inviteId, bool accept) async {
    await client.rpc('respond_to_game_invite', params: {
      'p_invite_id': inviteId,
      'p_accept': accept,
    });
  }

  @override
  Future<List<Map<String, Object?>>> turns(List<String> gameIds) async =>
      _rows(await client
          .from('online_game_states')
          .select('online_game_id, current')
          .inFilter('online_game_id', gameIds));

  @override
  Future<List<Map<String, Object?>>> deadlines(List<String> gameIds) async =>
      _rows(await client
          .from('online_game_states')
          // `players` da burada (6 Eylül 2026): puan satırı için üçüncü
          // bir `online_game_states` isteği açmak yerine aynı satırdan.
          .select('online_game_id, turn_deadline, players')
          .inFilter('online_game_id', gameIds));

  @override
  Future<void> checkTurnTimeout(String gameId) async {
    await client.rpc('check_turn_timeout', params: {'p_game_id': gameId});
  }

  @override
  Future<void> checkInviteExpiry(String gameId) async {
    await client.rpc('check_invite_expiry', params: {'p_game_id': gameId});
  }

  @override
  void Function() subscribe(void Function() onChange,
      {void Function()? onResubscribe}) {
    // Kanal adı benzersiz: Setup + (ileride) oyun ekranı aynı anda abone
    // olabilir — web'in crypto.randomUUID kanal adı kararıyla aynı gerekçe.
    final channel = client.channel('online-games-${uuidV4()}');
    for (final table in const [
      'online_games',
      'game_invites',
      'online_game_states',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onChange(),
      );
    }
    // İLK `subscribed` normal açılıştır, atlanır; sonrakiler kopup yeniden
    // bağlanmadır ve aradaki olaylar kayıptır — o yüzden tazeleme sinyali.
    var ilkBaglanti = true;
    channel.subscribe((status, _) {
      if (status != RealtimeSubscribeStatus.subscribed) return;
      if (ilkBaglanti) {
        ilkBaglanti = false;
        return;
      }
      onResubscribe?.call();
    });
    return () => client.removeChannel(channel);
  }

  @override
  Future<Map<String, Object?>?> gameState(String gameId) async {
    final row = await client
        .from('online_game_states')
        .select()
        .eq('online_game_id', gameId)
        .maybeSingle();
    return row?.cast<String, Object?>();
  }

  @override
  Future<List<Map<String, Object?>>> myRack(String gameId) async =>
      _rows(await client.rpc('get_my_online_rack', params: {
        'p_game_id': gameId,
      }));

  @override
  Future<List<Map<String, Object?>>> moves(String gameId) async => _rows(
      await client
          .from('online_game_moves')
          .select()
          .eq('online_game_id', gameId)
          .order('turn', ascending: true)
          .order('created_at', ascending: true));

  @override
  Future<void> triggerAiTurn(String gameId) async {
    await client.functions.invoke('play-ai-turn', body: {'game_id': gameId});
  }

  @override
  Future<void> setPlatform(String gameId, String platform) async {
    await client.rpc<void>('set_online_game_platform',
        params: {'p_game_id': gameId, 'p_platform': platform});
  }

  @override
  Future<void> submitMove({
    required String gameId,
    required String action,
    List<Map<String, Object?>>? placements,
    List<String>? exchangeLetters,
    List<String> words = const [],
    List<Map<String, Object?>>? wordScores,
    int basePoints = 0,
    List<Map<String, Object?>> lostShares = const [],
  }) =>
      // Mobil ağ dayanıklılığı burada: OnlineApi her çağrıya bir `p_move_id`
      // koyar ve taşıma hatalarında AYNI id ile yeniden dener (çifte hamle
      // yapısal olarak imkânsız — 20260805225619 migration'ı).
      _moves.submitMove(
        gameId: gameId,
        action: action,
        placements: placements,
        exchangeLetters: exchangeLetters,
        words: words,
        wordScores: wordScores,
        basePoints: basePoints,
        lostShares: lostShares,
      );

  @override
  void Function() subscribeGame(String gameId, void Function() onChange) {
    final channel = client.channel('online-game-$gameId-${uuidV4()}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'online_game_states',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'online_game_id',
        value: gameId,
      ),
      callback: (_) => onChange(),
    );
    channel.subscribe();
    return () => client.removeChannel(channel);
  }
}

class OnlineGamesRepo {
  final OnlineGamesGateway gateway;
  final int Function() _nowMs;
  final Future<void> Function(Duration) _delay;

  OnlineGamesRepo(this.gateway,
      {int Function()? nowMs, Future<void> Function(Duration)? delay})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _delay = delay ?? ((d) => Future<void>.delayed(d));

  /// Web `ABANDON_TIMEOUT_MS` — bekleyen davetin 7 günlük iptal penceresi.
  static const Duration inviteExpiry = Duration(days: 7);

  /// Web `RETRY_DELAYS_MS` ile AYNI gecikmeler — düşen bir istek yüzünden
  /// kullanıcıya "hiç oyunun yok" DENMEMELİ (21 Ağustos 2026 vakası: ağ
  /// değişiminde yarıda kalan istek boş liste gibi okunuyordu). Kapsam
  /// BİLEREK dar: yalnızca AĞ hatası tekrarlanır — sunucunun kendi reddi
  /// (yetki/kural) tekrar denenirse yalnızca gecikme üretir.
  static const List<Duration> retryDelays = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];

  /// Web `loadGames`: liste + sıra/son-tarih + hafif süpürme (+ gerekirse
  /// ikinci tur). Ağ hatasında null (UI eskiyi korur).
  Future<OnlineGamesSnapshot?> load() async {
    try {
      var snapshot = await _fetchWithRetry();

      final now = _nowMs();
      final expiredInvites = [
        for (final g in snapshot.games)
          if (g.status == OnlineGameStatus.pending &&
              DateTime.parse(g.createdAt).millisecondsSinceEpoch +
                      inviteExpiry.inMilliseconds <=
                  now)
            g.id
      ];
      final expiredTurns = [
        for (final g in snapshot.games)
          if (g.status == OnlineGameStatus.active)
            if (snapshot.deadlines[g.id] case final String d
                when DateTime.parse(d).millisecondsSinceEpoch <= now)
              g.id
      ];
      if (expiredInvites.isEmpty && expiredTurns.isEmpty) return snapshot;

      // Süpürme hataları listeyi düşürmez — bir sonraki açılış tekrar dener.
      await Future.wait([
        for (final id in expiredTurns)
          gateway.checkTurnTimeout(id).catchError(
              (Object e) => debugPrint('[Kelimeki] turn timeout: $e')),
        for (final id in expiredInvites)
          gateway.checkInviteExpiry(id).catchError(
              (Object e) => debugPrint('[Kelimeki] invite expiry: $e')),
      ]);
      snapshot = await _fetchWithRetry();
      return snapshot;
    } catch (e, st) {
      // TELEMETRİ ŞART (26 Ağustos 2026 dersi): burası yalnızca
      // `debugPrint`liyordu, bu yüzden `created_by` null çökmesi cihazda
      // TAMAMEN sessiz kaldı — `client_errors`ta tek satır yok, kullanıcı
      // yalnızca "yüklenemedi" gördü.
      //
      // AĞ HATASI ELENİYOR (`ErrorReporter`in "NE KAYDEDİLMEZ" kuralı):
      // `report` varsayılan `manual` türünde bu filtreyi UYGULAMAZ, çünkü
      // bazı çağrı yerlerinde sinyal tam da ağ hatasıdır. Burada değil —
      // liste zaten `_fetchWithRetry` ile iki kez denendi ve çevrimdışı
      // kullanıcı bu satıra her açılışta düşer. Kalan tek şey GERÇEK
      // kusurlar: ayrıştırma hataları, sunucu sözleşmesinin bozulması.
      debugPrint('[Kelimeki] Canlı oyun listesi alınamadı: $e');
      if (!isNetworkError(e)) {
        errorReporter.report(e, stack: st, context: 'online_games_repo.load');
      }
      return null;
    }
  }

  Future<OnlineGamesSnapshot> _fetchWithRetry() async {
    for (final gecikme in retryDelays) {
      try {
        return await _fetchOnce();
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        await _delay(gecikme);
      }
    }
    return _fetchOnce();
  }

  Future<OnlineGamesSnapshot> _fetchOnce() async {
    final rows = await gateway.listMine();
    final games = [for (final r in rows) OnlineGame.fromJson(r)];
    final activeIds = [
      for (final g in games)
        if (g.status == OnlineGameStatus.active) g.id
    ];
    if (activeIds.isEmpty) {
      return OnlineGamesSnapshot(games, const {}, const {});
    }
    final results = await Future.wait(
        [gateway.turns(activeIds), gateway.deadlines(activeIds)]);
    final turns = <String, int>{
      for (final r in results[0])
        r['online_game_id'] as String: (r['current'] as num).toInt(),
    };
    final deadlines = <String, String?>{
      for (final r in results[1])
        r['online_game_id'] as String: r['turn_deadline'] as String?,
    };
    final scores = <String, List<int>>{
      for (final r in results[1])
        r['online_game_id'] as String: scoresFromPlayersJson(r['players']),
    };
    return OnlineGamesSnapshot(games, turns, deadlines, scores);
  }

  /// Web `createOnlineGame`: RPC + davetlilere e-posta (fire-and-forget).
  /// Hatalar FIRLATILIR (form gösterir).
  Future<String> create(int playerCount, List<NewGameSlot> slots) async {
    final id = await gateway.create(
        playerCount, [for (final s in slots) s.toJson()]);
    gateway.notifyGameInvite(id).catchError(
        (Object e) => debugPrint('[Kelimeki] notifyGameInvite hatası: $e'));
    return id;
  }

  Future<void> respondInvite(String inviteId, {required bool accept}) =>
      gateway.respondInvite(inviteId, accept);

  /// Biten bir oyunun kadrosu — oyun geçmişindeki "Tekrar Oyna" için.
  ///
  /// Geçmiş kaydının kendi oyuncu anlık görüntüsü (`games.players`) yalnızca
  /// isim/skor/YZ taşıyor, **`user_id` YOK**; `create_online_game` ise koltuk
  /// başına `user_id` istiyor. Biten oyunun `online_games` satırı
  /// silinmediğinden kadro oradan çözülüyor. Erişilemezse `null` — çağıran
  /// bunu "rövanş açılamadı" olarak gösterir, sessizce yutmaz.
  Future<List<OnlineSlot>?> finishedGameSlots(String onlineGameId) async {
    final raw = await gateway.finishedGameSlots(onlineGameId);
    if (raw == null) return null;
    return [for (final m in raw) OnlineSlot.fromJson(m)];
  }

  // ── Oynanış (tek oyun) ────────────────────────────────────────────────

  /// Web `refresh()`'in veri yarısı: state + kendi rafım + hamleler TEK
  /// turda (Future.wait). Ağ hatasında null — çağıran eski ekranı korur
  /// (liste tarafındaki `load()` ile aynı sözleşme).
  Future<OnlineGameSnapshot?> loadGame(String gameId) async {
    try {
      final results = await Future.wait([
        gateway.gameState(gameId),
        gateway.myRack(gameId),
        gateway.moves(gameId),
      ]);
      final stateRow = results[0] as Map<String, Object?>?;
      if (stateRow == null) return null; // state henüz kurulmamış
      return OnlineGameSnapshot(
        OnlineGameStatePublic.fromJson(stateRow),
        [
          for (final t in results[1] as List<Map<String, Object?>>)
            Tile.fromJson(t)
        ],
        [
          for (final m in results[2] as List<Map<String, Object?>>)
            OnlineMoveRow.fromJson(m)
        ],
      );
    } catch (e) {
      debugPrint('[Kelimeki] Canlı oyun durumu alınamadı: $e');
      return null;
    }
  }

  /// 20 saniyelik tavan, web `withTimeout` ile aynı gerekçe: çağıranın
  /// "devam ediyor" bayrağı çok geç dönen bir istekte sonsuza dek askıda
  /// kalmasın (istek iptal edilmez, yalnızca bekleme kesilir).
  static const Duration _callTimeout = Duration(seconds: 20);

  Future<void> triggerAiTurn(String gameId) =>
      gateway.triggerAiTurn(gameId).timeout(_callTimeout);

  Future<void> sweepTurnTimeout(String gameId) =>
      gateway.checkTurnTimeout(gameId).timeout(_callTimeout);

  /// Platform telemetrisi — TAMAMEN fire-and-forget: bilinmeyen bir hedefte
  /// (masaüstü) hiç çağrılmaz, hata yalnızca yutulur. Bir telemetri hatası
  /// hiçbir zaman oyunu etkilememeli; sunucu tarafı da yetkisiz/geçersiz
  /// girdide sessizce no-op dönüyor.
  Future<void> reportPlatform(String gameId) async {
    final p = currentPlatform;
    if (p == null) return;
    try {
      await gateway.setPlatform(gameId, p).timeout(_callTimeout);
    } catch (_) {
      // yoksay
    }
  }

  /// Hamle gönderimi — hata FIRLATILIR (ekran mesaj satırında gösterir).
  Future<void> submitMove({
    required String gameId,
    required String action,
    List<Map<String, Object?>>? placements,
    List<String>? exchangeLetters,
    List<String> words = const [],
    List<Map<String, Object?>>? wordScores,
    int basePoints = 0,
    List<Map<String, Object?>> lostShares = const [],
  }) =>
      gateway.submitMove(
        gameId: gameId,
        action: action,
        placements: placements,
        exchangeLetters: exchangeLetters,
        words: words,
        wordScores: wordScores,
        basePoints: basePoints,
        lostShares: lostShares,
      );

  void Function() subscribeGame(String gameId, void Function() onChange) =>
      gateway.subscribeGame(gameId, onChange);

  /// Web `fetchPendingLiveGameCounts` — Setup'taki "Arkadaşınla (N)" rozeti
  /// ve girişte Canlı sekmesi varsayılanı için. `load()`'un aynı kova
  /// filtrelerini (`inviteBucket`/`myTurnCount`) yeniden kullanır — özellikle
  /// `inviteBucket`'ın `status == pending` şartı, süresi dolup iptal edilmiş
  /// bir davetin bu rozette de "hayalet" olarak sayılmasını (web 4 Ağustos
  /// 2026 dersi) önlüyor.
  ///
  /// ⚠ Ağ hatasında **`null`** döner, `0/0` DEĞİL (21 Ağustos 2026, webin
  /// `fetchPendingLiveGameCounts`'uyla aynı gerekçe): `0/0` yalnızca rozeti
  /// silmiyor, çağıranın TEK SEFERLİK giriş kararını da tüketiyordu — tek
  /// bir düşen istek "girişte doğru sekmeyi aç" kararını o oturum için
  /// kalıcı olarak yakıyordu.
  Future<PendingLiveGameCounts?> pendingCounts() async {
    final snap = await load();
    if (snap == null) return null;
    // ⚠ EN SONDA ve `load()`tan SONRA (web ikizinin aynı sırası): yukarıdaki
    // erken `return null` yolu bu isteği hiç atmıyor — sayılar zaten
    // kullanılmayacakken bir istek daha atmanın anlamı yok.
    //
    // Kendi başına düşmesi sayıları düşürMEZ: `null` döner ve çağıran son
    // bilinen rozeti korur (bkz. alanın notu).
    List<String>? unseen;
    try {
      unseen = await gateway.unseenFinishedGames();
    } catch (_) {
      unseen = null;
    }
    return PendingLiveGameCounts(
      inviteBucket(snap.games).length,
      myTurnCount(snap.games, snap.turns),
      snap.games.where((g) => g.status == OnlineGameStatus.active).length,
      finishedUnseenIds: unseen,
    );
  }

  /// Biten Canlı oyun(lar)ı "gördüm" işaretler. Dönüş: sunucuya ULAŞTI mı —
  /// `false` iken çağıran rozeti yerelde SIFIRLAMAMALI (web ikiziyle aynı
  /// gerekçe: sunucuda hâlâ görülmemiş durur, bir sonraki tazelemede geri
  /// gelip "kayboldu sonra döndü" diye tuhaf görünür).
  Future<bool> markFinishesSeen({String? onlineGameId}) async {
    try {
      await gateway.markFinishesSeen(onlineGameId: onlineGameId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class PendingLiveGameCounts {
  final int inviteCount;
  final int myTurnCount;

  /// `status == active` olan TÜM Canlı oyunlar — sırası kimde olursa olsun.
  /// Rozette KULLANILMAZ (rozet "bekleyen iş" sayar); tek tüketicisi
  /// giriş varsayılanı, bkz. [decideInitialMainView].
  final int activeCount;

  /// Bitişini GÖRMEDİĞİ Canlı oyunların `games.id`'leri (3 Eylül 2026).
  /// `null` = bilinmiyor (istek düştü) — boş liste DEĞİL.
  ///
  /// ⚠ Bu "bekleyen iş" DEĞİL, **HABER**. [inviteCount] + [myTurnCount]
  /// toplamına KATILMAZ ve katılmamalı: o toplam girişte hangi sekmenin
  /// açılacağını ([decideInitialMainView]) besliyor ve "yapacak işin var"
  /// demek; biten bir oyun yapılacak iş değil. Kullanıcı kararı (3 Eylül
  /// 2026): rozet "Arkadaşınla" sekmesine kadar çıksın, giriş kuralına
  /// dokunmasın. Web ikizi: `pendingLiveGames.ts` → `finishedUnseenIds`.
  final List<String>? finishedUnseenIds;

  const PendingLiveGameCounts(
    this.inviteCount,
    this.myTurnCount,
    this.activeCount, {
    this.finishedUnseenIds,
  });
}

/// Girişte HANGİ sekmeyle karşılanacağı — web
/// `pendingLiveGames.ts`'teki `decideInitialMainView`in birebir portu.
/// **İki taraf ELLE SENKRON; biri değişirse öteki de değişmeli.**
///
/// Dönen `null` = **HENÜZ KARAR VERME** (veri eksik). Üçüncü durum şart:
/// eksik veriyle `local` dönmek tek seferlik kararı yakıp kullanıcıyı
/// kalıcı olarak yanlış sekmede bırakırdı.
InitialMainView? decideInitialMainView(
  PendingLiveGameCounts? counts,
  List<Object?>? cloudSaves,
) {
  if (counts == null) return null;
  // (1) Canlı'da bekleyen iş varsa her hâlükârda oraya. ⚠ Bu kural
  //     `cloudSaves`e HİÇ BAKMAZ ve bakmamalı — ikisini birden beklemek
  //     gerçek bir regresyon üretiyor (bkz. web dosyasındaki not).
  if (counts.inviteCount > 0 || counts.myTurnCount > 0) {
    return InitialMainView.live;
  }
  // YALNIZCA (2) YZ listesini bilmeyi gerektiriyor.
  if (cloudSaves == null) return null;
  // (2) YZ tarafı BOŞ ve Canlı'da devam eden oyun VARSA yine oraya —
  //     sırası kendisinde olmasa bile (21 Ağustos 2026, kullanıcı isteği:
  //     hesabında 0 YZ oyunu ve 6 aktif Canlı oyun varken uygulama her
  //     açılışta BOŞ "Yapay Zeka ile" sekmesiyle karşılıyordu).
  if (cloudSaves.isEmpty && counts.activeCount > 0) {
    return InitialMainView.live;
  }
  return InitialMainView.local;
}

enum InitialMainView { local, live }

/// "Tekrar Oyna": biten bir oyunun kadrosunu AYNEN yeni bir Canlı oyuna
/// taşıyacak koltuk dizisini kurar. Sıra `create_online_game`'in üç
/// kısıtından çıkıyor: (1) ilk koltuk ÇAĞIRAN olmak zorunda — biten oyunu
/// ben kurmamış olabilirim, o yüzden kendimi başa alıyorum; (2) 4 kişilikte
/// YZ yalnız SON koltukta olabilir — insanları kendi aralarındaki sırayla
/// koruyup YZ'leri sona yazmak bunu kendiliğinden sağlıyor; (3) 2 kişilikte
/// YZ zaten olamaz (biten oyun geçerliyse yenisi de geçerli).
/// `list_my_online_games`'in eklediği name/avatar/relation alanları RPC'ye
/// GÖNDERİLMEZ — `NewGameSlot` yalnız type+user_id yazar.
///
/// ⚠ 4 Eylül 2026: imza `OnlineGame` yerine KOLTUK LİSTESİ alıyor. Sebep,
/// ikinci bir çağıranın doğması — oyun geçmişindeki "Tekrar Oyna"
/// (`game_history_modal.dart`) elinde bir `OnlineGame` DEĞİL, biten oyunun
/// ayrıca okunmuş `slots` dizisi tutuyor. Kopyalamak yerine imza daraltıldı;
/// web ikizi de aynı gün aynı sebeple `src/utils/rematchSlots.ts`e çıkarıldı.
List<NewGameSlot> rematchSlots(List<OnlineSlot> slots, String myUserId) => [
      NewGameSlot.human(myUserId),
      for (final s in slots)
        if (!s.isAi && s.userId != null && s.userId != myUserId)
          NewGameSlot.human(s.userId!),
      for (final s in slots)
        if (s.isAi) const NewGameSlot.ai(),
    ];

// ── Kova filtreleri + süre etiketleri (web LiveGamesTab'ın saf mantığı) ────

/// Yanıt bekleyen davetler. `status == pending` ŞART — web 4 Ağustos 2026
/// dersi: `check_invite_expiry` yalnızca online_games.status'u değiştirir,
/// game_invites satırına dokunmaz; bu şart olmadan iptal edilmiş davet
/// davetlinin listesinde sonsuza dek kalır.
/// Davet süresi `created_at + ABANDON_TIMEOUT_MS`'ten işlediğinden EN ESKİ
/// davet bitmeye en yakın olandır (bkz. `remainingInviteLabel`).
int? _davetBitis(OnlineGame g) =>
    DateTime.tryParse(g.createdAt)?.millisecondsSinceEpoch;

/// Yanıt bekleyen davetler — **süresi bitmeye en yakın ÜSTTE** (3 Eylül
/// 2026, kullanıcı isteği). Öncesinde sıra `list_my_online_games`in
/// `created_at desc`iydi, yani TAM TERSİ: en yakın biten en altta.
List<OnlineGame> inviteBucket(List<OnlineGame> games) => orderByExpiry([
      for (final g in games)
        if (g.myRole == 'invitee' &&
            g.myInviteStatus == 'pending' &&
            g.status == OnlineGameStatus.pending)
          g
    ], _davetBitis);

/// Aktif oyunlar — sırası çağıranda olanlar üstte, sonra SON OYNANAN üstte
/// (web'in `LiveGamesTab`'ıyla birebir aynı ölçütler).
///
/// ⚠ 31 Ağustos 2026 — ikinci ölçüt (`deadlines`) EKLENDİ. Öncesinde yalnızca
/// "sıra bende" vardı ve geri kalan sıra `games`'in geldiği sıraya
/// bırakılmıştı; o sıra `list_my_online_games` RPC'sinde
/// `order by og.created_at desc`, yani oyunun KURULMA sırası — son oynanan
/// oyun listede yerinde kalıyordu (kullanıcı web'de bildirdi).
/// Ölçüt `turn_deadline`: `submit_move` her hamlede onu `now() + 48 saat`
/// yapıyor, dolayısıyla deadline'ı geç olan = son oynanan.
List<OnlineGame> activeBucket(
  List<OnlineGame> games,
  Map<String, int> turns, {
  Map<String, String?> deadlines = const {},
}) {
  // ⚠ `sonHamle` null döner, 0 DEĞİL: 0 yalnızca AZALAN sıralamada
  // zararsızdı (dibe düşerdi). "Sıra bende" grubu 3 Eylül 2026'da ARTANA
  // çevrilince 0 "en yakın bitiş" sanılıp EN ÜSTE çıkardı.
  return orderActiveGames(
    [
      for (final g in games)
        if (g.status == OnlineGameStatus.active) g
    ],
    myTurn: (g) => turns[g.id] == g.mySlotIndex,
    deadlineMs: (g) {
      final d = deadlines[g.id];
      return d == null ? null : DateTime.tryParse(d)?.millisecondsSinceEpoch;
    },
  );
}

/// Rakip bekleyen kendi oyunlarım — davetlerle AYNI ölçüt (aynı kartı ve
/// aynı süre etiketini paylaşıyorlar).
List<OnlineGame> waitingBucket(List<OnlineGame> games) => orderByExpiry([
      for (final g in games)
        if (g.myRole == 'creator' && g.status == OnlineGameStatus.pending) g
    ], _davetBitis);

/// Kabul ettim, öteki davetliler bekleniyor — yine aynı ölçüt.
List<OnlineGame> acceptedWaitingBucket(List<OnlineGame> games) =>
    orderByExpiry([
      for (final g in games)
        if (g.myRole == 'invitee' &&
            g.myInviteStatus == 'accepted' &&
            g.status == OnlineGameStatus.pending)
          g
    ], _davetBitis);

int myTurnCount(List<OnlineGame> games, Map<String, int> turns) =>
    activeBucket(games, turns)
        .where((g) => turns[g.id] == g.mySlotIndex)
        .length;

class RemainingLabel {
  final String text;
  final bool urgent;
  const RemainingLabel(this.text, this.urgent);
}

/// Web `remainingTimeLabel` — 48 saatlik sıra zaman aşımına kalan süre.
RemainingLabel? remainingTimeLabel(String? deadline, int nowMs) {
  if (deadline == null) return null;
  final ms = DateTime.parse(deadline).millisecondsSinceEpoch - nowMs;
  if (ms <= 0) return const RemainingLabel('Süresi doldu - teslim oldu', true);
  final totalMinutes = (ms / 60000).ceil();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  // ⚠ Fiil DÜŞTÜ (30 Ağustos 2026, kullanıcı isteği) — üç sayaç da yalnızca
  // "… kaldı" diyor. Gerekçe web ikizinde yazılı.
  // Parantez içindeki sonuç (30 Ağustos 2026, kullanıcı isteği) — fiil
  // metinden çıkarılınca kaybolan bilgiyi ceza MİKTARIYLA geri getiriyor.
  final text = hours > 0
      ? '$hours saat $minutes dk sonra teslim (-2 puan)'
      : '$minutes dk sonra teslim (-2 puan)';
  return RemainingLabel(text, totalMinutes < 24 * 60);
}

/// Web `remainingInviteDays` — 7 günlük davet iptal penceresine kalan süre.
RemainingLabel remainingInviteLabel(String createdAt, int nowMs) {
  final ms = DateTime.parse(createdAt).millisecondsSinceEpoch +
      OnlineGamesRepo.inviteExpiry.inMilliseconds -
      nowMs;
  if (ms <= 0) return const RemainingLabel('Süresi doldu', true);
  final totalMinutes = (ms / 60000).ceil();
  final totalHours = totalMinutes ~/ 60;
  final days = totalHours ~/ 24;
  final hours = totalHours % 24;
  final minutes = totalMinutes % 60;
  final text = days > 0
      ? '$days gün $hours saat kaldı'
      : '$hours saat $minutes dakika kaldı';
  return RemainingLabel(text, days < 1);
}

/// Web `statusLabel`.
///
/// ⚠ Aktif oyunun iki etiketi KAYNAKTA BÜYÜK HARFLE (30 Ağustos 2026,
/// kullanıcı isteği). Çağıran zaten `trUpper`dan geçiriyor — idempotent;
/// web tarafında ise CSS `uppercase`in Türkçe i→İ duyarlılığına
/// güvenilmesin diye böyle yazıldı, iki taraf aynı dizeyi taşısın.
String onlineStatusLabel(OnlineGame g, {bool? isMyTurn}) =>
    switch (g.status) {
      OnlineGameStatus.active =>
        // ⚠ Ok (`>`) bu dizede DEĞİL — ayrı ve daha BÜYÜK bir span olarak
        // çiziliyor (`kTurnArrow*`, `live_games_tab.dart`); gerekçe orada.
        isMyTurn == true ? 'SIRA SENDE' : 'SIRA RAKİPTE',
      OnlineGameStatus.pending => 'Rakip bekleniyor',
      OnlineGameStatus.finished => 'Bitti',
      OnlineGameStatus.abandoned => 'Terk edildi',
    };

/// Web `participantLabel` — davet kartındaki katılımcı durumu.
String participantLabel(OnlineSlot slot, OnlineGame game) {
  // Null güvenli: kurucusu silinmiş oyunda (createdBy == null) userId'si
  // olmayan bir koltuk yanlışlıkla 'Davet gönderen' etiketi almasın.
  if (game.createdBy != null && slot.userId == game.createdBy) {
    return 'Davet gönderen';
  }
  if (slot.inviteStatus == 'accepted') return 'Kabul etti';
  if (slot.inviteStatus == 'declined') return 'Reddetti';
  return 'Bekliyor';
}
