// Kelimeki — kelime doğrulama, bölge kuralları ve puanlama
//
// src/utils/validator.ts'in KOPYASI (yalnızca play-ai-turn'ün ihtiyaç
// duyduğu kısım — validatePlacement/validatePlacementStructural burada
// yok, çünkü findAIMove zaten yalnızca sözlükte gerçekten var olan
// kelimeleri değerlendiriyor, sözlük kontrolünü kendi içinde yapıyor) —
// bkz. types.ts'teki not.
import { BINGO_BONUS, RACK_SIZE, SIZE, cornerBounds, inBonusZone } from './constants.ts';
import type { BonusType, Player } from './types.ts';
import type { Board, Placed } from './board.ts';
import { getFormedWords, key } from './board.ts';

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
 * ("taze") olanları döner.
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
function computeConqueredChain(
  board: Board,
  ownCorners: number[],
  owner: number,
  supported?: Set<string>[],
): Set<string> {
  // `chain` = zincire ÜYE hücreler. `visited` = gezilen hücreler. İkisi
  // AYRI olmak zorunda: aşağıdaki "iletken" hücreler gezilir ama üye
  // OLMAZ — üye olsalardı aynı hücre hem taşın sahibinin hem blok
  // sahibinin zincirine girip "iki oyuncunun bölgesi asla çakışmaz"
  // değişmezini kırabilirdi (ölçüldü: taşın sahibi o hücreye kendi
  // taşlarıyla ulaşabildiği bir tahtada gerçekten çakışıyor).
  const chain = new Set<string>();
  const visited = new Set<string>();
  const stack: [number, number][] = [];
  for (const corner of ownCorners) {
    const b = cornerBounds(corner);
    for (let r = b.r0; r <= b.r1; r++) {
      for (let c = b.c0; c <= b.c1; c++) {
        const cell = board[r][c];
        const k = key(r, c);
        if (cell && cell.owner !== owner) {
          // Kendi bloğunun içindeki RAKİP taşı. `supported` verilmediyse
          // (ön geçiş) eski davranış: zinciri keser. Verildiyse yalnızca o
          // taş RAKİBİN KENDİ zincirine bağlıysa keser — bağlı değilse
          // (izole bir akıncı) hücre İLETKEN olur: üzerinden geçilir.
          // Gerekçe: o hücre zaten senin bölgen sayılıyor (taban iddia,
          // aşağıda) ve rakip oraya bitişik oynarsa SANA vergi ödüyor;
          // kira toplanan ama üzerinden yürünemeyen bir hücre tutarsızdı.
          // `owner` opsiyonel: sahipsiz bir taş (ya da ön geçiş) için
          // karşılaştıracak zincir YOK — eski davranış, zinciri keser.
          const foeChain = cell.owner === undefined ? undefined : supported?.[cell.owner];
          if (!foeChain || foeChain.has(k)) continue;
          if (!visited.has(k)) {
            visited.add(k);
            stack.push([r, c]);
          }
          continue;
        }
        if (!visited.has(k)) {
          visited.add(k);
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
      if (visited.has(k)) continue;
      if (board[nr][nc]?.owner === owner) {
        visited.add(k);
        chain.add(k);
        stack.push([nr, nc]);
      }
    }
  }
  return chain;
}

/** Tüm oyuncuların bölgelerini (indekslerine göre) hesaplar. */
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
  // İKİ GEÇİŞ, ve sırası önemli. Ön geçiş her oyuncunun SAF zincirini
  // (yalnızca kendi taşları) hesaplar; ikinci geçiş "bu rakip taşı gerçekten
  // rakibin bölgesine bağlı mı" sorusunu O saf zincire sorar. Kapıyı ikinci
  // geçişin kendi sonucuna sormak dairesel olurdu (A'nın zinciri B'ninkine,
  // B'ninki A'nınkine bağlı). Saf zincir kullanmak hem döngüyü kırıyor hem
  // de doğru soruyu soruyor: "rakip oraya bölgesini KENDİ taşlarıyla taşımış
  // mı?" — taşımışsa hücre onundur, zinciri keser ve sen oraya oynarsan
  // vergi ödersin; taşımamışsa izole bir akıncıdır ve seni durduramaz.
  const supported = players.map((p, i) =>
    p.surrendered ? new Set<string>() : computeConqueredChain(board, p.corners, i),
  );
  const chains = players.map((p, i) =>
    p.surrendered ? new Set<string>() : computeConqueredChain(board, p.corners, i, supported),
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

/** Rakip bölge(ler)ine ödenecek bölge vergisini hesaplar (bkz. src/utils/validator.ts'teki tam not). */
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

function wordRawPoints(coords: [number, number][], board: Board, placed: Placed): number {
  let sum = 0;
  for (const [r, c] of coords) {
    const k = key(r, c);
    const pts = placed[k]?.pts ?? board[r][c]?.pts ?? 0;
    sum += pts;
  }
  return sum;
}

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

/** Bu turda oluşan tüm kelimelerin toplam puanını hesaplar (bingo bonusu dahil). */
export function calcScore(board: Board, placed: Placed, bonuses: Record<string, BonusType>): number {
  let total = 0;
  for (const { coords } of getFormedWords(board, placed)) {
    total += wordPoints(coords, board, placed, bonuses);
  }
  if (Object.keys(placed).length >= RACK_SIZE) total += BINGO_BONUS;
  return total;
}

/** Bu turda oluşan her kelimenin harf puanları toplamı (X2/X3 UYGULANMADAN) + bonus rozetleri. */
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
