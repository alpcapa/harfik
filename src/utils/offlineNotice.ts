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
