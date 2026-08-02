// Kelimeki — profil küçük resmi (fotoğraf ya da baş harf yedeği)
import { useEffect, useState } from 'react';
import { trUpper } from '../utils/turkish';

interface AvatarProps {
  url?: string | null;
  name?: string | null;
  /** Piksel cinsinden çap. */
  size?: number;
  className?: string;
  /**
   * Sağ üst köşede küçük kırmızı bir nokta gösterir (ör. bekleyen
   * arkadaşlık isteği). Varsayılan false — mevcut tüm kullanım yerlerinde
   * (ScoreCard/PlayerScoreCard/Leaderboard vb.) görünümü hiç değiştirmez,
   * yalnızca `dot` açıkça true verilince ekstra bir sarmalayıcı devreye girer.
   */
  dot?: boolean;
}

/** İsim/e-postadan baş harf(ler)i türetir. */
function initials(name?: string | null): string {
  const n = (name || '').trim();
  if (!n) return '?';
  // E-posta ise @ öncesini al.
  const base = n.includes('@') ? n.split('@')[0] : n;
  const parts = base.split(/[\s._-]+/).filter(Boolean);
  if (parts.length >= 2) return trUpper(parts[0][0] + parts[1][0]);
  return trUpper(base.slice(0, 2));
}

export function Avatar({ url, name, size = 32, className = '', dot = false }: AvatarProps) {
  const [broken, setBroken] = useState(false);
  // `url` değişince (ör. kullanıcı yeni bir profil fotoğrafı yükleyince)
  // önceki bir yükleme hatasının `broken` bayrağı sıfırlanmıyordu — aynı
  // `Avatar` örneği (ör. UserMenu'deki, oturum boyunca hiç unmount olmayan)
  // yeni geçerli bir URL gelse bile kalıcı olarak baş harfleri göstermeye
  // devam ediyordu (bkz. kod incelemesi).
  useEffect(() => {
    setBroken(false);
  }, [url]);
  const style = { width: size, height: size, fontSize: Math.round(size * 0.4) };

  const inner =
    url && !broken ? (
      <img
        src={url}
        alt={name || 'Avatar'}
        onError={() => setBroken(true)}
        style={style}
        className={`rounded-full object-cover border border-border bg-panel ${className}`}
      />
    ) : (
      <span
        style={style}
        className={`rounded-full flex items-center justify-center font-mono font-bold text-white bg-accent border border-accent select-none ${className}`}
      >
        {initials(name)}
      </span>
    );

  if (!dot) return inner;

  const dotSize = Math.max(8, Math.round(size * 0.3));
  return (
    <span className="relative inline-flex shrink-0">
      {inner}
      <span
        aria-hidden
        style={{ width: dotSize, height: dotSize }}
        className="absolute top-0 right-0 rounded-full bg-red border-2 border-panel"
      />
    </span>
  );
}
