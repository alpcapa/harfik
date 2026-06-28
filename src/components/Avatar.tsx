// Harfik — profil küçük resmi (fotoğraf ya da baş harf yedeği)
import { useState } from 'react';

interface AvatarProps {
  url?: string | null;
  name?: string | null;
  /** Piksel cinsinden çap. */
  size?: number;
  className?: string;
}

/** İsim/e-postadan baş harf(ler)i türetir. */
function initials(name?: string | null): string {
  const n = (name || '').trim();
  if (!n) return '?';
  // E-posta ise @ öncesini al.
  const base = n.includes('@') ? n.split('@')[0] : n;
  const parts = base.split(/[\s._-]+/).filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return base.slice(0, 2).toUpperCase();
}

export function Avatar({ url, name, size = 32, className = '' }: AvatarProps) {
  const [broken, setBroken] = useState(false);
  const style = { width: size, height: size, fontSize: Math.round(size * 0.4) };

  if (url && !broken) {
    return (
      <img
        src={url}
        alt={name || 'Avatar'}
        onError={() => setBroken(true)}
        style={style}
        className={`rounded-full object-cover border border-border bg-panel ${className}`}
      />
    );
  }

  return (
    <span
      style={style}
      className={`rounded-full flex items-center justify-center font-mono font-bold text-white bg-accent border border-accent select-none ${className}`}
    >
      {initials(name)}
    </span>
  );
}
