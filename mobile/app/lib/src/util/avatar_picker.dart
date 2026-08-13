// Profil fotoğrafı seçimi — web `<input type="file" accept="image/*">`'ın
// native karşılığı. Yalnızca GALERİDEN seçim (`ImageSource.gallery`) —
// kamerayla çekim BİLİNÇLİ kapsam dışı: web'in dosya seçicisi de yalnızca
// mevcut bir dosya seçtiriyor, ek bir kamera izni istemeden en yakın
// eşdeğer bu.
//
// **Neden ayrı bir dosya ve enjekte edilebilir:** `image_picker` platform
// kanalı kullanıyor, widget testlerinde çalışmaz — `share_board.dart`'taki
// `ShareBoardFn`/`CaptureBoardFn` deseniyle AYNI gerekçe. `AccountSettingsModal`
// seçimi `PickAvatarFn` olarak alıyor; testler sahte bir fonksiyon geçip
// AKIŞI (seç → yükle → profili tazele) doğruluyor, gerçek galeri seçici
// cihazda doğrulanıyor.
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedImage {
  final Uint8List bytes;
  final String mimeType;
  const PickedImage({required this.bytes, required this.mimeType});
}

/// Kullanıcı seçimi iptal ederse null.
typedef PickAvatarFn = Future<PickedImage?> Function();

const Map<String, String> _mimeByExt = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'gif': 'image/gif',
  // HEIC/HEIF — iPhone'un varsayılan formatı. Uzantı yolu yalnızca bir
  // yedek: asıl karar `sniffImageMime` ile baytlardan veriliyor (aşağı bkz.).
  'heic': 'image/heic',
  'heif': 'image/heif',
  'bmp': 'image/bmp',
};

bool _startsWith(Uint8List b, List<int> sig, [int offset = 0]) {
  if (b.length < offset + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[offset + i] != sig[i]) return false;
  }
  return true;
}

/// Görselin GERÇEK türünü baytlarından okur; tanınmazsa null.
///
/// **Neden uzantıdan/`XFile.mimeType`'tan ÖNCE geliyor — 13 Ağustos 2026'da
/// ÖLÇÜLEREK bulundu (bkz. Parça 87):** `image_picker`'ın Android uygulaması
/// `maxWidth/maxHeight/imageQuality` verildiğinde görseli yeniden kodluyor
/// (JPEG) ama çıktıyı `scaled_<orijinal ad>` olarak yazıyor — yani **uzantı
/// KORUNUYOR** (`ImageResizer.java`, `createImageOnExternalDirectory`).
/// HEIC seçen bir Android kullanıcısında dosya `.heic` uzantılı ama içi
/// JPEG oluyor; `XFile.mimeType` de o platformda null. Uzantıya bakan eski
/// kod bu yüzden `application/octet-stream` üretip `uploadAvatar`'ın
/// `image/*` kontrolüne takılıyordu — geçerli bir JPEG reddediliyordu.
/// Baytlar ise ASLA yalan söylemez ve sunucuya giden şey de zaten onlar.
///
/// iOS'ta sorun yok (çıktı her zaman `.jpg`), Flutter web'de de baytlar
/// gerçekten orijinal formatta — yani koklama üç platformda da doğru cevabı
/// veriyor, üçü için ayrı dal gerekmiyor.
String? sniffImageMime(Uint8List b) {
  if (_startsWith(b, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (_startsWith(b, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (_startsWith(b, [0x47, 0x49, 0x46, 0x38])) return 'image/gif'; // GIF8
  if (_startsWith(b, [0x52, 0x49, 0x46, 0x46]) && // RIFF
      _startsWith(b, [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  if (_startsWith(b, [0x42, 0x4D])) return 'image/bmp';
  // ISO-BMFF: 4-8 'ftyp', 8-12 marka. HEIC ailesinin ilk baytı 0x00
  // olduğundan hiçbir düz imzayla yakalanamaz, markaya bakmak şart.
  if (_startsWith(b, [0x66, 0x74, 0x79, 0x70], 4) && b.length >= 12) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    switch (brand) {
      case 'heic':
      case 'heix':
      case 'hevc':
      case 'hevx':
        return 'image/heic';
      case 'mif1':
      case 'msf1':
      case 'heim':
      case 'heis':
      case 'hevm':
      case 'hevs':
        return 'image/heif';
    }
  }
  return null;
}

/// Seçilen dosyanın MIME tipini üç kaynaktan ÖNCELİK SIRASIYLA çözer:
/// baytlar → platformun bildirdiği tip → dosya uzantısı.
///
/// Ayrı ve saf bir fonksiyon, çünkü asıl sözleşme bu SIRA ve `pickAvatarImage`
/// platform kanalına bağlı olduğundan test edilemiyor (Parça 86'nın dersi:
/// bir sözleşmeyi enjekte edilebilir sınırın ÜSTÜNDE test etmek, o sınırın
/// ALTINDAKİ iletimi kanıtlamaz).
///
/// Üçü de tutmazsa `image/*` doğrulamasını (`AuthService.uploadAvatar`)
/// geçemeyecek jenerik bir tip döner — sessizce yanlış bir MIME uydurmuyoruz.
String resolveAvatarMime({
  required Uint8List bytes,
  String? declaredMime,
  String path = '',
}) {
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : '';
  return sniffImageMime(bytes) ??
      declaredMime ??
      _mimeByExt[ext] ??
      'application/octet-stream';
}

/// Üretim uygulaması — galeriden bir görsel seçtirir.
Future<PickedImage?> pickAvatarImage() async {
  final picker = ImagePicker();
  // `maxWidth`/`maxHeight`/`imageQuality` NATIVE'de yeniden boyutlandırmayı
  // platforma yaptırır (ucuz, çıktı JPEG) — 13 Ağustos 2026'da eklendi,
  // gerekçe `avatar_image.dart`'ın başlığında. Flutter WEB'de bu üç parametre
  // sessizce yok sayılıyor (image_picker_for_web kaynağında yazılı), o yüzden
  // ikinci katman olarak `shrinkAvatarIfNeeded` var.
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  return PickedImage(
    bytes: bytes,
    mimeType: resolveAvatarMime(
      bytes: bytes,
      declaredMime: file.mimeType,
      path: file.path,
    ),
  );
}
