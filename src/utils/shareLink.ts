// Kelimeki — "Arkadaşını davet et" paylaşım linki. Hem Setup.tsx (React,
// uygulama içi) hem karşılama katmanının main.tsx'teki düz JS'i (Landing.tsx
// hiçbir olay handler'ı barındırmıyor, bkz. Landing.tsx dosya başlığı) BU
// fonksiyonu kullanır — link `?ref=arkadas` taşımak ZORUNDA (admin
// panelindeki "Kaynak Hunisi"nin ziyaretçi ucunu besleyen TEK üretici).
// Tek yerden üretilmezse iki taraf sessizce ayrışıp linki kaybedebilir
// (bkz. CLAUDE.md, Setup'taki "kendi başına bir paylaşım yolu YAZMA" uyarısı).
export function buildShareUrl(): string {
  return `${window.location.origin}/?ref=arkadas`;
}

const SHARE_TEXT = 'Hemen ücretsiz dene!';

/**
 * Native paylaşım sayfasını açar; desteklenmiyorsa linki panoya kopyalar.
 * Kullanıcı paylaşım sayfasını iptal ederse (ya da panoya erişim yoksa)
 * sessizce yutuluyor — çağıran yalnızca `'copied'` sonucunda geri bildirim
 * göstermeli ("Link kopyalandı!" gibi).
 */
export async function shareKelimekiLink(): Promise<'shared' | 'copied' | 'failed'> {
  const url = buildShareUrl();
  if (navigator.share) {
    try {
      await navigator.share({ title: 'Kelimeki', text: SHARE_TEXT, url });
    } catch {
      // kullanıcı paylaşım sayfasını iptal etti — hata sayılmaz
    }
    return 'shared';
  }
  try {
    await navigator.clipboard.writeText(url);
    return 'copied';
  } catch {
    return 'failed';
  }
}
