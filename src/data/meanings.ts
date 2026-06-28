// Harfik — sözlük anlamları (yerel, tembel yüklenen)
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

/** Tüm yerel anlam sözlüğünü (bir kez) yükler. */
async function loadAll(): Promise<MeaningMap> {
  if (cache) return cache;
  if (!loading) {
    loading = fetch(meaningsUrl)
      .then((r) => r.json() as Promise<MeaningMap>)
      .then((m) => {
        cache = m;
        return m;
      })
      .catch((err) => {
        console.error('[Harfik] anlamlar yüklenemedi:', err);
        loading = null;
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
