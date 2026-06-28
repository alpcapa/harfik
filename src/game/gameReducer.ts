// Harfik — useReducer ile oyun durumu yönetimi
import {
  EVOLVE_INTERVAL,
  MAX_CONSECUTIVE_PASSES,
  RACK_SIZE,
  buildInitialBonuses,
} from './constants';
import type { GameState, Tile } from './types';
import { buildBag, drawTiles } from '../utils/bag';
import { createEmptyBoard, key } from '../utils/board';
import { validatePlacement, calcScore } from '../utils/validator';
import { findAIMove } from '../utils/ai';
import { evolveBoard } from '../utils/boardEvolution';

export type Action =
  | { type: 'INIT' }
  | { type: 'SELECT_TILE'; index: number }
  | { type: 'PLACE_TILE'; r: number; c: number; wildLetter?: string }
  | { type: 'RECALL_CELL'; r: number; c: number }
  | { type: 'RECALL_ALL' }
  | { type: 'PLAY' }
  | { type: 'PASS' }
  | { type: 'AI_PLAY' }
  | { type: 'DISMISS_TOAST' };

export function createInitialState(): GameState {
  const bag = buildBag();
  const playerRack = drawTiles(bag, RACK_SIZE);
  const aiRack = drawTiles(bag, RACK_SIZE);
  return {
    board: createEmptyBoard(),
    bag,
    bonuses: buildInitialBonuses(),
    cellState: {},
    placed: {},
    playerRack,
    aiRack,
    playerScore: 0,
    aiScore: 0,
    playerTurn: true,
    selectedTile: null,
    turnCount: 0,
    turnsUntilEvolve: EVOLVE_INTERVAL,
    consecutivePasses: 0,
    isGameOver: false,
    message: 'Bir harf seç, sonra tahtaya yerleştir.',
    messageType: '',
    turnLabel: 'Senin sıran',
    evolveToast: false,
  };
}

/** Kalan raf puanlarını düşerek oyunu bitirir. */
function endGame(state: GameState): GameState {
  const playerScore = Math.max(
    0,
    state.playerScore - state.playerRack.reduce((s, t) => s + t.pts, 0),
  );
  const aiScore = Math.max(
    0,
    state.aiScore - state.aiRack.reduce((s, t) => s + t.pts, 0),
  );
  return {
    ...state,
    playerScore,
    aiScore,
    isGameOver: true,
    playerTurn: false,
    turnLabel: 'Oyun bitti',
    evolveToast: false,
  };
}

/**
 * Tur sayacını ilerletir; gerektiğinde tahtayı evrimleştirir; raf+torba
 * tükendiyse oyunu bitirir; sırayı `nextPlayerTurn` tarafına geçirir.
 * Çağrıldığında `state` zaten hamle sonrası güncel olmalıdır.
 */
function advanceTurn(state: GameState, nextPlayerTurn: boolean): GameState {
  let turnsUntilEvolve = state.turnsUntilEvolve - 1;
  let cellState = state.cellState;
  let bonuses = state.bonuses;
  let evolveToast = false;

  if (turnsUntilEvolve <= 0) {
    const res = evolveBoard(
      state.board,
      state.cellState,
      state.bonuses,
      state.turnCount,
    );
    cellState = res.cellState;
    bonuses = res.bonuses;
    turnsUntilEvolve = EVOLVE_INTERVAL;
    evolveToast = true;
  }

  const next: GameState = {
    ...state,
    cellState,
    bonuses,
    turnsUntilEvolve,
    turnCount: state.turnCount + 1,
    evolveToast,
    playerTurn: nextPlayerTurn,
    turnLabel: nextPlayerTurn ? 'Senin sıran' : 'YZ düşünüyor…',
  };

  // Bir raf boşaldıysa ve torba bittiyse oyun biter.
  if (
    (next.playerRack.length === 0 || next.aiRack.length === 0) &&
    next.bag.length === 0
  ) {
    return endGame(next);
  }
  return next;
}

/** Geçici yerleştirilen taşları rafa geri toplar. */
function recallAll(state: GameState): GameState {
  const playerRack = [...state.playerRack];
  for (const tile of Object.values(state.placed)) {
    playerRack.push({ letter: tile.wild ? '?' : tile.letter, pts: tile.pts });
  }
  return { ...state, playerRack, placed: {}, selectedTile: null };
}

