// Harfik — useReducer ile çok oyunculu (yerel) oyun durumu yönetimi
import {
  MAX_PASS_ROUNDS,
  PLAYER_COLORS,
  RACK_SIZE,
  buildInitialBonuses,
  cornersFor,
  regionOf,
} from './constants';
import type { GameState, Owner, Player, Tile } from './types';
import { buildBag, drawTiles } from '../utils/bag';
import { shuffle } from '../utils/random';
import { trUpper } from '../utils/turkish';
import {
  createEmptyBoard,
  getFormedWords,
  key,
  type FormedWord,
} from '../utils/board';
import {
  cellAllowed,
  calcScore,
  computeBreachedCorners,
  validatePlacement,
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
  | { type: 'PLACE_TILE'; r: number; c: number; wildLetter?: string }
  | { type: 'RECALL_CELL'; r: number; c: number }
  | { type: 'RECALL_ALL' }
  | { type: 'SHUFFLE_RACK' }
  | { type: 'TOGGLE_SWAP_MODE' }
  | { type: 'TOGGLE_SWAP_TILE'; index: number }
  | { type: 'CONFIRM_SWAP' }
  | { type: 'PLAY' }
  | { type: 'PASS' }
  | { type: 'AI_PLAY' };

/** Kurulum (oyuncu seçimi) ekranıyla başlayan boş durum. */
export function createInitialState(): GameState {
  return {
    phase: 'setup',
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
    lastWords: {},
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
    corner: corners[i],
    colorIndex: i % PLAYER_COLORS.length,
    isAI: s.isAI,
    rack: drawTiles(bag, RACK_SIZE),
    score: 0,
    bestMoveScore: 0,
    longestWord: '',
  }));

  return {
    phase: 'play',
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
    lastWords: {},
  };
}

/** Aktif oyuncunun tahtada hiç taşı yoksa true (ilk hamlesi). */
function isFirstMove(state: GameState): boolean {
  for (const row of state.board) {
    for (const t of row) {
      if (t && t.owner === state.current) return false;
    }
  }
  return true;
}

/**
 * Son hamlede oluşan kelimeleri `lastWords`'e yazar. Aynı oyuncunun önceki
 * kayıtları temizlenir.
 */
function setLastWords(
  prev: GameState['lastWords'],
  formed: FormedWord[],
  by: Owner,
): GameState['lastWords'] {
  const next = { ...prev };
  for (const k of Object.keys(next)) {
    if (next[k].by === by) delete next[k];
  }
  for (const fw of formed) {
    for (const [r, c] of fw.coords) {
      next[key(r, c)] = { word: fw.word, by };
    }
  }
  return next;
}

/** Kalan raf puanlarını her oyuncudan düşerek oyunu bitirir. */
function endGame(state: GameState): GameState {
  const players = state.players.map((p) => ({
    ...p,
    score: Math.max(0, p.score - p.rack.reduce((s, t) => s + t.pts, 0)),
  }));
  return {
    ...state,
    players,
    isGameOver: true,
    message: 'Oyun bitti.',
    messageType: '',
  };
}

/**
 * Tur sayacını ilerletir; bir raf+torba tükendiyse oyunu bitirir; sırayı
 * sonraki oyuncuya geçirir.
 */
