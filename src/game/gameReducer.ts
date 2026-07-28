// Kelimeki — useReducer ile çok oyunculu (yerel) oyun durumu yönetimi
import {
  MAX_PASS_ROUNDS,
  PLAYER_COLORS,
  RACK_SIZE,
  buildInitialBonuses,
  cornersFor,
  jokerFinishBonus,
} from './constants';
import type { GameState, HistoryEntry, Owner, Player, Tile } from './types';
import type { OnlineGameStatePublic } from '../lib/database.types';
import { buildBag, drawTiles } from '../utils/bag';
import { shuffle } from '../utils/random';
import { trUpper } from '../utils/turkish';
import {
  createEmptyBoard,
  getFormedWords,
  key,
} from '../utils/board';
import {
  calcScore,
  calcWordRawScores,
  computeInvasionSplit,
  validatePlacement,
  validatePlacementStructural,
} from '../utils/validator';
import { findAIMove } from '../utils/ai';

/** Kurulumda bir oyuncunun ayarı. */
export interface PlayerSetup {
  name: string;
  isAI: boolean;
}

export type Action =
  | { type: 'INIT' }
  | { type: 'ABANDON' }
  | { type: 'START'; players: PlayerSetup[] }
  | { type: 'SELECT_TILE'; index: number }
  | { type: 'PLACE_TILE'; r: number; c: number; wildLetter?: string; rackIndex?: number }
  | { type: 'MOVE_PLACED_TILE'; from: { r: number; c: number }; to: { r: number; c: number } }
  | { type: 'RECALL_CELL'; r: number; c: number }
  | { type: 'RECALL_ALL' }
  | { type: 'SHUFFLE_RACK' }
  | { type: 'TOGGLE_SWAP_MODE' }
  | { type: 'TOGGLE_SWAP_TILE'; index: number }
  | { type: 'CONFIRM_SWAP' }
  | { type: 'PLAY'; skipWordCheck?: boolean }
  | { type: 'SET_MESSAGE'; message: string; messageType: GameState['messageType'] }
  | { type: 'PASS' }
  | { type: 'AI_PLAY' }
  | { type: 'RENAME_PLAYER'; index: number; name: string }
  | { type: 'SURRENDER'; index: number }
  | {
      type: 'SYNC_ONLINE_STATE';
      publicState: OnlineGameStatePublic;
      myRack: Tile[];
      mySlotIndex: number;
    };

/** Kurulum (oyuncu seçimi) ekranıyla başlayan boş durum. */
export function createInitialState(): GameState {
  return {
    phase: 'setup',
    startedAt: '',
    multiSession: false,
    endReason: 'normal',
    board: createEmptyBoard(),
    bag: [],
    bonuses: {},
    placed: {},
    players: [],
    current: 0,
    selectedTile: null,
    swapMode: false,
    swapSelection: [],
    turnCount: 0,
    consecutivePasses: 0,
    isGameOver: false,
    message: '',
    messageType: '',
    lastMoveCells: [],
    moveHistory: [],
  };
}

/** Oyuncu ayarlarından (2 ya da 4) oyunu kurar ve ilk taşları dağıtır. */
function startGame(setup: PlayerSetup[]): GameState {
  const count = setup.length;
  const corners = cornersFor(count);
  const bag = buildBag();
  const players: Player[] = setup.map((s, i) => ({
    name:
      s.name.trim() ||
      (s.isAI
        ? count === 2
          ? 'Yapay Zeka'
          : `Yapay Zeka ${i + 1}`
        : `Oyuncu ${i + 1}`),
    corners: corners[i],
    colorIndex: i % PLAYER_COLORS.length,
    isAI: s.isAI,
    surrendered: false,
    rack: drawTiles(bag, RACK_SIZE),
    score: 0,
    bestMoveScore: 0,
    longestWord: '',
    moveCount: 0,
    moveScoreSum: 0,
  }));

  return {
    phase: 'play',
    startedAt: new Date().toISOString(),
    multiSession: false,
    endReason: 'normal',
    board: createEmptyBoard(),
    bag,
    bonuses: buildInitialBonuses(),
    placed: {},
    players,
    current: 0,
    selectedTile: null,
    swapMode: false,
    swapSelection: [],
    turnCount: 0,
    consecutivePasses: 0,
    isGameOver: false,
    message: `${players[0].name}, kendi köşenden bir kelime kur.`,
    messageType: '',
    lastMoveCells: [],
    moveHistory: [],
  };
}

