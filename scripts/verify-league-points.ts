// Kelimeki — k-lig PUAN tablosunun SQL ↔ TS ↔ Dart paritesi (ROADMAP #23).
//
// NEDEN VAR (6 Eylül 2026, Faz 1): "teslim -2, 1. +2, 2. +1 (yalnız 4
// kişilikte)" formülü sunucuda BEŞ kopya (`player_stats`,
// `player_stats_overall`, `leaderboard`, `_award_league_rewards`,
// `trg_award_league_rewards`), web'de bir (`leaguePoints.ts`), portta bir
// (`league_points.dart`) hâlinde yaşıyordu — yedi kopya, hiçbiri testli.
// Seviyeli YZ tabloyu üç sütuna çıkarıyor (Kolay/Normal/Zor); yedi kopyayı
// elle senkron tutmak "aynı metriğin iki yerde ayrışması" hata sınıfının
// ta kendisi. Faz 1 sunucudaki beşi TEK fonksiyona (`league_points_for`)
// indirdi; bu betik kalan üç kaynağı birbirine kilitler.
//
// `verify-league-tiers`in deseni: geçerli SQL tanımını taşıyan migration'ı
// ADA GÖRE (en yeni) bulur, `(values ...)` listesini ayrıştırır, kanonik
// tabloyla (ROADMAP 23.0) ve TS'in GERÇEK çıktısıyla karşılaştırır. Dart
// tarafı çalıştırılmaz (CI'ın web işinde Dart yok); orada kaynak metnindeki
// sabit dizisi TS'inkiyle karşılaştırılır — iki dosya aynı dallanmayı aynı
// sırayla taşımak zorunda.
//
// ⚠ KAPSAM SINIRI — `verify-league-tiers`le aynı: "migration dosyası ↔
// kod"u kilitler, "canlı veritabanı ↔ dosya"yı DEĞİL. O yarı migration
// disiplinine dayanıyor ve 6 Eylül 2026'da canlıdan ölçüldü (953 satırda
// yeni fonksiyon ↔ eski `case` sıfır fark; view karmaları öncesi/sonrası
// bayt-eş — kayıt migration'ın başındaki yorumda).
//
// FAZ 3 SÖZLEŞMESİ: `leaguePoints` bugün `(rank, playerCount, surrendered)`
// alıyor ve yalnızca Normal sütununu üretiyor. Faz 3 dördüncü parametreyi
// (`level`) ekleyince bu betik onu KENDİLİĞİNDEN üç seviyede de sınar
// (`leaguePoints.length` ile ariteyi okuyor) — ayrıca güncellenmesi
// gerekmez, ama o gün çıktıda "3 seviye" yazdığını GÖR.
//
// Koşum: npm run verify-league-points
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { leaguePoints } from '../src/utils/leaguePoints';

let failures = 0;
const check = (name: string, cond: boolean, detail = '') => {
  if (cond) console.log(`  ✓ ${name}`);
  else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
};
const J = (v: unknown) => JSON.stringify(v);

// esbuild çıktısı node_modules/.cache altına düştüğünden import.meta.url
// kullanılamaz; öteki bundle'lı betikler gibi repo kökünden koşulur.
const root = process.cwd();
const migDir = path.join(root, 'supabase', 'migrations');

/* ── 0) Kanonik tablo — ROADMAP 23.0 (backlog'daki kullanıcı kararı) ─────── */
type Seviye = 'kolay' | 'normal' | 'zor';
const SEVIYELER: Seviye[] = ['kolay', 'normal', 'zor'];
// [seviye][sıra] → puan; 2. sıra yalnız 4 kişilikte, 2 kişilikte 0.
const KANONIK: Record<Seviye, Record<1 | 2, number>> = {
  kolay: { 1: 1, 2: 0 },
  normal: { 1: 2, 2: 1 },
  zor: { 1: 4, 2: 2 },
};
const TESLIM = -2;
const kanonik = (rank: number, playerCount: number, surrendered: boolean, level: Seviye) => {
  if (surrendered) return TESLIM;
  if (rank === 1) return KANONIK[level][1];
  if (rank === 2 && playerCount !== 2) return KANONIK[level][2];
  return 0;
};

