// Kelimeki — Flutter portu için kelime anlamları asset'i (SQLite).
//
// Web `src/data/meanings.json`'u (~6.5 MB) tarayıcıda `?url` ile tembel
// çekip TAMAMINI RAM'de tutuyor (src/data/meanings.ts). Mobilde bu kötü bir
// tercih: 6.5 MB JSON'u telefonda parse etmek gözle görülür bir gecikme ve
// onlarca MB kalıcı bellek demek. Bunun yerine build-time'da tek tablolu bir
// SQLite dosyasına çevriliyor; uygulama sorgu anında TEK SATIR okuyor
// (bkz. mobile/CLAUDE.md, "Üst Düzey Kararlar" #4).
//
// Anahtar normalizasyonu web'le AYNI olmalı: `trLower` (İ→i, I→ı). Kaynak
// dosya zaten küçük harfli ama garantiyi burada da uyguluyoruz — aksi halde
// uygulama `trLower(word)` ile sorgulayıp bulamaz.
//
// Çalıştırma: npm run generate-meanings-db
// `meanings.json` değişirse bu script YENİDEN koşulmalı (sözlük/golden
// vector disiplininin aynısı).
import {
  readFileSync,
  writeFileSync,
  mkdirSync,
  rmSync,
  statSync,
} from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const ROOT = process.cwd();
const SRC = join(ROOT, 'src/data/meanings.json');
const ASSETS = join(ROOT, 'mobile/app/assets/dictionary');
const OUT = join(ASSETS, 'meanings.db');
// Küçük parmak izi asset'i: uygulama açılışta 5 MB'ı okumadan "elimdeki
// kopya güncel mi" sorusunu bunu okuyarak yanıtlar (bkz. meaning_store.dart).
const STAMP = join(ASSETS, 'meanings.db.sha256');

/** src/utils/turkish.ts:trLower ile birebir aynı olmalı. */
function trLower(s) {
  return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase();
}

function main() {
  const raw = JSON.parse(readFileSync(SRC, 'utf8'));
  mkdirSync(ASSETS, { recursive: true });
  rmSync(OUT, { force: true }); // her koşuda sıfırdan — artık satır kalmasın

  const db = new DatabaseSync(OUT);
  // `word` PRIMARY KEY → sorgu tek satır/indeksli. Anlamlar JSON dizisi
  // olarak tek sütunda: kelime başına ortalama 1.46 anlam olduğundan ayrı
  // bir tabloya normalleştirmek kazanç sağlamıyor, okuma da tek satır kalıyor.
  db.exec(`
    PRAGMA journal_mode = DELETE;
    CREATE TABLE meanings (
      word     TEXT PRIMARY KEY,
      pos      TEXT,
      meanings TEXT NOT NULL
    ) WITHOUT ROWID;
  `);

  const insert = db.prepare(
    'INSERT OR REPLACE INTO meanings (word, pos, meanings) VALUES (?, ?, ?)',
  );
  let count = 0;
  let collisions = 0;
  const seen = new Set();
  db.exec('BEGIN');
  for (const [key, value] of Object.entries(raw)) {
    const word = trLower(key);
    const meanings = Array.isArray(value?.meanings) ? value.meanings : [];
    if (meanings.length === 0) continue; // anlamsız kayıt asset'e girmesin
    if (seen.has(word)) collisions++;
    seen.add(word);
    insert.run(word, value?.pos ?? null, JSON.stringify(meanings));
    count++;
  }
  db.exec('COMMIT');
  db.exec('VACUUM');
  db.close();

  const bytes = statSync(OUT).size;
  const sha = createHash('sha256').update(readFileSync(OUT)).digest('hex');
  writeFileSync(STAMP, sha + '\n');
  console.log(
    `meanings.db: ${count} kelime, ${(bytes / 1024 / 1024).toFixed(2)} MB, ` +
      `sha ${sha.slice(0, 12)}…` +
      (collisions ? ` (${collisions} normalizasyon çakışması birleşti)` : ''),
  );
}

main();
