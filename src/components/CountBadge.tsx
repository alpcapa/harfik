// Kelimeki — kırmızı yuvarlak sayaç rozeti (Setup'taki "Oyun Tipi"/alt
// sekmeler, UserMenu'deki "Arkadaşlar" ve "Admin Paneli" satırları,
// FriendsModal ve AdminDashboard'un sekme başlıkları gibi "bekleyen N şey
// var" göstergelerinin hepsinde aynı görsel). Tek bir yerde yaşamasının
// sebebi, aynı öğenin TÜM kullanım yerlerini tek kaynağa bağlamak.
//
// Dikey ortalama (3 Ağustos 2026'da ölçülerek çözüldü) — önceki sürüm
// "'1' gibi ince rakamlar Space Grotesk'te optik olarak yukarıda duruyor"
// teşhisiyle bir `relative top-px` nudge taşıyordu. Chromium'da gerçek
// fontlarla ölçülünce bu teşhisin YANLIŞ olduğu görüldü: 1/2/8'in ink
// metrikleri birebir aynı (hepsi lining rakam, asc 7 / desc 0), yani sorun
// rakamda değil FONTTA. Bileşen kendi fontunu belirtmediğinden ebeveyninden
// miras alıyordu — UserMenu satırları `font-mono` (Space Mono), Setup
// sekmeleri Grotesk — ve iki fontun ascent'i farklı olduğundan (10 vs 9)
// tek bir sabit piksel nudge ikisinde birden doğru olamıyordu.
//
// Çözüm sihirli sayı gerektirmiyor: font burada SABİTLENİYOR (`font-mono`)
// ve nudge tamamen kalkıyor. Space Mono'da 9px/700 rakamların taban çizgisi
// 16px'lik kutuda 11.5px'e düşüyor, ink 4.5–11.5 arasını kaplıyor, yani ink
// merkezi tam olarak 8.0px = kutunun merkezi. Ebeveyn hangi fontu
// kullanırsa kullansın sonuç aynı; rozetler artık her yerde birebir aynı
// görünüyor (mono rakamlar sayaç için ayrıca tabular/hizalı avantajı da
// veriyor).
export function CountBadge({ count, className = '' }: { count: number; className?: string }) {
  return (
    <span
      className={`min-w-[16px] h-4 px-1 rounded-full bg-red text-white font-mono text-[9px] font-bold flex items-center justify-center leading-none ${className}`}
    >
      {count}
    </span>
  );
}
