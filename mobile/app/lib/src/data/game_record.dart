// Bitmiş (ya da terk edilerek teslim sayılan) bir yerel oyunun `games`
// satırı — web `src/utils/gameRecord.ts` + `NewGame` tipinin portu.
//
// Web'de olduğu gibi SAF bir fonksiyon: hem normal bitiş (canlı reducer
// state'i) hem 7 günlük terk-edilme akışı (depodan okunan süresi dolmuş bir
// state) aynı mantığı paylaşır. Alan adları `games` tablosunun sütunlarıyla
// birebir — aynı satırı web istemcisi de okuyor (Skor Kartı/Tüm Oyunlarım),
// biçim SÖZLEŞME.
import 'package:kelimeki_core/kelimeki_core.dart';

/// Web `GameResult` — `games.result` sütunu.
enum GameResult { win, lose, tie }

/// Web `GamePlayerSnapshot` — `games.players` jsonb dizisinin bir elemanı.
/// Final SIRALAMASINA göre dizilir (rankPlayers sırası); koltuk kimliği
/// `colorIndex`'te taşınır, böylece sıralama konumundan bağımsız olarak
/// köşe/renk eşlemesi korunur.
class GamePlayerSnapshot {
  final String name;
  final int score;
  final bool isAi;
  final bool surrendered;

