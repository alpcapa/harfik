// Kelimeki — oyun motorunun SQL kopyası ↔ TS kaynağı paritesi.
//
// NEDEN VAR (5 Eylül 2026, ROADMAP #18): `submit_move` artık hamleyi kendi
// motoruyla hesaplıyor ve bu, motorun DÖRDÜNCÜ kopyası:
//   1. src/                       — kaynak (TypeScript)
//   2. supabase/functions/_game/  — Deno kopyası (play-ai-turn kullanıyor)
//   3. mobile/kelimeki_core/      — Dart kopyası (golden vector'larla kilitli)
//   4. supabase/migrations/       — SQL kopyası (BU)
//
// 2. kopya aylarca sessizce ayrıştı ve CANLIDA kaldı; `verify-edge-engine-parity`
// tam da o yüzden var. 4. kopya METİN olarak karşılaştırılamaz (farklı dil),
// bu yüzden burada MEKANİK olarak karşılaştırılabilen şeyler kilitleniyor:
// sayısal sabitler ve kullanıcıya gösterilen hata metinleri. İkisi de sessiz
// ayrışmanın en olası yeri — biri değişip öteki unutulursa oyun iki yüzeyde
// FARKLI kurallarla oynanır.
//
// ⚠ KAPSAM SINIRI — üç katman, üçü de ayrı kanıtla:
//   (a) BU BETİK: migration dosyası ↔ src/ sabitleri + hata metinleri (CI).
//   (b) DAVRANIŞ: 2.641 gerçek üretim hamlesi yeniden oynatılıp SQL'in kayıtlı
//       puanı/vergisini birebir ürettiği ölçüldü (0 açıklanamayan sapma).
//       Veritabanı gerektirdiğinden CI'da koşamaz; kaydı roadmap-arsiv.md'de.
//   (c) SÜREKLİ: `move_shadow_diffs` tablosu — sunucu her gerçek hamlede
//       kendi hesabını istemciyle karşılaştırıp sapmayı yazıyor (gölge fazı).
//   Bu betik yalnızca (a)'yı kapatır; "canlı veritabanı ↔ dosya" yarısı
//   projenin migration disiplinine dayanıyor (verify-league-tiers ile aynı).
//
// Koşum: npm run verify-sql-engine-parity
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

let failures = 0;
const check = (name, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${name}`);
  else {
    failures++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
};

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const migDir = path.join(root, 'supabase', 'migrations');
const sql = readdirSync(migDir)
  .filter((f) =>
    f.includes('km_engine_sql_mirror') ||
    f.includes('km_all_territories') ||
    f.includes('km_shadow') ||
    f.includes('submit_move_shadow_phase'),
  )
  .sort()
  .map((f) => readFileSync(path.join(migDir, f), 'utf8'))
  .join('\n');

check('SQL ayna migration dosyaları bulundu', sql.length > 1000, `${sql.length} bayt`);

// ── 1. Sabitler: src/game/constants.ts ↔ SQL ────────────────────────────────
const constants = readFileSync(path.join(root, 'src', 'game', 'constants.ts'), 'utf8');
const num = (name) => {
  const m = constants.match(new RegExp(`export const ${name} = (\\d+)`));
  return m ? Number(m[1]) : null;
};
const SIZE = num('SIZE');
const CORNER = num('CORNER');
const RACK_SIZE = num('RACK_SIZE');
const BINGO_BONUS = num('BINGO_BONUS');

check('constants.ts okundu', SIZE === 13 && CORNER === 4 && RACK_SIZE === 7 && BINGO_BONUS === 25,
  `SIZE=${SIZE} CORNER=${CORNER} RACK=${RACK_SIZE} BINGO=${BINGO_BONUS}`);

// Tahta sınırı SQL'de `0 and 12` / `> 12` olarak gömülü (SIZE-1).
const maxIdx = SIZE - 1;
check(`tahta sınırı SIZE-1 = ${maxIdx} SQL'de kullanılıyor`,
  sql.includes(`between 0 and ${maxIdx}`) && sql.includes(`> ${maxIdx}`),
  `SIZE değişmişse SQL'deki 0..${maxIdx} sınırları da değişmeli`);

