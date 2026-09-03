// Tahta önizlemesini paylaşılabilir bir PNG'ye çevirip sistem paylaş
// sayfasını açar — web `captureNodeAsPng` (shareBoardImage.ts) +
// `handleShare` (GameHistoryModal.tsx) portu.
//
// Web DOM'u `html-to-image` ile yakalıyor (gradyan/gölge/SVG dış hatları
// elle canvas'a çizmek kırılgan olurdu); Flutter'da bunun yerleşik ve
// kayıpsız karşılığı `RepaintBoundary.toImage` — ekstra kütüphane yok,
// yakalanan şey ekranda görünenin ta kendisi.
//
// **Neden ayrı bir dosya ve enjekte edilebilir:** `share_plus` platform
// kanalı kullanıyor, widget testlerinde çalışmaz. `GameHistoryModal`
// paylaşımı `ShareBoardFn` olarak alıyor; testler sahte bir fonksiyon geçip
// AKIŞI (markShared → yakala → paylaş) doğruluyor, gerçek kanal cihazda
// doğrulanıyor.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show BuildContext, GlobalKey, MediaQuery;
import 'package:share_plus/share_plus.dart';

/// Paylaşım metni — web `SHARE_MESSAGE` birebir. Bilerek üçüncü şahıs:
/// paylaşan kişi oyunun sahibi olmak zorunda değil (herkes gördüğü herhangi
/// bir oyunu paylaşabiliyor).
const String shareMessage = "Kelimeki'deki şu oyunu görmeni istedim.";

/// [png] null olabilir (yakalama başarısız) — o durumda yalnızca metin+link
/// paylaşılır; web'in dosyasız `navigator.share` yedeğiyle aynı.
///
/// [origin] iPad ankrajı — bkz. [shareOriginFrom]. Bilerek ZORUNLU (nullable
/// ama adı verilmek zorunda): opsiyonel olsaydı yeni bir çağrı yeri onu
/// sessizce atlar ve paylaşım YALNIZCA iPad'de, yalnızca gerçek cihazda
/// ölürdü — derleyicinin yakalayabileceği bir şeyi çalışma anına bırakmak
/// olurdu.
typedef ShareBoardFn = Future<void> Function({
  required Uint8List? png,
  required String text,
  required String? url,
  required Rect? origin,
});

