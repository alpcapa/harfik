// Harfik — useReducer ile çok oyunculu (yerel) oyun durumu yönetimi
import {
  MAX_PASS_ROUNDS,
  PLAYER_COLORS,
  RACK_SIZE,
  buildInitialBonuses,
  cornersFor,
} from './constants';
import type { GameState, Owner, Player, Tile } from './types';
import { buildBag, drawTiles } from '../utils/bag';
import {
  createEmptyBoard,
  getFormedWords,
  key,
  type FormedWord,
} from '../utils/board';
import {
  cellAllowed,
  calcScore,
  computeOpenCorners,
  validatePlacement,
} from '../utils/validator';

export type Action =
  | { type: 'INIT' }
  | { type: 'START'; names: string[] }
  | { type: 'SELECT_TILE'; index: number }
  | { type: 'PLACE_TILE'; r: number; c: number; wildLetter?: string }
  | { type: 'RECALL_CELL'; r: number; c: number }
  | { type: 'RECALL_ALL' }
  | { type: 'PLAY' }
  | { type: 'PASS' };

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
    turnCount: 0,
    consecutivePasses: 0,
    isGameOver: false,
    message: '',
    messageType: '',
    lastWords: {},
  };
}

/** İsim listesinden (2 ya da 4) oyunu kurar ve ilk taşları dağıtır. */
function startGame(names: string[]): GameState {
  const count = names.length;
  const corners = cornersFor(count);
  const bag = buildBag();
  const players: Player[] = names.map((name, i) => ({
    name: name.trim() || `Oyuncu ${i + 1}`,
    corner: corners[i],
    colorIndex: i % PLAYER_COLORS.length,
    rack: drawTiles(bag, RACK_SIZE),
    score: 0,
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

    case 'START': {
      if (action.names.length !== 2 && action.names.length !== 4) return state;
      return startGame(action.names);
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
      const open = computeOpenCorners(state.board, state.players);
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
        const wl = (action.wildLetter || 'A').toUpperCase();
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

    case 'PLAY': {
      if (state.phase !== 'play' || state.isGameOver) return state;
      const me = state.players[state.current];
      const open = computeOpenCorners(state.board, state.players);
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
      const pts = calcScore(state.board, state.placed, state.bonuses);
      const formed = getFormedWords(state.board, state.placed);

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

      const players = state.players.map((p, i) =>
        i === state.current ? { ...p, rack, score: p.score + pts } : p,
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
        message: `${me.name}: +${pts} puan! Kelimeler: ${check.words!.join(', ')}`,
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
      // Herkes üst üste birkaç tur pas geçtiyse oyun biter.
      if (consecutivePasses >= state.players.length * MAX_PASS_ROUNDS) {
        return endGame(moved);
      }
      return advanceTurn(moved);
    }

    default:
      return state;
  }
}
