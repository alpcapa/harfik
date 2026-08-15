// Kelimeki — Türkçe sözlük veri üretici
// =====================================================================
// Kaynak: TDK Güncel Türkçe Sözlük (12. baskı), MIT lisanslı açık veri:
//   https://github.com/ogun/guncel-turkce-sozluk  (sozluk/v12/v12.gts.json.tar.gz)
//
// Bu betik, 99.236 maddelik NDJSON sözlük dökümünü alıp Kelimeki'nin
// oynanabilir kelime kümesine indirger ve şu çıktıları üretir.
// Çok sözcüklü maddeler ("dulavrat otu", "bir de" gibi deyim/atasözleri)
// tamamen elenir; şapkalı ünlüler (â, î, û) taş harfine indirgenir (â→a,
// î→i, û→ü — bkz. stripCircumflex); ardından yalnızca Türk alfabesi
// harfleri içeren, 2–25 harfli tokenlar tutulur.
//
// TDK'nin coğrafi/özel ad kapsamı eksiktir (Atina, Paris, Türkiye gibi çoğu
// ülke/başkent/dil adı GTS'te yok); bu eksik dünya ülkeleri, başkentleri,
// büyük şehirleri ve dilleri scripts/proper-nouns.mjs ile tamamlanır (GTS'te
// zaten varsa dokunulmaz). GTS kaynağı olmadan yalnızca bu listeyi
// güncellemek için scripts/augment-dictionary.mjs kullanılır.
//
//   src/data/words.ts       — oyun doğrulaması için sıralı kelime listesi
//                             (WORD_LIST / WORD_SET)
//   src/data/meanings.json  — { kelime: { pos, meanings: string[] } }
//                             (çalışma anında ?url ile tembel yüklenir)
//   supabase/migrations/20260628090300_seed_dictionary.sql
//                           — words tablosunu anlamlarıyla dolduran seed
//
// Kullanım:
//   1) Kaynağı indirip açın:
//        curl -sSL -o gts.json.tar.gz \
//          https://raw.githubusercontent.com/ogun/guncel-turkce-sozluk/master/sozluk/v12/v12.gts.json.tar.gz
//        tar xzf gts.json.tar.gz        # -> gts.json (NDJSON)
//   2) Betiği çalıştırın:
//        GTS_JSON=./gts.json node scripts/build-dictionary.mjs
//
// gts.json deposu büyük (~100 MB) olduğundan repoya eklenmez; üretilen
// çıktılar repoda tutulur ve gerektiğinde bu betikle yeniden üretilir.

import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
import { PROPER_NOUNS } from './proper-nouns.mjs';
import { EXTRA_WORDS } from './extra-words.mjs';
import { EXTRA_MEANINGS } from './extra-meanings.mjs';
import { PROTECTED_WORDS } from './protected-words.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const SRC = process.env.GTS_JSON || path.join(__dirname, 'gts.json');
if (!fs.existsSync(SRC)) {
  console.error(
    `Kaynak bulunamadı: ${SRC}\n` +
      'gts.json dosyasını indirip açın (betik başlığındaki talimata bakın) ' +
      'ya da GTS_JSON ile yolu verin.',
  );
  process.exit(1);
}

// Kelimeki taşlarındaki Türk alfabesi (q, w, x ve şapkalı ünlüler yok).
const ALLOWED = new Set('abcçdefgğhıijklmnoöprsştuüvyz');

