// Kelimeki — WORD_SET'i (~63k kelime) ayrı bir chunk'a bölüp arka planda
// önceden indirir; ana JS paketi böylece ilk boyama için bu veriyi
// beklemek zorunda kalmaz (bkz. PageSpeed "Reduce unused JavaScript").
// preloadWordSet() main.tsx'te uygulama daha render olmadan tetiklenir —
// Setup ekranında oyuncu kurulumuna harcanan birkaç saniye içinde
// neredeyse her zaman tamamlanmış olur. Yine de gerçek hamle/YZ
// akışlarını tetikleyen kodlar (App.tsx, Setup.tsx) isWordSetReady() ile
// hazır olduğunu doğruladıktan sonra devam etmeli — aksi halde
// getWordSet() henüz yüklenmemişken çağrılırsa hata fırlatır.
let wordSet: ReadonlySet<string> | undefined;
let loadPromise: Promise<ReadonlySet<string>> | undefined;

export function preloadWordSet(): Promise<ReadonlySet<string>> {
  if (!loadPromise) {
    loadPromise = import('./words')
      .then((mod) => {
        wordSet = mod.WORD_SET;
        return wordSet;
      })
      .catch((err) => {
        // Bir kerelik ağ hatası (ör. chunk indirilemedi) yüzünden reddedilen
        // bir promise'i kalıcı olarak önbellekte tutmuyoruz — aksi halde
        // `if (!loadPromise)` koruması bir daha asla yeniden denemeye izin
        // vermez ve uygulama "Hazırlanıyor…" ekranında sonsuza dek kilitli
        // kalırdı. Bir sonraki `preloadWordSet()` çağrısı (ör. kullanıcının
        // tekrar denemesiyle) baştan indirmeyi yeniden dener.
        loadPromise = undefined;
        throw err;
      });
  }
  return loadPromise;
}

export function isWordSetReady(): boolean {
  return wordSet !== undefined;
}

export function getWordSet(): ReadonlySet<string> {
  if (!wordSet) {
    throw new Error('Kelime listesi henüz yüklenmedi');
  }
  return wordSet;
}
