// Tahta önizlemesini paylaşılabilir bir PNG'ye çevirip sistem paylaş
// sayfasını açar — web `captureNodeAsPng` (shareBoardImage.ts) +
// `handleShare` (GameHistoryModal.tsx) portu.
//
// Web DOM'u `html-to-image` ile yakalıyor (gradyan/gölge/SVG dış hatları
// elle canvas'a çizmek kırılgan olurdu); Flutter'da bunun yerleşik ve
// kayıpsız karşılığı `RepaintBoundary.toImage` — ekstra kütüphane yok,
// yakalanan şey ekranda görünenin ta kendisi.
//
// **Neden ayrı bir dosya ve enjekte edilebilir:** `share_plus` ve
// `path_provider` platform kanalı kullanıyor, widget testlerinde çalışmaz.
// `GameHistoryModal` paylaşımı `ShareBoardFn` olarak alıyor; testler sahte
// bir fonksiyon geçip AKIŞI (markShared → yakala → paylaş) doğruluyor,
// gerçek kanal cihazda doğrulanıyor.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Paylaşım metni — web `SHARE_MESSAGE` birebir. Bilerek üçüncü şahıs:
/// paylaşan kişi oyunun sahibi olmak zorunda değil (herkes gördüğü herhangi
/// bir oyunu paylaşabiliyor).
const String shareMessage = "Kelimeki'deki şu oyunu görmeni istedim.";

/// [png] null olabilir (yakalama başarısız) — o durumda yalnızca metin+link
/// paylaşılır; web'in dosyasız `navigator.share` yedeğiyle aynı.
typedef ShareBoardFn = Future<void> Function({
  required Uint8List? png,
  required String text,
  required String? url,
});

/// Görsel yakalama — testlerde enjekte edilebilir olması ŞART: `toImage`
/// gerçek asenkron iş yapıyor ve widget testlerinin sahte zamanında ASLA
/// tamamlanmıyor (paylaş akışı sessizce orada asılı kalırdı). Gerçek
/// uygulaması ayrıca `tester.runAsync` içinde tek başına test ediliyor.
typedef CaptureBoardFn = Future<Uint8List?> Function(GlobalKey boundaryKey);

/// Bir `RepaintBoundary`'yi PNG baytlarına çevirir. Hata durumunda null —
/// çağıran linksiz/görselsiz paylaşmaya devam eder (web'in aynı kararı).
Future<Uint8List?> captureBoundaryAsPng(GlobalKey boundaryKey,
    {double pixelRatio = 2}) async {
  try {
    final obj = boundaryKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (e) {
    debugPrint('[Kelimeki] tahta görseli yakalanamadı: $e');
    return null;
  }
}

/// Üretim uygulaması — sistem paylaş sayfasını açar.
Future<void> shareBoard({
  required Uint8List? png,
  required String text,
  required String? url,
}) async {
  // Web `${text}\n${url}` yedeğiyle aynı gövde: birçok hedef (SMS, not
  // uygulamaları) ayrı bir "url" alanı taşımadığından link metne katılıyor.
  final body = url == null ? text : '$text\n$url';
  try {
    if (png == null) {
      await SharePlus.instance.share(ShareParams(text: body));
      return;
    }
    // share_plus dosya yolu istiyor; geçici dizine yazıp paylaşıyoruz
    // (sistem paylaş sayfası kapanınca dosya orada kalır, işletim sistemi
    // geçici dizini kendi temizler).
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kelimeki.png');
    await file.writeAsBytes(png, flush: true);
    await SharePlus.instance.share(
      ShareParams(text: body, files: [XFile(file.path, mimeType: 'image/png')]),
    );
  } catch (e) {
    // Kullanıcının paylaş sayfasını iptal etmesi de buraya düşebilir —
    // web'de olduğu gibi sessizce geçiliyor, hata gösterilmiyor.
    debugPrint('[Kelimeki] paylaşım tamamlanmadı: $e');
  }
}
