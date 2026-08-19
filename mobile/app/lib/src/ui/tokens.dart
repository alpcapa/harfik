/// Web'in `tailwind.config.js`'indeki renk paletinin TEK Dart karşılığı.
///
/// **Neden var (11 Ağustos 2026, Parça 54):** port bugüne kadar her dosyada
/// kendi `const Color _muted = ...` kopyasını taşıyordu. Bir denetimde bu
/// kopyaların sessizce AYRIŞTIĞI bulundu — `_red` 13 dosyada iki farklı
/// değere bölünmüştü (`#DC2626` vs `#E0483A`), `_green` de öyle
/// (`#16A34A` vs `#1FA05C`). Hiçbir derleyici/test bunu yakalamaz.
///
/// **Kural: web'de `text-green`/`bg-red` gibi bir TOKEN sınıfı kullanılıyorsa
/// buradaki sabit kullanılır; yeni bir yerel `const Color _x` AÇILMAZ.**
/// Değer `tailwind.config.js` ile birebir aynı kalmalı — orası kanonik.
library;

import 'dart:ui';

// tailwind.config.js → theme.extend.colors
const kBg = Color(0xFFFFFFFF);
const kPanel = Color(0xFFF5F7FA);
const kBorder = Color(0xFFDCE2EA);
const kText = Color(0xFF1B2430);
const kMuted = Color(0xFF5A6673);
const kAccent = Color(0xFF2563EB);
const kGold = Color(0xFFB7791F);
const kOrange = Color(0xFFF2650F);
const kGreen = Color(0xFF16A34A);
const kRed = Color(0xFFDC2626);
const kVoid = Color(0xFFE8EBEF);

/// k-lig'in üç üst kademesinin damga renkleri (Efsane/Uzaylı/Kozmik, 12
/// Ağustos 2026). Palet kırmızıya kadar doluydu; bu üçü tailwind'e de token
/// olarak eklendi ki "her kademe rengi bir palet token'ıdır" değişmezi
/// kırılmasın (kanonik kaynak yine `tailwind.config.js`).
///
/// `color_tokens_test`in "yerel kopya" taramasına DA eklendiler — `kTilePts`
/// gibi bir istisna gerekmiyor, bu üç değerin `lib/` altında başka hiçbir
/// anlamı yok.
const kIndigo = Color(0xFF4F46E5);
const kCyan = Color(0xFF06B6D4);
const kGoldBright = Color(0xFFEAB308);

/// tailwind `tile-pts` — taş puanının soluk grisi. Parça 61'de eklendi:
/// k-lig rütbe merdiveninin ilk kademesi (Çaylak) web'de bu değeri taşıyor
/// (`leagueRank.ts`, `#8A93A2`), yani artık taşın dışında da kullanılıyor.
///
/// **`color_tokens_test`in "yerel kopya" taramasına BİLİNÇLİ olarak
/// eklenmedi** (yalnızca tailwind parite testine): `lib/` altında bu değerde
/// 8 literal var ve hepsi `tile-pts` DEĞİL — beşi form placeholder'ı, web
/// oraya hiç renk yazmıyor (tarayıcı varsayılanı), port kendi yaklaşık
/// değerini seçmiş. Beyazın (`bg` ↔ `tile-bg`) dışlanmasıyla aynı gerekçe:
/// literalden hangi kavram olduğu anlaşılamıyor. Ayrım gerektiren bu
/// migrasyon ayrı bir denetim işi.
const kTilePts = Color(0xFF8A93A2);

/// Tahtanın hamle durumu renkleri — token DEĞİL, `Board.tsx`'te BİLİNÇLİ
/// olarak sabit yazılmış iki ayrı değer (`moveColor` ve sürükleme sırasındaki
/// kesikli çerçeve). Token yeşili/kırmızısıyla KARIŞTIRILMAMALI: bunlar
/// yalnızca tahta üstündeki geçerli/geçersiz göstergesi için.
///
/// Yalnızca üç yerde meşru: `board_widget.dart`'ın dış hattı + puan rozeti,
/// ve iki oyun ekranının sürükleme hedefi çerçevesi. Başka bir yerde
/// görürsen bu, token'la karıştırılmış bir sapmadır.
const kMoveValid = Color(0xFF1FA05C);
const kMoveInvalid = Color(0xFFE0483A);
