// Kelimeki — kelime doğrulama, bölge kuralları ve puanlama
import { BINGO_BONUS, RACK_SIZE, SIZE, cornerBounds, cornerCell, inBonusZone } from '../game/constants';
import type { BonusType, Player, ValidationResult } from '../game/types';
import { getWordSet } from '../data/wordSetLoader';
import { trLower } from './turkish';
import {
  getFormedWords,
  key,
  type Board,
  type Placed,
} from './board';

/** Verilen harf havuzuyla kelime hecelenebilir mi? Joker ('?') jokeri sayar. */
export function canSpell(word: string, rack: string[]): boolean {
  const avail = [...rack];
  for (const ch of word) {
    const i = avail.indexOf(ch);
    if (i >= 0) {
      avail.splice(i, 1);
    } else {
      const wi = avail.indexOf('?');
      if (wi >= 0) avail.splice(wi, 1);
      else return false;
    }
  }
  return true;
}

/**
 * Oyuncunun sahip olduğu köşelerden, henüz hiç kendi taşının bulunmadığı
 * ("taze") olanları döner. Her oyuncunun tek bir köşesi olduğundan, bu
 * yalnızca ilk hamleden önce (o köşe hâlâ boşken) doludur; bir kez
 * oynandıktan sonra oyuncunun tüm sonraki kelimeleri mevcut taşlara
 * bağlanmak zorundadır.
 */
export function freshCorners(board: Board, ownCorners: number[], owner: number): number[] {
  return ownCorners.filter((corner) => {
    const b = cornerBounds(corner);
    for (let r = b.r0; r <= b.r1; r++) {
      for (let c = b.c0; c <= b.c1; c++) {
        if (board[r][c]?.owner === owner) return false;
      }
    }
    return true;
  });
}

/**
 * Yapısal doğrulama — hizalama, bölge kuralları, bağlantı, kelime varlığı;
 * sözlük kontrolü yapılmaz. Geçerliyse oluşan kelimeleri döner.
 * Sunucu doğrulaması yaparken önce bu çağrılır, ardından kelimeler RPC'ye gönderilir.
 */
export function validatePlacementStructural(
  board: Board,
  placed: Placed,
  owner: number,
  ownCorners: number[],
  isFirstMove: boolean,
): ValidationResult {
  const keys = Object.keys(placed);
  if (keys.length === 0) {
    return { valid: false, reason: 'Harf yerleştirilmedi.' };
  }

  const coords = keys.map((k) => k.split(',').map(Number) as [number, number]);
  const rows = [...new Set(coords.map((p) => p[0]))];
  const cols = [...new Set(coords.map((p) => p[1]))];
  const horiz = rows.length === 1;
  const vert = cols.length === 1;
  if (!horiz && !vert) {
    return { valid: false, reason: 'Harfler aynı satır ya da sütunda olmalı.' };
  }

  // Süreklilik kuralı: yerleştirilen taşlar arasında, tahtada zaten bir taş
  // bulunmayan boş hücre olamaz — aradaki her hücre ya bu turda konmuş ya da
  // önceden tahtada olmalı.
  if (horiz) {
    const r = rows[0];
    const minC = Math.min(...cols);
    const maxC = Math.max(...cols);
    for (let c = minC; c <= maxC; c++) {
      if (!placed[key(r, c)] && !board[r][c]) {
        return { valid: false, reason: 'Harfler arasında boşluk bırakılamaz.' };
      }
    }
  } else {
    const c = cols[0];
    const minR = Math.min(...rows);
    const maxR = Math.max(...rows);
    for (let r = minR; r <= maxR; r++) {
      if (!placed[key(r, c)] && !board[r][c]) {
        return { valid: false, reason: 'Harfler arasında boşluk bırakılamaz.' };
      }
    }
  }

  const fresh = freshCorners(board, ownCorners, owner);
  const startsFreshCorner = coords.some(([r, c]) =>
    fresh.some((corner) => {
      const [cr, cc] = cornerCell(corner);
      return r === cr && c === cc;
    }),
  );

  if (isFirstMove) {
    if (!startsFreshCorner) {
      return { valid: false, reason: 'İlk kelimen kendi köşe karesine değmeli.' };
    }
  } else {
    const connects = coords.some(([r, c]) =>
      [
        [r - 1, c],
        [r + 1, c],
        [r, c - 1],
        [r, c + 1],
      ].some(
        ([nr, nc]) =>
          nr >= 0 && nr < SIZE && nc >= 0 && nc < SIZE && board[nr][nc],
      ),
    );
    // Bağlanmıyorsa, oyuncunun henüz kullanmadığı bir köşesinden bağımsız
    // yeni bir kelimeyle başlaması da (ilk hamledeki gibi) geçerlidir.
    if (!connects && !startsFreshCorner) {
      return { valid: false, reason: 'Kelime mevcut harflere bağlanmalı.' };
    }
  }

  const formed = getFormedWords(board, placed);
  if (formed.length === 0) {
    return { valid: false, reason: 'Geçerli kelime oluşmadı.' };
  }

  return { valid: true, words: formed.map((f) => f.word) };
}