  /// Koltuk kimliği — final SIRALAMADAN bağımsız (renk/köşe eşlemesi bundan
  /// gelir). Bu alan eklenmeden ÖNCEKİ kayıtlarda YOK: null ile 0'ı ayırt
  /// edebilmek şart, yoksa eski kayıtlarda herkes 0. koltuk sanılır
  /// (web `colorIndex !== undefined` kontrolünün karşılığı).
  final int? colorIndex;
  const GamePlayerSnapshot({
    required this.name,
    required this.score,
    required this.isAi,
    required this.surrendered,
    this.colorIndex,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'score': score,
        'is_ai': isAi,
        'surrendered': surrendered,
        'colorIndex': colorIndex,
      };

  factory GamePlayerSnapshot.fromJson(Map<String, Object?> j) =>
      GamePlayerSnapshot(
        name: j['name'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        isAi: j['is_ai'] == true,
        surrendered: j['surrendered'] == true,
        colorIndex: (j['colorIndex'] as num?)?.toInt(),
      );
}

/// Web `NewGame` — `games` tablosuna gidecek satır.
///
/// `id` istemcide üretilir: kayıp bir yanıttan sonra aynı kaydın tekrar
/// denenmesi sunucuda ikinci satır açmasın diye (`saveGame` 23505'i başarı
/// sayar). `createdAt` gerçek bitiş anını taşır — kayıt günler sonra
/// senkronlanabildiğinden sunucunun insert anındaki `now()` varsayılanı
/// yerine geçer.
class NewGameRecord {
  final String id;
  final String createdAt; // ISO 8601
  final int playerScore;
  final int aiScore;
  final GameResult result;
  final int rank;
  final int turnCount;
  final int playerCount;
  final int? moveCount;
  final int? bestMoveScore;
  final int? bestWordScore;
  final String? longestWord;
  final int? movePointsSum;
  final bool surrendered;
  final List<GamePlayerSnapshot> players;
  final List<BoardSnapshotTile> boardSnapshot;

  /// Bu oyunun TAM hamle dökümü — "Tüm Oyunlarım"daki hamle geçmişi ikonu
  /// bunu gösterir. Yerel oyunlarda tek kaynak burası: `moveHistory` yalnızca
  /// `GameState`te yaşıyor ve oyun bitince kayboluyor. Alan KIRPILMAZ
  /// (`invasionFrom` vergi satırları dahil) — modal onları kart olarak
  /// göstermiyor ama toplam puana katıyor.
  ///
  /// AYNI SATIRA YAZAN İKİ İSTEMCİ: web `gameRecord.ts` de bu kolonu aynı
  /// şekilde dolduruyor; biri değişirse öteki de değişmeli.
  final List<HistoryEntry> moves;

  const NewGameRecord({
    required this.id,
    required this.createdAt,
    required this.playerScore,
    required this.aiScore,
    required this.result,
    required this.rank,
    required this.turnCount,
    required this.playerCount,
    required this.moveCount,
    required this.bestMoveScore,
    required this.bestWordScore,
    required this.longestWord,
    required this.movePointsSum,
    required this.surrendered,
    required this.players,
    required this.boardSnapshot,
    required this.moves,
  });

  /// PostgREST'e giden satır (sütun adları). `user_id` BURADA YOK — çağıran
  /// (GamesApi) oturumdan ekler, web `saveGame` ile aynı.
  Map<String, Object?> toJson() => {
        'id': id,
        'created_at': createdAt,
        'player_score': playerScore,
        'ai_score': aiScore,
        'result': result.name,
        'rank': rank,
        'turn_count': turnCount,
        'player_count': playerCount,
        'move_count': moveCount,
        'best_move_score': bestMoveScore,
        'best_word_score': bestWordScore,
        'longest_word': longestWord,
        'move_points_sum': movePointsSum,
        'surrendered': surrendered,
        'players': [for (final p in players) p.toJson()],
        'board_snapshot': [for (final t in boardSnapshot) t.toJson()],
        'moves': [for (final m in moves) m.toJson()],
      };

  factory NewGameRecord.fromJson(Map<String, Object?> j) => NewGameRecord(
        id: j['id'] as String,
        createdAt: j['created_at'] as String,
        playerScore: (j['player_score'] as num).toInt(),
        aiScore: (j['ai_score'] as num).toInt(),
        result: GameResult.values.byName(j['result'] as String),
        rank: (j['rank'] as num).toInt(),
        turnCount: (j['turn_count'] as num).toInt(),
        playerCount: (j['player_count'] as num).toInt(),
        moveCount: (j['move_count'] as num?)?.toInt(),
        bestMoveScore: (j['best_move_score'] as num?)?.toInt(),
        bestWordScore: (j['best_word_score'] as num?)?.toInt(),
        longestWord: j['longest_word'] as String?,
        movePointsSum: (j['move_points_sum'] as num?)?.toInt(),
        surrendered: j['surrendered'] == true,
        players: [
          for (final p in (j['players'] as List? ?? const []))
            GamePlayerSnapshot.fromJson((p as Map).cast<String, Object?>())
        ],
        boardSnapshot: [
          for (final t in (j['board_snapshot'] as List? ?? const []))
            BoardSnapshotTile.fromJson((t as Map).cast<String, Object?>())
        ],
        moves: [
          for (final m in (j['moves'] as List? ?? const []))
            HistoryEntry.fromJson((m as Map).cast<String, Object?>())
        ],
      );
}

/// Bir `board_snapshot`tan, gerçek `BoardWidget`'ı salt-okunur çizebilmek
/// için sahte ama tip açısından geçerli bir `GameState` üretir — web
/// `buildSnapshotGameState` (boardSnapshot.ts) portu.
///
/// **Neden core'da DEĞİL:** yazma yönü (`serializeBoardSnapshot`) yalnızca
/// `Board` alıyor ve core'da; okuma yönü ise DB satır şeklini
/// (`GamePlayerSnapshot`) istiyor — onu core'a taşımak veri katmanını
/// motora sızdırırdı. Bu yüzden çift bilinçli olarak ayrıldı ve core'a hiç
/// dokunulmadı (dolayısıyla golden vector turu gerekmiyor).
///
/// Koltuk kimliği `colorIndex`'ten okunur — final SIRALAMADAKİ konumdan
/// bağımsız, böylece köşeler/renkler gerçek oyundaki gibi eşleşir (web'in
/// aynı kuralı).
GameState buildSnapshotGameState(
  List<BoardSnapshotTile> snapshot,
  int playerCount,
  List<GamePlayerSnapshot> players,
) {
  final board = createEmptyBoard();
  for (final t in snapshot) {
    board[t.r][t.c] = Tile(
      letter: t.w ? '?' : t.l,
      pts: t.w ? 0 : letterPoints(t.l),
      wild: t.w,
      wildLetter: t.w ? t.l : null,
      owner: t.o,
    );
  }

  final corners = cornersFor(playerCount);
  return GameState(
    phase: GamePhase.play,
    startedAt: '',
    multiSession: false,
    endReason: EndReason.normal,
    board: board,
    bag: const [],
    bonuses: buildInitialBonuses(),
    placed: {},
    players: [
      for (var seat = 0; seat < playerCount; seat++)
        () {
          final meta = players.where((p) => p.colorIndex == seat).firstOrNull;
          return Player(
            name: meta?.name ?? '',
            corners: seat < corners.length ? corners[seat] : const [],
            colorIndex: seat,
            isAI: meta?.isAi ?? false,
            surrendered: meta?.surrendered ?? false,
            rack: const [],
            score: meta?.score ?? 0,
            bestMoveScore: 0,
            bestWordScore: 0,
            longestWord: '',
            moveCount: 0,
            moveScoreSum: 0,
          );
        }(),
    ],
    current: 0,
    selectedTile: null,
    swapMode: false,
    swapSelection: const [],
    turnCount: 0,
    consecutivePasses: 0,
    isGameOver: true,
    message: '',
    messageType: MessageKind.none,
    lastMoveCells: const [],
    moveHistory: const [],
  );
}

/// Web `buildGameRecord` birebir.
///
/// [surrenderingIndex] verilirse o oyuncu SURRENDER dispatch edilmeden
/// önceki state üzerinde elle teslim/0 puan işaretlenir — web'de anlık
/// teslim akışı için vardı; mobilde tek çağıran 7 günlük terk-edilme
/// akışı (index 0, hesap sahibi). null döner: 1. koltuk insan değilse ya
/// da rakip yoksa (motor testi/geçersiz kadro).
///
/// [now]/[newId] enjekte edilebilir — core'un determinizm sözleşmesinin
/// devamı (testler saat/uuid sabitleyerek koşuyor).
NewGameRecord? buildGameRecord(
  GameState state, {
  required bool surrendered,
  int? surrenderingIndex,
  required String Function() newId,
  required DateTime Function() now,
}) {
  final effectivePlayers = surrenderingIndex == null
      ? state.players
      : [
          for (var i = 0; i < state.players.length; i++)
            i == surrenderingIndex
                ? state.players[i].copyWith(surrendered: true, score: 0)
                : state.players[i]
        ];
  if (effectivePlayers.isEmpty) return null;
  final human = effectivePlayers[0];
  if (human.isAI) return null;
  final opponents = effectivePlayers.sublist(1);
  if (opponents.isEmpty) return null;

  final bestOpponentScore =
      opponents.map((p) => p.score).reduce((a, b) => a > b ? a : b);
  final ranked = rankPlayers(effectivePlayers);
  final humanEntry = ranked.firstWhere((r) => r.index == 0);
  final rank = humanEntry.rank;
  final tiedForFirst = ranked.where((r) => r.rank == 1).length;
  final result = surrendered
      ? GameResult.lose
      : rank > 1
          ? GameResult.lose
          : tiedForFirst > 1
              ? GameResult.tie
              : GameResult.win;

  // Web `human.moveCount || null` — 0/'' değerleri null'a düşer (JS falsy
  // kısayolu). Sütunlar nullable ve web bu ayrımı koruyor.
  int? nz(int v) => v == 0 ? null : v;

  return NewGameRecord(
    id: newId(),
    createdAt: now().toUtc().toIso8601String(),
    playerScore: human.score,
    aiScore: bestOpponentScore,
    result: result,
    rank: rank,
    turnCount: state.turnCount,
    playerCount: state.players.length,
    moveCount: nz(human.moveCount),
    bestMoveScore: nz(human.bestMoveScore),
    bestWordScore: nz(human.bestWordScore),
    longestWord: human.longestWord.isEmpty ? null : human.longestWord,
    movePointsSum: nz(human.moveScoreSum),
    surrendered: surrendered,
    players: [
      for (final r in ranked)
        GamePlayerSnapshot(
          name: r.player.name,
          score: r.player.score,
          isAi: r.player.isAI,
          surrendered: r.player.surrendered,
          colorIndex: r.player.colorIndex,
        )
    ],
    boardSnapshot: serializeBoardSnapshot(state.board),
    moves: state.moveHistory,
  );
}