/// iPad'de paylaş sayfası bir POPOVER olarak açılıyor ve iOS bir ankraj
/// dikdörtgeni istiyor. share_plus'ın iOS eklentisi (`FPPSharePlusPlugin.m`)
/// bunu SERT bir koşul olarak uyguluyor: cihaz iPad ise ve origin boşsa ya da
/// kök view'ın koordinat uzayının dışındaysa paylaşmak yerine
/// `FlutterError` DÖNDÜRÜYOR — yani ankraj vermemek, iPad'de paylaşımı
/// tamamen ve SESSİZCE öldürüyor (Dart tarafında `PlatformException`, bizim
/// `catch`imiz onu yutuyor). iPhone ve Android'de parametre yok sayılıyor,
/// web'de zaten anlamsız.
///
/// Bu, web derlemesinde ASLA görünmez (orada share_plus'ın web eklentisi
/// `navigator.share`e gidiyor, iOS kanalına hiç uğramıyor) — yani cihaz
/// testine kadar gizli kalan, platforma özgü bir sınıf.
/// ⚠ **EKRAN BOYUTUNDA BİR ANKRAJ DA GEÇERSİZDİR — 2 Eylül 2026'da
/// ÖLÇÜLDÜ (Appetize, iPad Air / iOS 16.2).** İlk sürüm yalnızca BOŞ
/// dikdörtgene karşı korunuyordu; ekranın tamamını kaplayan bir ankraj
/// "boş değil" ve "kök view'ın içinde" olduğundan kontrolden geçiyordu, ama
/// iPad'de popover görünmüyor ve `SharePlus.share` çağrısı **hiç
/// tamamlanmıyordu** (fırlatmıyor — ASILI KALIYOR). Belirti çağrı yerine
/// göre değişiyordu ve ikisi de kullanıcı tarafından bildirildi:
///   • Setup footer "Paylaş"      → "hiç tepki vermiyor"
///   • Arkadaşlar "Davet et"      → buton `…` (meşgul) durumunda KİLİTLİ
/// Kanıt fırlatma olmadığıdır: `_handleInvite`in `finally`si `_inviteBusy`i
/// sıfırlıyor, buton yine de `…`ta kaldı → future dönmedi.
///
/// Üçüncü çağrı yeri (oyun geçmişi) AYNI GÜN ÇALIŞTI, çünkü ankrajını
/// tahtanın `RepaintBoundary`sinden alıyor — küçük ve gerçek bir kutu.
/// Aradaki tek fark buydu.
///
/// Bu yüzden artık iki eşik var: dikdörtgen boşsa YA DA ekranı İKİ EKSENDE
/// birden neredeyse tamamen kaplıyorsa yedeğe düşülür.
///
/// ⚠ **Ölçüt bilerek "büyük" değil "ekranın TAMAMI".** İlk yazdığım sürüm
/// alan oranına (>= %50) bakıyordu ve ÇALIŞAN yolu kırardı: oyun
/// geçmişindeki ankraj tahtanın `RepaintBoundary`si, telefon ekranında
/// alanın ~%46'sı — eşiğe teğet. Popover büyük bir kutuya de sorunsuz
/// bağlanıyor; kıran şey ankrajın kök view'ın kendisiyle ÖRTÜŞMESİ. Bu
/// yüzden koşul iki eksende birden aranıyor: geniş ama kısa (ya da dar ama
/// uzun) bir kutu geçerli ankraj olmaya devam ediyor.
const double _kFullScreenOriginRatio = 0.95;

