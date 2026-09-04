// `GamesGateway`'in bellek içi sahtesi — üç test dosyası paylaşır
// (game_record, local_game_repo, setup_cloud). Gerçek uç
// (`SupabaseGamesGateway`) cihazda doğrulanır.
import 'package:kelimeki/src/data/games_api.dart';

class FakeGamesGateway implements GamesGateway {
  /// null = misafir (oturum yok) — flush ağa hiç dokunmaz.
  String? userId;
  final inserted = <Map<String, Object?>>[];
  final starts = <Map<String, Object?>>[];
  final finishes = <Map<String, Object?>>[];
  final notified = <({String gameId, int playerCount})>[];

  /// Bir sonraki insert ağ hatasıyla düşsün (kuyruk davranışı testi).
  bool failNextInsert = false;

  FakeGamesGateway({this.userId});

  Map<String, Object?>? rowById(String id) {
    for (final r in inserted) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  @override
  String? get currentUserId => userId;

  @override
  Future<({String id, bool alreadyExisted})> insertGame(
      Map<String, Object?> row, String uid) async {
    if (failNextInsert) {
      failNextInsert = false;
      throw Exception('ağ hatası');
    }
    final id = row['id'] as String;
    if (rowById(id) != null) {
      return (id: id, alreadyExisted: true); // sunucudaki 23505 eşleniği
    }
    inserted.add({...row, 'user_id': uid});
    return (id: id, alreadyExisted: false);
  }

  @override
  Future<void> logGameStart({required int playerCount}) async {
    starts.add({'player_count': playerCount});
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
    finishes.add({
      'user_id': userId,
      'player_count': playerCount,
      'duration_seconds': durationSeconds,
      'multi_session': multiSession,
      'ended_by_surrender': endedBySurrender,
      // ⚠ Sahte uç bu alanı KAYDETMEK ZORUNDA: terk kaydının doğru güne
      // yazıldığını yalnızca burası görebiliyor (gerçek uçta `created_at`
      // olarak gidiyor).
      'finished_at_ms': finishedAtMs,
    });
  }

  @override
  Future<void> notifyLocalGameAbandoned(String gameId, int playerCount) async {
    notified.add((gameId: gameId, playerCount: playerCount));
  }

  // ── Okuma ucu (parça 5a: oyun geçmişi) ────────────────────────────────
  /// Geçmiş listesi kaynağı — `created_at` azalan verilmeli (gerçek uç
  /// sıralamayı sunucuda yapıyor).
  List<Map<String, Object?>> history = const [];

  /// gameId → tahta anlık görüntüsü; anahtarı olmayan oyun "kaydedilmemiş"
  /// sayılır (eski kayıt), null döner.
  Map<String, List<Map<String, Object?>>> snapshots = const {};

  final listCalls = <({int offset, int limit, int? playerCount})>[];

  /// Liste çekimi ağ hatasıyla düşsün. Gerçek uç çevrimdışıyken fırlatıyor
  /// ve "hiç oyunun yok" ile "yüklenemedi" AYRI mesajlar olduğundan
  /// (bkz. `GamesRepo.history`'nin `failed` bayrağı) sahte uç da bu yolu
  /// üretebilmek ZORUNDA — Parça 46'nın dersi: sahtenin taklit etmediği
  /// bir hata yolu, o yol hakkındaki testleri sessizce anlamsız kılar.
  bool failList = false;

  @override
  Future<List<Map<String, Object?>>> listGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
    bool? onlineOnly,
  }) async {
    listCalls.add((offset: offset, limit: limit, playerCount: playerCount));
    if (failList) throw Exception('ağ yok');
    final filtered = [
      for (final r in history)
        if (r['user_id'] == userId &&
            (playerCount == null || r['player_count'] == playerCount) &&
            (onlineOnly == null ||
                (onlineOnly
                    ? r['online_game_id'] != null
                    : r['online_game_id'] == null)))
          r
    ];
    // Gerçek uçtaki `.range(offset, offset + limit)` gibi BİR FAZLA satır.
    return filtered.skip(offset).take(limit + 1).toList();
  }

  @override
  Future<List<Map<String, Object?>>?> gameBoardSnapshot(String gameId) async =>
      snapshots[gameId];

  /// gameId → dondurulmuş hamle dökümü. Anahtarın HİÇ olmaması gerçek uçtaki
  /// "kaydedilmemiş" (null kolon) durumunu, `movesFail` ise ağ hatasını
  /// taklit eder — repo ikisini AYRI taşıdığından (bkz. `GamesRepo.moves`)
  /// sahte uç da ikisini ayrı üretebilmek zorunda (Parça 46'nın dersi).
  Map<String, List<Map<String, Object?>>> movesByGame = const {};
  bool movesFail = false;

  /// "Lazy mi?" sorusunun kanıtı — liste yüklenirken boş kalmalı.
  final movesCalls = <String>[];

  @override
  Future<List<Map<String, Object?>>?> gameMoves(String gameId) async {
    movesCalls.add(gameId);
    if (movesFail) throw Exception('ağ yok');
    return movesByGame[gameId];
  }

  // ── Beğeni / sohbet arşivi (parça 5b) ─────────────────────────────────
  /// gameId → o oyunu beğenenler (gerçek uçtaki `game_likers` sırası:
  /// en yeni önce; sahte tarafta verilen sıra korunur).
  Map<String, List<Map<String, Object?>>> likersByGame = const {};

  /// Bu kullanıcının beğendiği oyun id'leri — hem `game_like_stats`in
  /// `liked_by_me`si hem "Favoriler" listesi buradan türer.
  Set<String> likedByMe = <String>{};

  /// gameId → toplam beğeni sayısı (`game_like_stats`).
  Map<String, int> likeCounts = <String, int>{};

  /// gameId → dondurulmuş sohbet (`games.messages`).
  Map<String, List<Map<String, Object?>>> messagesByGame = const {};

  /// onlineGameId → renk indeksi bazlı rozetler.
  Map<String, List<Map<String, Object?>>> chatFlagsByGame = const {};

  final toggledLikes = <String>[];
  bool failNextToggleLike = false;

  @override
  Future<List<Map<String, Object?>>> listLikedGames({
    required String userId,
    required int? playerCount,
    required int offset,
    required int limit,
  }) async {
    // Gerçek RPC sahiplikten bağımsız çalışır: BEĞENİLEN oyunlar döner,
    // satır başkasının bile olabilir — sahte de bunu taklit ediyor.
    final filtered = [
      for (final r in history)
        if (likedByMe.contains(r['id']) &&
            (playerCount == null || r['player_count'] == playerCount))
          r
    ];
    return filtered.skip(offset).take(limit).toList();
  }

  /// Sohbet sayacı da buradan gelir (gerçek uçta `game_like_stats`
  /// katılımcı/admin değilse 0 döner) — `unauthorizedChats`'teki oyunlar o
  /// davranışı taklit eder.
  ///
  /// `has_moves` de burada: gerçek uçta `games.moves is not null`, yani
  /// sahtede "bu oyun için bir döküm KURULMUŞ mu". Sahte uç gerçek ucun
  /// HER kararını taklit etmeli (Parça 46'nın dersi) — aksi halde "dökümü
  /// olmayan kartta ikon çizilmez" kuralı testlerde hiç sınanmazdı.
  @override
  Future<List<Map<String, Object?>>> likeStats(List<String> gameIds) async => [
        for (final id in gameIds)
          {
            'game_id': id,
            'like_count': likeCounts[id] ?? 0,
            'liked_by_me': likedByMe.contains(id),
            'message_count': unauthorizedChats.contains(id)
                ? 0
                : (messagesByGame[id]?.length ?? chatCounts[id] ?? 0),
            'has_moves': movesByGame.containsKey(id),
          }
      ];

  /// Mesaj gövdesi verilmeden yalnızca sayaç kurmak için (rozet testleri).
  final chatCounts = <String, int>{};

  @override
  Future<bool> toggleLike(String gameId) async {
    if (failNextToggleLike) {
      failNextToggleLike = false;
      throw Exception('ağ hatası');
    }
    toggledLikes.add(gameId);
    final now = !likedByMe.contains(gameId);
    if (now) {
      likedByMe.add(gameId);
      likeCounts[gameId] = (likeCounts[gameId] ?? 0) + 1;
    } else {
      likedByMe.remove(gameId);
      likeCounts[gameId] = (likeCounts[gameId] ?? 1) - 1;
    }
    return now;
  }

  /// `set_game_shared` çağrılan oyunlar.
  final sharedGames = <String>[];

  @override
  Future<void> markShared(String gameId) async => sharedGames.add(gameId);

  @override
  Future<List<Map<String, Object?>>> likers(String gameId) async =>
      likersByGame[gameId] ?? const [];

  /// Yetkisiz kabul edilecek oyunlar — gerçek uçtaki katılımcı kapısının
  /// (`game_chat_archive`) test karşılığı.
  final unauthorizedChats = <String>{};

  @override
  Future<({bool allowed, List<Map<String, Object?>> messages})> gameMessages(
          String gameId) async =>
      unauthorizedChats.contains(gameId)
          ? (allowed: false, messages: const <Map<String, Object?>>[])
          : (allowed: true, messages: messagesByGame[gameId] ?? const []);

  @override
  Future<List<Map<String, Object?>>> chatFlags(String onlineGameId) async =>
      chatFlagsByGame[onlineGameId] ?? const [];
}
