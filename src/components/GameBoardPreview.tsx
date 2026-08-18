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
   * oyuncu-numarası filigranı yok, merkezdeki büyük "X2" filigranı ve
   * ortadaki "X3" etiketi yok.
   *
   * Varsayılan `true`, çünkü bu bileşenin ilk iki kullanım yeri
   * (`GameHistoryModal`'daki oyun kartı açılımı ve `SharedGamePage`) tahtayı
   * KÜÇÜK bir önizleme olarak çiziyor — orada filigranlar okunaksız bir
   * kalabalık üretiyordu.
   *
   * Karşılama katmanı (`src/landing/Landing.tsx`) bunu **`false`** geçiyor
   * (18 Ağustos 2026, kullanıcı isteği: *"Tanıtımda 2 veya 4 kişilik oyun
   * görsellerinde watermark'lar yok. Oyunun birebir aynı görüntüsü
   * olmalı."*) — orada tahta bir "önizleme" değil, oyunun vitrini; gerçek
   * oyunda görünen HER şey görünmeli. Ölçüldü: katmanın tahta kabı da
   * gerçek oyun ekranıyla aynı `max-w-[680px] px-3` kutusunda, yani
   * filigranların `vw` tabanlı `clamp()` boyutları iki yerde aynı düşüyor.
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
        <Board state={state} onCellClick={noop} moveStatus={null} onOpenHistory={noop} hideFooter compact={compact} />
      </div>
    </div>
  );
}
