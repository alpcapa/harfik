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

/// Panelin geri butonu — bilerek HEDEF ADI TAŞIMIYOR ("Canlı Listesi"
/// değil): çevrimdışıyken o listeye dönünce Canlı sekmeleri zaten "bağlantı
/// yok" diyor (kullanıcı: "geri gitmek için yazan Canlı listesi çok saçma").
const kOfflineBackLabel = 'Geri Dön';

/// Canlı sekmelerinin (Devam Edenler/Oyun Davetleri/Son Oynananlar) hâli.
const kOfflineNoConnection = 'İnternet bağlantısı yok';

/// Yapay Zeka sekmesi çevrimdışıyken FARKLI konuşur: orada gerçekten
/// oynanabilir bir şey var, o yüzden kullanıcı bir çıkmaza değil bir
/// seçeneğe yönlendiriliyor. [kOfflineAiCta] ayrı bir sabit çünkü LİNK
/// olarak render ediliyor — dokunuşu "+ Yeni Yapay Zeka Oyunu" ile aynı.
///
/// Yalnızca gösterilecek kayıt YOKKEN çıkar: devam eden YZ oyunları
/// çevrimdışı da listelenip oynanabiliyor, o listeyi bir uyarıyla
/// değiştirmek gerçek bir yeteneği gizlerdi.
const kOfflineAiSuggestion =
    'İnternet bağlantısı yok ama sorun değil, yapay zeka ile çevrimdışı da oynayabilirsin.';
const kOfflineAiCta = 'Hemen oyun aç.';

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
  // `toLowerCase` burada Türkçe değişmezini İHLAL ETMİYOR (bkz. tarama
  // listesi): karşılaştırılan şey kullanıcıya gösterilecek Türkçe bir metin
  // değil, ASCII kalıplara bakılan bir istisna dizesi. Türkçe bir sunucu
  // mesajı ("Sıra sende değil.") bu kalıpların hiçbirine denk gelmez.
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

/// Kelime anlamı penceresi — sözlük AÇILAMADIĞINDA (kelime bulunamadı'dan
/// farklı). Flutter WEB derlemesinde sözlük asset'i HTTP ile çekildiğinden
/// uçak modunda ulaşılamıyor; native'de asset pakette olduğu için bu dal
/// pratikte ulaşılamaz.
const kOfflineMeaningNotice =
    'Kelime anlamları için internet bağlantısı gerekiyor.';
