// Kelimeki — `src/utils/cloudSaveMirror.ts`'in saf karar fonksiyonlarını
// (`classifyCloudSaves`, `mergeOfflineCloudSaves`) ÜRETİM kodunu import ederek
// doğrular.
//
// NEDEN AYRI BİR BETİK: web tarafında birim test çatısı yok (`npm run test`
// Playwright duman testleri). Bu, `generate-golden-vectors`in kullandığı AYNI
// desen — esbuild ile bundle'layıp node'da koşuyoruz, yani yeni bir bağımlılık
// ya da test altyapısı eklenmiyor. Fonksiyonlar bilerek saf (ağ/localStorage/
// React yok) olduğundan bu yeterli.
//
// KAPSAM: bu özelliğin riski hep aynı yerdeydi — Flutter portunda açılıp aynı
// gün kapatılan üç gedik (bkz. `mobile/CLAUDE.md` Parça 38/43/46). Aşağıdaki
// vakalar o üçünü ve kardeşlerini birebir kapsıyor.
//
// Koşum: npm run verify-cloud-save-mirror
import {
  classifyCloudSaves,
  mergeOfflineCloudSaves,
  type MirroredSave,
  type ServerRowLike,
} from '../src/utils/cloudSaveMirror';
import type { GameState } from '../src/game/types';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (cond) {
    console.log(`  ✓ ${name}`);
  } else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const DAY = 24 * 60 * 60 * 1000;
const NOW = 1_760_000_000_000;
const CUTOFF = NOW - 7 * DAY;

/** Karar fonksiyonlarının OKUDUĞU alanlar kadarıyla bir GameState. */
function st(
  opts: { turnCount?: number; over?: boolean; setup?: boolean; aiLevel?: GameState['aiLevel'] } = {},
): GameState {
  return {
    phase: opts.setup ? 'setup' : 'play',
    isGameOver: opts.over ?? false,
    turnCount: opts.turnCount ?? 5,
    startedAt: new Date(NOW - 10 * DAY).toISOString(),
    multiSession: false,
    players: [{}, {}],
    // ROADMAP #23 Faz 3: seviye alanı state'in İÇİNDE yolculuk eder — ayna
    // ve sunucu satırı jsonb'yi olduğu gibi taşır. Normal'de alan YOK
    // (`undefined`), Kolay/Zor'da yazılı; karar mantığı ona bakmaz ama
    // seçilen state'le birlikte kaybolmadan dönmesi gerekir.
    ...(opts.aiLevel ? { aiLevel: opts.aiLevel } : {}),
  } as unknown as GameState;
}

function row(id: string, updatedAt: number, state = st()): ServerRowLike {
  return { id, state, updatedAt };
}
function mir(id: string, savedAt: number, state = st()): MirroredSave {
  return { id, userId: 'u1', state, savedAt };
}

console.log('classifyCloudSaves');
{
  // 1 — offline oynanan hamleler kaybolmaz: ayna sunucudan yeniyse o kazanır.
  const p = classifyCloudSaves([row('a', NOW - 2 * DAY, st({ turnCount: 3 }))], [mir('a', NOW - 1 * DAY, st({ turnCount: 9 }))], CUTOFF);
  check('ayna sunucudan yeniyse aynanın state\'i gösterilir',
    p.active.length === 1 && p.active[0].state.turnCount === 9,
    `active=${JSON.stringify(p.active.map((x) => x.state.turnCount))}`);

  // 2 — tersi: başka bir cihaz daha yeni oynadıysa SUNUCU kazanır.
  const q = classifyCloudSaves([row('a', NOW - 1 * DAY, st({ turnCount: 9 }))], [mir('a', NOW - 3 * DAY, st({ turnCount: 3 }))], CUTOFF);
  check('ayna eskiyse sunucu satırı kazanır',
    q.active.length === 1 && q.active[0].state.turnCount === 9);

  // 3 — GEDİK (a): süresi dolmuş sunucu satırı + TAZE ayna → ceza YOK.
  const r = classifyCloudSaves([row('a', NOW - 9 * DAY)], [mir('a', NOW - 1 * DAY)], CUTOFF);
  check('taze ayna, süresi dolmuş sunucu satırını cezadan kurtarır',
    r.active.length === 1 && r.expired.length === 0,
    `active=${r.active.length} expired=${r.expired.length}`);

  // 4 — ayna yoksa süresi dolmuş satır gerçekten iddia edilmeli.
  const s = classifyCloudSaves([row('a', NOW - 9 * DAY)], [], CUTOFF);
  check('aynasız süresi dolmuş satır expired listesine düşer',
    s.expired.length === 1 && s.active.length === 0);

  // 5 — sunucunun hiç görmediği taze oyun listede görünür.
  const t = classifyCloudSaves([], [mir('z', NOW - 1 * DAY)], CUTOFF);
  check('yalnızca aynada olan taze oyun listede',
    t.active.length === 1 && t.active[0].id === 'z');

  // 6 — GEDİK (c): sunucunun hiç görmediği ESKİ oyun da cezalandırılır.
  const u = classifyCloudSaves([], [mir('z', NOW - 9 * DAY)], CUTOFF);
  check('yalnızca aynada olan süresi dolmuş oyun cezaya gider',
    u.orphanExpired.length === 1 && u.active.length === 0);

  // 7 — bitmiş kayıtlar iki tarafta da temizliğe ayrılır, listeye girmez.
  const v = classifyCloudSaves([row('a', NOW, st({ over: true }))], [mir('z', NOW, st({ setup: true }))], CUTOFF);
  check('bitmiş sunucu satırı finished, bitmiş ayna orphanFinished',
    v.finished.length === 1 && v.orphanFinished.length === 1 && v.active.length === 0);

  // 8 — sıralama: en son oynanan en üstte.
  const w = classifyCloudSaves([row('a', NOW - 3 * DAY), row('b', NOW - 1 * DAY)], [], CUTOFF);
  check('aktif liste yeniden eskiye sıralı', w.active.map((x) => x.id).join(',') === 'b,a');
}

