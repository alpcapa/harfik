// Kelimeki — karşılama katmanındaki tanıtım tahtası (statik, elle yazılmış).
//
// NEDEN GERÇEK `Board.tsx`: bu tahta bir çizim/ekran görüntüsü DEĞİL, üretim
// bileşeninin (`GameBoardPreview` → `Board`, `hideFooter compact`) sunucuda
// render edilmiş hâli. Yani köşe tonlamaları, bölge dış hatları, ev işareti,
// X2 bölgesi ve X3 hücresi oyunda ne görünüyorsa birebir odur — ayrı bir
// "tanıtım tahtası" çizimi bakımı imkânsız bir ikinci kopya olurdu (bu kod
// tabanının en sık tekrarlayan hata sınıfı; bkz. CLAUDE.md'deki renk paleti /
// rütbe tablosu / hukuki metin ayrışmaları).
//
// ⚠ HER YATAY VE DİKEY DİZİLİM GERÇEK BİR TÜRKÇE KELİME OLMAK ZORUNDA.
// Rastgele harf serpmek, kelime oyunu bilen bir ziyaretçiye anında sahte
// görünür. Doğrulama elle DEĞİL ölçerek yapıldı: `scripts/verify-demo-board.ts`
// bu dosyayı okuyup ≥2 uzunluktaki TÜM yatay/dikey dizilimleri
// `src/data/words.ts`e karşı sınar (`npm run verify-demo-board`).
//
// Kadro bilinçli: 2 kişilik oyun, 1. oyuncu (camgöbeği) sol-üst köşeden,
// 2. oyuncu (kırmızı) sağ-alt köşeden başlıyor — `cornersFor(2)` ile aynı.
// İkisi de kendi 4×4 bloğundan çıkıp merkezdeki 5×5 X2 bölgesine uzanıyor,
// yani ekran görüntüsü oyunun ASIL mekaniğini (bölge genişletme) anlatıyor.
import type { BoardSnapshotTile } from '../lib/database.types';

type Yon = 'yatay' | 'dikey';

/** [satır, sütun, yön, kelime, oyuncu (0 = camgöbeği, 1 = kırmızı)] */
const YERLESIM: [number, number, Yon, string, number][] = [
  // ── 1. oyuncu: sol-üst köşeden merkeze ────────────────────────────────
  [0, 0, 'yatay', 'KELİME', 0], // ev karesi (0,0) — zorunlu başlangıç
  [0, 0, 'dikey', 'KAPI', 0],
  [3, 0, 'yatay', 'IRMAK', 0],
  [3, 4, 'dikey', 'KUZEY', 0],
  [5, 4, 'yatay', 'ZAMAN', 0], // 5×5 X2 bölgesini boydan boya geçiyor
  // ── 2. oyuncu: sağ-alt köşeden merkeze ────────────────────────────────
  [12, 9, 'yatay', 'OYUN', 1], // ev karesi (12,12)
  [10, 12, 'dikey', 'SON', 1],
  [10, 10, 'yatay', 'SES', 1],
  [8, 10, 'dikey', 'KAS', 1],
  [8, 6, 'yatay', 'KONAK', 1], // bu da X2 bölgesine giriyor
];

// JOKER TAŞI BİLEREK YOK: `Tile.tsx` joker taşını ayrı çizmiyor (yalnızca
// puanı 0), `compact` modda da puanlar hiç gösterilmiyor — yani tanıtım
// tahtasına konan bir joker ziyaretçiye HİÇBİR ŞEY anlatmazdı. (Denendi ve
// ekran görüntüsüyle doğrulandı: normal taştan ayırt edilemiyordu.)

function uret(): BoardSnapshotTile[] {
  const tiles: BoardSnapshotTile[] = [];
  const dolu = new Set<string>();
  for (const [r, c, yon, kelime, sahip] of YERLESIM) {
    const harfler = Array.from(kelime);
    for (let i = 0; i < harfler.length; i++) {
      const rr = yon === 'yatay' ? r : r + i;
      const cc = yon === 'yatay' ? c + i : c;
      const key = `${rr},${cc}`;
      // Kesişen kelimeler ortak harfi paylaşır — ikinci kez yazılmaz.
      if (dolu.has(key)) continue;
      dolu.add(key);
      tiles.push({ r: rr, c: cc, l: harfler[i], o: sahip });
    }
  }
  return tiles;
}

export const DEMO_TILES: BoardSnapshotTile[] = uret();
