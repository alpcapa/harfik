// Kelimeki — bitmiş bir oyunun tahtasının salt-okunur önizlemesi (GameHistoryModal)
import { buildSnapshotGameState } from '../utils/boardSnapshot';
import type { BoardSnapshotTile, GamePlayerSnapshot } from '../lib/database.types';
import { Board } from './Board';

interface GameBoardPreviewProps {
  snapshot: BoardSnapshotTile[];
  playerCount: number;
  players: GamePlayerSnapshot[];
  /** Verilirse tahtaya tıklanabilir olur (ör. kapat/paylaş aksiyon menüsünü açmak için). */
  onClick?: () => void;
}

const noop = () => {};

export function GameBoardPreview({ snapshot, playerCount, players, onClick }: GameBoardPreviewProps) {
  const state = buildSnapshotGameState(snapshot, playerCount, players);
  return (
    <div onClick={onClick} className={onClick ? 'cursor-pointer' : undefined}>
      <div className="pointer-events-none">
        <Board state={state} onCellClick={noop} moveStatus={null} onOpenHistory={noop} hideFooter compact />
      </div>
    </div>
  );
}