console.log('mergeOfflineCloudSaves');
{
  // 9 — GEDİK (mobil ilk sürüm): damgalar EŞİTKEN ayna kazanmalı.
  const same = NOW - 1 * DAY;
  const a = mergeOfflineCloudSaves(
    [{ id: 'a', state: st({ turnCount: 3 }), updatedAt: same }],
    [mir('a', same, st({ turnCount: 9 }))],
    CUTOFF,
  );
  check('eşit damgada ayna önbelleği EZER (offline hamleler gizlenmez)',
    a !== null && a.length === 1 && a[0].state.turnCount === 9,
    `turnCount=${a?.[0]?.state.turnCount}`);

  // 10 — GEDİK (b): önbellek de ayna da yoksa null (UI "hiç oyunun yok" demesin).
  check('bilgi yoksa null döner — "liste alınamadı" korunur',
    mergeOfflineCloudSaves([], [], CUTOFF) === null);

  // 11 — yalnızca aynayı göstermek yetmez: offline oynanmamış oyunlar da kalmalı.
  const b = mergeOfflineCloudSaves(
    [{ id: 'a', state: st(), updatedAt: NOW - 2 * DAY }, { id: 'b', state: st(), updatedAt: NOW - 3 * DAY }],
    [mir('a', NOW - 1 * DAY)],
    CUTOFF,
  );
  check('önbellekteki diğer oyunlar listeden düşmez',
    b !== null && b.length === 2 && b.map((x) => x.id).sort().join(',') === 'a,b');

  // 12 — offline dalda süresi geçmiş satır GÖSTERİLMEZ (birazdan silinecek bir
  // oyuna devam ettirmeyelim) ve ceza da üretilmez (dönüş yalnızca satırlar).
  const c = mergeOfflineCloudSaves([{ id: 'a', state: st(), updatedAt: NOW - 9 * DAY }], [], CUTOFF);
  check('süresi geçmiş satır offline listede yok', c !== null && c.length === 0);

  // 13 — bitmiş oyun offline listede de görünmez.
  const d = mergeOfflineCloudSaves([{ id: 'a', state: st({ over: true }), updatedAt: NOW }], [], CUTOFF);
  check('bitmiş oyun offline listede yok', d !== null && d.length === 0);

  // 14 — ROADMAP #23 Faz 3: Kolay bir oyunun `aiLevel`i aynadan ve sunucudan
  // gelen state'te KORUNUR; Normal oyun alansız kalır (sözleşme: alan yok =
  // Normal, `STORAGE_VERSION` bump edilmedi).
  const e = mergeOfflineCloudSaves(
    [{ id: 'k', state: st({ turnCount: 3, aiLevel: 'kolay' }), updatedAt: NOW - 2 * DAY },
     { id: 'n', state: st({ turnCount: 3 }), updatedAt: NOW - 2 * DAY }],
    [mir('k', NOW - 1 * DAY, st({ turnCount: 7, aiLevel: 'kolay' }))],
    CUTOFF,
  );
  const eK = e?.find((x) => x.id === 'k');
  const eN = e?.find((x) => x.id === 'n');
  check("Kolay oyunun aiLevel'i ayna kazanınca da state'te kalır",
    eK?.state.aiLevel === 'kolay' && eK.state.turnCount === 7,
    `aiLevel=${eK?.state.aiLevel} turnCount=${eK?.state.turnCount}`);
  check("Normal oyunun state'inde aiLevel anahtarı YOK",
    !!eN && !('aiLevel' in eN.state));
}

console.log('');
if (failures > 0) {
  console.log(`${failures} kontrol BAŞARISIZ`);
  process.exit(1);
}
console.log('Tüm kontroller geçti.');