/* ── 1) Geçerli SQL tanımı ────────────────────────────────────────────────── */
const migrations = readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort();
const readMig = (f: string) => readFileSync(path.join(migDir, f), 'utf8');
const sonTanim = (re: RegExp) => {
  const list = migrations.filter((f) => re.test(readMig(f)));
  return list.length ? list[list.length - 1] : null;
};

const fnDosya = sonTanim(/create (or replace )?function public\.league_points_for\(/);
check('league_points_for tanımlayan bir migration var', !!fnDosya);
if (!fnDosya) process.exit(1);
console.log(`  · geçerli tanım: ${fnDosya}`);
const fnSql = readMig(fnDosya);
const govde = fnSql.match(
  /create (?:or replace )?function public\.league_points_for\([\s\S]*?\$\$([\s\S]*?)\$\$;/,
)?.[1];
check('fonksiyon gövdesi ayrıştırıldı', !!govde);

// (values ('seviye', sıra, puan), …) — satır biçimi migration'da SABİT.
const sqlSatirlar = [...(govde ?? '').matchAll(/\('(kolay|normal|zor)',\s*(\d+),\s*(\d+)\)/g)].map(
  (m) => [m[1] as Seviye, Number(m[2]), Number(m[3])] as const,
);
check('SQL (values …) listesi 6 satır (3 seviye × 2 sıra)', sqlSatirlar.length === 6, J(sqlSatirlar));

const sqlTablo: Partial<Record<Seviye, Partial<Record<1 | 2, number>>>> = {};
for (const [lv, sira, puan] of sqlSatirlar) {
  (sqlTablo[lv] ??= {})[sira as 1 | 2] = puan;
}
check('SQL tablosu ↔ kanonik (23.0) tablo', J(sqlTablo) === J(KANONIK), `SQL ${J(sqlTablo)} ≠ ${J(KANONIK)}`);

const teslimSql = govde?.match(/when p_surrendered then (-?\d+)/)?.[1];
check('SQL teslim sabiti -2', teslimSql === String(TESLIM), `bulunan: ${teslimSql}`);
check(
  'SQL: 2 kişilikte 2. sıra 0 (seviyeden bağımsız)',
  /when p_rank = 2 and p_player_count = 2 then 0/.test(govde ?? ''),
);
check(
  "SQL: null seviye Normal'e düşüyor",
  /coalesce\(p_ai_level,\s*'normal'\)/.test(govde ?? ''),
);

/* ── 2) Beş sunucu kopyası GERÇEKTEN tek çağrıya indi mi ──────────────────── */
// Her nesnenin EN YENİ tanımı `league_points_for(` çağırmalı. Biri yeniden
// inline `case` ile yazılırsa (altıncı kopya) burada düşer.
const nesneler: [string, RegExp][] = [
  ['player_stats (view)', /create (or replace )?view public\.player_stats\b(?!_)/],
  ['player_stats_overall (view)', /create (or replace )?view public\.player_stats_overall\b/],
  ['leaderboard (view)', /create (or replace )?view public\.leaderboard\b/],
  ['_award_league_rewards', /create (or replace )?function public\._award_league_rewards\(/],
  ['trg_award_league_rewards', /create (or replace )?function public\.trg_award_league_rewards\(/],
];
for (const [ad, re] of nesneler) {
  const dosya = sonTanim(re);
  const tanim = dosya ? readMig(dosya) : '';
  // Aynı dosyada birden çok nesne var; yalnızca BU nesnenin bloğuna bak —
  // ve aynı nesne bir dosyada iki kez tanımlanmışsa SONUNCUSU geçerli.
  const g = new RegExp(re.source, 'g');
  let basla = -1;
  for (const m of tanim.matchAll(g)) basla = m.index ?? basla;
  const blok = basla >= 0 ? tanim.slice(basla) : '';
  const sonlar = ad.includes('view') ? [';'] : ['$function$;', '$$;'];
  const bitis = sonlar.map((t) => blok.indexOf(t)).filter((i) => i >= 0).sort((a, b) => a - b)[0];
  const govdesi = blok.slice(0, bitis === undefined ? undefined : bitis);
  check(
    `${ad} en yeni tanımı league_points_for çağırıyor (${dosya ?? 'dosya yok'})`,
    /league_points_for\(/.test(govdesi),
  );
  check(`${ad} içinde inline formül KALMADI`, !/player_count\s*<>\s*2/.test(govdesi));
}

/* ── 3) TS — gerçek çıktı ─────────────────────────────────────────────────── */
// Faz 3'e kadar 3 parametre (yalnız Normal); sonra 4 (üç seviye).
const tsSeviyeli = leaguePoints.length >= 4;
const tsSeviyeler: Seviye[] = tsSeviyeli ? SEVIYELER : ['normal'];
console.log(`  · leaguePoints.ts ${tsSeviyeli ? '3 seviye' : 'yalnız Normal (Faz 3 öncesi)'}`);
const tsFn = leaguePoints as unknown as (
  rank: number,
  playerCount: number,
  surrendered?: boolean,
  level?: Seviye,
) => number;
let tsFark = 0;
for (const level of tsSeviyeler)
  for (const pc of [2, 4])
    for (let rank = 1; rank <= pc; rank++)
      for (const s of [false, true]) {
        const got = tsSeviyeli ? tsFn(rank, pc, s, level) : tsFn(rank, pc, s);
        const want = kanonik(rank, pc, s, level);
        if (got !== want) {
          tsFark++;
          console.log(`    TS ${level} pc=${pc} rank=${rank} teslim=${s}: ${got} ≠ ${want}`);
        }
      }
check(`leaguePoints.ts ↔ kanonik tablo (${tsSeviyeler.length} seviye × 2 mod × sıra × teslim)`, tsFark === 0);

/* ── 4) Dart — kaynak metnindeki sabit dizisi TS ile aynı ─────────────────── */
// İki dosya da `if (…) return N;` zinciri; yorumlar/boşluklar atılıp geriye
// kalan sayı dizisi karşılaştırılır. Dallanma sırası da eşleşmek zorunda
// (surrendered → rank 1 → rank 2 && count != 2 → 0).
const sabitDizisi = (src: string) =>
  src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/.*$/gm, '')
    .replace(/\/\/\/.*$/gm, '')
    .match(/return\s+(-?\d+)\s*;/g)
    ?.map((m) => Number(m.replace(/return\s+/, '').replace(';', '')));
const tsSrc = readFileSync(path.join(root, 'src', 'utils', 'leaguePoints.ts'), 'utf8');
const dartSrc = readFileSync(
  path.join(root, 'mobile', 'kelimeki_core', 'lib', 'src', 'rules', 'league_points.dart'),
  'utf8',
);
const tsFonk = tsSrc.match(/export function leaguePoints\([\s\S]*?\n\}/)?.[0] ?? '';
const dartFonk = dartSrc.match(/int leaguePoints\([\s\S]*?\n\}/)?.[0] ?? '';
check('leaguePoints.ts fonksiyon gövdesi bulundu', tsFonk.length > 0);
check('league_points.dart fonksiyon gövdesi bulundu', dartFonk.length > 0);
const tsSabit = sabitDizisi(tsFonk);
const dartSabit = sabitDizisi(dartFonk);
check('TS ↔ Dart sabit dizisi aynı', J(tsSabit) === J(dartSabit), `TS ${J(tsSabit)} ≠ Dart ${J(dartSabit)}`);
check(
  'Dart dallanma sırası: surrendered → rank 1 → rank 2 && playerCount != 2',
  /surrendered\)[\s\S]*rank == 1[\s\S]*rank == 2 && playerCount != 2/.test(dartFonk),
);

console.log(failures ? `\n${failures} kontrol düştü.` : '\nTümü geçti.');
process.exit(failures ? 1 : 0);