// Türkçe küçük harfe çevirme (I→ı, İ→i kuralı).
function trLower(s) {
  return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

// Şapkalı ünlüler (â, î, û) Türk alfabesinde ayrı bir harf değildir — TDK'nin
// bazı Arapça/Farsça kökenli maddelerde uzunluk/incelik belirtmek için
// kullandığı bir yazım işaretidir; günlük kullanımda ve kelimeki taşlarında
// karşılığı yoktur. Oyunda oynanabilir olmaları için taş harfine indirgenir
// (â→a, î→i, û→ü). Bu, aynı yazılışa düşen farklı TDK maddelerinin (ör.
// "hâlâ"/"hala") anlamlarının tek girişte birleşmesine yol açabilir — sözlük
// zaten homograflar için bu birleştirmeyi yapıyor (aşağıdaki dict.get(word) ile).
function stripCircumflex(s) {
  return s.replace(/â/g, 'a').replace(/î/g, 'i').replace(/û/g, 'ü');
}

const dict = new Map(); // kelime -> { pos, meanings: string[] }
let total = 0;
let dropped = 0;

const rl = readline.createInterface({
  input: fs.createReadStream(SRC, 'utf8'),
  crlfDelay: Infinity,
});

for await (const line of rl) {
  const t = line.trim();
  if (!t) continue;
  total++;
  let entry;
  try {
    entry = JSON.parse(t);
  } catch {
    continue;
  }

  // Element simgeleri (büyük harfli, ozel_mi=0): kelime oyununda geçersiz.
  const maddeOrijinal = (entry.madde || '').replace(/\s+/g, '');
  if (maddeOrijinal !== trLower(maddeOrijinal) && entry.ozel_mi !== '1') {
    dropped++;
    continue;
  }

  // Çok sözcüklü maddeler (2+) TDK'de resmen ayrı yazılan deyim, atasözü ya
  // da bileşik terimlerdir ("acele ile menzil alınmaz", "dulavrat otu",
  // "bir de" gibi) — hiçbiri tek bir Türkçe kelime değildir, bu yüzden
  // oynanabilir kelime kümesinden tamamen elenir.
  const rawMadde = (entry.madde || '').trim();
  if (rawMadde.split(/\s+/).filter(Boolean).length >= 2) {
    dropped++;
    continue;
  }

  const word = stripCircumflex(trLower(entry.madde || ''));
  // Yalnızca oynanabilir harfler + 2–25 uzunluk.
  if (!word || word.length < 2 || word.length > 25) {
    dropped++;
    continue;
  }
  let ok = true;
  for (const ch of word) {
    if (!ALLOWED.has(ch)) {
      ok = false;
      break;
    }
  }
  if (!ok) {
    dropped++;
    continue;
  }

  const meanings = [];
  let pos = null;
  for (const a of entry.anlamlarListe || []) {
    const text = (a.anlam || '').trim();
    if (text) meanings.push(text);
    if (pos == null) {
      for (const o of a.ozelliklerListe || []) {
        // tur === '3' => sözcük türü (isim, sıfat, fiil...)
        if (o.tur === '3' && o.kisa_adi) {
          pos = o.kisa_adi;
          break;
        }
      }
    }
  }
  if (meanings.length === 0) continue;

  // Birleştirme, despaced bir bileşiğin var olan tek sözcükle çakışmasına
  // yol açabilir; anlamları tekrarsız birleştir.
  const existing = dict.get(word);
  if (existing) {
    for (const m of meanings) {
      if (!existing.meanings.includes(m)) existing.meanings.push(m);
    }
    if (!existing.pos) existing.pos = pos;
  } else {
    dict.set(word, { pos, meanings });
  }
}

// TDK'nin coğrafi/özel ad kapsamı eksik (bkz. proper-nouns.mjs başlığı);
// GTS'te bulunmayan ülke/başkent/şehir/dil adlarını burada tamamlıyoruz.
// GTS'te zaten varsa (gerçek TDK tanımı) dokunmuyoruz.
for (const [word, meaning] of Object.entries(PROPER_NOUNS)) {
  if (!dict.has(word)) {
    dict.set(word, { pos: null, meanings: [meaning] });
  }
}

// GTS'te hiç geçmeyen ama oynanabilir sayılan sözcükler (bkz.
// extra-words.mjs başlığı). PROPER_NOUNS ile aynı "zaten varsa dokunma"
// kuralı; ayrı dosya olmasının sebebi kapsam — orası yalnızca coğrafi/özel
// adlar için.
for (const [word, entry] of Object.entries(EXTRA_WORDS)) {
  if (!dict.has(word)) {
    dict.set(word, { pos: entry.pos ?? null, meanings: [...entry.meanings] });
  }
}

// TDK'de zaten var olan bazı kelimelere günlük dilde yaygın olan ek bir
// anlam ekliyoruz (bkz. extra-meanings.mjs başlığı). PROPER_NOUNS'un
// aksine burada "zaten varsa dokunma" kuralı uygulanmaz.
for (const [word, meaning] of Object.entries(EXTRA_MEANINGS)) {
  const existing = dict.get(word);
  if (existing) {
    if (!existing.meanings.includes(meaning)) existing.meanings.push(meaning);
  } else {
    dict.set(word, { pos: null, meanings: [meaning] });
  }
}

// Upstream GTS zaman içinde madde kaldırabiliyor/değiştirebiliyor (bkz.
// protected-words.mjs başlığı — 21 Temmuz 2026'da 159 kelimede tespit edildi).
// GTS'te artık bulunmayan bu kelimeleri burada saklanan verilerle geri
// ekliyoruz; GTS'te zaten varsa (güncel TDK verisi) dokunmuyoruz.
for (const [word, entry] of Object.entries(PROTECTED_WORDS)) {
  if (!dict.has(word)) {
    dict.set(word, { pos: entry.pos, meanings: entry.meanings });
  }
}

// Türkçe sıralı kelime listesi.
const collator = new Intl.Collator('tr');
const words = [...dict.keys()].sort(collator.compare);

// ── Çıktı: words.ts ─────────────────────────────────────────────────────────
// Açıkça `readonly string[]` türüyle yazılır; böylece tsc dev bir tuple
// türü çıkarmaya çalışmaz (tip kontrolü hızlı kalır).
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
const meanings = {};
for (const w of words) {
  const d = dict.get(w);
  meanings[w] = { pos: d.pos, meanings: d.meanings };
}
const meaningsPath = path.join(ROOT, 'src/data/meanings.json');
fs.writeFileSync(meaningsPath, JSON.stringify(meanings) + '\n');

// ── Çıktı: Supabase seed migration ──────────────────────────────────────────
// words tablosuna toplu ekleme; len ve points DB tarafında hesaplanır,
// anlamlar jsonb olarak saklanır. Çok satırlı INSERT'ler partilenir.
function sqlStr(s) {
  return "'" + String(s).replace(/'/g, "''") + "'";
}

const BATCH = 500;
const out = [];
out.push('-- Kelimeki — TDK Güncel Türkçe Sözlük (12. baskı) seed');
out.push('-- Kaynak: https://github.com/ogun/guncel-turkce-sozluk (MIT)');
out.push(`-- ${words.length} oynanabilir madde, anlamlarıyla birlikte.`);
out.push('-- Üretim: scripts/build-dictionary.mjs (elle düzenlemeyin).');
out.push('-- Tekrar çalıştırmaya güvenli (ON CONFLICT DO UPDATE).');
out.push('');

for (let i = 0; i < words.length; i += BATCH) {
  const chunk = words.slice(i, i + BATCH);
  out.push(
    'insert into public.words (word, len, points, pos, meanings) values',
  );
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

const seedPath = path.join(
  ROOT,
  'supabase/migrations/20260628090300_seed_dictionary.sql',
);
fs.writeFileSync(seedPath, out.join('\n'));

console.log(`Toplam madde okundu      : ${total}`);
console.log(`Elenen (oynanamaz)       : ${dropped}`);
console.log(`Oynanabilir kelime       : ${words.length}`);
console.log(`Yazıldı: ${path.relative(ROOT, wordsPath)}`);
console.log(`Yazıldı: ${path.relative(ROOT, meaningsPath)}`);
console.log(`Yazıldı: ${path.relative(ROOT, seedPath)}`);
