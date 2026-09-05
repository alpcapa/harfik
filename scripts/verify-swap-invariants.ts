// Kelimeki — taş değiştirme (swap) akışının İKİ değişmezini ÜRETİM
// reducer'ını import ederek doğrular.
//
// NEDEN AYRI BİR BETİK: golden vector'lar web ile Dart'ı KARŞILAŞTIRIR,
// yani ikisinde de aynı olan bir hatayı asla göremezler. Aşağıdaki iki
// kusur (5 Eylül 2026, hata avı geçişi) tam olarak bu türdendi: parite
// yemyeşilken ikisi de yanlıştı. Fixture'lar artık DAVRANIŞI koruyor,
// bu betik ise DOĞRULUĞU — ikisi farklı sorular.
//
// NEDEN ÖNEMLİ: ikisi de sessiz. Biri taşı oyundan siliyor (hata mesajı
// yok, torba küçülüyor), öteki kullanıcının tutmak istediği taşı
// değiştiriyor (yine hata yok, yanlış taş gidiyor).
//
// Koşum: npm run verify-swap-invariants
import { gameReducer, createInitialState, type Action } from '../src/game/gameReducer';
import type { GameState, Tile } from '../src/game/types';
import { setRandomSource } from '../src/utils/random';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

// Deterministik tohum — torba/çekiliş her koşumda aynı olsun.
let seed = 4242;
setRandomSource(() => {
  seed = (seed * 1103515245 + 12345) & 0x7fffffff;
  return seed / 0x7fffffff;
});

/** Oyundaki TÜM taşlar: torba + raflar + tahta + tahtadaki taslaklar. */
function tileTotal(s: GameState): number {
  let n = s.bag.length;
  for (const p of s.players) n += p.rack.length;
  for (const row of s.board) for (const t of row) if (t) n++;
  return n + Object.keys(s.placed).length;
}

const start = (): GameState =>
  gameReducer(createInitialState(), {
    type: 'START',
    players: [
      { name: 'Ben', isAI: false },
      { name: 'Rakip', isAI: false },
    ],
  } as Action);

console.log('\nTaş değiştirme değişmezleri\n');

// ── 1. CONFIRM_SWAP taslak taşları YOK ETMEMELİ ──────────────────────────────
// Bu kombinasyonu bugün dört ayrı ekrandaki dört ayrı `if` engelliyor
// (App.tsx · OnlineGameScreen.tsx · portun game_screen/online_game_screen'i).
// Yani koruma UI'da; reducer bunu kendi başına da sağlamalı, çünkü beşinci
// bir yüzey ya da o guard'lardan birindeki bir gerileme taşları yok ederdi.
{
  let s = start();
  const toplam = tileTotal(s);
  s = gameReducer(s, { type: 'TOGGLE_SWAP_MODE' });
  s = gameReducer(s, { type: 'PLACE_TILE', r: 0, c: 0, rackIndex: 0 });
  s = gameReducer(s, { type: 'PLACE_TILE', r: 0, c: 1, rackIndex: 0 });
  check('swap modunda taslak taş konabildi (senaryo gerçekten kuruldu)', Object.keys(s.placed).length === 2);
  s = gameReducer(s, { type: 'TOGGLE_SWAP_TILE', index: 0 });
  s = gameReducer(s, { type: 'CONFIRM_SWAP' });
  check(
    'CONFIRM_SWAP sonrası taş sayısı korunuyor',
    tileTotal(s) === toplam,
    `${tileTotal(s)} ≠ ${toplam}`,
  );
  check('taslak tahtada kalmadı', Object.keys(s.placed).length === 0);
}

// ── 2. Boş seçimde taslak SEBEPSİZ toplanmamalı ──────────────────────────────
// Recall, seçim kontrolünün ALTINDA olmalı: "En az bir taş seçmelisin."
// dalı kullanıcının dizdiği taslağı dağıtmamalı.
{
  let s = start();
  s = gameReducer(s, { type: 'TOGGLE_SWAP_MODE' });
  s = gameReducer(s, { type: 'PLACE_TILE', r: 0, c: 0, rackIndex: 0 });
  const before = Object.keys(s.placed).length;
  s = gameReducer(s, { type: 'CONFIRM_SWAP' });
  check('seçim yokken taslak yerinde duruyor', Object.keys(s.placed).length === before);
  check('seçim yokken uyarı veriliyor', s.messageType === 'err');
}

