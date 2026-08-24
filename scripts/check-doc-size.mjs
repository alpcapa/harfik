// Kelimeki — doküman boyutu bütçesi.
//
// NEDEN VAR (kullanıcı isteği, 24 Ağustos 2026): *"md dosyalarının
// büyümesinden dolayı sürekli hata alıyor ve senin işlerin takılıyordu.
// Dosyaları böldük ve düzeldi. Bundan sonra tekrar aynı şeyin yaşanmaması
// için gerekli kontrolleri koyup ona göre zamanında önlem alalım."*
//
// O gün iki kez öğrenildi: (1) `CLAUDE.md` ~200K token'a çıkıp her turu
// yiyordu — bölündü; (2) bölünme sorunu ÇÖZMEDİ, YER DEĞİŞTİRDİ:
// `mobile/docs/parca-log.md` 714 KB'a (eski CLAUDE.md'nin 7 katı) ulaştı.
// Yani "bir gün fark ederiz" işe yaramıyor; ölçüm otomatik olmalı.
//
// ÜÇ SINIF, çünkü maliyetleri farklı:
//   • AUTO  — her turda bağlama YÜKLENİR (CLAUDE.md'ler). Maliyeti
//             kaçınılmaz, bütçesi en dar.
//   • ACTIVE— isteğe bağlı okunur ama BÜYÜMEYE devam eder. Sınıra gelince
//             yeni bir "cilt" açılır (parça günlüğünde yapıldığı gibi).
//   • FROZEN— dondurulmuş arşiv. Okuması opt-in, o yüzden büyük olabilir;
//             tek kural BÜYÜMEMESİ. Yeni giriş aktif cilde yazılır.
//
// Koşum: npm run check-doc-size   (CI: .github/workflows/docs-size.yml)
import { readdirSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname.replace(/\/$/, '');
const SKIP = new Set(['node_modules', '.git', 'build', 'dist', '.dart_tool', 'ios', 'android']);

const KB = 1000;
const BUTCE = {
  auto: { uyar: 80 * KB, sinir: 120 * KB },
  active: { uyar: 120 * KB, sinir: 200 * KB },
};

// Her turda bağlama yüklenen dosyalar.
const AUTO = new Set(['CLAUDE.md', 'mobile/CLAUDE.md']);

// Dondurulmuş arşivler: `max` = bugünkü boyutun biraz üstü. BÜYÜRSE düşer —
// bu, "yanlışlıkla arşive yazdım" hatasının tek yakalayıcısı.
const FROZEN = {
  'mobile/docs/parca-log-1-48.md': 300 * KB,
  'mobile/docs/parca-log-49-109.md': 290 * KB,
};

function walk(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (SKIP.has(e.name)) continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.md')) out.push(p);
  }
  return out;
}

const tok = (b) => `~${Math.round(b / 4 / 1000)}K token`;
const kb = (b) => `${(b / KB).toFixed(0)} KB`;

const rows = walk(ROOT)
  .map((p) => {
    const rel = relative(ROOT, p);
    const size = statSync(p).size;
    const sinif = AUTO.has(rel) ? 'auto' : rel in FROZEN ? 'frozen' : 'active';
    const sinir = sinif === 'frozen' ? FROZEN[rel] : BUTCE[sinif].sinir;
    const uyar = sinif === 'frozen' ? Infinity : BUTCE[sinif].uyar;
    return { rel, size, sinif, sinir, uyar };
  })
  .sort((a, b) => b.size - a.size);

const dusenler = rows.filter((r) => r.size > r.sinir);
const uyarilar = rows.filter((r) => r.size <= r.sinir && r.size > r.uyar);

console.log('\nDoküman boyutu bütçesi\n');
for (const r of rows.slice(0, 12)) {
  const durum = r.size > r.sinir ? 'SINIR AŞILDI' : r.size > r.uyar ? 'uyarı' : '';
  console.log(
    `  ${r.rel.padEnd(42)} ${kb(r.size).padStart(7)}  ${tok(r.size).padStart(12)}` +
      `  [${r.sinif}]${durum ? '  ← ' + durum : ''}`,
  );
}

if (uyarilar.length) {
  console.log('\nUYARI — sınıra yaklaşıyor, bir sonraki dokunuşta böl:');
  for (const r of uyarilar) {
    console.log(`  • ${r.rel} — ${kb(r.size)} / ${kb(r.sinir)}`);
  }
}

if (dusenler.length) {
  console.log('\nSINIR AŞILDI:\n');
  for (const r of dusenler) {
    console.log(`  ✗ ${r.rel} — ${kb(r.size)} > ${kb(r.sinir)} (${r.sinif})`);
    if (r.sinif === 'auto') {
      console.log(
        '    Bu dosya HER TURDA yükleniyor. Tarihli "neden böyle" anlatılarını\n' +
          '    ilgili docs/decisions/*.md ya da mobile/docs/*.md dosyasına taşı;\n' +
          '    burada yalnızca her yerde geçerli kural/değişmez kalsın.',
      );
    } else if (r.sinif === 'frozen') {
      console.log(
        '    Bu bir ARŞİV — büyümemeliydi. Yeni girişi AKTİF cilde yaz\n' +
          '    (parça günlüğünde: mobile/docs/parca-log.md).',
      );
    } else {
      console.log(
        '    Yeni bir CİLT aç: mevcut dosyayı bir bölüm/parça sınırından kes,\n' +
          '    dondurulmuş yarıyı FROZEN listesine ekle, yeni girişler aktif\n' +
          '    ciltte devam etsin (örnek: mobile/docs/parca-log*.md).',
      );
    }
  }
  console.log('');
  process.exit(1);
}

console.log('\nTüm dosyalar bütçe içinde.');
