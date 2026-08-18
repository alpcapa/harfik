// Kelimeki — karşılama katmanındaki tanıtım tahtaları (statik, elle yazılmış).
//
// NEDEN GERÇEK `Board.tsx`: bu tahtalar çizim/ekran görüntüsü DEĞİL, üretim
// bileşeninin (`GameBoardPreview` → `Board`, `hideFooter compact`) sunucuda
// render edilmiş hâli. Yani köşe tonlamaları, bölge dış hatları, ev işareti,
// X2 bölgesi ve X3 hücresi oyunda ne görünüyorsa birebir odur — ayrı bir
// "tanıtım tahtası" çizimi bakımı imkânsız bir ikinci kopya olurdu (bu kod
// tabanının en sık tekrarlayan hata sınıfı; bkz. CLAUDE.md'deki renk paleti /
// rütbe tablosu / hukuki metin ayrışmaları).
//
// ⚠ HER YATAY VE DİKEY DİZİLİM GERÇEK BİR TÜRKÇE KELİME OLMAK ZORUNDA.
// Rastgele harf serpmek, kelime oyunu bilen bir ziyaretçiye anında sahte
// görünür. Doğrulama elle DEĞİL ölçerek yapılıyor: `npm run verify-demo-board`
// AŞAĞIDAKİ İKİ TAHTAYI DA okuyup ≥2 uzunluktaki TÜM yatay/dikey dizilimleri
// `src/data/words.ts`e karşı sınar ve her oyuncunun taşlarının kendi EV
// karesinden ortogonal bağlı olduğunu kontrol eder.
//
// İKİ TAHTA VAR (18 Ağustos 2026, kullanıcı isteği — kaydırmalı iki görsel):
//   • 2 kişilik — karşılıklı köşeler, ikisi de merkezdeki X2 bölgesine uzanmış.
//   • 4 kişilik — dört köşe birden dolu; "3 rakibe karşı" mesajını taşıyor.
// Köşe/renk eşlemesi `cornersFor(playerCount)` ile aynı, yani tahtalar
// oyunun kendi kurallarına uyuyor.
import type { BoardSnapshotTile } from '../lib/database.types';

type Yon = 'yatay' | 'dikey';

/** [satır, sütun, yön, kelime, oyuncu (koltuk indeksi = renk indeksi)] */
type Yerlesim = [number, number, Yon, string, number][];

// ── 2 kişilik: 0 = sol-üst (camgöbeği), 1 = sağ-alt (kırmızı) ──────────────
const IKI_KISILIK: Yerlesim = [
  [0, 0, 'yatay', 'KELİME', 0], // ev karesi (0,0) — zorunlu başlangıç
  [0, 0, 'dikey', 'KAPI', 0],
  [3, 0, 'yatay', 'IRMAK', 0],
  [3, 4, 'dikey', 'KUZEY', 0],
  [5, 4, 'yatay', 'ZAMAN', 0], // 5×5 X2 bölgesini boydan boya geçiyor
  [12, 9, 'yatay', 'OYUN', 1], // ev karesi (12,12)
  [10, 12, 'dikey', 'SON', 1],
  [10, 10, 'yatay', 'SES', 1],
  [8, 10, 'dikey', 'KAS', 1],
  [8, 6, 'yatay', 'KONAK', 1], // bu da X2 bölgesine giriyor
];

// ── 4 kişilik: 0 sol-üst, 1 sağ-üst, 2 sol-alt, 3 sağ-alt ─────────────────
// Ev kareleri sırasıyla (0,0) · (0,12) · (12,0) · (12,12).
const DORT_KISILIK: Yerlesim = [
  [0, 0, 'yatay', 'KELİME', 0],
  [0, 0, 'dikey', 'KAPI', 0],
  [3, 0, 'yatay', 'IRMAK', 0],
  [0, 7, 'yatay', 'BALKON', 1], // (0,12) ev karesinde bitiyor
  [0, 12, 'dikey', 'NAR', 1],
  [2, 10, 'yatay', 'SIR', 1],
  [2, 10, 'dikey', 'SAP', 1],
  [12, 0, 'yatay', 'KUZEY', 2], // (12,0) ev karesinden başlıyor
  [11, 0, 'dikey', 'OK', 2],
  [11, 4, 'yatay', 'ADAM', 2],
  [11, 4, 'dikey', 'AY', 2], // (12,4) KUZEY'in Y'si — zinciri birleştiriyor
  [12, 9, 'yatay', 'OYUN', 3], // (12,12) ev karesinde bitiyor
  [10, 12, 'dikey', 'SON', 3],
  [10, 10, 'yatay', 'SES', 3],
  [8, 10, 'dikey', 'KAS', 3],
];

// JOKER TAŞI BİLEREK YOK: `Tile.tsx` joker taşını ayrı çizmiyor (yalnızca
// puanı 0), `compact` modda da puanlar hiç gösterilmiyor — yani tanıtım
// tahtasına konan bir joker ziyaretçiye HİÇBİR ŞEY anlatmazdı. (Denendi ve
// ekran görüntüsüyle doğrulandı: normal taştan ayırt edilemiyordu.)

function uret(yerlesim: Yerlesim): BoardSnapshotTile[] {
  const tiles: BoardSnapshotTile[] = [];
  const dolu = new Set<string>();
  for (const [r, c, yon, kelime, sahip] of yerlesim) {
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

export const DEMO_TILES_2: BoardSnapshotTile[] = uret(IKI_KISILIK);
export const DEMO_TILES_4: BoardSnapshotTile[] = uret(DORT_KISILIK);

/** Doğrulama betiğinin (ve tanıtım sayfasının) tükettiği ortak liste. */
export const DEMO_BOARDS: { playerCount: number; tiles: BoardSnapshotTile[] }[] = [
  { playerCount: 2, tiles: DEMO_TILES_2 },
  { playerCount: 4, tiles: DEMO_TILES_4 },
];
