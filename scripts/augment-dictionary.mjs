// Kelimeki — elle tutulan kelime/anlam listelerini mevcut sözlüğe uygular.
// =====================================================================
// build-dictionary.mjs, GTS kaynağının (gts.json, ~100 MB) indirilmesini
// gerektirir ve repoda tutulmaz. Elle tutulan listeleri GTS'i yeniden
// indirmeden uygulamak için bu betik kullanılır: mevcut
// src/data/meanings.json'ı okur, aşağıdaki üç listeyi uygular ve çıktıları
// yeniden üretir.
//
//   proper-nouns.mjs   — ülke/başkent/şehir/dil adları   (yoksa EKLE)
//   extra-words.mjs    — GTS'te hiç geçmeyen sözcükler   (yoksa EKLE)
//   extra-meanings.mjs — VAR OLAN kelimeye ek anlam      (varsa GÜNCELLE)
//
// Üçüncüsü bu betiğe 15 Ağustos 2026'da eklendi: o güne dek ek anlamları
// yalnızca GTS'li tam üretim uyguluyordu, yani 100 MB'lık kaynak olmadan
// var olan bir kelimeye anlam eklemenin YOLU YOKTU.
//
//   src/data/words.ts       — build-dictionary.mjs ile birebir aynı biçimde
//   src/data/meanings.json  —            "
//   supabase/migrations/<damga>_add_words.sql
//                           — yalnızca bu çalıştırmada eklenen/güncellenen
//                             maddeler için yeni bir migration (ana seed
//                             dosyası değişmez)
//
// Kullanım:
//   node scripts/augment-dictionary.mjs
//
// GTS kaynağıyla tam yeniden üretim yapıldığında (build-dictionary.mjs),
// üç liste de zaten otomatik olarak birleştirilir; bu betik yalnızca GTS
// kaynağı olmadan aynı sonucu almak içindir. **Yeni bir liste dosyası
// eklenirse İKİ betiğe birden tanıtılmalı** — yalnızca buraya eklemek,
// ileride yapılacak bir tam üretimde o maddelerin sessizce düşmesi demektir.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROPER_NOUNS } from './proper-nouns.mjs';
import { EXTRA_WORDS } from './extra-words.mjs';
import { EXTRA_MEANINGS } from './extra-meanings.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const meaningsPath = path.join(ROOT, 'src/data/meanings.json');
const currentMeanings = JSON.parse(fs.readFileSync(meaningsPath, 'utf8'));

const dict = new Map(); // kelime -> { pos, meanings: string[] }
for (const [word, d] of Object.entries(currentMeanings)) {
  dict.set(word, { pos: d.pos ?? null, meanings: d.meanings });
}

const added = [];
for (const [word, meaning] of Object.entries(PROPER_NOUNS)) {
  if (!dict.has(word)) {
    dict.set(word, { pos: null, meanings: [meaning] });
    added.push(word);
  }
}

// extra-words.mjs — proper-nouns ile AYNI "zaten varsa dokunma" kuralı;
// tek fark biçimin `{pos, meanings[]}` olması (protected-words.mjs gibi).
for (const [word, entry] of Object.entries(EXTRA_WORDS)) {
  if (!dict.has(word)) {
    dict.set(word, { pos: entry.pos ?? null, meanings: [...entry.meanings] });
    added.push(word);
  }
}

// extra-meanings.mjs — build-dictionary.mjs'teki davranışın birebir aynısı:
// kelime VARSA anlam listesine eklenir (mükerrer değilse), YOKSA yeni madde
// olarak açılır. Bunlar `added` değil `updated` sayılır, çünkü migration'da
// insert değil güncelleme üretirler.
const updated = [];
for (const [word, meaning] of Object.entries(EXTRA_MEANINGS)) {
  const existing = dict.get(word);
  if (existing) {
    if (!existing.meanings.includes(meaning)) {
      existing.meanings.push(meaning);
      updated.push(word);
    }
  } else {
    dict.set(word, { pos: null, meanings: [meaning] });
    added.push(word);
  }
}

if (added.length === 0 && updated.length === 0) {
  console.log('Yapacak bir şey yok — listelerin tamamı sözlüğe zaten uygulanmış.');
  process.exit(0);
}

// Türkçe sıralı kelime listesi.
const collator = new Intl.Collator('tr');
const words = [...dict.keys()].sort(collator.compare);