/**
 * Bir ya da daha fazla geçersiz kelimeyi tek bir Türkçe hata mesajında
 * birleştirir: tek kelimede "geçerli bir kelime değil", birden fazlasında
 * hepsi listelenip "geçerli kelimeler değil" olur.
 */
export function formatInvalidWordsReason(words: string[]): string {
  const quoted = words.map((w) => `"${w}"`);
  const list =
    quoted.length <= 1
      ? quoted.join('')
      : `${quoted.slice(0, -1).join(', ')} ve ${quoted[quoted.length - 1]}`;
  return quoted.length > 1
    ? `${list} geçerli kelimeler değil.`
    : `${list} geçerli bir kelime değil.`;
}

/**
 * Oyuncunun bu turdaki yerleştirmesini doğrular: hizalama, bölge kuralları,
 * bağlantı ve yerel sözlük. Geçerliyse oluşan kelimeleri döndürür.
 */
export function validatePlacement(
  board: Board,
  placed: Placed,
  owner: number,
  ownCorners: number[],
  isFirstMove: boolean,
): ValidationResult {
  const structural = validatePlacementStructural(board, placed, owner, ownCorners, isFirstMove);
  if (!structural.valid) return structural;

  // structural.words zaten validatePlacementStructural içindeki getFormedWords
  // sonucudur — burada aynı tahtayı ikinci kez taramaya gerek yok.
  const invalidWords = Array.from(
    new Set((structural.words ?? []).filter((word) => !getWordSet().has(trLower(word)))),
  );
  if (invalidWords.length > 0) {
    return { valid: false, reason: formatInvalidWordsReason(invalidWords) };
  }
  return structural;
}

/**
 * Bir oyuncunun köşesinden başlayıp yalnızca KENDİ taşları üzerinden
 * ortogonal olarak bağlı hücreleri döner — gerçek "fetih" zinciri. Seed,
 * köşe sınırları içindeki hücrelerin TAMAMIDIR — ister `owner`a ait bir taş
 * taşısın ister boş olsun; sadece BAŞKA bir oyuncuya ait bir taş taşıyan
 * köşe hücreleri seed'in dışında kalır (bir kale fethi tarafından ele
 * geçirilmiş olabilirler, bkz. `computeAllTerritories`). Böylece 4×4 köşe
 * bloğunun henüz kimse tarafından ele geçirilmemiş kısmı baştan itibaren
 * "geçit" gibi davranır: bloğun herhangi bir kenarına bitişik yeni bir taş,
 * o taş `owner`a aitse zincire hemen dahil olur — köşenin tam ucundaki
 * başlangıç hücresinden fiilen taş taş ilerlemiş olmaya gerek yoktur.
 * Bloğun DIŞINDAKİ genişleme ise hâlâ yalnızca gerçek, bağlı `owner` taşları
 * üzerinden ilerler — boş bir dış hücre zinciri taşımaz, sadece genişlemeyi
 * kesmez.
 */
