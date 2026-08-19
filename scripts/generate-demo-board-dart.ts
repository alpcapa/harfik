// Kelimeki — karşılama katmanındaki tanıtım tahtalarını (2 VE 4 kişilik)
// Flutter portuna ÜRETİR (`mobile/app/lib/src/ui/intro/demo_board_data.dart`).
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
// İKİ tahta da üretiliyor: tanıtım ekranı 19 Ağustos 2026'da kullanıcı
// isteğiyle 4 kişilik tahtayı da ayrı bir slayt olarak gösteriyor ("webdeki
// 4 oyunculu görseli ve altındaki yazıyı da 2. slayt yap").
import { writeFileSync } from 'node:fs';
import { DEMO_TILES_2, DEMO_TILES_4 } from '../src/landing/demoBoard';
import type { BoardSnapshotTile } from '../src/utils/boardSnapshot';

const HEDEF = 'mobile/app/lib/src/ui/intro/demo_board_data.dart';

const dizi = (tiles: BoardSnapshotTile[]) =>
  tiles
    .map((t) => `  BoardSnapshotTile(r: ${t.r}, c: ${t.c}, l: '${t.l}', o: ${t.o}),`)
    .join('\n');

const icerik = `// ÜRETİLMİŞ DOSYA — ELLE DÜZENLEME.
//
// Kaynak: src/landing/demoBoard.ts (\`DEMO_TILES_2\` + \`DEMO_TILES_4\`)
// Yeniden üret: npm run generate-demo-board-dart
//
// Web'in karşılama katmanındaki 2 ve 4 kişilik tanıtım tahtaları. Her yatay/dikey
// dizilimin gerçek bir Türkçe kelime olduğu ve izole hamlelerin gerçekten
// izole kaldığı \`npm run verify-demo-board\` ile ÖLÇÜLEREK doğrulanıyor —
// bu dosya o doğrulanmış kaynaktan üretildiği için ayrıca sınanmıyor.
import 'package:kelimeki_core/kelimeki_core.dart';

const List<BoardSnapshotTile> kDemoTiles2 = [
${dizi(DEMO_TILES_2)}
];

const List<BoardSnapshotTile> kDemoTiles4 = [
${dizi(DEMO_TILES_4)}
];
`;

writeFileSync(HEDEF, icerik, 'utf8');
console.log(
  `${HEDEF} yazıldı (2 kişilik ${DEMO_TILES_2.length}, 4 kişilik ${DEMO_TILES_4.length} taş).`,
);
