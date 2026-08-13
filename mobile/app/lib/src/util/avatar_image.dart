// Avatar görselini YÜKLEMEDEN ÖNCE küçültme.
//
// NEDEN (13 Ağustos 2026, kullanıcı isteği): eski 2 MB'lık giriş sınırı
// gerçek hayatta çok dardı — galeriden seçilen tipik fotoğraf iPhone HEIC'te
// 1.5-3 MB, iPhone JPEG'de 2-4 MB, Android 50-200MP'de 3-12 MB. Kullanıcı
// "2'nin altında resim bulamadım" dedi ve haklıydı.
//
// Sınırı yükseltmek TEK BAŞINA yanlış çözüm olurdu: 10 MB'lık bir fotoğrafı,
// hiçbir zaman 96 px'den büyük gösterilmeyen bir avatar için depolamak ve her
// açılışta indirmek israf. Bunun yerine giriş sınırı 10 MB'a çıkarılıyor ama
// SAKLANAN her zaman küçültülmüş hâli oluyor.
//
// **Bellek tuzağı — "önce çöz, sonra küçült" YANLIŞ:** 48MP'lik bir görselin
// ham RGBA'sı ~190 MB. `instantiateImageCodec`'in `targetWidth`'i çözmeyi
// ZATEN hedef boyutta yapıyor (Skia ölçekleyerek çözüyor), yani tepe bellek
// küçük kalıyor. Bu yüzden ölçekleme kodek seviyesinde yapılıyor, çözülmüş
// bir görseli sonradan `Canvas`'a yeniden çizerek değil.
//
// **İKİ KATMAN, çünkü `image_picker` her yerde aynı davranmıyor:**
//   * Native (iOS/Android — ÜRÜN): `pickImage(maxWidth/maxHeight/imageQuality)`
//     yeniden boyutlandırmayı NATIVE yapıp küçük bir JPEG döndürüyor. Bu yol
//     hem en ucuzu hem de çıktısı JPEG (birkaç on KB).
//   * Flutter web (GitHub Pages TEST ortamı): aynı parametreler
//     **sessizce yok sayılıyor** — `image_picker_for_web` kaynağında birebir
//     yazılı ("the `maxWidth`, `maxHeight` and `imageQuality` arguments are
//     not supported on the web ... silently ignored"). Yani orada ham dosya
//     geliyor ve bu dosyanın küçültülmesi bize kalıyor.
// Aşağıdaki `shrinkAvatarIfNeeded` ikinci katman: yalnızca GEREKTİĞİNDE
// (bayt bütçesi aşıldığında) devreye giriyor. Native'de picker zaten
// küçülttüğü için hiç çalışmıyor — çalışsaydı küçücük bir JPEG'i PNG'ye
// çevirip BÜYÜTÜRDÜ (`dart:ui` yalnızca PNG/rawRgba yazabiliyor).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'avatar_picker.dart';

/// Küçültülmüş avatarın azami kenar uzunluğu. Avatar uygulamada en fazla
/// 36-64 px gösteriliyor; DPR 3'te bile ~192 px, yani 512 bol bir pay.
const int kAvatarMaxEdge = 512;

/// Bu bayttan küçük gelen görsel OLDUĞU GİBİ bırakılır. Native picker'ın
/// ürettiği JPEG'ler bunun çok altında kalır ve yeniden kodlanmaları (PNG'ye)
/// onları büyütürdü.
const int kAvatarShrinkThreshold = 400 * 1024;

/// Kodek çağrısı testlerde sahtelenebilsin diye enjekte edilebilir —
/// `dart:ui` kodeki `flutter test` ortamında gerçek görsel baytları istiyor.
typedef DecodeImageFn = Future<ui.Image> Function(Uint8List bytes, int maxEdge);

Future<ui.Image> _decodeAtMostWide(Uint8List bytes, int maxEdge) async {
  // YALNIZCA targetWidth veriliyor — en/boy oranı korunuyor. Kare kırpma
  // BİLİNÇLİ olarak yapılmıyor: avatar her iki platformda da dairesel bir
  // `cover` kırpmasıyla gösteriliyor (web `object-cover`, port `BoxFit.cover`),
  // yani kırpma zaten görüntüleme anında oluyor — web'in `uploadAvatar`'ı da
  // hiç kırpmıyor.
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxEdge);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// `AccountSettingsModal`'ın test injection'ı için imza.
typedef ShrinkAvatarFn = Future<PickedImage> Function(PickedImage picked);

/// Gerekiyorsa küçültür; gerekmiyorsa girdiyi AYNEN döner.
///
/// Çözülemeyen/bozuk bir görselde de girdiyi aynen döner — küçültme bir
/// iyileştirme, yükleme yolunu kırmamalı; gerçek MIME/boyut doğrulaması
/// zaten `AuthService.uploadAvatar`'da.
Future<PickedImage> shrinkAvatarIfNeeded(
  PickedImage picked, {
  int maxEdge = kAvatarMaxEdge,
  int threshold = kAvatarShrinkThreshold,
  DecodeImageFn decode = _decodeAtMostWide,
}) async {
  if (picked.bytes.length <= threshold) return picked;
  try {
    final image = await decode(picked.bytes, maxEdge);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return picked;
    final out = data.buffer.asUint8List();
    // Yeniden kodlama beklenmedik şekilde BÜYÜTTÜYSE (ör. zaten iyi
    // sıkıştırılmış küçük bir JPEG) orijinali koru.
    if (out.length >= picked.bytes.length) return picked;
    return PickedImage(bytes: out, mimeType: 'image/png');
  } catch (_) {
    return picked;
  }
}