/** Aktif oyuncunun tahtada hiç taşı yoksa true (ilk hamlesi). */
export function isFirstMove(state: GameState): boolean {
  for (const row of state.board) {
    for (const t of row) {
      if (t && t.owner === state.current) return false;
    }
  }
  return true;
}

/**
 * Kalan raf puanlarını her oyuncudan düşerek oyunu bitirir. Rafını
 * tamamen bitiren oyuncuya diğerlerinin kalan taş puanları eklenmez —
 * sadece kalan taşı olan oyuncuların puanından düşülür.
 */
function endGame(state: GameState, reason: GameState['endReason'] = 'normal'): GameState {
  const remaining = (p: Player) => p.rack.reduce((s, t) => s + t.pts, 0);

  const players = state.players.map((p) => {
    const score = Math.max(0, p.score - remaining(p));
    return { ...p, score };
  });
  return {
    ...state,
    players,
    isGameOver: true,
    endReason: reason,
    message: 'Oyun bitti.',
    messageType: '',
  };
}

/** Teslim olmamış (hâlâ oynayan) oyuncu sayısı. */
function activePlayerCount(players: Player[]): number {
  return players.filter((p) => !p.surrendered).length;
}

/** `from`dan başlayarak dairesel biçimde bir sonraki teslim olmamış oyuncunun indeksi. */
function nextActiveIndex(players: Player[], from: number): number {
  const n = players.length;
  for (let step = 1; step <= n; step++) {
    const idx = (from + step) % n;
    if (!players[idx].surrendered) return idx;
  }
  return from;
}

/**
 * Tur sayacını ilerletir; bir raf+torba tükendiyse oyunu bitirir; sırayı
 * sonraki (teslim olmamış) oyuncuya geçirir.
 */
function advanceTurn(state: GameState): GameState {
  const next = nextActiveIndex(state.players, state.current);
  const nextState: GameState = {
    ...state,
    turnCount: state.turnCount + 1,
    current: next,
    selectedTile: null,
    swapMode: false,
    swapSelection: [],
  };

  // Teslim olmamış bir oyuncunun rafı boşaldıysa ve torba bittiyse oyun biter.
  const someoneEmpty = nextState.players.some((p) => !p.surrendered && p.rack.length === 0);
  if (someoneEmpty && nextState.bag.length === 0) {
    return endGame(nextState);
  }
  return nextState;
}

/** Geçici yerleştirilen taşları aktif oyuncunun rafına geri toplar. */
function recallAll(state: GameState): GameState {
  const rack = [...state.players[state.current].rack];
  for (const tile of Object.values(state.placed)) {
    rack.push({ letter: tile.wild ? '?' : tile.letter, pts: tile.pts });
  }
  const players = state.players.map((p, i) =>
    i === state.current ? { ...p, rack } : p,
  );
  return { ...state, players, placed: {}, selectedTile: null };
}

/**
 * Bir hamlenin hamle geçmişine ekleyeceği satırları oluşturur: oynayanın
 * kendi satırı + sınırına değinilen her oyuncu için ayrı bir bonus satırı.
 */
function appendMoveHistory(
  prev: HistoryEntry[],
  turn: number,
  actor: Owner,
  words: string[],
  pts: number,
  shares: { index: number; amount: number }[],
  finishJokerCount?: number,
  wordScores?: { word: string; score: number; x2: boolean; x3: boolean }[],
  bingo?: boolean,
): HistoryEntry[] {
  const actorEntry: HistoryEntry = { turn, player: actor, words, points: pts };
  if (wordScores) actorEntry.wordScores = wordScores;
  if (finishJokerCount) actorEntry.finishJokerCount = finishJokerCount;
  if (bingo) actorEntry.bingo = true;
  if (shares.length > 0) {
    actorEntry.lostShares = shares.map((s) => ({ to: s.index, amount: s.amount }));
  }
  const entries: HistoryEntry[] = [...prev, actorEntry];
  for (const s of shares) {
    entries.push({ turn, player: s.index, words, points: s.amount, invasionFrom: actor });
  }
  return entries;
}

