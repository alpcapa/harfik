// "Uygulamadan uzakta kalma" izleyicisi.
//
// Neden var (21 Ağustos 2026, kullanıcı bildirdi): masaüstünde arka planda
// açık kalan uygulama öne getirildiğinde, sıra kendisinde olmasına rağmen
// "Arkadaşınla" sekmesi açık gelmiyordu. Bu bir regresyon DEĞİLDİ — Setup'ın
// `appliedLoginDefaultRef`'i hesap başına YALNIZCA BİR KEZ uygulanıyor (bkz.
// CLAUDE.md, "Sekme OTOMATİK değişmez") ve uzun süre arka planda kalan bir
// sekme/pencere hiç unmount olmadığından o "bir kez" aylar önce, ilk girişte
// tükenmiş oluyordu. Kullanıcının daha önce doğru davranış görmesinin sebebi
// muhtemelen sayfanın (deploy sonrası service worker güncellemesiyle) tam
// yeniden yüklenmesiydi — yani davranış deploy sıklığına bağlı, kararsızdı.
//
// Kuralın kendisi ("kullanıcı bir sekmede otururken yeni davet/hamle onu
// oradan koparmaz") DEĞİŞMEDİ; değişen, "ekrana giriş" tanımı: uygulamadan
// gerçekten UZAKLAŞIP geri dönmek de bir giriştir. Kısa bir alt-tab (başka
// pencereye bakıp dönmek) giriş SAYILMAZ — aksi halde kullanıcı bilerek
// oturduğu sekmeden habersizce koparılırdı. Ayrımı bu eşik yapıyor.
export const LONG_AWAY_MS = 5 * 60 * 1000;

export type AwayTracker = {
  /** Sekme/pencere arka plana alındığında (hidden/blur) çağrılır. */
  markAway(): void;
  /**
   * Öne dönüşte çağrılır. Uzakta geçen süre eşiği aştıysa `true` döner ve
   * sayacı sıfırlar; her dönüşte sıfırlandığından art arda gelen olaylar
   * (masaüstünde `focus` + `visibilitychange` neredeyse aynı anda geliyor)
   * kararı ikinci kez tetiklemez.
   */
  takeLongAway(thresholdMs?: number): boolean;
};

export function createAwayTracker(now: () => number = Date.now): AwayTracker {
  // Uzaklaşma anı: İLK işaret kazanır. `blur` ve `visibilitychange` çoğu
  // masaüstü tarayıcısında art arda geliyor; ikincisi damgayı tazeleseydi
  // uzakta geçen süre olduğundan kısa ölçülürdü.
  let awayAt: number | null = null;
  return {
    markAway() {
      if (awayAt === null) awayAt = now();
    },
    takeLongAway(thresholdMs = LONG_AWAY_MS) {
      const at = awayAt;
      awayAt = null;
      // Hiç uzaklaşma görülmediyse (ör. sayfa odaksız açıldı) karar
      // VERİLMEZ — "bilmiyorum" durumunda mevcut sekmede kalmak doğrusu.
      return at !== null && now() - at >= thresholdMs;
    },
  };
}
