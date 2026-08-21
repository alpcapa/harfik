// Kelimeki — k-lig kademe/ödül tablosunun SQL ↔ TS paritesi.
//
// NEDEN VAR (22 Ağustos 2026): eşik/ödül tablosu ÜÇ KOPYA elle senkron —
// sunucudaki `_award_league_rewards`ın `(values ...)` listeleri, web'in
// `src/utils/leagueRank.ts`i ve portun `league_rank.dart`ı. TS ↔ Dart yarısı
// 14 Ağustos'tan beri `rank_tiers_parity_test.dart` ile kilitli; SQL yarısı
// korumasızdı.
//
// Doküman "güncel tanım tek bir migration dosyasında durmadığından bir test
// onu okuyamaz" diyordu — ÖLÇÜLDÜ ve bugün YANLIŞ: fonksiyonu tanımlayan beş
// migration var ama SONUNCUSU tam gövdeyi (`create function ... (values ...)`)
// taşıyor, yani geçerli tanım tek dosyada. Bu betik o dosyayı MEKANİK olarak
// bulur (ada göre en yeni), üç listeyi ayrıştırır ve TS tablosuyla karşılaştırır.
//
// ⚠ KAPSAM SINIRI — bu betik "migration dosyası ↔ TS"yi kilitler,
// "canlı VERİTABANI ↔ migration dosyası"nı DEĞİL: CI'ın veritabanına erişimi
// yok. O yarı, projenin migration disiplinine (her migration MCP ile uygulanır
// ve dosya adı `list_migrations` ile eşleştirilir) dayanıyor ve 22 Ağustos
// 2026'da canlıdan `pg_get_functiondef` okunarak DOĞRULANDI: üç liste
// dosyayla birebir aynıydı.
//
// Koşum: npm run verify-league-tiers
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

let failures = 0;
const check = (name, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${name}`);
  else { failures++; console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`); }
};

/* ── 1) Geçerli tanımı taşıyan migration ─────────────────────────────────── */
const DIR = 'supabase/migrations';
const tanimlayan = readdirSync(DIR)
  .filter(f => f.endsWith('.sql'))
  .sort() // dosya adı zaman damgasıyla başlıyor → sıralama = uygulama sırası
  .filter(f => /create (or replace )?function public\._award_league_rewards/
    .test(readFileSync(path.join(DIR, f), 'utf8')));

check('fonksiyonu tanımlayan en az bir migration var', tanimlayan.length > 0);
if (!tanimlayan.length) process.exit(1);

const dosya = tanimlayan[tanimlayan.length - 1];
console.log(`  · geçerli tanım: ${dosya}`);
const sql = readFileSync(path.join(DIR, dosya), 'utf8');

/* ── 2) Üç (values ...) listesi ──────────────────────────────────────────── */
const listeler = [...sql.matchAll(/from \(values ([\s\S]*?)\) as t\(/g)]
  .map(m => m[1]);
check('üç (values ...) listesi bulundu', listeler.length === 3,
  `bulunan: ${listeler.length}`);

const ciftler = liste =>
  [...liste.matchAll(/\((\d+)(?:\s*,\s*(\d+))?\)/g)]
    .map(m => (m[2] === undefined ? [Number(m[1])] : [Number(m[1]), Number(m[2])]));

const odulListesi = ciftler(listeler[0] ?? '');
const rankUp = ciftler(listeler[1] ?? '').map(r => r[0]);
const rankDown = ciftler(listeler[2] ?? '').map(r => r[0]);

check('ödül listesi (eşik, puan) çiftleri veriyor',
  odulListesi.length >= 8 && odulListesi.every(r => r.length === 2),
  JSON.stringify(odulListesi));

/* ── 3) TS tablosu ───────────────────────────────────────────────────────── */
const ts = readFileSync('src/utils/leagueRank.ts', 'utf8');
const blok = ts.match(/export const RANK_TIERS: RankTier\[\] = \[([\s\S]*?)\n\];/);
check('leagueRank.ts içinde RANK_TIERS bulundu', !!blok);
const tsTiers = [...(blok?.[1] ?? '').matchAll(/threshold: (\d+), reward: (\d+)/g)]
  .map(m => [Number(m[1]), Number(m[2])]);
check('TS tablosu en az 9 kademe veriyor', tsTiers.length >= 9,
  `bulunan: ${tsTiers.length}`);

/* ── 4) Karşılaştırma ────────────────────────────────────────────────────── */
// Çaylak (eşik 0) SQL'de YOK ve olmamalı: 0 puana ödül verilmez, kademe
// gösterimi zaten `tierFor` ile toplamdan türetiliyor.
const caylak = tsTiers.filter(([t]) => t === 0);
check('TS tablosunda tam bir Çaylak (eşik 0, ödül 0) var',
  caylak.length === 1 && caylak[0][1] === 0, JSON.stringify(caylak));

const tsOdul = tsTiers.filter(([t]) => t > 0);
const J = v => JSON.stringify(v);
check('SQL ödül listesi ↔ TS (eşik, ödül) çiftleri aynı',
  J(odulListesi) === J(tsOdul), `SQL ${J(odulListesi)} ≠ TS ${J(tsOdul)}`);

const tsEsikler = tsOdul.map(([t]) => t);
check('SQL rank_up eşikleri ↔ TS eşikleri', J(rankUp) === J(tsEsikler),
  `SQL ${J(rankUp)} ≠ TS ${J(tsEsikler)}`);
check('SQL rank_down eşikleri ↔ TS eşikleri', J(rankDown) === J(tsEsikler),
  `SQL ${J(rankDown)} ≠ TS ${J(tsEsikler)}`);

// Kümülatif ödüller BİRBİRİNDEN FARKLI olmak zorunda: `rewardAlreadyClaimed`
// ödenen eşik kümesini yalnızca TOPLAMDAN türetiyor, iki farklı prefix aynı
// toplamı verirse o çıkarım bozulur (bkz. kök CLAUDE.md).
let toplam = 0;
const kumulatif = tsOdul.map(([, r]) => (toplam += r));
check('kümülatif ödüller birbirinden farklı',
  new Set(kumulatif).size === kumulatif.length, J(kumulatif));

// `league_rewards_points_check` tavanı: tek bir ödül 1000'i aşamaz.
check('hiçbir ödül 1000 tavanını aşmıyor',
  tsOdul.every(([, r]) => r <= 1000),
  'aşılırsa league_rewards_points_check kısıtı da büyütülmeli');

console.log(failures ? `\n${failures} kontrol düştü.` : '\nTümü geçti.');
process.exit(failures ? 1 : 0);