// ── Çıktı: words.ts (build-dictionary.mjs ile aynı biçim) ──────────────────
const PER_LINE = 16;
const wordLines = [];
for (let i = 0; i < words.length; i += PER_LINE) {
  wordLines.push(
    '  ' + words.slice(i, i + PER_LINE).map((w) => JSON.stringify(w)).join(', ') + ',',
  );
}
const wordsTs =
  '// Kelimeki — Türkçe kelime listesi\n' +
  '// TDK Güncel Türkçe Sözlük (12. baskı) kaynaklı oynanabilir maddeler.\n' +
  '// Kaynak: https://github.com/ogun/guncel-turkce-sozluk (MIT)\n' +
  '// ÜRETİLMİŞTİR — elle düzenlemeyin. Yeniden üretmek için:\n' +
  '//   GTS_JSON=./gts.json node scripts/build-dictionary.mjs\n' +
  '\n' +
  `export const WORD_LIST: readonly string[] = [\n${wordLines.join('\n')}\n];\n` +
  '\n' +
  'export const WORD_SET: ReadonlySet<string> = new Set(WORD_LIST);\n';
const wordsPath = path.join(ROOT, 'src/data/words.ts');
fs.writeFileSync(wordsPath, wordsTs);

// ── Çıktı: meanings.json ────────────────────────────────────────────────────
const meaningsOut = {};
for (const w of words) {
  const d = dict.get(w);
  meaningsOut[w] = { pos: d.pos, meanings: d.meanings };
}
fs.writeFileSync(meaningsPath, JSON.stringify(meaningsOut) + '\n');

// ── Çıktı: Supabase migration (yalnızca bu çalıştırmada eklenenler) ─────────
function sqlStr(s) {
  return "'" + String(s).replace(/'/g, "''") + "'";
}

function timestamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}` +
    `${pad(d.getUTCHours())}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}`
  );
}

// Eklenen ve güncellenen maddeler AYNI upsert'ten geçer: `on conflict do
// update` zaten var olan satırın anlamlarını da tazeliyor, yani ek anlam
// için ayrı bir UPDATE ifadesi gerekmiyor.
const touchedSorted = [...new Set([...added, ...updated])].sort(collator.compare);
const BATCH = 500;
const out = [];
out.push('-- Kelimeki — elle tutulan kelime/anlam listelerinin uygulanması');
out.push('-- Kaynak: scripts/{proper-nouns,extra-words,extra-meanings}.mjs');
out.push('--         (scripts/augment-dictionary.mjs ile üretildi).');
out.push(`-- ${added.length} yeni madde, ${updated.length} anlam güncellemesi.`);
out.push('-- Tekrar çalıştırmaya güvenli (ON CONFLICT DO UPDATE).');
out.push('');

for (let i = 0; i < touchedSorted.length; i += BATCH) {
  const chunk = touchedSorted.slice(i, i + BATCH);
  out.push('insert into public.words (word, len, points, pos, meanings) values');
  const rows = chunk.map((w) => {
    const d = dict.get(w);
    const meaningsJson = JSON.stringify(d.meanings);
    const posSql = d.pos ? sqlStr(d.pos) : 'null';
    return `  (${sqlStr(w)}, char_length(${sqlStr(w)}), public.kelimeki_points(${sqlStr(
      w,
    )}), ${posSql}, ${sqlStr(meaningsJson)}::jsonb)`;
  });
  out.push(rows.join(',\n'));
  out.push(
    'on conflict (word) do update set ' +
      'len = excluded.len, points = excluded.points, ' +
      'pos = excluded.pos, meanings = excluded.meanings;',
  );
  out.push('');
}

const migrationPath = path.join(
  ROOT,
  `supabase/migrations/${timestamp()}_add_words.sql`,
);
fs.writeFileSync(migrationPath, out.join('\n'));

const listeToplam = Object.keys(PROPER_NOUNS).length + Object.keys(EXTRA_WORDS).length;
console.log(`Sözlükte zaten vardı (dokunulmadı) : ${listeToplam - added.length}`);
console.log(`Yeni eklenen                       : ${added.length}  [${added.join(', ')}]`);
console.log(`Anlamı güncellenen                 : ${updated.length}  [${updated.join(', ')}]`);
console.log(`Toplam oynanabilir kelime          : ${words.length}`);
console.log(`Yazıldı: ${path.relative(ROOT, wordsPath)}`);
console.log(`Yazıldı: ${path.relative(ROOT, meaningsPath)}`);
console.log(`Yazıldı: ${path.relative(ROOT, migrationPath)}`);