// Bonus bölgesi: CORNER .. SIZE-CORNER-1  → 13/4 için 4..8
const z0 = CORNER;
const z1 = SIZE - CORNER - 1;
check(`X2 bonus bölgesi ${z0}..${z1} SQL'de doğru`,
  sql.includes(`between ${z0} and ${z1}`),
  `constants.ts BONUS_ZONE ile SQL _km_word_bonus ayrışmış olabilir`);

// Merkez X3: floor(SIZE/2)
const ctr = Math.floor(SIZE / 2);
check(`X3 merkez hücresi (${ctr},${ctr}) SQL'de doğru`,
  new RegExp(`v_r = ${ctr} and v_c = ${ctr}`).test(sql),
  'BOARD_CENTER ile _km_word_bonus ayrışmış olabilir');

check(`bingo eşiği RACK_SIZE=${RACK_SIZE} ve bonusu ${BINGO_BONUS} SQL'de doğru`,
  new RegExp(`>= ${RACK_SIZE} then`).test(sql) && sql.includes(`+ ${BINGO_BONUS}`),
  '_km_calc_score bingo dalı');

// Köşe sınırları: üst köşeler 0..CORNER-1, alt köşeler SIZE-CORNER..SIZE-1
check(`köşe blok sınırları (0..${CORNER - 1} / ${SIZE - CORNER}..${maxIdx}) SQL'de doğru`,
  sql.includes(`then 0 else ${SIZE - CORNER} end`) && sql.includes(`then ${CORNER - 1} else ${maxIdx} end`),
  '_km_corner_bounds ile constants.ts cornerBounds ayrışmış');

// ── 2. Hata metinleri: validator.ts ↔ SQL ───────────────────────────────────
// Aynı hatayı iki yüzey AYNI cümleyle anlatmalı: istemci yerel doğrulamada,
// sunucu zorlama fazında bu metinleri gösterecek.
const validator = readFileSync(path.join(root, 'src', 'utils', 'validator.ts'), 'utf8');
const mesajlar = [
  'Harf yerleştirilmedi.',
  'Harfler aynı satır ya da sütunda olmalı.',
  'Harfler arasında boşluk bırakılamaz.',
  'İlk kelimen kendi köşe karesine değmeli.',
  'Kelime mevcut harflere bağlanmalı.',
  'Geçerli kelime oluşmadı.',
];
for (const m of mesajlar) {
  check(`"${m}" iki tarafta da var`,
    validator.includes(m) && sql.includes(m),
    validator.includes(m) ? 'SQL kopyasında YOK' : 'validator.ts’te YOK (metin mi değişti?)');
}

// Sözlük hatasının biçimi (formatInvalidWordsReason) da eşleşmeli.
check('sözlük hata biçimi ("geçerli bir kelime değil." / "geçerli kelimeler değil.") eşleşiyor',
  validator.includes('geçerli bir kelime değil.') && sql.includes('geçerli bir kelime değil.') &&
  validator.includes('geçerli kelimeler değil.') && sql.includes('geçerli kelimeler değil.'));

// ── 3. Ayna envanteri eksiksiz mi ───────────────────────────────────────────
const beklenen = [
  '_km_tile_letter', '_km_letter_at', '_km_full_word', '_km_formed_words',
  '_km_word_raw_points', '_km_word_bonus', '_km_word_scores', '_km_calc_score',
  '_km_corner_bounds', '_km_corner_cell', '_km_fresh_corners',
  '_km_validate_structural', '_km_validate_words',
  '_km_conquered_chain', '_km_all_territories', '_km_invasion_split',
  '_km_shadow_check',
];
for (const fn of beklenen) {
  check(`${fn} tanımlı`, sql.includes(`function public.${fn}(`));
}

// ── 4. Gölge fazı gerçek hamleyi bozamaz ────────────────────────────────────
check('_km_shadow_check hata yutucuyla sarılı (gerçek hamleyi bozamaz)',
  /exception when others then/.test(sql),
  'aynadaki bir bug gerçek bir hamleyi düşürebilir hale gelmiş');

check('vergi ÖNCEKİ tahtayla hesaplanıyor (v_board_before)',
  sql.includes('v_board_before'),
  'submit_move yaması tahtayı dondurmuyor — vergi yanlış hesaplanır');

console.log(failures === 0
  ? '\ntamam — SQL motor aynası TS kaynağıyla tutarlı'
  : `\n${failures} kontrol DÜŞTÜ`);
process.exit(failures === 0 ? 0 : 1);
