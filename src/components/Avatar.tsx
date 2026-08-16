// Kelimeki — profil küçük resmi (fotoğraf ya da baş harf yedeği)
import { useEffect, useState } from 'react';
import { trUpper } from '../utils/turkish';
import { CountBadge } from './CountBadge';

interface AvatarProps {
  url?: string | null;
  name?: string | null;
  /** Piksel cinsinden çap. */
  size?: number;
  className?: string;
  /**
   * Sağ üst köşede bekleyen iş SAYISINI gösterir (`CountBadge`). Varsayılan
   * 0 — mevcut tüm kullanım yerlerinde (ScoreCard/PlayerScoreCard/Leaderboard
   * vb.) görünümü hiç değiştirmez, yalnızca >0 verilince ekstra bir
   * sarmalayıcı devreye girer.
   *
   * 16 Ağustos 2026'ya kadar bu bir `dot?: boolean` idi ve bilinçli olarak
   * `CountBadge` DEĞİLDİ ("var/yok bilgisi taşıyor, adet değil"). Kullanıcı
   * kırmızı noktaların fark edilmediğini bildirince karar tersine çevrildi —
   * bkz. kök CLAUDE.md, `CountBadge`.
   */
  badgeCount?: number;
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

export function Avatar({ url, name, size = 32, className = '', badgeCount = 0 }: AvatarProps) {
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
  // Baş harf yedeğinin punto oranı İKİ harfe göre ayarlı (0.4) — dairenin
  // içine yatayda ancak öyle sığıyor. Tek karakterlik yedekte (misafirin
  // "?"i ya da tek harfli bir isim) bu kısıt yok ve 0.4 optik olarak zayıf
  // kalıyor: `PlayerAvatarRow`'da "?" avatarı, yanında durduğu robot
  // avatarının 0.55 oranıyla yan yana gelince belirgin şekilde küçük
  // görünüyordu (kullanıcı bildirdi). Tek karakter aynı 0.55'e çekildi —
  // iki harfli baş harfler (yani kullanım yerlerinin ezici çoğunluğu) hiç
  // etkilenmiyor.
  const text = initials(name);
  const fallbackStyle = {
    ...style,
    fontSize: Math.round(size * (text.length === 1 ? 0.55 : 0.4)),
  };

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
        style={fallbackStyle}
        className={`rounded-full flex items-center justify-center font-mono font-bold text-white bg-accent border border-accent select-none ${className}`}
      >
        {text}
      </span>
    );

  if (badgeCount <= 0) return inner;

  // Konum, projedeki diğer TÜM rozetlerle aynı (`absolute -top-1 -right-1`,
  // bkz. Setup sekmeleri) — rozet köşeden taşar, avatarın yüzünü kapatmaz.
  // `ring` (border değil) bilinçli: `CountBadge`'in kutusu `border-box`
  // olduğundan border eklemek 16px'lik daireyi içeriden yiyip rakamı
  // küçültürdü; ring layout'a hiç dokunmuyor.
  return (
    <span className="relative inline-flex shrink-0">
      {inner}
      <CountBadge count={badgeCount} className="absolute -top-1 -right-1 ring-2 ring-panel" />
    </span>
  );
}