function computeConqueredChain(board: Board, ownCorners: number[], owner: number): Set<string> {
  const chain = new Set<string>();
  const stack: [number, number][] = [];
  for (const corner of ownCorners) {
    const b = cornerBounds(corner);
    for (let r = b.r0; r <= b.r1; r++) {
      for (let c = b.c0; c <= b.c1; c++) {
        const cell = board[r][c];
        if (cell && cell.owner !== owner) continue;
        const k = key(r, c);
        if (!chain.has(k)) {
          chain.add(k);
          stack.push([r, c]);
        }
      }
    }
  }
  while (stack.length > 0) {
    const [r, c] = stack.pop()!;
    const neighbors: [number, number][] = [
      [r - 1, c],
      [r + 1, c],
      [r, c - 1],
      [r, c + 1],
    ];
    for (const [nr, nc] of neighbors) {
      if (nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE) continue;
      const k = key(nr, nc);
      if (chain.has(k)) continue;
      if (board[nr][nc]?.owner === owner) {
        chain.add(k);
        stack.push([nr, nc]);
      }
    }
  }
  return chain;
}

/**
 * Bir oyuncunun bölgesini hesaplar: kendi fetih zinciri (bkz.
 * `computeConqueredChain`) + kendi köşe kare(ler)inden, BAŞKA bir oyuncunun
 * zinciri tarafından ele geçirilmemiş olanlar. 16 karelik köşe bloğu hiçbir
 * koşulda garanti/dokunulmaz değildir — yalnızca henüz kimse tarafından
 * fethedilmemiş hücreler için taban/varsayılan sahiplik sağlar. Rakip,
 * kendi köşesinden (ya da önce izole bıraktığı bir taşı sonradan zincirine
 * bağlayarak) kesintisiz kendi taşlarıyla bu bloğun içine kadar ulaşırsa, o
 * hücreler (teorik olarak blok tamamen de olsa) rakibe geçer — bir kale
 * fethi gibi. Diğer oyuncuların zincirleri bilinmediğinden bu fonksiyon tek
 * başına çağrıldığında (ör. dışarıdan) yalnızca yaklaşık bir sonuç verir; tam
 * doğru sonuç için tüm oyuncuları birlikte çözen `computeAllTerritories`
 * kullanılmalıdır.
 */
export function computeTerritory(board: Board, ownCorners: number[], owner: number): Set<string> {
  const territory = new Set(computeConqueredChain(board, ownCorners, owner));
  for (const corner of ownCorners) {
    const b = cornerBounds(corner);
    for (let r = b.r0; r <= b.r1; r++) {
      for (let c = b.c0; c <= b.c1; c++) {
        territory.add(key(r, c));
      }
    }
  }
  return territory;
}

/**
 * Tüm oyuncuların bölgelerini (indekslerine göre) hesaplar. Önce her
 * oyuncunun gerçek fetih zinciri ayrı ayrı hesaplanır; bir hücre bir
 * zincirde olabilir en fazla TEK bir oyuncuya ait olduğundan (bir hücrede
 * aynı anda tek taş durur) zincirler asla çakışmaz. Köşe bloklarındaki taban
 * iddia da yalnızca başka HİÇBİR oyuncunun zincirine girmemiş hücreler için
 * uygulanır — böylece bir rakibin köşenin içine kadar uzanan zinciri, o
 * hücreleri asıl sahibinin bölgesinden gerçekten düşürür.
 */
