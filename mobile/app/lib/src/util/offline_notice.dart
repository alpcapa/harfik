// Canlı oyun çevrimdışıyken ne denir — web `src/utils/offlineNotice.ts` portu.
//
// NEDEN (14 Ağustos 2026, kullanıcı cihaz testinde bildirdi): Canlı oyun
// YAPISI GEREĞİ çevrimiçi — tahta/raf/torba sunucuda otoriter
// (`online_game_states`/`online_game_secrets`); offline dayanıklılık yalnızca
// yerel/YZ oyunları için var. Ama kullanıcı bunu uçak modunda İKİ kez
// sessizce öğreniyordu: (1) listeden bir Canlı oyuna dokununca ekran
// "Yükleniyor…"da asılı kalıyordu (ilk yükleme başarısız olunca ekran
// "korunuyor", oysa korunacak bir şey yok), (2) hamle gönderince hiçbir şey
// olmuyordu. Kullanıcının isteği: "Şu anda çevrimdışısınız. Canlı oyun için
// internete bağlı olmanız gerekir. Dilerseniz yapay zekayla oynayabilirsiniz"
// tarzında bir uyarı — hem web hem app için.
//
// **METİNLER İKİ PLATFORMDA AYNI OLMAK ZORUNDA** — biri değişirse öteki de.
// (`test/offline_notice_test.dart` bunu web dosyasını okuyarak zorluyor.)

/// Oyun ekranı hiç açılamadığında gösterilen panelin başlığı.
const kOfflineLiveTitle = 'Canlı oyun için internet gerekiyor';

/// Panelin gövdesi. Bilerek "sunucuya ulaşılamıyor" diyor, "çevrimdışısın"
/// DEĞİL: aynı metin hem uçak modunda hem (nadir de olsa) sunucu erişilemez
/// olduğunda DOĞRU olmak zorunda. Gerçek bir bağlantı göstergesi
/// (`useOnlineStatus` portu) henüz yok — bkz. "Sonraya Bırakılan İşler".
const kOfflineLiveBody =
    'Şu anda sunucuya ulaşılamıyor. Bağlantını kontrol edip tekrar dene. '
    'Dilersen Yapay Zeka’ya karşı çevrimdışı da oynayabilirsin.';

/// Mesaj satırına sığacak kısa hâli.
const kOfflineMoveNotice = 'Bağlantı yok — Canlı oyun için internet gerekiyor.';

/// Hata "sunucuya hiç ulaşamadık" mı, yoksa sunucunun kendi reddi mi?
///
/// Ayrım şart: `submit_move`'un iş kuralı hataları ("Sıra sende değil.",
/// "Yalnızca arkadaşlarını davet edebilirsin.") OLDUĞU GİBİ gösterilmeli;
/// yalnızca ağ katmanı hataları [kOfflineMoveNotice]'a çevrilir. Eşleşmeyen
/// bir hata BİLEREK ham hâliyle geçer — bilinmeyen bir hatayı "bağlantı yok"
/// diye maskelemek hata ayıklamayı imkânsız kılardı.
///
/// `dart:io` BİLEREK import EDİLMİYOR (web derlemesini kırar) — tip yerine
/// metin eşlemesi yapılıyor. Kalıplar: `SocketException` (native),
/// `ClientException`/`Failed to fetch` (package:http + tarayıcı),
/// `Load failed` (**Safari'nin fetch hata metni** — port iPad Safari'de
/// test edildiğinden bu şart).
bool isNetworkError(Object? e) {
  final s = e.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('failed host lookup') ||
      s.contains('failed to fetch') ||
      s.contains('load failed') ||
      s.contains('network is unreachable') ||
      s.contains('connection closed') ||
      s.contains('connection refused') ||
      s.contains('timeoutexception');
}
