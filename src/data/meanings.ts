// Kelimeki — sözlük anlamları (yerel, tembel yüklenen)
//
// meanings.json ~6 MB olduğundan ana paket içine gömülmez; `?url` ile
// statik varlık olarak alınır ve ilk anlam sorgusunda fetch ile yüklenir.
// Çevrimiçi sürüm anlamları Supabase'ten (word_meaning RPC) de çekebilir;
// bu yerel veri çevrimdışı yedek olarak kullanılır.
import meaningsUrl from './meanings.json?url';
import { trLower } from '../utils/turkish';

export interface WordMeaning {
  /** Sözcük türü kısaltması (TDK), örn. "a.", "sf.", "-i". */
  pos: string | null;
  /** Sözlük anlamları. */
  meanings: string[];
}

type MeaningMap = Record<string, WordMeaning>;

let cache: MeaningMap | null = null;
let loading: Promise<MeaningMap> | null = null;
/**
 * Anlam verisi İNDİRİLEMEDİ mi (kelime sözlükte yok'tan farklı)?
 *
 * `meanings.json` 6.3 MB ve service worker precache'inde BİLEREK yok
 * (herkese 6 MB'lık bir ön indirme yüklemek, bir oyun için orantısız) —
 * dolayısıyla çevrimdışıyken `fetch` düşüyor ve `getLocalMeaning` null
 * dönüyor. O null "kelime bulunamadı" ile aynı değerdi, ekranda da aynı
 * mesaj çıkıyordu ("Bu kelimenin anlamı bulunamadı.") — oysa kelime
 * sözlükte olabilir, biz bakamıyoruz (14 Ağustos 2026, cihaz testi).
 *
 * **Flutter portunda bu sorun YOK ve bu bayrak PORTA TAŞINMAZ:** orada
 * anlamlar uygulama paketindeki `assets/dictionary/meanings.db` içinde,
 * yani çevrimdışı da çalışıyor.
 */
let loadFailed = false;

/** Son yükleme denemesi başarısız mı — `MeaningModal` mesajı buna göre seçer. */
export function isMeaningDataUnavailable(): boolean {
  return loadFailed;
}

/** Tüm yerel anlam sözlüğünü (bir kez) yükler. */
async function loadAll(): Promise<MeaningMap> {
  if (cache) return cache;
  if (!loading) {
    loading = fetch(meaningsUrl)
      .then((r) => r.json() as Promise<MeaningMap>)
      .then((m) => {
        cache = m;
        loadFailed = false;
        return m;
      })
      .catch((err) => {
        console.error('[Kelimeki] anlamlar yüklenemedi:', err);
        loading = null;
        loadFailed = true;
        return {};
      });
  }
  return loading;
}

/**
 * Bir kelimenin yerel sözlükteki anlamını döner; yoksa null.
 * İlk çağrıda anlam verisini tembel yükler.
 */
export async function getLocalMeaning(word: string): Promise<WordMeaning | null> {
  const all = await loadAll();
  return all[trLower(word)] ?? null;
}
