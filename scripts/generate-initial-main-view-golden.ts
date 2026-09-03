// Kelimeki — girişte hangi sekmenin açılacağı kararının TÜKETİCİ golden'ı.
//
// NEDEN VAR (21 Ağustos 2026): `decideInitialMainView` web'de
// `src/utils/pendingLiveGames.ts`, portta `mobile/app/lib/src/data/
// online_games_api.dart` — İKİ ELLE SENKRON kopya. Öteki parite testleri
// SAYI karşılaştırıyor; burada karşılaştırılacak sayı yok, DAVRANIŞ var.
// Bu yüzden çözüm golden vector deseni: web'in ÜRETİM fonksiyonu tüm girdi
// uzayında koşturulup sonuç dondurulur, Dart testi kendi kopyasını aynı
// tabloya karşı sınar.
//
// ⚠ TÜKETİCİ (exhaustive), örneklem DEĞİL: girdi uzayı küçük olduğundan
// hepsi taranıyor — `counts` null ya da üç sayacın {0,1,2} kombinasyonu,
// `cloudSaves` null ya da uzunluk {0,1,2}. (1+27)×(1+3) = 112 vaka. Örnekleme
// yapılsaydı bir dal sessizce sınanmadan kalabilirdi.
//
// ⚠ BAYATLAMA: golden'lar üretilmiş dosyalardır; TS kuralı değişip golden
// yeniden üretilmezse Dart testi ESKİ tabloya karşı geçer. Bu delik CI'da
// kapatıldı — `web-ci.yml` bu betiği koşup `git diff --exit-code` ile
// dosyanın tazeliğini zorluyor.
//
// Koşum: npm run generate-initial-main-view-golden
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

import { decideInitialMainView } from '../src/utils/pendingLiveGames';

const OUT = join(
  process.cwd(),
  'mobile/app/test/goldens/initial_main_view.json',
);

const AXIS = [0, 1, 2];
type Case = {
  counts: [number, number, number] | null;
  saves: number | null;
  expected: string | null;
};

const cases: Case[] = [];
const countsList: ([number, number, number] | null)[] = [null];
for (const invite of AXIS) {
  for (const myTurn of AXIS) {
    for (const active of AXIS) countsList.push([invite, myTurn, active]);
  }
}

for (const counts of countsList) {
  for (const saves of [null, 0, 1, 2]) {
    const sonuc = decideInitialMainView(
      counts === null
        ? null
        : {
            inviteCount: counts[0],
            myTurnCount: counts[1],
            activeCount: counts[2],
            // Giriş sekmesi kararına GİRMEZ (biten oyun "haber", "iş"
            // değil — bkz. alanın notu). Sabit boş: bu golden'ın kapsamı
            // değişmedi, yalnızca tip zorunluluğu.
            finishedUnseenIds: [],
          },
      saves === null ? null : { length: saves },
    );
    cases.push({ counts, saves, expected: sonuc });
  }
}

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, `${JSON.stringify({ cases }, null, 2)}\n`);

const dagilim = cases.reduce<Record<string, number>>((acc, c) => {
  const k = String(c.expected);
  acc[k] = (acc[k] ?? 0) + 1;
  return acc;
}, {});
console.log(`${cases.length} vaka yazıldı → ${OUT}`);
console.log('dağılım:', dagilim);
// Boşa geçen golden koruması: üç sonucun ÜÇÜ de temsil edilmeli.
for (const beklenen of ['live', 'local', 'null']) {
  if (!dagilim[beklenen]) {
    console.error(`HATA: "${beklenen}" sonucu hiç üretilmedi — girdi uzayı bozuk`);
    process.exit(1);
  }
}