function advanceTurn(state: GameState): GameState {
  const next = (state.current + 1) % state.players.length;
  const nextState: GameState = {
    ...state,
    turnCount: state.turnCount + 1,
    current: next,
    selectedTile: null,
    swapMode: false,
    swapSelection: [],
  };

  // Bir oyuncunun rafı boşaldıysa ve torba bittiyse oyun biter.
  const someoneEmpty = state.players.some((p) => p.rack.length === 0);
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

/** Aktif oyuncunun rafından bir taş çıkararak oyuncular dizisini günceller. */
function withRack(state: GameState, rack: Tile[]): Player[] {
  return state.players.map((p, i) => (i === state.current ? { ...p, rack } : p));
}

export function gameReducer(state: GameState, action: Action): GameState {
  switch (action.type) {
    case 'INIT':
      return createInitialState();

    case 'ABANDON':
      // Oyundan çıkış: -500 ceza skoru setup ekranına dönmeden önce uygulanır.
      // Skor yalnızca görsel (kalıcı istatistiklere kaydedilmez).
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
      if (state.selectedTile === null) {
        return { ...state, message: 'Önce bir harf seç.', messageType: '' };
      }
      const { r, c } = action;
      const k = key(r, c);
      if (state.board[r][c] || state.placed[k]) {
        return state; // dolu kare
      }

      // Bölge kuralı: kendi köşen, merkez ya da açılmış bir köşe olmalı.
      const me = state.players[state.current];
      const open = computeBreachedCorners(state.board, state.players);
      if (!cellAllowed(me.corner, open, r, c)) {
        return {
          ...state,
          message: 'Burası başka bir oyuncunun köşesi — henüz oraya oynayamazsın.',
          messageType: 'err',
        };
      }

      const source = me.rack[state.selectedTile];
      const tile: Tile = { ...source, owner: state.current };
      if (tile.letter === '?') {
        const wl = trUpper(action.wildLetter || 'A');
        tile.wild = true;
        tile.wildLetter = wl;
      }
      const rack = me.rack.filter((_, i) => i !== state.selectedTile);
      return {
        ...state,
        placed: { ...state.placed, [k]: tile },
        players: withRack(state, rack),
        selectedTile: null,
        message: 'Oyna tuşuyla kelimeyi onayla.',
        messageType: '',
      };
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

      const moved: GameState = {
        ...state,
        bag,
        players: withRack(state, rack),
        placed: {},
        selectedTile: null,
        swapMode: false,
        swapSelection: [],
        consecutivePasses: 0,
        message: `${me.name} ${returned.length} taş değiştirdi ve sırasını kullandı.`,
        messageType: 'warn',
      };
      return advanceTurn(moved);
    }

    case 'PLAY': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      const open = computeBreachedCorners(state.board, state.players);
      const check = validatePlacement(
        state.board,
        state.placed,
        me.corner,
        open,
        isFirstMove(state),
      );
      if (!check.valid) {
        return { ...state, message: check.reason!, messageType: 'err' };
      }
      const basePts = calcScore(state.board, state.placed, state.bonuses);
      const formed = getFormedWords(state.board, state.placed);

      // Rakip köşesine giriş bonusu: %50 fazla puan.
      const invadedZone = Object.keys(state.placed).some((k) => {
        const [r, c] = k.split(',').map(Number);
        const region = regionOf(r, c);
        return region !== -1 && region !== me.corner;
      });
      const pts = invadedZone ? Math.round(basePts * 1.5) : basePts;
      const bonusNote = invadedZone ? ' (+%50 köşe bonusu!)' : '';

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

      const newLongestWord = formed.reduce(
        (best, fw) => (fw.word.length > best.length ? fw.word : best),
        me.longestWord,
      );
      const players = state.players.map((p, i) =>
        i === state.current
          ? { ...p, rack, score: p.score + pts, bestMoveScore: Math.max(p.bestMoveScore, pts), longestWord: newLongestWord }
          : p,
      );

      const moved: GameState = {
        ...state,
        board,
        bag,
        placed: {},
        players,
        consecutivePasses: 0,
        selectedTile: null,
        lastWords: setLastWords(state.lastWords, formed, state.current),
        message: `${me.name}: +${pts} puan${bonusNote} Kelimeler: ${check.words!.join(', ')}`,
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
        message: `${state.players[state.current].name} pas geçti.`,
        messageType: 'warn',
      };
      // Tüm oyuncular üst üste MAX_PASS_ROUNDS tur pas geçtiyse oyun biter.
      if (consecutivePasses >= state.players.length * MAX_PASS_ROUNDS) {
        return endGame(moved);
      }
      return advanceTurn(moved);
    }

    case 'AI_PLAY': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      if (!me.isAI) return state;

      const open = computeBreachedCorners(state.board, state.players);
      const move = findAIMove(
        state.board,
        me.rack,
        state.bonuses,
        state.current,
        me.corner,
        open,
        isFirstMove(state),
      );

      // Geçerli hamle yoksa YZ pas geçer.
      if (!move) {
        const consecutivePasses = state.consecutivePasses + 1;
        const moved: GameState = {
          ...state,
          consecutivePasses,
          message: `${me.name} pas geçti.`,
          messageType: 'warn',
        };
        if (consecutivePasses >= state.players.length * MAX_PASS_ROUNDS) {
          return endGame(moved);
        }
        return advanceTurn(moved);
      }

      // Hamledeki taşları tahtaya işle ve raftan düş.
      const placedMap: Record<string, Tile> = {};
      for (const p of move.placements) placedMap[key(p.r, p.c)] = p.tile;
      const formed = getFormedWords(state.board, placedMap);

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

      const aiLongestWord = formed.reduce(
        (best, fw) => (fw.word.length > best.length ? fw.word : best),
        me.longestWord,
      );
      const players = state.players.map((p, i) =>
        i === state.current
          ? { ...p, rack, score: p.score + move.score, bestMoveScore: Math.max(p.bestMoveScore, move.score), longestWord: aiLongestWord }
          : p,
      );

      const moved: GameState = {
        ...state,
        board,
        bag,
        players,
        consecutivePasses: 0,
        lastWords: setLastWords(state.lastWords, formed, state.current),
        message: `${me.name} "${move.word}" oynadı. +${move.score} puan.`,
        messageType: 'ok',
      };
      return advanceTurn(moved);
    }

    default:
      return state;
  }
}
