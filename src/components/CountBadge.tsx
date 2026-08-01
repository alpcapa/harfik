// Kelimeki — kırmızı yuvarlak sayaç rozeti (Setup'taki "Oyun Tipi" sekmeleri,
// UserMenu'deki "Arkadaşlar" satırı, FriendsModal'ın sekme başlıkları gibi
// "bekleyen N şey var" göstergelerinin hepsinde aynı görsel). Tek bir yerde
// yaşamasının sebebi: "1" gibi ince gövdeli rakamlar Space Grotesk'te
// dairenin merkezine göre optik olarak biraz yukarıda duruyor (dolgun "2"
// gibi rakamlarda fark edilmiyor) — bu düzeltme (relative top-px) burada
// tek seferde uygulanıyor, kopyaların her birine ayrı ayrı eklenmesi
// gerekmiyor.
export function CountBadge({ count, className = '' }: { count: number; className?: string }) {
  return (
    <span
      className={`min-w-[16px] h-4 px-1 rounded-full bg-red text-white text-[9px] font-bold flex items-center justify-center leading-none ${className}`}
    >
      <span className="relative top-px">{count}</span>
    </span>
  );
}
