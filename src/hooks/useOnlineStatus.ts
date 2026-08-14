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
 */
export function useOnlineStatus(): boolean {
  const [online, setOnline] = useState(() => navigator.onLine);

  useEffect(() => {
    const sync = () => setOnline(navigator.onLine);
    window.addEventListener('online', sync);
    window.addEventListener('offline', sync);
    document.addEventListener('visibilitychange', sync);
    window.addEventListener('focus', sync);
    return () => {
      window.removeEventListener('online', sync);
      window.removeEventListener('offline', sync);
      document.removeEventListener('visibilitychange', sync);
      window.removeEventListener('focus', sync);
    };
  }, []);

  return online;
}