export function gameReducer(state: GameState, action: Action): GameState {
  switch (action.type) {
    case 'INIT':
      return createInitialState();

    case 'SELECT_TILE': {
      if (!state.playerTurn || state.isGameOver) return state;
      const selectedTile =
        state.selectedTile === action.index ? null : action.index;
      return { ...state, selectedTile };
    }

    case 'PLACE_TILE': {
      if (!state.playerTurn || state.isGameOver) return state;
      if (state.selectedTile === null) {
        return {
          ...state,
          message: 'Önce bir harf seç.',
          messageType: '',
        };
      }
      const { r, c } = action;
      const k = key(r, c);
      const st = state.cellState[k];
      if (state.board[r][c] || state.placed[k] || st === 'void' || st === 'crack') {
        return state; // dolu ya da oynanamaz kare
      }
      const source = state.playerRack[state.selectedTile];
      const tile: Tile = { ...source, owner: 'player' };
      if (tile.letter === '?') {
        const wl = (action.wildLetter || 'A').toUpperCase();
        tile.wild = true;
        tile.wildLetter = wl;
      }
      const playerRack = state.playerRack.filter(
        (_, i) => i !== state.selectedTile,
      );
      return {
        ...state,
        board: state.board,
        placed: { ...state.placed, [k]: tile },
        playerRack,
        selectedTile: null,
        message: 'Oyna tuşuyla kelimeyi onayla.',
        messageType: '',
      };
    }

    case 'RECALL_CELL': {
      if (!state.playerTurn || state.isGameOver) return state;
      const k = key(action.r, action.c);
      const tile = state.placed[k];
      if (!tile) return state;
      const placed = { ...state.placed };
      delete placed[k];
      const playerRack = [
        ...state.playerRack,
        { letter: tile.wild ? '?' : tile.letter, pts: tile.pts },
      ];
      return { ...state, placed, playerRack, selectedTile: null };
    }

    case 'RECALL_ALL': {
      if (!state.playerTurn || state.isGameOver) return state;
      return {
        ...recallAll(state),
        message: 'Taşlar rafa geri alındı.',
        messageType: '',
      };
    }

    case 'PLAY': {
      if (!state.playerTurn || state.isGameOver) return state;
      const check = validatePlacement(state.board, state.placed, state.cellState);
      if (!check.valid) {
        return { ...state, message: check.reason!, messageType: 'err' };
      }
      const pts = calcScore(state.board, state.placed, state.bonuses);

      // Yerleştirmeleri tahtaya işle.
      const board = state.board.map((row) => [...row]);
      for (const [k, tile] of Object.entries(state.placed)) {
        const [r, c] = k.split(',').map(Number);
        board[r][c] = { ...tile, owner: 'player' };
      }

      // Rafı doldur.
      const bag = [...state.bag];
      const playerRack = [...state.playerRack];
      playerRack.push(...drawTiles(bag, RACK_SIZE - playerRack.length));

      const moved: GameState = {
        ...state,
        board,
        bag,
        placed: {},
        playerRack,
        playerScore: state.playerScore + pts,
        consecutivePasses: 0,
        selectedTile: null,
        message: `+${pts} puan! Kelimeler: ${check.words!.join(', ')}`,
        messageType: 'ok',
      };
      return advanceTurn(moved, false);
    }

    case 'PASS': {
      if (!state.playerTurn || state.isGameOver) return state;
      const recalled = recallAll(state);
      const consecutivePasses = state.consecutivePasses + 1;
      const moved: GameState = {
        ...recalled,
        consecutivePasses,
        message: 'Pas geçtin.',
        messageType: 'warn',
      };
      if (consecutivePasses >= MAX_CONSECUTIVE_PASSES) {
        return endGame(moved);
      }
      return advanceTurn(moved, false);
    }

    case 'AI_PLAY': {
      if (state.playerTurn || state.isGameOver) return state;
      const move = findAIMove(
        state.board,
        state.aiRack,
        state.cellState,
        state.bonuses,
      );

      if (!move) {
        const consecutivePasses = state.consecutivePasses + 1;
        const moved: GameState = {
          ...state,
          consecutivePasses,
          message: 'YZ pas geçti.',
          messageType: 'warn',
        };
        if (consecutivePasses >= MAX_CONSECUTIVE_PASSES) {
          return endGame(moved);
        }
        return advanceTurn(moved, true);
      }

      const board = state.board.map((row) => [...row]);
      const aiRack = [...state.aiRack];
      for (const p of move.placements) {
        board[p.r][p.c] = { ...p.tile, owner: 'ai' };
        const idx = p.tile.wild
          ? aiRack.findIndex((t) => t.letter === '?')
          : aiRack.findIndex((t) => t.letter === p.tile.letter);
        if (idx >= 0) aiRack.splice(idx, 1);
      }
      const bag = [...state.bag];
      aiRack.push(...drawTiles(bag, RACK_SIZE - aiRack.length));

      const moved: GameState = {
        ...state,
        board,
        bag,
        aiRack,
        aiScore: state.aiScore + move.score,
        consecutivePasses: 0,
        message: `YZ "${move.word}" oynadı. +${move.score} puan.`,
        messageType: '',
      };
      return advanceTurn(moved, true);
    }

    case 'DISMISS_TOAST':
      return state.evolveToast ? { ...state, evolveToast: false } : state;

    default:
      return state;
  }
}
