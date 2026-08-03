// Kelimeki — bir oyunun katılımcılarını yan yana (hafif üst üste binen)
// küçük avatarlar olarak gösterir. Canlı "Devam Eden Oyunlar" kartlarında ve
// "Son Oynananlar" listesinde, önceden "2/4 Kişilik Oyun" ya da rakip
// isimlerinin yazdığı KALIN BAŞLIK SATIRININ yerine geçer (3 Ağustos 2026,
// kullanıcı isteği) — kartlardaki diğer tüm metinler (durum, kalan süre,
// "X açtı", tarih, skor, k-lig puanı) olduğu gibi kalır.
//
// Avatar sayısı eski "N Kişilik" bilgisinin yerini tuttuğundan çağıranlar
// oyuncuların TAMAMINI (çağıran dahil) geçer — yalnızca rakipleri göstermek
// 4 kişilik bir oyunda 3 avatar bırakıp oyunun kaç kişilik olduğunu
// kaybettirirdi.
import { Avatar } from './Avatar';

export interface AvatarRowPlayer {
  name: string;
  /** Yalnızca Canlı oyun kartlarında dolu olabilir — bkz. dosya sonundaki not. */
  avatarUrl?: string | null;
  /**
   * YZ koltuğu — baş harf yerine robot avatarı gösterilir. Görsel dil
   * `LiveGameCreateForm`/`PendingGameCard`'daki (oyun daveti) robot
   * avatarıyla birebir aynı: `bg-void` zemin + `border-border` çerçeve
   * içinde 🤖. YZ'nin profili olmadığından baş harf üretmek ("YZ") onu
   * gerçek bir üye gibi gösteriyordu.
   */
  isAi?: boolean;
}

/**
 * `size` bilinçli olarak 20px: başlık satırının yerine geçtiğinden kartı
 * neredeyse hiç büyütmüyor, ama 16px'te baş harfler 6-7px'e düşüp
 * okunamaz hale geliyordu (üyelerin çoğunun profil fotoğrafı yok, yani
 * pratikte görünen şey baş harfler).
 */
export function PlayerAvatarRow({
  players,
  size = 20,
}: {
  players: AvatarRowPlayer[];
  size?: number;
}) {
  return (
    <span className="flex -space-x-1" style={{ height: size }}>
      {players.map((p, i) => (
        // Halka (`ring-panel`), üst üste binen avatarların birbirinden
        // ayrışmasını sağlıyor; `ring` layout'a hiç yer kaplamadığından
        // avatar boyutunu/satır yüksekliğini etkilemiyor.
        <span key={`${p.name}-${i}`} className="inline-flex rounded-full ring-2 ring-panel">
          {p.isAi ? (
            <span
              style={{ width: size, height: size, fontSize: Math.round(size * 0.55) }}
              className="rounded-full bg-void border border-border flex items-center justify-center select-none"
              title={p.name}
              aria-label={p.name}
              role="img"
            >
              🤖
            </span>
          ) : (
            <Avatar url={p.avatarUrl} name={p.name} size={size} />
          )}
        </span>
      ))}
    </span>
  );
}