/** Aktif oyuncunun rafından bir taş çıkararak oyuncular dizisini günceller. */
function withRack(state: GameState, rack: Tile[]): Player[] {
  return state.players.map((p, i) => (i === state.current ? { ...p, rack } : p));
}

export function gameReducer(state: GameState, action: Action): GameState {
  switch (action.type) {
    case 'INIT':
      return createInitialState();

    case 'ABANDON':
      // Oyundan çıkış: teslim kaydı (varsa 2 puan ceza) App.tsx'te bu action
      // dispatch edilmeden önce saveGame ile kaydedilir; burada yalnızca
      // setup ekranına dönülür.
      return createInitialState();

    case 'START': {
      if (action.players.length !== 2 && action.players.length !== 4) return state;
      return startGame(action.players);
    }

    case 'SELECT_TILE': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const selectedTile =
        state.selectedTile === action.index ? null : action.index;
      return { ...state, selectedTile };
    }

    case 'PLACE_TILE': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const idx = action.rackIndex ?? state.selectedTile;
      if (idx === null || idx === undefined) {
        return { ...state, message: 'Önce bir harf seç.', messageType: '' };
      }
      const { r, c } = action;
      const k = key(r, c);
      if (state.board[r][c] || state.placed[k]) {
        return state; // dolu kare
      }

      const me = state.players[state.current];
      const source = me.rack[idx];
      if (!source) return state;
      const tile: Tile = { ...source, owner: state.current };
      if (tile.letter === '?') {
        const wl = trUpper(action.wildLetter || 'A');
        tile.wild = true;
        tile.wildLetter = wl;
      }
      const rack = me.rack.filter((_, i) => i !== idx);
      return {
        ...state,
        placed: { ...state.placed, [k]: tile },
        players: withRack(state, rack),
        selectedTile: null,
        message: 'Oyna tuşuyla kelimeyi onayla.',
        messageType: '',
      };
    }

    case 'MOVE_PLACED_TILE': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const fromKey = key(action.from.r, action.from.c);
      const toKey = key(action.to.r, action.to.c);
      const tile = state.placed[fromKey];
      if (!tile || fromKey === toKey) return state;
      if (state.board[action.to.r][action.to.c] || state.placed[toKey]) return state;

      const placed = { ...state.placed };
      delete placed[fromKey];
      placed[toKey] = tile;
      return { ...state, placed, selectedTile: null };
    }

    case 'RECALL_CELL': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const k = key(action.r, action.c);
      const tile = state.placed[k];
      if (!tile) return state;
      const placed = { ...state.placed };
      delete placed[k];
      const rack = [
        ...state.players[state.current].rack,
        { letter: tile.wild ? '?' : tile.letter, pts: tile.pts },
      ];
      return {
        ...state,
        placed,
        players: withRack(state, rack),
        selectedTile: null,
      };
    }

    case 'RECALL_ALL': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      return {
        ...recallAll(state),
        message: 'Taşlar rafa geri alındı.',
        messageType: '',
      };
    }

    case 'SHUFFLE_RACK': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      if (me.isAI) return state;
      const rack = shuffle([...me.rack]);
      return {
        ...state,
        players: withRack(state, rack),
        selectedTile: null,
        message: 'Harfler karıştırıldı.',
        messageType: '',
      };
    }

    case 'TOGGLE_SWAP_MODE': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      if (me.isAI) return state;
      // Modu kapat.
      if (state.swapMode) {
        return {
          ...state,
          swapMode: false,
          swapSelection: [],
          message: '',
          messageType: '',
        };
      }
      // Torba boşsa değiştirilecek taş yok.
      if (state.bag.length === 0) {
        return {
          ...state,
          message: 'Torba boş — taş değiştirilemez.',
          messageType: 'err',
        };
      }
      // Önce tahtaya konan geçici taşları rafa geri al.
      const recalled = recallAll(state);
      return {
        ...recalled,
        swapMode: true,
        swapSelection: [],
        message: 'Değiştireceğin taşları seç, sonra "Değiştir"e bas.',
        messageType: 'warn',
      };
    }

    case 'TOGGLE_SWAP_TILE': {
      if (state.phase !== 'play' || state.isGameOver || !state.swapMode) {
        return state;
      }
      const swapSelection = state.swapSelection.includes(action.index)
        ? state.swapSelection.filter((i) => i !== action.index)
        : [...state.swapSelection, action.index];
      return { ...state, swapSelection };
    }

    case 'CONFIRM_SWAP': {
      if (state.phase !== 'play' || state.isGameOver || !state.swapMode) {
        return state;
      }
      const me = state.players[state.current];
      if (state.swapSelection.length === 0) {
        return {
          ...state,
          message: 'En az bir taş seçmelisin.',
          messageType: 'err',
        };
      }
      // Seçilen taşları torbaya geri koy, yerine yeni taş çek.
      const selected = new Set(state.swapSelection);
      const returned: Tile[] = [];
      const kept: Tile[] = [];
      me.rack.forEach((t, i) => {
        if (selected.has(i)) {
          returned.push({ letter: t.wild ? '?' : t.letter, pts: t.pts });
        } else {
          kept.push(t);
        }
      });
      const bag = shuffle([...state.bag, ...returned]);
      const drawn = drawTiles(bag, returned.length);
      const rack = [...kept, ...drawn];

      // Taş değiştirmek de tıpkı pas gibi puansız bir turdur ve torbadaki
      // taşları azaltmaz — bu yüzden YZ'nin zorunlu değişimiyle aynı şekilde
      // art-arda-pas sayacına dahil edilir (bkz. AI_PLAY). Aksi halde
      // oyuncular sürekli taş değiştirerek oyunu hiç bitirmeyebilirdi.
      const consecutivePasses = state.consecutivePasses + 1;
      const moved: GameState = {
        ...state,
        bag,
        players: withRack(state, rack),
        placed: {},
        selectedTile: null,
        swapMode: false,
        swapSelection: [],
        consecutivePasses,
        moveHistory: [
          ...state.moveHistory,
          {
            turn: state.turnCount,
            player: state.current,
            words: [],
            points: 0,
            action: 'exchange',
            tileCount: returned.length,
          },
        ],
        message: `${me.name} ${returned.length} taş değiştirdi ve sırasını kullandı.`,
        messageType: 'warn',
      };
      if (consecutivePasses >= activePlayerCount(state.players) * MAX_PASS_ROUNDS) {
        return endGame(moved);
      }
      return advanceTurn(moved);
    }

    case 'SET_MESSAGE': {
      return { ...state, message: action.message, messageType: action.messageType };
    }

    case 'PLAY': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      const check = action.skipWordCheck
        ? validatePlacementStructural(state.board, state.placed, state.current, me.corners, isFirstMove(state))
        : validatePlacement(state.board, state.placed, state.current, me.corners, isFirstMove(state));
      if (!check.valid) {
        return { ...state, message: check.reason!, messageType: 'err' };
      }
      const basePts = calcScore(state.board, state.placed, state.bonuses);
      const formed = getFormedWords(state.board, state.placed);
      const wordRawScores = calcWordRawScores(state.board, state.placed, state.bonuses);

      // Rakip köşe sınırına değme: kazanılan puan köşe sahip(ler)iyle paylaşılır.
      const placedCoords = Object.keys(state.placed).map(
        (k) => k.split(',').map(Number) as [number, number],
      );
      const { pts, shares } = computeInvasionSplit(
        placedCoords,
        state.current,
        state.players,
        basePts,
        state.board,
      );
      const bonusNote = shares.length > 0
        ? ` (${shares.map((s) => `${s.amount} puanı ${state.players[s.index].name} kaptı`).join(', ')})`
        : '';

      // Yerleştirmeleri tahtaya işle.
      const board = state.board.map((row) => [...row]);
      for (const [k, tile] of Object.entries(state.placed)) {
        const [r, c] = k.split(',').map(Number);
        board[r][c] = { ...tile, owner: state.current };
      }

      // Rafı doldur.
      const bag = [...state.bag];
      const rack = [...me.rack];
      rack.push(...drawTiles(bag, RACK_SIZE - rack.length));

      // Bu hamle rafı + torbayı tamamen bitiriyorsa ve oynanan taşların
      // TAMAMI jokerse, jokerli bitiş bonusu eklenir (köşe vergisine tabi
      // değildir). Jokerle birlikte normal bir harf de oynandıysa bonus yok.
      const placedTiles = Object.values(state.placed);
      const jokerCount = placedTiles.filter((t) => t.wild).length;
      const onlyJokers = placedTiles.length > 0 && jokerCount === placedTiles.length;
      const finishesGame = rack.length === 0 && bag.length === 0;
      const finishBonus = finishesGame && onlyJokers ? jokerFinishBonus(jokerCount) : 0;
      const finishBonusNote = finishBonus > 0 ? ` (jokerli bitiş bonusu +${finishBonus})` : '';

      const newLongestWord = formed.reduce(
        (best, fw) => (fw.word.length > best.length ? fw.word : best),
        me.longestWord,
      );
      const isNewBestMove = basePts > me.bestMoveScore;
      const players = state.players.map((p, i) => {
        if (i === state.current) {
          return {
            ...p,
            rack,
            score: p.score + pts + finishBonus,
            bestMoveScore: isNewBestMove ? basePts : p.bestMoveScore,
            longestWord: newLongestWord,
            moveCount: p.moveCount + 1,
            moveScoreSum: p.moveScoreSum + basePts,
          };
        }
        const share = shares.find((s) => s.index === i);
        if (share) {
          return { ...p, score: p.score + share.amount };
        }
        return p;
      });

      const moved: GameState = {
        ...state,
        board,
        bag,
        placed: {},
        players,
        consecutivePasses: 0,
        selectedTile: null,
        lastMoveCells: placedCoords,
        moveHistory: appendMoveHistory(
          state.moveHistory,
          state.turnCount,
          state.current,
          formed.map((f) => f.word),
          pts + finishBonus,
          shares,
          finishBonus > 0 ? jokerCount : undefined,
          wordRawScores,
          placedTiles.length >= RACK_SIZE,
        ),
        message: `${me.name}: +${pts} puan${bonusNote}${finishBonusNote} Kelimeler: ${check.words!.join(', ')}`,
        messageType: 'ok',
      };
      return advanceTurn(moved);
    }

    case 'PASS': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const recalled = recallAll(state);
      const consecutivePasses = state.consecutivePasses + 1;
      const moved: GameState = {
        ...recalled,
        consecutivePasses,
        moveHistory: [
          ...state.moveHistory,
          { turn: state.turnCount, player: state.current, words: [], points: 0, action: 'pass' },
        ],
        message: `${state.players[state.current].name} pas geçti.`,
        messageType: 'warn',
      };
      // Tüm (teslim olmamış) oyuncular üst üste MAX_PASS_ROUNDS tur pas geçtiyse oyun biter.
      if (consecutivePasses >= activePlayerCount(state.players) * MAX_PASS_ROUNDS) {
        return endGame(moved);
      }
      return advanceTurn(moved);
    }

    case 'AI_PLAY': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      if (!me.isAI) return state;

      const move = findAIMove(
        state.board,
        me.rack,
        state.bonuses,
        state.current,
        me.corners,
        isFirstMove(state),
        state.players,
      );

      // Geçerli hamle yoksa: torbada taş varsa rafını değiştirir (aksi halde
      // oynanamayan aynı harflerle sonsuza dek pas geçer); torba boşsa pas
      // geçer. Her iki durum da pas sayacını artırır — herkes art arda
      // tıkanırsa oyun yine de biter, sadece tıkanan oyuncu bir sonraki
      // turunda şansını taze harflerle dener.
      if (!move) {
        const consecutivePasses = state.consecutivePasses + 1;
        let moved: GameState;
        if (state.bag.length > 0) {
          const returned = me.rack.map((t) => ({
            letter: t.wild ? '?' : t.letter,
            pts: t.pts,
          }));
          const bag = shuffle([...state.bag, ...returned]);
          const rack = drawTiles(bag, returned.length);
          moved = {
            ...state,
            bag,
            players: withRack(state, rack),
            consecutivePasses,
            moveHistory: [
              ...state.moveHistory,
              {
                turn: state.turnCount,
                player: state.current,
                words: [],
                points: 0,
                action: 'exchange',
                tileCount: returned.length,
              },
            ],
            message: `${me.name} harflerini değiştirdi.`,
            messageType: 'warn',
          };
        } else {
          moved = {
            ...state,
            consecutivePasses,
            moveHistory: [
              ...state.moveHistory,
              { turn: state.turnCount, player: state.current, words: [], points: 0, action: 'pass' },
            ],
            message: `${me.name} pas geçti.`,
            messageType: 'warn',
          };
        }
        if (consecutivePasses >= activePlayerCount(state.players) * MAX_PASS_ROUNDS) {
          return endGame(moved);
        }
        return advanceTurn(moved);
      }

      // Hamledeki taşları tahtaya işle ve raftan düş.
      const placedMap: Record<string, Tile> = {};
      for (const p of move.placements) placedMap[key(p.r, p.c)] = p.tile;
      const formed = getFormedWords(state.board, placedMap);
      const aiWordRawScores = calcWordRawScores(state.board, placedMap, state.bonuses);

      const board = state.board.map((row) => [...row]);
      const rack = [...me.rack];
      for (const p of move.placements) {
        board[p.r][p.c] = { ...p.tile, owner: state.current };
        const idx = p.tile.wild
          ? rack.findIndex((t) => t.letter === '?')
          : rack.findIndex((t) => t.letter === p.tile.letter);
        if (idx >= 0) rack.splice(idx, 1);
      }
      const bag = [...state.bag];
      rack.push(...drawTiles(bag, RACK_SIZE - rack.length));

      // Bu hamle rafı + torbayı tamamen bitiriyorsa ve oynanan taşların
      // TAMAMI jokerse, jokerli bitiş bonusu eklenir (köşe vergisine tabi
      // değildir). Jokerle birlikte normal bir harf de oynandıysa bonus yok.
      const aiJokerCount = move.placements.filter((p) => p.tile.wild).length;
      const aiOnlyJokers = move.placements.length > 0 && aiJokerCount === move.placements.length;
      const aiFinishesGame = rack.length === 0 && bag.length === 0;
      const aiFinishBonus = aiFinishesGame && aiOnlyJokers ? jokerFinishBonus(aiJokerCount) : 0;

      const aiCoords = move.placements.map((p) => [p.r, p.c] as [number, number]);
      const { pts: aiPts, shares: aiShares } = computeInvasionSplit(
        aiCoords,
        state.current,
        state.players,
        move.score,
        state.board,
      );

      const aiLongestWord = formed.reduce(
        (best, fw) => (fw.word.length > best.length ? fw.word : best),
        me.longestWord,
      );
      const aiIsNewBestMove = move.score > me.bestMoveScore;
      const players = state.players.map((p, i) => {
        if (i === state.current) {
          return {
            ...p,
            rack,
            score: p.score + aiPts + aiFinishBonus,
            bestMoveScore: aiIsNewBestMove ? move.score : p.bestMoveScore,
            longestWord: aiLongestWord,
            moveCount: p.moveCount + 1,
            moveScoreSum: p.moveScoreSum + move.score,
          };
        }
        const share = aiShares.find((s) => s.index === i);
        if (share) {
          return { ...p, score: p.score + share.amount };
        }
        return p;
      });

      const aiInvasionNote = aiShares.length > 0
        ? ` (${aiShares.map((s) => `${s.amount} puanı ${state.players[s.index].name} kaptı`).join(', ')})`
        : '';
      const aiFinishBonusNote = aiFinishBonus > 0 ? ` (jokerli bitiş bonusu +${aiFinishBonus})` : '';
      const moved: GameState = {
        ...state,
        board,
        bag,
        players,
        consecutivePasses: 0,
        lastMoveCells: aiCoords,
        moveHistory: appendMoveHistory(
          state.moveHistory,
          state.turnCount,
          state.current,
          formed.map((f) => f.word),
          aiPts + aiFinishBonus,
          aiShares,
          aiFinishBonus > 0 ? aiJokerCount : undefined,
          aiWordRawScores,
          move.placements.length >= RACK_SIZE,
        ),
        message: `${me.name} "${move.word}" oynadı. +${aiPts} puan.${aiInvasionNote}${aiFinishBonusNote}`,
        messageType: 'ok',
      };
      return advanceTurn(moved);
    }

    case 'RENAME_PLAYER': {
      if (state.phase !== 'play') return state;
      const players = state.players.map((p, i) =>
        i === action.index ? { ...p, name: action.name } : p,
      );
      return { ...state, players };
    }

    case 'SURRENDER': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const target = state.players[action.index];
      if (!target || target.surrendered) return state;

      // Sırası gelen oyuncu teslim olduysa, o turda tahtaya koyduğu geçici
      // taşları önce rafına geri al (yoksa taşlar oyundan tamamen kaybolur).
      const recalled = action.index === state.current ? recallAll(state) : state;

      // Rafında kalan kullanılmamış taşlar torbaya geri döner (yoksa
      // kalan oyuncular için o taşlar oyundan tamamen kaybolurdu). Puanı
      // dondurulmaz, sıfırlanır — teslim olmak puanı korumaz.
      const surrenderingPlayer = recalled.players[action.index];
      const returnedTiles = surrenderingPlayer.rack.map((t) => ({
        letter: t.wild ? '?' : t.letter,
        pts: t.pts,
      }));
      const bag = shuffle([...recalled.bag, ...returnedTiles]);
      const players = recalled.players.map((p, i) =>
        i === action.index ? { ...p, surrendered: true, score: 0, rack: [] } : p,
      );
      const withSurrender: GameState = {
        ...recalled,
        bag,
        players,
        moveHistory: [
          ...state.moveHistory,
          { turn: state.turnCount, player: action.index, words: [], points: 0, action: 'surrender' },
        ],
        message: `${target.name} teslim oldu.`,
        messageType: 'warn',
      };

      // Yalnızca 1 oyuncu kalırsa oyun biter — o oyuncu kazanır.
      if (activePlayerCount(players) <= 1) {
        return endGame(withSurrender, 'surrender');
      }
      // Teslim olan sıradaki oyuncuysa, sırayı bir sonraki (teslim olmamış)
      // oyuncuya geçir; değilse mevcut sıraya dokunma.
      if (action.index === state.current) {
        return advanceTurn(withSurrender);
      }
      return withSurrender;
    }

    // Faz 3 — Canlı oyun: sunucudan (online_game_states + get_my_online_rack)
    // gelen otoriter state'i yerel state'e uygular. `players[i].rack`
    // yalnızca `mySlotIndex`te gerçek (raftaki taşlar); diğer oyuncularınki
    // hiçbir zaman client'a gönderilmediğinden sahte/dolgu taşlarla
    // dolduruluyor — Board/GameHeader bunlara hiç bakmıyor, yalnızca
    // `Rack` bileşeni (her zaman kendi rafımızı gösterdiğimizden) gerçek
    // veriyle çalışıyor. Bu turda yerel olarak yerleştirilmiş taşlar
    // (`placed`) sunucudaki hamleyle her zaman ya onaylanmış ya da hâlâ
    // gönderilmemiş olduğundan sıfırlanır — sunucu tek doğruluk kaynağı.
    case 'SYNC_ONLINE_STATE': {
      const players: Player[] = action.publicState.players.map((p, i) => ({
        name: p.name,
        corners: p.corners,
        colorIndex: p.colorIndex,
        isAI: p.isAI,
        surrendered: p.surrendered,
        rack: i === action.mySlotIndex ? action.myRack : new Array(p.rackCount).fill({ letter: 'A', pts: 1 }),
        score: p.score,
        bestMoveScore: p.bestMoveScore,
        longestWord: p.longestWord,
        moveCount: p.moveCount,
        moveScoreSum: p.moveScoreSum,
      }));
      return {
        ...state,
        phase: 'play',
        startedAt: action.publicState.started_at,
        endReason: action.publicState.end_reason ?? 'normal',
        board: action.publicState.board,
        bag: new Array(action.publicState.bag_count).fill({ letter: 'A', pts: 1 }),
        bonuses: action.publicState.bonuses,
        placed: {},
        players,
        current: action.publicState.current,
        selectedTile: null,
        swapMode: false,
        swapSelection: [],
        turnCount: action.publicState.turn_count,
        consecutivePasses: action.publicState.consecutive_passes,
        isGameOver: action.publicState.is_game_over,
        message: '',
        messageType: '',
        lastMoveCells: action.publicState.last_move_cells,
      };
    }

    default:
      return state;
  }
}
