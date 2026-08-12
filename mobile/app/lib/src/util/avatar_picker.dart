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
};

/// Üretim uygulaması — galeriden bir görsel seçtirir. `XFile.mimeType`
/// platforma göre boş kalabildiğinden (bkz. `cross_file` kaynağı) dosya
/// adının uzantısına düşülüyor; ikisi de tanınmazsa `image/*` doğrulamasını
/// (AuthService.uploadAvatar) geçemeyecek jenerik bir tip döner — sessizce
/// yanlış bir MIME uydurmuyoruz.
Future<PickedImage?> pickAvatarImage() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : '';
  final mimeType = file.mimeType ?? _mimeByExt[ext] ?? 'application/octet-stream';
  return PickedImage(bytes: bytes, mimeType: mimeType);
}