// ── 3. Senkron rafı yeniden sıralarsa seçim DÜŞMELİ ──────────────────────────
// `swapSelection` raf İNDEKSLERİ tutuyor. Turn ilerlemeyen bir senkron
// (periyodik yenileme / uygulamaya geri dönüş) rafı sunucudaki sıraya geri
// yazar; kullanıcı o turda "Karıştır"a basmışsa aynı indeks artık BAŞKA
// bir taştır. Seçim korunursa yanlış taş değiştirilir.
{
  let s = start();
  const sunucuRafi: Tile[] = JSON.parse(JSON.stringify(s.players[0].rack));
  s = gameReducer(s, { type: 'SHUFFLE_RACK' });
  const karisik = s.players[0].rack.map((t) => t.letter).join('');
  check(
    'karıştırma rafın sırasını gerçekten değiştirdi (senaryo anlamlı)',
    karisik !== sunucuRafi.map((t) => t.letter).join(''),
  );
  s = gameReducer(s, { type: 'TOGGLE_SWAP_MODE' });
  // Seçimi rastgele değil, iki sıranın GERÇEKTEN ayrıştığı bir indeksten
  // yap — aksi halde (o tohumda indeks 0 iki sırada da aynı harfe denk
  // gelirse) senaryo hatayı gösteremez ve kontrol sessizce anlamsızlaşır.
  const ayrisanIdx = s.players[0].rack.findIndex(
    (t, i) => t.letter !== sunucuRafi[i]?.letter,
  );
  check('karıştırma sonrası ayrışan bir indeks bulundu', ayrisanIdx >= 0);
  s = gameReducer(s, { type: 'TOGGLE_SWAP_TILE', index: ayrisanIdx });
  const secilen = s.players[0].rack[ayrisanIdx].letter;

  const pub = {
    board: s.board,
    bonuses: s.bonuses,
    players: s.players.map((p) => ({
      name: p.name,
      corners: p.corners,
      colorIndex: p.colorIndex,
      isAI: p.isAI,
      surrendered: p.surrendered,
      rackCount: p.rack.length,
      score: p.score,
      bestMoveScore: p.bestMoveScore,
      bestWordScore: p.bestWordScore,
      longestWord: p.longestWord,
      moveCount: p.moveCount,
      moveScoreSum: p.moveScoreSum,
    })),
    current: s.current,
    turn_count: s.turnCount, // turn İLERLEMİYOR — swapMode bilerek korunmalı
    consecutive_passes: s.consecutivePasses,
    is_game_over: false,
    end_reason: null,
    last_move_cells: [],
    bag_count: s.bag.length,
    started_at: s.startedAt,
  };
  s = gameReducer(s, {
    type: 'SYNC_ONLINE_STATE',
    publicState: pub as never,
    myRack: sunucuRafi,
    mySlotIndex: 0,
  });

  check(
    'senkron rafı sunucu sırasına geri yazdı',
    s.players[0].rack.map((t) => t.letter).join('') ===
      sunucuRafi.map((t) => t.letter).join(''),
  );
  check('turn ilerlemediği için swap modu korundu', s.swapMode === true);
  check(
    'seçilen indeks senkron sonrası BAŞKA bir taşı gösteriyor (senaryo anlamlı)',
    s.players[0].rack[ayrisanIdx].letter !== secilen,
  );
  check(
    'raf yeniden sıralandığı için seçim düşürüldü',
    s.swapSelection.length === 0,
    `swapSelection=[${s.swapSelection}] — "${secilen}" seçilmişti, indeks ${ayrisanIdx} artık "${s.players[0].rack[ayrisanIdx]?.letter}" (bu taş değişirdi)`,
  );
}

// ── 4. Raf DEĞİŞMEDİYSE seçim korunmalı (aşırı hevesli olmamalı) ─────────────
// Düzeltmenin ters yönü: arka plandan dönen sekmenin tetiklediği, hiçbir
// şeyi değiştirmeyen bir senkron kullanıcının seçimini SİLMEMELİ — bu
// davranış bilerek korunuyordu (bkz. SYNC_ONLINE_STATE yorumu).
{
  let s = start();
  s = gameReducer(s, { type: 'TOGGLE_SWAP_MODE' });
  s = gameReducer(s, { type: 'TOGGLE_SWAP_TILE', index: 1 });
  const ayniRaf: Tile[] = JSON.parse(JSON.stringify(s.players[0].rack));
  const pub = {
    board: s.board,
    bonuses: s.bonuses,
    players: s.players.map((p) => ({
      name: p.name,
      corners: p.corners,
      colorIndex: p.colorIndex,
      isAI: p.isAI,
      surrendered: p.surrendered,
      rackCount: p.rack.length,
      score: p.score,
      bestMoveScore: p.bestMoveScore,
      bestWordScore: p.bestWordScore,
      longestWord: p.longestWord,
      moveCount: p.moveCount,
      moveScoreSum: p.moveScoreSum,
    })),
    current: s.current,
    turn_count: s.turnCount,
    consecutive_passes: s.consecutivePasses,
    is_game_over: false,
    end_reason: null,
    last_move_cells: [],
    bag_count: s.bag.length,
    started_at: s.startedAt,
  };
  s = gameReducer(s, {
    type: 'SYNC_ONLINE_STATE',
    publicState: pub as never,
    myRack: ayniRaf,
    mySlotIndex: 0,
  });
  check('raf aynıysa seçim korunuyor', JSON.stringify(s.swapSelection) === '[1]');
}

console.log('');
if (failures > 0) {
  console.log(`${failures} kontrol BAŞARISIZ`);
  process.exit(1);
}
console.log('Tüm kontroller geçti.');
