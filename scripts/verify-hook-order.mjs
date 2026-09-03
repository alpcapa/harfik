// Kelimeki — "hook'lar erken return'lerin ÜSTÜNDE mi?" kapısı.
//
// NEDEN VAR (3 Eylül 2026, CANLIDA yakalandı): `LiveGamesTab.tsx`'e eklenen
// `freshFinished` state'i + effect'i dosyanın SONUNA, yani `if (authLoading)`,
// `if (creating)` ve `if (!user)` dallarının ALTINA yazılmıştı. Kullanıcı
// "Yeni Canlı Oyun"a bastığında bileşen `creating` dalından erken dönüyor ve
// önceki render'dan DAHA AZ hook çalıştırıyordu → React #300 → ErrorBoundary.
//
// Hiçbir mevcut kontrol bunu görmedi: `tsc --noEmit` hook sırasını bilmez,
// Playwright duman testi Canlı oyuna Supabase oturumu olmadan giremez, ve
// bileşen İLK render'da (creating=false) sorunsuz çalıştığından hata ancak
// butona basılınca doğuyordu. Bu repoda ESLint kurulu olmadığı için
// `react-hooks/rules-of-hooks` de yok — bu betik onun dar bir ikamesi.
//
// KAPSAM (bilinçli olarak dar): yalnızca "bir fonksiyonun 2 boşluk girintili
// gövdesinde, ilk erken `return`den SONRA gelen hook çağrısı". Koşullu hook
// (if içinde `useState`) ya da döngüde hook gibi öteki ihlalleri GÖRMEZ;
// onlar bu kod tabanında hiç yaşanmadı, yaşanırsa desen buraya eklenir.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const FN_START = /^(?:export\s+)?(?:default\s+)?function\s+\w+|^(?:export\s+)?const\s+\w+\s*(?::[^=]+)?=\s*(?:function|\()/;
const HOOK = /^ {2}(?:const .*=\s*)?use[A-Z]\w*\(/;
const EARLY_RETURN = /^ {2}(?:if \(.*\)\s*return|return)\b/;

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else if (p.endsWith('.tsx')) out.push(p);
  }
  return out;
}

const findings = [];
for (const file of walk('src')) {
  const lines = readFileSync(file, 'utf8').split('\n');
  let firstReturn = null;
  lines.forEach((line, i) => {
    if (FN_START.test(line)) {
      firstReturn = null; // yeni fonksiyon — sayaç sıfırlanır
      return;
    }
    if (firstReturn === null && EARLY_RETURN.test(line)) firstReturn = i + 1;
    else if (firstReturn !== null && HOOK.test(line)) {
      findings.push({ file, line: i + 1, at: firstReturn, code: line.trim() });
    }
  });
}

if (findings.length === 0) {
  console.log('✓ Hook sırası temiz — erken return altında hook yok.');
  process.exit(0);
}

console.error('✗ Erken `return`den SONRA hook çağrısı bulundu (React #300 riski):\n');
for (const f of findings) {
  console.error(`  ${f.file}:${f.line}  (erken return: satır ${f.at})`);
  console.error(`    ${f.code}\n`);
}
console.error('Çare: hook\'u fonksiyonun BAŞINA, tüm erken dallardan önce taşı.');
process.exit(1);
