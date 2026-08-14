// Canlı oyun çevrimdışıyken ne denir — TEK kaynak.
//
// NEDEN (14 Ağustos 2026, kullanıcı cihaz testinde bildirdi): Canlı oyun
// YAPISI GEREĞİ çevrimiçi — tahta/raf/torba sunucuda otoriter
// (`online_game_states`/`online_game_secrets`), offline dayanıklılık yalnızca
// yerel/YZ oyunları için var (localStorage + `cloudSaveMirror`). Ama kullanıcı
// bunu uçak modunda İKİ kez sessizce öğreniyordu: (1) listeden bir Canlı
// oyuna dokununca ekran beyaz "Yükleniyor…"da asılı kalıyordu (ilk yükleme
// başarısız olunca ekran "korunuyor", oysa korunacak bir şey yok), (2)
// hamle gönderince hiçbir şey olmuyordu. Kullanıcının isteği: "kişi bunları
// yaptığında 'Şu anda çevrimdışısınız. Canlı oyun için internete bağlı
// olmanız gerekir. Dilerseniz yapay zekayla oynayabilirsiniz' tarzında bir
// uyarı gerekir. (Hem web hem de app için)".
//
// **Metin İKİ PLATFORMDA AYNI OLMAK ZORUNDA** — Flutter portundaki eşi
// `mobile/app/lib/src/util/offline_notice.dart`; biri değişirse öteki de.

/** Oyun ekranı hiç açılamadığında gösterilen panelin başlığı. */
export const OFFLINE_LIVE_TITLE = 'Canlı oyun için internet gerekiyor';

/**
 * Panelin gövdesi. Bilerek "sunucuya ulaşılamıyor" diyor, "çevrimdışısın"
 * DEĞİL: aynı metin hem uçak modunda hem (nadir de olsa) sunucu erişilemez
 * olduğunda DOĞRU olmak zorunda — ikisini ayırt etmek için Flutter tarafında
 * bir bağlantı API'si yok (bkz. `mobile/CLAUDE.md`, "Sonraya Bırakılan
 * İşler"), ve iki platformun metninin ayrışması bu projede yasak.
 */
export const OFFLINE_LIVE_BODY =
  'Şu anda sunucuya ulaşılamıyor. Bağlantını kontrol edip tekrar dene. ' +
  'Dilersen Yapay Zeka’ya karşı çevrimdışı da oynayabilirsin.';

/** Mesaj satırına sığacak kısa hâli (tek satır, 11px mono). */
export const OFFLINE_MOVE_NOTICE =
  'Bağlantı yok — Canlı oyun için internet gerekiyor.';

/**
 * Panelin geri butonu. Bilerek HEDEF ADI TAŞIMIYOR ("Canlı Listesi" değil):
 * çevrimdışıyken o listeye dönünce Canlı sekmeleri zaten "bağlantı yok"
 * diyor, yani kullanıcıya var olmayan bir yere gidiyormuş izlenimi vermek
 * yanlıştı (14 Ağustos 2026, kullanıcı: "geri gitmek için yazan Canlı
 * listesi çok saçma").
 */
export const OFFLINE_BACK_LABEL = 'Geri Dön';

/** Canlı sekmelerinin (Devam Edenler/Oyun Davetleri/Son Oynananlar) hâli. */
export const OFFLINE_NO_CONNECTION = 'İnternet bağlantısı yok';

/**
 * Yapay Zeka sekmesi çevrimdışıyken FARKLI konuşur: orada gerçekten
 * oynanabilir bir şey var (yerel oyun tamamen çevrimdışı çalışır), o yüzden
 * kullanıcı bir çıkmaza değil bir seçeneğe yönlendiriliyor. [OFFLINE_AI_CTA]
 * ayrı bir sabit çünkü LİNK olarak render ediliyor — dokunuşu "+ Yeni Yapay
 * Zeka Oyunu" butonuyla aynı şeyi yapar.
 *
 * Yalnızca gösterilecek bir kayıt YOKKEN çıkar: devam eden YZ oyunları
 * çevrimdışıyken de listelenip oynanabiliyor (bkz. `cloudSaveMirror`), o
 * listeyi bir uyarıyla değiştirmek gerçek bir yeteneği gizlerdi.
 */
export const OFFLINE_AI_SUGGESTION =
  'İnternet bağlantısı yok ama sorun değil, yapay zeka ile çevrimdışı da oynayabilirsin.';
export const OFFLINE_AI_CTA = 'Hemen oyun aç.';

/**
 * Hata "sunucuya hiç ulaşamadık" mı, yoksa sunucunun kendi reddi mi?
 *
 * Ayrım şart: `submit_move`'un iş kuralı hataları ("Sıra sende değil.",
 * "Yalnızca arkadaşlarını davet edebilirsin.") OLDUĞU GİBİ gösterilmeli;
 * yalnızca ağ katmanı hataları yukarıdaki metne çevrilir. Eşleşmeyen bir
 * hata BİLEREK ham hâliyle geçer — bilinmeyen bir hatayı "çevrimdışısın"
 * diye maskelemek hata ayıklamayı imkânsız kılardı (aynı ilke:
 * `friendlyAuthMessage`, src/lib/api.ts).
 *
 * `navigator.onLine === false` kesin bir sinyal; metin eşlemesi ise sunucuya
 * ulaşılamayan ama tarayıcının "online" saydığı durumlar için.
 * **"load failed" Safari'nin `fetch` hata metnidir** — kullanıcı iPad
 * Safari'de test ettiğinden bu kalıbın listede olması şart.
 */
export function isNetworkError(err: unknown): boolean {
  if (typeof navigator !== 'undefined' && navigator.onLine === false) return true;
  const message = err instanceof Error ? err.message : String(err ?? '');
  return /failed to fetch|load failed|networkerror|network request failed|fetch failed/i.test(
    message,
  );
}

/**
 * Kelime anlamı penceresi — YALNIZCA WEB. Flutter portuna TAŞINMAZ (ve
 * `offline_notice.dart`'ta karşılığı YOK): orada anlamlar uygulama
 * paketindeki SQLite asset'inde, çevrimdışı da çalışıyor. Web'de ise
 * `meanings.json` 6.3 MB ve precache'e bilerek alınmıyor — herkese 6 MB'lık
 * bir ön indirme yüklemek bir oyun için orantısız (14 Ağustos 2026).
 */
export const OFFLINE_MEANING_NOTICE =
  'Kelime anlamları için internet bağlantısı gerekiyor.';
