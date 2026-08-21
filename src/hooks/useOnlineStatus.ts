import { useEffect, useState } from 'react';

/**
 * Tarayıcının ağ bağlantı durumunu izler.
 *
 * `online`/`offline` olaylarının YANINDA öne dönüşte (`visibilitychange` +
 * `focus`) `navigator.onLine` YENİDEN OKUNUR — 14 Ağustos 2026'da kullanıcı
 * cihazda (ana ekrana eklenmiş PWA, iPad) tahtanın altındaki "Çevrimdışı"
 * uyarısını göremediğini bildirdi ve kök sebep buydu: uçak modunu açmak için
 * Kontrol Merkezi'ne çıkıldığında sayfa askıya alınıyor, `offline` olayı JS'e
 * hiç ulaşmıyor ve durum sonsuza dek bayat `true` kalıyordu. Olay tabanlı
 * durum bu projede iki kez aynı şekilde kırıldı (sohbet Realtime'ı ve bulut
 * senkronu) — çare her seferinde aynı: **kaçırılan olay kalıcı kayıptır,
 * öne dönüşte gerçeği yeniden oku.**
 *
 * Tek bir `sync` kullanılıyor (ayrı goOnline/goOffline yerine): olayın TÜRÜNE
 * değil `navigator.onLine`'ın O ANKİ değerine bakmak, hangi yoldan
 * tetiklenirse tetiklensin doğru sonucu verir.
 *
 * **ASİMETRİK (21 Ağustos 2026):** `false`'a geçiş `OFFLINE_CONFIRM_MS` kadar
 * DOĞRULANIR, `true`'ya dönüş ANINDA uygulanır. Sebep: WiFi ↔ hücresel
 * geçişinde hiçbir arayüzün ayakta olmadığı birkaç yüz milisaniyelik bir
 * pencere var ve `navigator.onLine` o anda gerçekten `false` — yalan değil,
 * ama ANLIK. Debounce olmadan Canlı sekmesi o anda üç alt sekmeyi birden
 * "İnternet bağlantısı yok"a çevirip geri dönüyordu; kullanıcı internetinin
 * çalıştığını bildiğinden bu, yanlış alarm olarak okunuyor. Yanlış alarmın
 * bedeli ("oyunlarım kayboldu" korkusu) gecikmeli alarmın bedelinden
 * (gerçekten uçak moduna geçen biri 1.5 sn geç öğrenir) çok daha büyük;
 * iyileşmeyi geciktirmenin ise hiçbir faydası yok, o yüzden `true` anında.
 *
 * İlk değer BİLEREK debounce edilmiyor: spesifikasyonda `false` "hiçbir ağa
 * bağlı değil" demek, yani soğuk açılışta doğru cevap odur — debounce
 * yalnızca GEÇİŞLERİ yumuşatıyor.
 */
const OFFLINE_CONFIRM_MS = 1500;

export function useOnlineStatus(): boolean {
  const [online, setOnline] = useState(() => navigator.onLine);

  useEffect(() => {
    let timer: number | null = null;
    const clearTimer = () => {
      if (timer != null) {
        window.clearTimeout(timer);
        timer = null;
      }
    };
    const sync = () => {
      if (navigator.onLine) {
        clearTimer();
        setOnline(true);
        return;
      }
      // Zaten bir doğrulama bekliyorsa yenisini kurma — art arda gelen
      // offline/visibilitychange olayları pencereyi sürekli ötelemesin.
      if (timer != null) return;
      timer = window.setTimeout(() => {
        timer = null;
        setOnline(navigator.onLine);
      }, OFFLINE_CONFIRM_MS);
    };
    window.addEventListener('online', sync);
    window.addEventListener('offline', sync);
    document.addEventListener('visibilitychange', sync);
    window.addEventListener('focus', sync);
    return () => {
      clearTimer();
      window.removeEventListener('online', sync);
      window.removeEventListener('offline', sync);
      document.removeEventListener('visibilitychange', sync);
      window.removeEventListener('focus', sync);
    };
  }, []);

  return online;
}
