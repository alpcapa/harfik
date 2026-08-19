// Kelimeki — karşılama katmanındaki 2 kişilik tanıtım tahtasını Flutter
// portuna ÜRETİR (`mobile/app/lib/src/ui/intro/demo_board_data.dart`).
//
// NEDEN ÜRETİLİYOR (elle yazılmıyor): aynı tahta artık İKİ istemcide birden
// gösteriliyor — web'in karşılama katmanı ve portun ilk açılış tanıtımı
// (`IntroScreen`). İkinci bir elle yazılmış kopya, bu kod tabanının en sık
// tekrarlayan hata sınıfını (iki kopyanın sessizce ayrışması) doğrudan geri
// getirirdi; üstelik tahtanın doğruluğunu sınayan tek şey TS tarafındaki
// `npm run verify-demo-board` — Dart kopyası ondan koparsa hiçbir şey
// yakalamaz.
//
// Koşum: npm run generate-demo-board-dart
// (`src/landing/demoBoard.ts` değişirse ZORUNLU — `verify-demo-board` ile
// birlikte koşulmalı.)
//
// Yalnızca 2 kişilik tahta üretiliyor: tanıtım ekranı kullanıcı isteğiyle
// (19 Ağustos 2026) yalnızca onu gösteriyor. 4 kişilik de gerekirse aynı
// yerden eklenir.
import { writeFileSync } from 'node:fs';
import { DEMO_TILES_2 } from '../src/landing/demoBoard';

const HEDEF = 'mobile/app/lib/src/ui/intro/demo_board_data.dart';

const satirlar = DEMO_TILES_2.map(
  (t) => `  BoardSnapshotTile(r: ${t.r}, c: ${t.c}, l: '${t.l}', o: ${t.o}),`,
).join('\n');

const icerik = `// ÜRETİLMİŞ DOSYA — ELLE DÜZENLEME.
//
// Kaynak: src/landing/demoBoard.ts (\`DEMO_TILES_2\`)
// Yeniden üret: npm run generate-demo-board-dart
//
// Web'in karşılama katmanındaki 2 kişilik tanıtım tahtası. Her yatay/dikey
// dizilimin gerçek bir Türkçe kelime olduğu ve izole hamlelerin gerçekten
// izole kaldığı \`npm run verify-demo-board\` ile ÖLÇÜLEREK doğrulanıyor —
// bu dosya o doğrulanmış kaynaktan üretildiği için ayrıca sınanmıyor.
import 'package:kelimeki_core/kelimeki_core.dart';

const List<BoardSnapshotTile> kDemoTiles2 = [
${satirlar}
];
`;

writeFileSync(HEDEF, icerik, 'utf8');
console.log(`${HEDEF} yazıldı (${DEMO_TILES_2.length} taş).`);