export function computeAllTerritories(board: Board, players: Player[]): Set<string>[] {
  // Teslim olmuş bir oyuncunun zinciri boş sayılır — hem kendi bölgesi
  // (aşağıda erken dönüş) hem de daha önce başkasından fethettiği hücreler
  // artık kimseyi "yakalamıyor", bu yüzden o hücreler orijinal sahibinin
  // taban iddiasına geri döner. Sonuç: teslim olan oyuncunun tüm bölgesi
  // (kendi köşesi dahil) doğal/sahipsiz alana dönüşür — kimse ona bölge
  // vergisi ödemez, dış hat çizgisi de kalkar (bkz. Board.tsx).
  const chains = players.map((p, i) =>
    p.surrendered ? new Set<string>() : computeConqueredChain(board, p.corners, i),
  );
  return players.map((p, i) => {
    if (p.surrendered) return new Set<string>();
    const territory = new Set(chains[i]);
    for (const corner of p.corners) {
      const b = cornerBounds(corner);
      for (let r = b.r0; r <= b.r1; r++) {
        for (let c = b.c0; c <= b.c1; c++) {
          const k = key(r, c);
          if (territory.has(k)) continue;
          const capturedByOther = chains.some((chain, j) => j !== i && chain.has(k));
          if (!capturedByOther) territory.add(k);
        }
      }
    }
    return territory;
  });
}

/**
 * Rakip bölge(ler)ine sınır vergisini hesaplar. Bu tur konan taşlardan biri
 * bir rakip bölgesinin içine düşüyorsa (girme) ya da dışarıdan sınırına
 * bitişikse (değme), kazanılan puandan bir pay bölge sahibine gider. Bölge
 * artık sabit 5x5 köşe değil, `computeTerritory` ile hesaplanan — oyuncunun
 * kendi taşlarıyla köşesinden genişlettiği— dinamik alandır. Rakip bölgesine
 * girmek için hiçbir ön koşul yok — her zaman serbest.
 * Etkileşilen rakip bölge sayısına (n) göre saldırganın payı küçülür: n=1'de
 * puanın 2/3'ü saldırgana kalır, kalan 1/3 tek bölge sahibine gider. n=2'de
 * saldırgan yarısını (1/2) alır, kalan yarısı iki bölge sahibi arasında eşit
 * paylaşılır (kişi başı 1/4). n=3'te saldırgan 1/3'ünü alır, kalan 2/3 üç
 * bölge sahibi arasında eşit paylaşılır (kişi başı 2/9). Genel olarak her
 * bölge sahibinin payı basePts*(n+1)/(6n)'dir. Yuvarlama farkı saldırganda
 * kalır, böylece toplam puan her zaman korunur.
 */
export function computeInvasionSplit(
  coords: [number, number][],
  ownerIndex: number,
  players: Player[],
  basePts: number,
  board: Board,
): { pts: number; shares: { index: number; amount: number }[] } {
  const territories = computeAllTerritories(board, players);
  const touchedIdx = new Set<number>();
  const addIfForeign = (r: number, c: number) => {
    const k = key(r, c);
    for (let i = 0; i < territories.length; i++) {
      if (i !== ownerIndex && territories[i].has(k)) touchedIdx.add(i);
    }
  };
  for (const [r, c] of coords) {
    addIfForeign(r, c);
    const neighbors: [number, number][] = [
      [r - 1, c],
      [r + 1, c],
      [r, c - 1],
      [r, c + 1],
    ];
    for (const [nr, nc] of neighbors) {
      if (nr < 0 || nr >= SIZE || nc < 0 || nc >= SIZE) continue;
      addIfForeign(nr, nc);
    }
  }
  if (touchedIdx.size === 0) return { pts: basePts, shares: [] };
  const n = touchedIdx.size;
  const share = Math.round((basePts * (n + 1)) / (6 * n));
  const shares = [...touchedIdx].map((index) => ({ index, amount: share }));
  const pts = basePts - share * n;
  return { pts, shares };
}

