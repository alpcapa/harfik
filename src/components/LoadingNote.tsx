// Bekleme göstergesi — Flutter portundaki `KLoadingNote` ile BİREBİR aynı.
//
// NEDEN VAR (24 Ağustos 2026): kullanıcı cihazda (mobil uygulamada) lider
// tablosunu ve skor kartını açınca *"önce 1-2 saniye bir popup görüyorum,
// sonra sıralama üstüne geliyor"* dedi — pencere BOŞ açılıyor sanılıyordu.
// Oysa yükleme durumu vardı: `text-muted text-xs`, küçük harf
// "Yükleniyor…". Yani eksik olan durum değil, OKUNURLUĞUYDU — ve aynı
// kusur webde de vardı (iki taraf da aynı deseni taşıyordu).
//
// Gecikmenin kendisi UI'ın çözebileceği bir şey DEĞİL (lider tablosu
// sorgusu sunucuda 4.3 ms; kalanı mesafe — veritabanı `ap-south-1`/
// Mumbai'de, bkz. `docs/decisions/product-backlog.md`). Yapılabilecek şey
// bekleyişi GÖRÜNÜR kılmak.
//
// METİN AYNI KALDI ("Yükleniyor…") — hem kullanıcı alışkanlığı hem de
// birkaç testin (Playwright + portun widget testleri) bu dizeyi araması
// yüzünden.
//
// ⚠ Admin paneli BİLEREK dışarıda: orada aynı metin 15 yerde geçiyor,
// yalnızca yöneticiye görünüyor ve kullanıcı deneyimiyle ilgisi yok.
export function LoadingNote({ py = 'py-6' }: { py?: string }) {
  return (
    <p className={`text-accent text-[13px] font-mono font-bold tracking-[1.5px] text-center ${py}`}>
      Yükleniyor…
    </p>
  );
}
