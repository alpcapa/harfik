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
  /**
   * `Board`'un `compact` modu — küçük harfler, puan üst simgesi yok, köşe
   * oyuncu-numarası filigranı yok, merkezdeki "X2" ve ortadaki "X3" yok.
   *
   * Varsayılanı `true`: ilk iki kullanım yeri (`GameHistoryModal` kart
   * açılımı, `SharedGamePage`) tahtayı KÜÇÜK bir önizleme olarak çiziyor.
   *
   * Karşılama katmanı `false` geçiyor — orada tahta bir önizleme değil
   * oyunun vitrini ve kullanıcının şartı "oyunun birebir aynı görüntüsü".
   * ⚠ Bunun DOĞRU görünmesi tahtanın gerçek oyunla AYNI GENİŞLİKTE
   * olmasına bağlı: harf boyutu `vw` tabanlı bir clamp (`Tile.tsx`), hücre
   * ise kabın genişliğine bağlı. Dar bir kapta `compact={false}` harfleri
   * orantısız büyük gösterir (18 Ağustos 2026'da tam bu yaşandı). Bkz.
   * `Landing.tsx`'te tahta bölümünün metin kolonunun dışına alınması.
   */
  compact?: boolean;
}

const noop = () => {};

export function GameBoardPreview({
  snapshot,
  playerCount,
  players,
  onClick,
  compact = true,
}: GameBoardPreviewProps) {
  const state = buildSnapshotGameState(snapshot, playerCount, players);
  return (
    <div onClick={onClick} className={onClick ? 'cursor-pointer' : undefined}>
      <div className="pointer-events-none">
        <Board
          state={state}
          onCellClick={noop}
          moveStatus={null}
          onOpenHistory={noop}
          hideFooter
          compact={compact}
        />
      </div>
    </div>
  );
}