/**
 * Tek bir kelimenin puanını hesaplar. Kelimenin bu turda yeni konan
 * taşlarından biri tahtanın tam ortasındaki tek X3 hücresindeyse, kelime
 * puanı üçe katlanır — kelimenin başka bir yeni taşı ayrıca 5×5 X2 bölgesine
 * düşse bile üstüne X2 eklenmez, X3 ve X2 hiçbir zaman aynı kelimede
 * birleşmez. X3 hücresine değmeyen bir kelimenin yeni bir taşı 5×5 bonus
 * bölgesine düşüyorsa puan X2 katlanır. Her iki durumda da yalnızca o hücreye
 * bu turda yeni taş konduysa geçerlidir; önceden tahtada duran bir taşla
 * (daha önceki bir turda oraya konmuş olsa bile) sadece bağlantı kurmak
 * bonus kazandırmaz — her bonus hücresi klasik bonus kare gibi yalnızca bir
 * kez, ilk kullanıldığı turda etkilidir.
 */
/** Bir kelimenin harf puanları toplamı — X2/X3 kelime çarpanı uygulanmadan önce. */
function wordRawPoints(coords: [number, number][], board: Board, placed: Placed): number {
  let sum = 0;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const pts = placed[k]?.pts ?? board[r][c]?.pts ?? 0;
    sum += pts;
  }
  return sum;
}

/**
 * Bir kelimenin bu turda yeni konan taşlarından biri X3 (tam ortadaki tek
 * hücre) ve/veya X2 (bonus bölgesi) hücresine değiyor mu? Bir kelime X3'e
 * değdiyse yalnızca X3 sayılır (X2 ile birleşmez).
 */
function wordBonusFlags(
  coords: [number, number][],
  placed: Placed,
  bonuses: Record<string, BonusType>,
): { x2: boolean; x3: boolean } {
  let hasTw = false;
  let touchesZone = false;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const newTile = placed[k];
    if (newTile && bonuses[k] === 'tw') hasTw = true;
    if (newTile && inBonusZone(r, c)) touchesZone = true;
  }
  return { x2: !hasTw && touchesZone, x3: hasTw };
}

function wordPoints(
  coords: [number, number][],
  board: Board,
  placed: Placed,
  bonuses: Record<string, BonusType>,
): number {
  const { x2, x3 } = wordBonusFlags(coords, placed, bonuses);
  const wordMult = x3 ? 3 : x2 ? 2 : 1;
  return wordRawPoints(coords, board, placed) * wordMult;
}

/**
 * Bu turda oluşan tüm kelimelerin toplam puanını hesaplar. Bonuslar yalnızca
 * bu turda yeni konan taşlara uygulanır. Tüm raf kullanılırsa bingo bonusu.
 */
export function calcScore(
  board: Board,
  placed: Placed,
  bonuses: Record<string, BonusType>,
): number {
  let total = 0;
  for (const { coords } of getFormedWords(board, placed)) {
    total += wordPoints(coords, board, placed, bonuses);
  }
  if (Object.keys(placed).length >= RACK_SIZE) total += BINGO_BONUS;
  return total;
}

/**
 * Bu turda oluşan her kelimenin harf puanları toplamını (X2/X3 kelime
 * çarpanı UYGULANMADAN) ve o kelimenin hangi bonusa değdiğini döner — Oyun
 * Geçmişi'nde kelimenin yanında hem parantez içi saf puan, hem de değdiği
 * bonusun (×2/×3) rozeti bu bilgiyle gösterilir.
 */
export function calcWordRawScores(
  board: Board,
  placed: Placed,
  bonuses: Record<string, BonusType>,
): { word: string; score: number; x2: boolean; x3: boolean }[] {
  return getFormedWords(board, placed).map(({ word, coords }) => ({
    word,
    score: wordRawPoints(coords, board, placed),
    ...wordBonusFlags(coords, placed, bonuses),
  }));
}
