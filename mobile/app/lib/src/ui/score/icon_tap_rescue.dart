// Oyun kartındaki KÜÇÜK ikonlara yapılan ıskalanan dokunuşu kurtarma.
//
// NEDEN VAR (27 Ağustos 2026, kullanıcı sordu: *"oyun kartlarında yer alan
// mesaj balonu ve hamleler ikonu tıklaması nasıl? Orada da sorun var mı?"*):
// evet, vardı — ve bunlar uygulamadaki EN KÜÇÜK hedeflerdi. Ölçüldü
// (390×844): kalp 15×13, mesaj balonu 18.5×13, hamle ikonu 19×13, yani
// ~240 px². 48×48'lik standardın (2304 px²) ONDA BİRİ.
//
// Kullanıcı bunu 12 Ağustos 2026'da bir kez bildirmişti: *"en az 4-5 kere
// dokunmam gerekti, tam basamazsan oyun detayları açılıp kapanıyor"*. O
// günkü düzeltme hedefi BÜYÜTMEDİ, yalnızca hamle ikonunu mesaj balonuyla
// eşitledi (121 → 247 px²) — çünkü satırın kendi yüksekliği 14 ve 44'lük
// bir kutu HER kartı büyütürdü (ölçüldü: kart 74 px; satır 44 olsaydı kart
// ~104'e çıkardı, %40 daha uzun bir liste).
//
// Yani bu, tahta hücresiyle aynı sınıf: hedef BÜYÜTÜLEMEZ. Projenin o
// duruma verdiği cevap `draftRescue` (bkz. `src/utils/draftRescue.ts` ve
// `docs/decisions/touch-ux-bugs.md`): ıskalamayı, ait olduğu hedefe
// YÖNLENDİR. Kartın kendi dokunuş yakalayıcısı zaten satırın tamamını
// kapsıyor; ıskalayan dokunuş oraya düşüyor ve bugün kartı açıp kapatıyor.
//
// ⚠ YALNIZCA DİKEY genişletme — bilinçli. Zayıf eksen dikey (13 px); yatayda
// ikonlar 18.5–19 px ve aralarında yalnızca 2 px var. Yatayda da
// genişletmek iki ikonun bölgelerini ÜST ÜSTE bindirirdi ve "hangisi"
// sorusu doğardı; `draftRescue`'nun oradaki cevabı "belirsizse hiçbir şey
// yapma"ydı. Burada o soruyu hiç doğurmamak daha iyi: her ikonun x aralığı
// ayrık kaldığından aday HER ZAMAN en fazla bir tanedir. Yatay ıskalamalar
// gerçekten sorun çıkarırsa ayrı bir iş olarak, ÖLÇÜYLE ele alınır.
import 'package:flutter/widgets.dart';

/// Dikeyde her yöne eklenen pay. 13 px'lik ikon böylece 41 px'lik bir
/// hedefe dönüşür (alan ~240 → ~760 px², 3,2 katı) ve kartın dışına
/// taşmaz — kart 74 px, satır kartın üst kenarından 9 px aşağıda.
const double kIconRescueSlopY = 14.0;

/// [point] (global) hangi ikona ait "ıskalama bölgesine" düşüyor?
///
/// Aday, x aralığı noktayı KAPSAYAN ve dikeyde [kIconRescueSlopY] kadar
/// genişletilmiş kutusu noktayı içeren ikondur. Kutular yatayda ayrık
/// olduğundan en fazla bir aday çıkar; hiçbiri çıkmazsa `null` döner ve
/// çağıran kendi olağan davranışını (kartı aç/kapat) sürdürür.
///
/// [rects] boş ya da hepsi `null` olabilir (ikonlar koşullu çiziliyor:
/// mesaj balonu yalnızca mesaj varsa, hamle ikonu yalnızca döküm varsa).
T? rescuedIconTarget<T>(
  Offset point,
  List<({Rect? rect, T target})> icons, {
  double slopY = kIconRescueSlopY,
}) {
  for (final icon in icons) {
    final r = icon.rect;
    if (r == null || r.isEmpty) continue;
    // Yatayda genişletme YOK (bkz. dosya başlığı).
    if (point.dx < r.left || point.dx > r.right) continue;
    if (point.dy < r.top - slopY || point.dy > r.bottom + slopY) continue;
    return icon.target;
  }
  return null;
}

/// Bir `GlobalKey` ile işaretlenmiş kutunun global dikdörtgeni; widget
/// henüz yerleşmemişse `null`.
Rect? globalRectOf(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final box = ctx.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
