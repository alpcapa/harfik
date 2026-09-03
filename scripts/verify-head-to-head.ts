// Kelimeki — `src/utils/headToHead.ts`in saf kuralını ÜRETİM kodunu import
// ederek doğrular. Port ikizi `util/head_to_head.dart`, vakaları
// `head_to_head_test.dart` — AYNI vakalar.
//
// NEDEN ÖNEMLİ: bar bir ORANı gösteriyor ve yüzdeler toplamı 100 etmezse
// çubuğun ucunda görünür bir boşluk/taşma oluşur. Üç dilimi bağımsız
// yuvarlamak tam olarak bunu yapıyor (33+33+33=99) — aşağıdaki "toplam
// HER ZAMAN 100" iddiası o hatanın negatif eşi.
//
// Koşum: npm run verify-head-to-head
import { headToHeadBar, hasHeadToHead, type HeadToHead } from '../src/utils/headToHead';

let failures = 0;
const check = (name: string, cond: boolean, detail = '') => {
  if (cond) console.log(`  ✓ ${name}`);
  else { failures++; console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`); }
};
const h = (games: number, wins: number, losses: number, draws: number): HeadToHead =>
  ({ games, wins, losses, draws });

console.log('Yön: sol = BAKILAN kişi, sağ = BAKAN kişi');
{
  // Canlıdan ölçülen gerçek vaka: A→B 14 oyun, 5 galibiyet, 9 mağlubiyet.
  const b = headToHeadBar(h(14, 5, 9, 0));
  check('bakılan kişi daha çok kazandıysa SOL dilim büyük', b.left > b.right,
    `sol=${b.left} sağ=${b.right}`);
  check('sol dilim = losses oranı', b.left === Math.round((9 * 100) / 14));
}

console.log('Yüzdeler toplamı');
for (const [g, w, l, d] of [
  [14, 5, 9, 0], [3, 1, 1, 1], [1, 1, 0, 0], [7, 3, 3, 1], [100, 33, 33, 34],
] as const) {
  const b = headToHeadBar(h(g, w, l, d));
  check(`${g} oyun (${w}/${l}/${d}) → toplam 100`,
    b.left + b.middle + b.right === 100,
    `sol=${b.left} orta=${b.middle} sağ=${b.right}`);
}

console.log('Uç durumlar');
{
  const b = headToHeadBar(h(0, 0, 0, 0));
  check('hiç oyun yok → üçü de 0', b.left === 0 && b.middle === 0 && b.right === 0);
  check('hiç oyun yok → blok çizilmez', !hasHeadToHead(h(0, 0, 0, 0)));
  check('null → blok çizilmez', !hasHeadToHead(null));
  check('oyun varsa blok çizilir', hasHeadToHead(h(1, 1, 0, 0)));
}
{
  const b = headToHeadBar(h(4, 4, 0, 0));
  check('hepsini BAKAN kazandıysa sağ 100', b.right === 100 && b.left === 0);
  const b2 = headToHeadBar(h(4, 0, 4, 0));
  check('hepsini BAKILAN kazandıysa sol 100', b2.left === 100 && b2.right === 0);
  const b3 = headToHeadBar(h(2, 0, 0, 2));
  check('hepsi beraberlikse orta 100', b3.middle === 100);
}

console.log(failures === 0 ? '\nTÜMÜ GEÇTİ' : `\n${failures} KONTROL DÜŞTÜ`);
process.exit(failures === 0 ? 0 : 1);
