// Kelimeki core — oyun durumu makinesi (src/game/gameReducer.ts portu).
//
// Determinizm sözleşmesi: motor kendi başına Random()/DateTime üretmez —
// rastgelelik `rng`, saat `nowIso` olarak enjekte edilir. Golden vector
// replay'i bunların üstüne kuruludur (mobile/CLAUDE.md).
//
// Türkçe mesaj metinleri web'dekiyle BİREBİR aynı tutulmalı — parite testleri
// mesajları da karşılaştırır; bir metni değiştirmek web'de de değiştirmeyi
// gerektirir (tek kaynak: TS tarafı, bkz. golden vector iş akışı).
import '../actions.dart';
import '../ai/find_move.dart';
import '../constants.dart';
import '../dictionary/word_source.dart';
import '../model/game_state.dart';
import '../model/history_entry.dart';
import '../model/player.dart';
import '../model/results.dart';
import '../model/tile.dart';
import '../model/types.dart';
import '../rng.dart';
import '../rules/board.dart';
import '../rules/validator.dart';
import '../text/turkish.dart';
import 'bag.dart';

/// Kurulum ekranıyla başlayan boş durum.
GameState createInitialState() => GameState(
      phase: GamePhase.setup,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: const [],
      bonuses: const {},
      placed: const {},
      players: const [],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 0,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

/// Aktif oyuncunun tahtada hiç taşı yoksa true (ilk hamlesi).
bool isFirstMove(GameState state) {
  for (final row in state.board) {
    for (final t in row) {
      if (t != null && t.owner == state.current) return false;
    }
  }
  return true;
}

GameState _endGame(GameState state, [EndReason reason = EndReason.normal]) {
  int remaining(Player p) => p.rack.fold(0, (s, t) => s + t.pts);
  final players = [
    for (final p in state.players)
      p.copyWith(score: (p.score - remaining(p)) < 0 ? 0 : p.score - remaining(p)),
  ];
  return state.copyWith(
    players: players,
    isGameOver: true,
    endReason: reason,
    message: 'Oyun bitti.',
    messageType: MessageKind.none,
  );
}

int _activePlayerCount(List<Player> players) =>
    players.where((p) => !p.surrendered).length;

int _nextActiveIndex(List<Player> players, int from) {
  final n = players.length;
  for (var step = 1; step <= n; step++) {
    final idx = (from + step) % n;
    if (!players[idx].surrendered) return idx;
  }
  return from;
}

GameState _advanceTurn(GameState state) {
  final next = _nextActiveIndex(state.players, state.current);
  final nextState = state.copyWith(
    turnCount: state.turnCount + 1,
    current: next,
    selectedTile: null,
    swapMode: false,
    swapSelection: const [],
  );
  final someoneEmpty =
      nextState.players.any((p) => !p.surrendered && p.rack.isEmpty);
  if (someoneEmpty && nextState.bag.isEmpty) {
    return _endGame(nextState);
  }
  return nextState;
}

/// Sunucudan taze çekilen rafı, henüz gönderilmemiş yerel `placed` taşları
/// için düşürür (taş çoğaltma hatasının önlemi — TS'teki aynı fonksiyon).
List<Tile> _subtractPlacedFromRack(List<Tile> rack, Placed placed) {
  final remaining = [...rack];
  for (final tile in placed.values) {
    final letter = tile.wild ? '?' : tile.letter;
    final idx =
        remaining.indexWhere((t) => t.letter == letter && t.pts == tile.pts);
    if (idx != -1) remaining.removeAt(idx);
  }
  return remaining;
}

/// Geçici yerleştirilen taşları aktif oyuncunun rafına geri toplar.
GameState _recallAll(GameState state) {
  final rack = [...state.players[state.current].rack];
  for (final tile in state.placed.values) {
    rack.add(Tile(letter: tile.wild ? '?' : tile.letter, pts: tile.pts));
  }
  final players = [
    for (var i = 0; i < state.players.length; i++)
      i == state.current ? state.players[i].copyWith(rack: rack) : state.players[i],
  ];
  return state.copyWith(players: players, placed: {}, selectedTile: null);
}

List<HistoryEntry> _appendMoveHistory(
  List<HistoryEntry> prev,
  int turn,
  int actor,
  List<String> words,
  int pts,
  List<InvasionShare> shares, {
  int? finishJokerCount,
  List<WordScore>? wordScores,
  bool bingo = false,
}) {
  final actorEntry = HistoryEntry(
    turn: turn,
    player: actor,
    words: words,
    points: pts,
    wordScores: wordScores,
    // TS: `if (finishJokerCount)` — 0/undefined atlanır.
    finishJokerCount:
        (finishJokerCount != null && finishJokerCount != 0) ? finishJokerCount : null,
    bingo: bingo,
    lostShares: shares.isNotEmpty
        ? [for (final s in shares) LostShare(to: s.index, amount: s.amount)]
        : null,
  );
  final entries = [...prev, actorEntry];
  for (final s in shares) {
    entries.add(HistoryEntry(
      turn: turn,
      player: s.index,
      words: words,
      points: s.amount,
      invasionFrom: actor,
    ));
  }
  return entries;
}

List<Player> _withRack(GameState state, List<Tile> rack) => [
      for (var i = 0; i < state.players.length; i++)
        i == state.current
            ? state.players[i].copyWith(rack: rack)
            : state.players[i],
    ];

int _bestWordScoreFrom(List<WordScore> wordScores, int prevBest) {
  var best = prevBest;
  for (final w in wordScores) {
    final f = w.score * (w.x3 ? 3 : (w.x2 ? 2 : 1));
    if (f > best) best = f;
  }
  return best;
}

typedef _MoveMessageCtx = ({
  int pts,
  List<InvasionShare> shares,
  int finishBonus,
  List<String> words,

  /// Rafın 7 taşı birden kullanıldı mı (Bingo). `bingoBonus` puanı zaten
  /// `basePts`'in İÇİNDE (calcScore ekliyor) — mesajdaki not yalnızca o
  /// puanın nereden geldiğini açıklıyor, ikinci kez eklemiyor.
  bool bingo,
});

/// PLAY ve AI_PLAY ortak çekirdeği — TS `applyPlacement` ile aynı sözleşme.
GameState _applyPlacement(
  GameState state,
  Placed placedMap,
  List<Tile> rackAfterRemoval,
  int basePts,
  String Function(_MoveMessageCtx ctx) buildMessage,
) {
  final me = state.players[state.current];
  final formed = getFormedWords(state.board, placedMap);
  final wordRawScores = calcWordRawScores(state.board, placedMap, state.bonuses);

  final placedCoords = [for (final k in placedMap.keys) parseKey(k)];
  final split = computeInvasionSplit(
      placedCoords, state.current, state.players, basePts, state.board);
  final pts = split.pts;
  final shares = split.shares;

  final board = [
    for (final row in state.board) [...row],
  ];
  for (final e in placedMap.entries) {
    final p = parseKey(e.key);
    board[p.$1][p.$2] = e.value.copyWith(owner: state.current);
  }

  final bag = [...state.bag];
  final rack = [...rackAfterRemoval];
  rack.addAll(drawTiles(bag, rackSize - rack.length));

  final placedTiles = placedMap.values.toList();
  // Bingo ile jokerli bitiş bonusu AYNI hamlede oluşamaz: jokerli bitiş tüm
  // taşların joker olmasını ister, torbada yalnızca 2 joker var; bingo ise 7
  // taş ister. Yani mesaja en fazla tek bir bonus parantezi eklenir.
  final isBingo = placedTiles.length >= rackSize;
  final jokerCount = placedTiles.where((t) => t.wild).length;
  final onlyJokers = placedTiles.isNotEmpty && jokerCount == placedTiles.length;
  final finishesGame = rack.isEmpty && bag.isEmpty;
  final finishBonus =
      (finishesGame && onlyJokers) ? jokerFinishBonus(jokerCount) : 0;

  var newLongestWord = me.longestWord;
  for (final fw in formed) {
    if (fw.word.length > newLongestWord.length) newLongestWord = fw.word;
  }
  final moveTotal = basePts + finishBonus;
  final isNewBestMove = moveTotal > me.bestMoveScore;
  final newBestWordScore = _bestWordScoreFrom(wordRawScores, me.bestWordScore);
  final players = <Player>[];
  for (var i = 0; i < state.players.length; i++) {
    final p = state.players[i];
    if (i == state.current) {
      players.add(p.copyWith(
        rack: rack,
        score: p.score + pts + finishBonus,
        bestMoveScore: isNewBestMove ? moveTotal : p.bestMoveScore,
        bestWordScore: newBestWordScore,
        longestWord: newLongestWord,
        moveCount: p.moveCount + 1,
        moveScoreSum: p.moveScoreSum + moveTotal,
      ));
      continue;
    }
    InvasionShare? share;
    for (final s in shares) {
      if (s.index == i) {
        share = s;
        break;
      }
    }
    players.add(share != null ? p.copyWith(score: p.score + share.amount) : p);
  }

  final wordsList = [for (final f in formed) f.word];
  return state.copyWith(
    board: board,
    bag: bag,
    placed: {},
    players: players,
    consecutivePasses: 0,
    selectedTile: null,
    lastMoveCells: placedCoords,
    moveHistory: _appendMoveHistory(
      state.moveHistory,
      state.turnCount,
      state.current,
      wordsList,
      pts + finishBonus,
      shares,
      finishJokerCount: finishBonus > 0 ? jokerCount : null,
      wordScores: wordRawScores,
      bingo: isBingo,
    ),
    message: buildMessage((
      pts: pts,
      shares: shares,
      finishBonus: finishBonus,
      words: wordsList,
      bingo: isBingo,
    )),
    messageType: MessageKind.ok,
  );
}

/// Oyun motoru: `reduce` saf bir geçiş fonksiyonudur; tüm yan-etki kaynakları
/// (rastgelelik, saat, sözlük) kurucuya enjekte edilir.
class GameEngine {
  final WordSource words;
  final Rng rng;
  final String Function() nowIso;

  GameEngine({required this.words, required this.rng, required this.nowIso});

  GameState _startGame(List<PlayerSetup> setup, AiLevel? aiLevel) {
    final count = setup.length;
    final corners = cornersFor(count);
    final bag = buildBag(rng);
    final players = <Player>[];
    for (var i = 0; i < setup.length; i++) {
      final s = setup[i];
      final trimmed = s.name.trim();
      players.add(Player(
        name: trimmed.isNotEmpty
            ? trimmed
            : (s.isAI
                ? (count == 2 ? 'Yapay Zeka' : 'Yapay Zeka ${i + 1}')
                : 'Oyuncu ${i + 1}'),
        corners: corners[i],
        colorIndex: i % playerColorCount,
        isAI: s.isAI,
        surrendered: false,
        rack: drawTiles(bag, rackSize),
        score: 0,
        bestMoveScore: 0,
        bestWordScore: 0,
        longestWord: '',
        moveCount: 0,
        moveScoreSum: 0,
      ));
    }

    return GameState(
      phase: GamePhase.play,
      startedAt: nowIso(),
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: bag,
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: players,
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 0,
      consecutivePasses: 0,
      isGameOver: false,
      message: '${players[0].name}, kendi köşenden bir kelime kur.',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
      aiLevel: aiLevel,
    );
  }

  GameState reduce(GameState state, GameAction action) {
    switch (action) {
      case AbandonAction():
        return createInitialState();

      case StartAction(players: final setup, aiLevel: final aiLevel):
        if (setup.length != 2 && setup.length != 4) return state;
        return _startGame(setup, aiLevel);

      case ResumeSavedAction(state: final saved):
        return saved;

      case SelectTileAction(index: final index):
        if (state.phase != GamePhase.play || state.isGameOver) return state;
        return state.copyWith(
            selectedTile: state.selectedTile == index ? null : index);

      case PlaceTileAction():
        return _placeTile(state, action);

      case MovePlacedTileAction():
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final fromKey = cellKey(action.fromR, action.fromC);
          final toKey = cellKey(action.toR, action.toC);
          final tile = state.placed[fromKey];
          if (tile == null || fromKey == toKey) return state;
          if (state.board[action.toR][action.toC] != null ||
              state.placed.containsKey(toKey)) {
            return state;
          }
          final placed = Map<String, Tile>.from(state.placed);
          placed.remove(fromKey);
          placed[toKey] = tile;
          return state.copyWith(placed: placed, selectedTile: null);
        }

      case SetWildLetterAction():
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final k = cellKey(action.r, action.c);
          final tile = state.placed[k];
          if (tile == null || !tile.wild) return state;
          final wl = trUpper(action.wildLetter);
          final placed = Map<String, Tile>.from(state.placed);
          placed[k] = tile.copyWith(wildLetter: wl);
          return state.copyWith(placed: placed);
        }

      case RecallCellAction():
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final k = cellKey(action.r, action.c);
          final tile = state.placed[k];
          if (tile == null) return state;
          final placed = Map<String, Tile>.from(state.placed);
          placed.remove(k);
          final rack = [
            ...state.players[state.current].rack,
            Tile(letter: tile.wild ? '?' : tile.letter, pts: tile.pts),
          ];
          return state.copyWith(
            placed: placed,
            players: _withRack(state, rack),
            selectedTile: null,
          );
        }

      case RecallAllAction():
        if (state.phase != GamePhase.play || state.isGameOver) return state;
        return _recallAll(state).copyWith(
          message: 'Taşlar rafa geri alındı.',
          messageType: MessageKind.none,
        );

      case ShuffleRackAction():
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final me = state.players[state.current];
          if (me.isAI) return state;
          final rack = shuffleList([...me.rack], rng);
          return state.copyWith(
            players: _withRack(state, rack),
            selectedTile: null,
            message: 'Harfler karıştırıldı.',
            messageType: MessageKind.none,
          );
        }

      case ToggleSwapModeAction():
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final me = state.players[state.current];
          if (me.isAI) return state;
          if (state.swapMode) {
            return state.copyWith(
              swapMode: false,
              swapSelection: const [],
              message: '',
              messageType: MessageKind.none,
            );
          }
          if (state.bag.isEmpty) {
            return state.copyWith(
              message: 'Torba boş — taş değiştirilemez.',
              messageType: MessageKind.err,
            );
          }
          final recalled = _recallAll(state);
          return recalled.copyWith(
            swapMode: true,
            swapSelection: const [],
            message: 'Değiştireceğin taşları seç, sonra "Değiştir"e bas.',
            messageType: MessageKind.warn,
          );
        }

      case ToggleSwapTileAction(index: final index):
        {
          if (state.phase != GamePhase.play ||
              state.isGameOver ||
              !state.swapMode) {
            return state;
          }
          final swapSelection = state.swapSelection.contains(index)
              ? [for (final i in state.swapSelection) if (i != index) i]
              : [...state.swapSelection, index];
          return state.copyWith(swapSelection: swapSelection);
        }

      case ConfirmSwapAction():
        return _confirmSwap(state);

      case SetMessageAction():
        return state.copyWith(
            message: action.message, messageType: action.messageType);

      case PlayAction(skipWordCheck: final skipWordCheck):
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final me = state.players[state.current];
          final check = skipWordCheck
              ? validatePlacementStructural(state.board, state.placed,
                  state.current, me.corners, isFirstMove(state))
              : validatePlacement(state.board, state.placed, state.current,
                  me.corners, isFirstMove(state), words);
          if (!check.valid) {
            return state.copyWith(
                message: check.reason!, messageType: MessageKind.err);
          }
          final basePts = calcScore(state.board, state.placed, state.bonuses);
          final moved = _applyPlacement(
            state,
            state.placed,
            me.rack,
            basePts,
            (ctx) {
              final bonusNote = ctx.shares.isNotEmpty
                  ? ' (${ctx.shares.map((s) => '${s.amount} puanı ${state.players[s.index].name} kaptı').join(', ')})'
                  : '';
              final bingoNote = ctx.bingo ? ' (Bingo bonusu +$bingoBonus)' : '';
              final finishBonusNote = ctx.finishBonus > 0
                  ? ' (jokerli bitiş bonusu +${ctx.finishBonus})'
                  : '';
              return '${me.name}: +${ctx.pts} puan$bonusNote$bingoNote$finishBonusNote Kelimeler: ${ctx.words.join(', ')}';
            },
          );
          return _advanceTurn(moved);
        }

      case PassAction():
        {
          if (state.phase != GamePhase.play || state.isGameOver) return state;
          final recalled = _recallAll(state);
          final consecutivePasses = state.consecutivePasses + 1;
          final moved = recalled.copyWith(
            consecutivePasses: consecutivePasses,
            moveHistory: [
              ...state.moveHistory,
              HistoryEntry(
                turn: state.turnCount,
                player: state.current,
                words: const [],
                points: 0,
                action: 'pass',
              ),
            ],
            message: '${state.players[state.current].name} pas geçti.',
            messageType: MessageKind.warn,
          );
          if (consecutivePasses >=
              _activePlayerCount(state.players) * maxPassRounds) {
            return _endGame(moved);
          }
          return _advanceTurn(moved);
        }

      case AiPlayAction():
        return _aiPlay(state);

      case RenamePlayerAction():
        {
          if (state.phase != GamePhase.play) return state;
          final players = [
            for (var i = 0; i < state.players.length; i++)
              i == action.index
                  ? state.players[i].copyWith(name: action.name)
                  : state.players[i],
          ];
          return state.copyWith(players: players);
        }

      case SurrenderAction(index: final index):
        return _surrender(state, index);

      case SyncOnlineStateAction():
        return _syncOnlineState(state, action);
    }
  }

  GameState _placeTile(GameState state, PlaceTileAction action) {
    if (state.phase != GamePhase.play || state.isGameOver) return state;
    final idx = action.rackIndex ?? state.selectedTile;
    if (idx == null) {
      return state.copyWith(
          message: 'Önce bir harf seç.', messageType: MessageKind.none);
    }
    final k = cellKey(action.r, action.c);
    if (state.board[action.r][action.c] != null ||
        state.placed.containsKey(k)) {
      return state; // dolu kare
    }

    final me = state.players[state.current];
    if (idx < 0 || idx >= me.rack.length) return state;
    final source = me.rack[idx];
    var tile = source.copyWith(owner: state.current);
    if (tile.letter == '?') {
      final raw = action.wildLetter;
      final wl = trUpper((raw == null || raw.isEmpty) ? 'A' : raw);
      tile = tile.copyWith(wild: true, wildLetter: wl);
    }
    final rack = [
      for (var i = 0; i < me.rack.length; i++)
        if (i != idx) me.rack[i],
    ];
    final placed = Map<String, Tile>.from(state.placed);
    placed[k] = tile;
    return state.copyWith(
      placed: placed,
      players: _withRack(state, rack),
      selectedTile: null,
      message: 'Oyna tuşuyla kelimeyi onayla.',
      messageType: MessageKind.none,
    );
  }

  GameState _confirmSwap(GameState state) {
    if (state.phase != GamePhase.play || state.isGameOver || !state.swapMode) {
      return state;
    }
    if (state.swapSelection.isEmpty) {
      return state.copyWith(
        message: 'En az bir taş seçmelisin.',
        messageType: MessageKind.err,
      );
    }
    // Taş korunumu REDUCER'ın sorumluluğu — bkz. gameReducer.ts'teki aynı
    // yerdeki uzun not (5 Eylül 2026 hata avı geçişi). Kısaca:
    // `ToggleSwapModeAction` swap moduna GİRERKEN `_recallAll` çağırıyordu,
    // `_confirmSwap` çıkarken çağırmayıp yalnızca `placed: {}` yazıyordu —
    // tahtadaki taslak taşlar rafa da torbaya da dönmeden siliniyordu.
    // Seçim kontrolü bilerek recall'ın ÜSTÜNDE (hata dalında taslağı toplama).
    final base = _recallAll(state);
    final me = base.players[base.current];
    final selected = base.swapSelection.toSet();
    final returned = <Tile>[];
    final kept = <Tile>[];
    for (var i = 0; i < me.rack.length; i++) {
      final t = me.rack[i];
      if (selected.contains(i)) {
        returned.add(Tile(letter: t.wild ? '?' : t.letter, pts: t.pts));
      } else {
        kept.add(t);
      }
    }
    final bag = shuffleList([...base.bag, ...returned], rng);
    final drawn = drawTiles(bag, returned.length);
    final rack = [...kept, ...drawn];

    // Taş değiştirmek de pas gibi puansız bir turdur (bkz. TS yorumu).
    final consecutivePasses = base.consecutivePasses + 1;
    final moved = base.copyWith(
      bag: bag,
      players: _withRack(base, rack),
      placed: {},
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      consecutivePasses: consecutivePasses,
      moveHistory: [
        ...base.moveHistory,
        HistoryEntry(
          turn: base.turnCount,
          player: base.current,
          words: const [],
          points: 0,
          action: 'exchange',
          tileCount: returned.length,
        ),
      ],
      message: '${me.name} ${returned.length} taş değiştirdi ve sırasını kullandı.',
      messageType: MessageKind.warn,
    );
    if (consecutivePasses >= _activePlayerCount(base.players) * maxPassRounds) {
      return _endGame(moved);
    }
    return _advanceTurn(moved);
  }

  GameState _aiPlay(GameState state) {
    if (state.phase != GamePhase.play || state.isGameOver) return state;
    final me = state.players[state.current];
    if (!me.isAI) return state;

    final move = findAIMove(
      state.board,
      me.rack,
      state.bonuses,
      state.current,
      me.corners,
      isFirstMove(state),
      state.players,
      words,
      level: state.aiLevel ?? AiLevel.normal,
      rng: rng,
    );

    // Geçerli hamle yoksa: torbada taş varsa rafı değiştir, boşsa pas.
    if (move == null) {
      final consecutivePasses = state.consecutivePasses + 1;
      GameState moved;
      if (state.bag.isNotEmpty) {
        final returned = [
          for (final t in me.rack)
            Tile(letter: t.wild ? '?' : t.letter, pts: t.pts),
        ];
        final bag = shuffleList([...state.bag, ...returned], rng);
        final rack = drawTiles(bag, returned.length);
        moved = state.copyWith(
          bag: bag,
          players: _withRack(state, rack),
          consecutivePasses: consecutivePasses,
          moveHistory: [
            ...state.moveHistory,
            HistoryEntry(
              turn: state.turnCount,
              player: state.current,
              words: const [],
              points: 0,
              action: 'exchange',
              tileCount: returned.length,
            ),
          ],
          message: '${me.name} harflerini değiştirdi.',
          messageType: MessageKind.warn,
        );
      } else {
        moved = state.copyWith(
          consecutivePasses: consecutivePasses,
          moveHistory: [
            ...state.moveHistory,
            HistoryEntry(
              turn: state.turnCount,
              player: state.current,
              words: const [],
              points: 0,
              action: 'pass',
            ),
          ],
          message: '${me.name} pas geçti.',
          messageType: MessageKind.warn,
        );
      }
      if (consecutivePasses >=
          _activePlayerCount(state.players) * maxPassRounds) {
        return _endGame(moved);
      }
      return _advanceTurn(moved);
    }

    final placedMap = <String, Tile>{};
    for (final p in move.placements) {
      placedMap[cellKey(p.r, p.c)] = p.tile;
    }
    final rackAfterRemoval = [...me.rack];
    for (final p in move.placements) {
      final idx = p.tile.wild
          ? rackAfterRemoval.indexWhere((t) => t.letter == '?')
          : rackAfterRemoval.indexWhere((t) => t.letter == p.tile.letter);
      if (idx >= 0) rackAfterRemoval.removeAt(idx);
    }

    final moved = _applyPlacement(
      state,
      placedMap,
      rackAfterRemoval,
      move.score,
      (ctx) {
        final invasionNote = ctx.shares.isNotEmpty
            ? ' (${ctx.shares.map((s) => '${s.amount} puanı ${state.players[s.index].name} kaptı').join(', ')})'
            : '';
        final bingoNote = ctx.bingo ? ' (Bingo bonusu +$bingoBonus)' : '';
        final finishBonusNote = ctx.finishBonus > 0
            ? ' (jokerli bitiş bonusu +${ctx.finishBonus})'
            : '';
        return '${me.name} "${move.word}" oynadı. +${ctx.pts} puan.$invasionNote$bingoNote$finishBonusNote';
      },
    );
    return _advanceTurn(moved);
  }

  GameState _surrender(GameState state, int index) {
    if (state.phase != GamePhase.play || state.isGameOver) return state;
    if (index < 0 || index >= state.players.length) return state;
    final target = state.players[index];
    if (target.surrendered) return state;

    // Sırası gelen teslim oluyorsa geçici taşları önce rafına geri al.
    final recalled = index == state.current ? _recallAll(state) : state;

    final surrenderingPlayer = recalled.players[index];
    final returnedTiles = [
      for (final t in surrenderingPlayer.rack)
        Tile(letter: t.wild ? '?' : t.letter, pts: t.pts),
    ];
    final bag = shuffleList([...recalled.bag, ...returnedTiles], rng);
    final players = [
      for (var i = 0; i < recalled.players.length; i++)
        i == index
            ? recalled.players[i]
                .copyWith(surrendered: true, score: 0, rack: const [])
            : recalled.players[i],
    ];
    final withSurrender = recalled.copyWith(
      bag: bag,
      players: players,
      moveHistory: [
        ...state.moveHistory,
        HistoryEntry(
          turn: state.turnCount,
          player: index,
          words: const [],
          points: 0,
          action: 'surrender',
        ),
      ],
      message: '${target.name} teslim oldu.',
      messageType: MessageKind.warn,
    );

    if (_activePlayerCount(players) <= 1) {
      return _endGame(withSurrender, EndReason.surrender);
    }
    if (index == state.current) {
      return _advanceTurn(withSurrender);
    }
    return withSurrender;
  }

  GameState _syncOnlineState(GameState state, SyncOnlineStateAction action) {
    final pub = action.publicState;
    final turnAdvanced = pub.turnCount != state.turnCount;
    final placed = turnAdvanced ? <String, Tile>{} : state.placed;
    final myRack = turnAdvanced
        ? action.myRack
        : _subtractPlacedFromRack(action.myRack, placed);
    // `swapSelection` raf İNDEKSLERİ tutuyor — bkz. gameReducer.ts'teki aynı
    // yerdeki not (5 Eylül 2026 hata avı geçişi). Turn ilerlemediyse seçim
    // bilerek korunuyor, ama raf sunucu sırasına geri yazıldığından
    // "Karıştır"dan sonra aynı indeks BAŞKA bir taşı gösterir. Raf
    // değiştiyse seçimi düşürüyoruz: yanlış taşı göndermektense kullanıcı
    // güncel rafta yeniden seçsin.
    String rackSignature(List<Tile> r) =>
        r.map((t) => '${t.letter}:${t.pts}').join('|');
    final prevRack = action.mySlotIndex >= 0 &&
            action.mySlotIndex < state.players.length
        ? state.players[action.mySlotIndex].rack
        : const <Tile>[];
    final rackChanged = rackSignature(prevRack) != rackSignature(myRack);
    final players = <Player>[];
    for (var i = 0; i < pub.players.length; i++) {
      final p = pub.players[i];
      players.add(Player(
        name: p.name,
        corners: p.corners,
        colorIndex: p.colorIndex,
        isAI: p.isAI,
        surrendered: p.surrendered,
        rack: i == action.mySlotIndex
            ? myRack
            : List<Tile>.filled(p.rackCount, const Tile(letter: 'A', pts: 1)),
        score: p.score,
        bestMoveScore: p.bestMoveScore,
        bestWordScore: p.bestWordScore,
        longestWord: p.longestWord,
        moveCount: p.moveCount,
        moveScoreSum: p.moveScoreSum,
      ));
    }
    return state.copyWith(
      phase: GamePhase.play,
      startedAt: pub.startedAt,
      endReason: pub.endReason == null
          ? EndReason.normal
          : EndReasonJson.parse(pub.endReason!),
      board: pub.board,
      bag: List<Tile>.filled(pub.bagCount, const Tile(letter: 'A', pts: 1)),
      bonuses: pub.bonuses,
      placed: placed,
      players: players,
      current: pub.current,
      selectedTile: turnAdvanced ? null : state.selectedTile,
      swapMode: turnAdvanced ? false : state.swapMode,
      swapSelection:
          turnAdvanced || rackChanged ? const [] : state.swapSelection,
      turnCount: pub.turnCount,
      consecutivePasses: pub.consecutivePasses,
      isGameOver: pub.isGameOver,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: pub.lastMoveCells,
    );
  }
}
