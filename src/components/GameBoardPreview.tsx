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
   * Tahtanın filigranları: köşelerdeki büyük 1/2/3/4, merkezdeki X2 ve
   * ortadaki X3 etiketi. Varsayılanı `false` — `GameHistoryModal` kart
   * açılımı ve `SharedGamePage` KÜÇÜK bir önizleme çiziyor, orada
   * filigranlar okunaksız bir kalabalık üretiyordu.
   *
   * Karşılama katmanı (`src/landing/Landing.tsx`) bunu `true` geçiyor
   * (18 Ağustos 2026, kullanıcı isteği: *"Tanıtımda 2 veya 4 kişilik oyun
   * görsellerinde watermark'lar yok. Oyunun birebir aynı görüntüsü
   * olmalı."*).
   *
   * ⚠ Taş boyutunu DEĞİŞTİRMEZ. İlk denemede bunun yerine `compact`
   * tamamen kapatılmıştı ve harfler de büyüyüp puan üst simgeleri geldi —
   * kullanıcı "sadece filigranı düzelt demiştim" diye bildirdi. `Board`'da
   * iki kavram artık ayrı prop: `compact` taşları, `showMarks` filigranları
   * yönetiyor. Bu bileşen taşları HER ZAMAN `compact` çiziyor.
   */
  showMarks?: boolean;
}

const noop = () => {};

export function GameBoardPreview({
  snapshot,
  playerCount,
  players,
  onClick,
  showMarks = false,
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
          compact
          showMarks={showMarks}
        />
      </div>
    </div>
  );
}
