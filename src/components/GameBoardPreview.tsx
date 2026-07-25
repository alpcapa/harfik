// Kelimeki — bitmiş bir oyunun tahtasının salt-okunur önizlemesi (GameHistoryModal)
import { buildSnapshotGameState } from '../utils/boardSnapshot';
import type { BoardSnapshotTile, GamePlayerSnapshot } from '../lib/database.types';
import { Board } from './Board';

interface GameBoardPreviewProps {
  snapshot: BoardSnapshotTile[];
  playerCount: number;
  players: GamePlayerSnapshot[];
}

const noop = () => {};

export function GameBoardPreview({ snapshot, playerCount, players }: GameBoardPreviewProps) {
  const state = buildSnapshotGameState(snapshot, playerCount, players);
  return (
    <div className="pointer-events-none">
      <Board state={state} onCellClick={noop} moveStatus={null} onOpenHistory={noop} hideFooter />
    </div>
  );
}
