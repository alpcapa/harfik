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
// DÖRT SINIF, çünkü maliyetleri farklı:
//   • AUTO  — her turda bağlama YÜKLENİR (CLAUDE.md'ler). Maliyeti
//             kaçınılmaz, bütçesi en dar.
//   • ACTIVE— BAŞTAN SONA okunan, büyümeye devam eden dosyalar: kontrol
//             listeleri (TESTING*), README, ROADMAP. Sınıra gelince yeni bir
//             "cilt" açılır ya da bölünür.
//   • REFERENCE — yalnızca GREP'lenen başvuru dokümanları
//             (docs/decisions/*, parça günlüğünün aktif cildi). Tavanı geniş
//             çünkü maliyet dosya boyutunda DEĞİL, onu baştan sona okumakta.
//   • FROZEN— dondurulmuş arşiv. Okuması opt-in, o yüzden büyük olabilir;
//             tek kural BÜYÜMEMESİ.
//
// ⚠ REFERENCE 29 Ağustos 2026'da EKLENDİ, kullanıcı sorusuyla: *"Büyüyen md
// dosyalarını bölme işini tüm md'lerde yapıyor muyuz? Gerek var mı?"*
// Ölçüm: repoda 43 `.md`, 2.3 MB. `active` bütçesi ÖDENMEYEN bir maliyeti
// vekaleten ölçüyordu — o dosyalar isteğe bağlı ve çoğunlukla `grep`'le
// okunuyor; parça günlüğünün kendi başlığı bile "bir cildi BAŞTAN SONA
// OKUMA, grep ile ara" diyor. Bölmenin ise gerçek bir bedeli var ve bu repo
// onu ödedi: `docs/decisions/` 22 dosyaya çıktı ve doğru dosyayı bulmak için
// kök CLAUDE.md'de bir indeks tablosu tutuluyor (eski atıflar bölünmeyle
// kırıldı). Yani kural kaldırılmadı, DARALTILDI: bölme refleksi artık
// yalnızca baştan sona okunan dosyalar için.
//
// Bir dosya uyarı bandına girdiğinde ilk soru "nasıl bölerim" DEĞİL,
// "bunu baştan sona okuyan var mı?" — cevabı hayırsa çare bölmek değil,
// bayat anlatıyı budamak ya da bir cilt dondurmak. Yeni giriş aktif cilde yazılır.
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
  // Grep'lenen başvuru dokümanları: tavan geniş ama SONSUZ değil — 300 KB'ı
  // aşan bir dosya artık dondurulup ciltlenmeli, yoksa baştan sona okumak
  // gereken nadir durumda (ör. bir bölümü yeniden yazarken) bağlamı yakar.
  reference: { uyar: 200 * KB, sinir: 300 * KB },
};

// Her turda bağlama yüklenen dosyalar.
const AUTO = new Set(['CLAUDE.md', 'mobile/CLAUDE.md']);

// Dondurulmuş arşivler: `max` = bugünkü boyutun biraz üstü. BÜYÜRSE düşer —
// bu, "yanlışlıkla arşive yazdım" hatasının tek yakalayıcısı.
const FROZEN = {
  'mobile/docs/parca-log-1-48.md': 300 * KB,
  'mobile/docs/parca-log-49-109.md': 290 * KB,
  // 26 Ağustos 2026: aktif cilt 151 KB'a çıkınca Parça 110-138 donduruldu.
  // Tavan bugünkü boyutun biraz üstünde — tek kural BÜYÜMEMESİ.
  'mobile/docs/parca-log-110-138.md': 150 * KB,
};

// Yalnızca GREP'lenen başvuru dokümanları. Kural DOSYA ADINA değil, dosyanın
// nasıl OKUNDUĞUNA bakıyor:
//   • docs/decisions/*        — "neden böyle yapıldı" kayıtları; bir konuda
//                               çalışırken tek bir madde aranır.
//   • mobile/docs/parca-log*  — parça günlüğü; dosyanın kendi başlığı baştan
//                               sona okumayı açıkça YASAKLIYOR.
// TESTING* dosyaları BİLEREK dışarıda: onlar baştan sona koşulan kontrol
// listeleri, yani gerçekten okunuyorlar → `active` kalırlar.
function isReference(rel) {
  if (/TESTING/i.test(rel) || /\btesting-/.test(rel)) return false;
  return rel.startsWith('docs/decisions/') || /^mobile\/docs\/parca-log/.test(rel);
}

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
    const sinif = AUTO.has(rel)
      ? 'auto'
      : rel in FROZEN
        ? 'frozen'
        : isReference(rel)
          ? 'reference'
          : 'active';
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
  console.log('\nUYARI — sınıra yaklaşıyor:');
  for (const r of uyarilar) {
    const ne = r.sinif === 'reference'
      ? 'bayat anlatıyı buda ya da cilt dondur'
      : 'bir sonraki dokunuşta böl';
    console.log(`  • ${r.rel} — ${kb(r.size)} / ${kb(r.sinir)} [${r.sinif}] → ${ne}`);
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
    } else if (r.sinif === 'reference') {
      console.log(
        '    Bu dosya grep\'leniyor, baştan sona okunmuyor — yani bölmek çoğu\n' +
          '    zaman baytı yer değiştirmekten ibaret. ÖNCE bayat/aşılmış\n' +
          '    anlatıyı buda; hâlâ büyükse bir CİLT dondur (FROZEN listesi).\n' +
          '    docs/decisions/ zaten 22 dosya — yeni dosya açmadan önce\n' +
          '    kök CLAUDE.md\'deki indeks tablosunun büyüme bedelini hesaba kat.',
      );
    } else {
      console.log(
        '    Bu dosya BAŞTAN SONA okunuyor (kontrol listesi/plan), yani boyut\n' +
          '    gerçek bir maliyet. Bir bölüm sınırından kes; kesme noktası\n' +
          '    boyut değil İÇERİĞİN TÜRÜ olsun (tek oturum ↔ iki oturum,\n' +
          '    normal kullanıcı ↔ admin — örnek: TESTING.md → docs/testing-admin.md).',
      );
    }
  }
  console.log('');
  process.exit(1);
}

console.log('\nTüm dosyalar bütçe içinde.');