Rect shareOriginFrom(BuildContext context) {
  final screen = Offset.zero & MediaQuery.sizeOf(context);
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    // Ekranla kesiştiriyoruz: iOS ankrajın kök view'ın İÇİNDE olmasını da
    // şart koşuyor, kaydırma yüzünden kısmen dışarı taşan bir kutu yine
    // hataya düşerdi.
    final rect = (box.localToGlobal(Offset.zero) & box.size).intersect(screen);
    final ekraniKapliyor = screen.width > 0 &&
        screen.height > 0 &&
        rect.width >= screen.width * _kFullScreenOriginRatio &&
        rect.height >= screen.height * _kFullScreenOriginRatio;
    if (rect.width > 0 && rect.height > 0 && !ekraniKapliyor) return rect;
  }
  // Yedek: ekranın ortasında minik bir kare — `CGRectIsEmpty` false olsun
  // ve kök view'ın içinde kalsın diye. Ekran boyutunda bir kutu yerine BUNU
  // vermek, popover'ı ekranın ortasında GÖRÜNÜR kılıyor (yukarıdaki ölçüm).
  return Rect.fromCenter(center: screen.center, width: 1, height: 1);
}

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
  required Rect? origin,
}) async {
  // Web `${text}\n${url}` yedeğiyle aynı gövde: birçok hedef (SMS, not
  // uygulamaları) ayrı bir "url" alanı taşımadığından link metne katılıyor.
  final body = url == null ? text : '$text\n$url';

  // Web `handleShare`in YEDEK ZİNCİRİ birebir: önce dosyalı paylaşım
  // (`navigator.canShare({files})` dalı), OLMAZSA dosyasız metin+link
  // (`navigator.share({title,text,url})` dalı). Portun ilk sürümünde bu
  // ikinci basamak YOKTU: dosya yazımı ya da dosyalı paylaşım herhangi bir
  // sebeple patlarsa (geçici dizin yok/dolu, o platformda path_provider
  // yok…) tek bir `catch` her şeyi yutuyor ve kullanıcıya HİÇBİR ŞEY
  // olmuyordu — 9 Ağustos 2026'da cihaz testinde "Paylaş çalışmıyor, tepki
  // yok" diye bildirildi.
  //
  // NOT: kullanıcının paylaş sayfasını İPTAL etmesi bu dala DÜŞMEZ —
  // share_plus iptalde fırlatmaz, `ShareResult.dismissed` döner; yani iptal
  // ikinci bir paylaş sayfası açtırmaz.
  if (png != null) {
    try {
      // Baytları DOSYAYA YAZMIYORUZ, `XFile.fromData` ile bellekte veriyoruz —
      // 13 Ağustos 2026'da cihaz testinde bulunan hatanın düzeltmesi: portun
      // ilk sürümü `path_provider`'ın `getTemporaryDirectory()`si + `dart:io`
      // `File`ıyla geçici bir dosya yazıyordu, ikisi de FLUTTER WEB'DE
      // ÇALIŞMIYOR → dosyalı dal her seferinde patlayıp aşağıdaki metin+link
      // yedeğine düşüyordu, WhatsApp da linkten sitenin GENEL og:image
      // kartını üretiyordu; kullanıcı "app tahta yerine jenerik Kelimeki
      // görseli gönderiyor, web gerçek tahtayı gönderiyor" diye bildirdi.
      //
      // GERÇEK CanvasKit derlemesinde ÖLÇÜLDÜ (tahmin değil — bkz. Parça 84):
      //   getTemporaryDirectory()      → FIRLATIYOR
      //   File(...).writeAsBytes()     → "Unsupported operation: _Namespace"
      //   XFile.fromData(...)          → OK (11 bayt, mime/name korunuyor)
      //   share_plus web prepareData   → OK, ShareData'da files DOLU
      //
      // `XFile.fromData` HER İKİ platformda da doğru: web'de share_plus
      // baytları `readAsBytes()` ile alıp `navigator.share({files})`e veriyor
      // (web `handleShare`in birebir aynı dalı); native'de path boş kaldığından
      // share_plus'ın kendisi geçici dizine yazıyor
      // (`method_channel_share.dart`, `_getFile`) — yani dosya yazma işi
      // kaybolmadı, yalnızca bizden kütüphaneye taşındı ve bu kod yolu
      // `path_provider`a hiç dokunmuyor.
      //
      // `fileNameOverrides` ŞART: `cross_file`'ın io uygulaması `name`
      // parametresini YOK SAYIYOR (paket belgesinde yazılı), o olmadan
      // native'de dosya adı boş/rastgele kalırdı. Web'de `name` zaten
      // kullanılıyor, override de aynı adı verdiğinden iki taraf eşit.
      //
      // `downloadFallbackEnabled: false` YALNIZCA web'de anlamlı (native'de
      // parametre yok sayılıyor) ve web `handleShare` zinciriyle hizalamak
      // için: varsayılan `true` iken `navigator.canShare({files})` false
      // dönerse share_plus paylaşmak yerine PNG'yi sessizce İNDİRİYOR —
      // web'in kendi yedeği ise metin+link paylaşımı. `false` ile o durumda
      // fırlıyor ve aşağıdaki yedeğe düşüyoruz.
      await SharePlus.instance.share(
        ShareParams(
          text: body,
          files: [
            XFile.fromData(png, mimeType: 'image/png', name: 'kelimeki.png')
          ],
          fileNameOverrides: const ['kelimeki.png'],
          downloadFallbackEnabled: false,
          sharePositionOrigin: origin,
        ),
      );
      return;
    } catch (e) {
      debugPrint('[Kelimeki] görselli paylaşım olmadı, metne düşülüyor: $e');
    }
  }

  try {
    await SharePlus.instance
        .share(ShareParams(text: body, sharePositionOrigin: origin));
  } catch (e) {
    debugPrint('[Kelimeki] paylaşım tamamlanmadı: $e');
  }
}
