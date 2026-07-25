// Kelimeki — bitmiş bir oyunun tahtasını kompakt bir JSON'a (games.board_snapshot)
// çevirir ve geri yükler. Yalnızca dolu hücreler tutulur (boş hücreler hiç
// yazılmaz) — Board.tsx'in kendisi zaten bonus bölgesi/köşe düzenini
// sabitlerden (constants.ts) türettiğinden bunları ayrıca saklamaya gerek yok.
import { buildInitialBonuses, cornersFor } from '../game/constants';
import type { GameState, Player } from '../game/types';
import { createEmptyBoard, type Board } from './board';
import { letterPoints } from '../data/tiles';
import type { BoardSnapshotTile, GamePlayerSnapshot } from '../lib/database.types';

export type { BoardSnapshotTile };

export function serializeBoardSnapshot(board: Board): BoardSnapshotTile[] {
  const tiles: BoardSnapshotTile[] = [];
  for (let r = 0; r < board.length; r++) {
    for (let c = 0; c < board[r].length; c++) {
      const tile = board[r][c];
      if (!tile) continue;
      const wild = !!tile.wild;
      tiles.push({
        r,
        c,
        l: wild ? tile.wildLetter ?? tile.letter : tile.letter,
        o: tile.owner ?? 0,
        ...(wild ? { w: true } : null),
      });
    }
  }
  return tiles;
}

/**
 * Bir board_snapshot'tan, `Board.tsx`'i olduğu gibi (salt-okunur) render
 * edebilmek için sahte ama tip açısından geçerli bir `GameState` üretir.
 * `players`, o oyunun `games.players` (final sıralaması) sütunudur — koltuk
 * kimliği `colorIndex`'ten okunur (final sıralamadaki KONUMdan bağımsız),
 * böylece köşeler/renkler gerçek oyundaki gibi eşleşir.
 */
export function buildSnapshotGameState(
  snapshot: BoardSnapshotTile[],
  playerCount: number,
  players: GamePlayerSnapshot[],
): GameState {
  const board = createEmptyBoard();
  for (const t of snapshot) {
    board[t.r][t.c] = {
      letter: t.w ? '?' : t.l,
      pts: t.w ? 0 : letterPoints(t.l),
      wild: t.w || undefined,
      wildLetter: t.w ? t.l : undefined,
      owner: t.o,
    };
  }

  const corners = cornersFor(playerCount);
  const seats: Player[] = Array.from({ length: playerCount }, (_, seat) => {
    const meta = players.find((p) => p.colorIndex === seat);
    return {
      name: meta?.name ?? '',
      corners: corners[seat] ?? [],
      colorIndex: seat,
      isAI: meta?.is_ai ?? false,
      surrendered: meta?.surrendered ?? false,
      rack: [],
      score: meta?.score ?? 0,
      bestMoveScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    };
  });

  return {
    phase: 'play',
    startedAt: '',
    multiSession: false,
    endReason: 'normal',
    board,
    bag: [],
    bonuses: buildInitialBonuses(),
    placed: {},
    players: seats,
    current: 0,
    selectedTile: null,
    swapMode: false,
    swapSelection: [],
    turnCount: 0,
    consecutivePasses: 0,
    isGameOver: true,
    message: '',
    messageType: '',
    lastMoveCells: [],
    moveHistory: [],
  };
}
