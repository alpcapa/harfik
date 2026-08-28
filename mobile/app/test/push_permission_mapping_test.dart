// `izinDurumu` — eklentinin `AuthorizationStatus`'ü ile bizim
// `PushPermission`ımız arasındaki eşleme.
//
// Derleyici KÜMENİN TAMAMINI zorluyor (switch exhaustive) ama ANLAMI
// zorlamıyor: `provisional`ı `denied` saymak da derlenirdi. Aşağıdaki iki
// iddia tam olarak o anlam seçimlerini kilitliyor.
//
// ⚠ Bu dosya bir kez gerçek bir hatayı yakaladı: `deniedPermanently` ilk
// yazımda hiç ele alınmamıştı, çünkü "firebase_messaging kalıcı reddi
// bildirmiyor" varsayılmıştı. `dart analyze` non_exhaustive_switch ile
// düşürdü — varsayım yanlıştı ve o yanlışa dayanan yerel bir sayaç da
// silindi (bkz. `flags_store.dart` sonundaki not).
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/push_gateways.dart';
import 'package:kelimeki/src/data/push_repo.dart';

void main() {
  test('provisional VERİLMİŞ sayılır', () {
    // iOS'un sessiz teslim modu: bildirim GERÇEKTEN gidiyor, yalnızca sessiz
    // kutuda. `denied` saymak, izni olan kullanıcıya tekrar tekrar sormak
    // olurdu.
    expect(izinDurumu(AuthorizationStatus.provisional), PushPermission.granted);
    expect(izinDurumu(AuthorizationStatus.authorized), PushPermission.granted);
  });

  test('denied ile deniedPermanently AYRI kalır', () {
    // Bu ayrım olmadan kalıcı reddedilmiş kullanıcıya "Bildirimleri Aç"
    // butonu gösterilir, basar ve HİÇBİR ŞEY olmaz — gözünde bozuk bir buton.
    expect(izinDurumu(AuthorizationStatus.denied), PushPermission.denied);
    expect(izinDurumu(AuthorizationStatus.deniedPermanently),
        PushPermission.permanentlyDenied);
  });

  test('notDetermined kendi durumunu korur', () {
    expect(izinDurumu(AuthorizationStatus.notDetermined),
        PushPermission.notDetermined);
  });
}
