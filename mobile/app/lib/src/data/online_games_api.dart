// Canlı oyun davet/kabul veri katmanı — web `src/lib/api.ts`'in
// `listMyOnlineGames`/`createOnlineGame`/`respondToGameInvite`/
// `fetchOnlineGameTurns`/`fetchOnlineGameDeadlines`/
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
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String createdBy;
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
        createdBy: m['created_by'] as String,
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

  OnlineSlot? get creatorSlot {
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

  const OnlineGamesSnapshot(this.games, this.turns, this.deadlines);
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

  /// online_games + game_invites + online_game_states değişikliklerini
  /// dinler; dönüş aboneliği kapatır. Debounce ÇAĞIRANIN işi (web kuralı).
  void Function() subscribe(void Function() onChange);
}

class SupabaseOnlineGamesGateway implements OnlineGamesGateway {
  final SupabaseClient client;
  SupabaseOnlineGamesGateway(this.client);

  List<Map<String, Object?>> _rows(dynamic data) => [
        for (final r in (data as List? ?? const []))
          (r as Map).cast<String, Object?>()
      ];

  @override
  Future<List<Map<String, Object?>>> listMine() async =>
      _rows(await client.rpc('list_my_online_games'));

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
          .select('online_game_id, turn_deadline')
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
  void Function() subscribe(void Function() onChange) {
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
    channel.subscribe();
    return () => client.removeChannel(channel);
  }
}

class OnlineGamesRepo {
  final OnlineGamesGateway gateway;
  final int Function() _nowMs;

  OnlineGamesRepo(this.gateway, {int Function()? nowMs})
      : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Web `ABANDON_TIMEOUT_MS` — bekleyen davetin 7 günlük iptal penceresi.
  static const Duration inviteExpiry = Duration(days: 7);

  /// Web `loadGames`: liste + sıra/son-tarih + hafif süpürme (+ gerekirse
  /// ikinci tur). Ağ hatasında null (UI eskiyi korur).
  Future<OnlineGamesSnapshot?> load() async {
    try {
      var snapshot = await _fetchOnce();

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
      snapshot = await _fetchOnce();
      return snapshot;
    } catch (e) {
      debugPrint('[Kelimeki] Canlı oyun listesi alınamadı: $e');
      return null;
    }
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
    return OnlineGamesSnapshot(games, turns, deadlines);
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
}

// ── Kova filtreleri + süre etiketleri (web LiveGamesTab'ın saf mantığı) ────

/// Yanıt bekleyen davetler. `status == pending` ŞART — web 4 Ağustos 2026
/// dersi: `check_invite_expiry` yalnızca online_games.status'u değiştirir,
/// game_invites satırına dokunmaz; bu şart olmadan iptal edilmiş davet
/// davetlinin listesinde sonsuza dek kalır.
List<OnlineGame> inviteBucket(List<OnlineGame> games) => [
      for (final g in games)
        if (g.myRole == 'invitee' &&
            g.myInviteStatus == 'pending' &&
            g.status == OnlineGameStatus.pending)
          g
    ];

/// Aktif oyunlar — sırası çağıranda olanlar üstte (web'in kararlı sort'u).
List<OnlineGame> activeBucket(List<OnlineGame> games, Map<String, int> turns) {
  final active = [
    for (final g in games)
      if (g.status == OnlineGameStatus.active) g
  ];
  int myTurn(OnlineGame g) => turns[g.id] == g.mySlotIndex ? 1 : 0;
  // Dart List.sort kararlı DEĞİL (core sözleşmeleri) — indeks tie-break.
  final indexed = active.asMap().entries.toList()
    ..sort((a, b) {
      final d = myTurn(b.value) - myTurn(a.value);
      return d != 0 ? d : a.key - b.key;
    });
  return [for (final e in indexed) e.value];
}

List<OnlineGame> waitingBucket(List<OnlineGame> games) => [
      for (final g in games)
        if (g.myRole == 'creator' && g.status == OnlineGameStatus.pending) g
    ];

List<OnlineGame> acceptedWaitingBucket(List<OnlineGame> games) => [
      for (final g in games)
        if (g.myRole == 'invitee' &&
            g.myInviteStatus == 'accepted' &&
            g.status == OnlineGameStatus.pending)
          g
    ];

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
  final text = hours > 0
      ? '$hours saat $minutes dakika sonra teslim sayılacak'
      : '$minutes dakika sonra teslim sayılacak';
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
      ? '$days gün $hours saat sonra iptal edilecek'
      : '$hours saat $minutes dakika sonra iptal edilecek';
  return RemainingLabel(text, days < 1);
}

/// Web `statusLabel`.
String onlineStatusLabel(OnlineGame g, {bool? isMyTurn}) =>
    switch (g.status) {
      OnlineGameStatus.active => isMyTurn == true
          ? 'Senin Hamlen Bekleniyor'
          : 'Rakibin hamlesi bekleniyor',
      OnlineGameStatus.pending => 'Rakip bekleniyor',
      OnlineGameStatus.finished => 'Bitti',
      OnlineGameStatus.abandoned => 'Terk edildi',
    };

/// Web `participantLabel` — davet kartındaki katılımcı durumu.
String participantLabel(OnlineSlot slot, OnlineGame game) {
  if (slot.userId == game.createdBy) return 'Davet gönderen';
  if (slot.inviteStatus == 'accepted') return 'Kabul etti';
  if (slot.inviteStatus == 'declined') return 'Reddetti';
  return 'Bekliyor';
}
