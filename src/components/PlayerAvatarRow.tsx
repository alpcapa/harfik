// Kelimeki — bir oyunun katılımcılarını yan yana (hafif üst üste binen)
// küçük avatarlar olarak gösterir. Canlı "Devam Eden Oyunlar" kartlarında ve
// "Son Oynananlar" listesinde, önceden "2/4 Kişilik Oyun" ya da rakip
// isimlerinin yazdığı KALIN BAŞLIK SATIRININ yerine geçer (3 Ağustos 2026,
// kullanıcı isteği) — kartlardaki diğer tüm metinler (durum, kalan süre,
// tarih, skor, k-lig puanı) olduğu gibi kalır; 6 Eylül 2026'dan beri hemen
// altında koltuk sırasıyla puan satırı var (`utils/scoreLine.ts`).
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
  /**
   * Misafir (girişsiz) koltuk — yerel (YZ) oyunlarda mümkün, Canlı'da değil
   * (orada herkes kayıtlı). Profil olmadığından baş harf üretilecek anlamlı
   * bir isim de yok: `GameState`'e literal `GUEST_PLAYER_NAME` gömülüyor
   * (bkz. `Setup`'un `doStart`'ı), yani baş harf "MI" çıkıp misafiri gerçek
   * bir üye gibi gösteriyor. Bu bayrak `Avatar`'a boş isim geçirterek onun
   * zaten var olan **"?"** yedeğini seçtiriyor — yeni bir görsel icat
   * edilmedi.
   *
   * İki çağrı yeri var ve misafirliği FARKLI yollardan biliyorlar:
   * `Setup`'un devam eden oyun satırı (`savedGameAvatars`) oturum durumundan
   * (`!user`), `RecentGamesSection`'ın bitmiş oyun satırı ise dondurulmuş
   * `games.players` anlık görüntüsündeki isimden — o snapshot bilerek
   * `user_id` taşımadığından tespitin tek yolu `GUEST_PLAYER_NAME`
   * karşılaştırması.
   */
  isGuest?: boolean;
}

/**
 * `size` **26px** (2 Eylül 2026, kullanıcı isteği: "avatarları biraz daha
 * büyütelim"). Öncesi 20'ydi ve bu yorum 3 Eylül'e kadar hâlâ 20 diyordu —
 * o turda değer değişti, gerekçe güncellenmedi.
 *
 * Alt taban hâlâ geçerli: 16px'te baş harfler 6-7px'e düşüp okunamaz hâle
 * geliyor (üyelerin çoğunun profil fotoğrafı yok, yani pratikte görünen şey
 * baş harfler).
 *
 * ⚠ **Üst sınırı belirleyen taraf PORT** (`ui/game/player_avatar_row.dart`):
 * orada şerit `Expanded` bir alanda ve yazı ölçeği tavanında 320px ekranda
 * 92,5px'e iniyor — 4 oyunculu şerit 26/6 bindirmeyle 86px, yani 6,5px marj.
 * Web'de böyle bir kısıt yok (tarayıcı kutuları da birlikte zoom'lar), ama
 * ikisi aynı değeri paylaşıyor: **burada büyütmeden önce portun ölçümünü
 * oku**, yoksa parite cihazda taşarak kırılır.
 */
export function PlayerAvatarRow({
  players,
  size = 26,
}: {
  players: AvatarRowPlayer[];
  size?: number;
}) {
  return (
    <span className="flex -space-x-1.5" style={{ height: size }}>
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
            <Avatar url={p.avatarUrl} name={p.isGuest ? '' : p.name} size={size} />
          )}
        </span>
      ))}
    </span>
  );
}
