// Bir oyunun katılımcılarını yan yana (hafif üst üste binen) küçük
// avatarlar olarak gösterir — web `PlayerAvatarRow.tsx` portu.
//
// Kartlarda "N Kişilik Oyun" KALIN BAŞLIK SATIRININ yerine geçer; avatar
// sayısı zaten oyuncu sayısını verdiğinden çağıranlar oyuncuların TAMAMINI
// (kendileri dahil) geçer — yalnızca rakipleri göstermek 4 kişilik bir
// oyunda kaç kişilik olduğunu kaybettirirdi.
//
// İki çağrı yeri var ve girdileri FARKLI: Setup'ın devam eden oyun satırı
// canlı `Player` listesinden, "Son Oynadıklarım" ise dondurulmuş
// `games.players` anlık görüntüsünden besleniyor. Web'de de tek bileşen iki
// yeri besliyor; ortak biçim `AvatarRowPlayer`.
import 'package:flutter/material.dart';

import '../auth/k_avatar.dart';
import '../tokens.dart';

const _border = kBorder;

/// Web `bg-void` — robot avatarının zemini.
const _void = kVoid;

class AvatarRowPlayer {
  final String name;

  /// Yalnızca gerçek üyelerde dolu olabilir; dondurulmuş snapshot BİLEREK
  /// avatar taşımadığından (girişli herkese açık) orada hep null → baş harf.
  final String? avatarUrl;

  /// YZ koltuğu — baş harf yerine robot. "YZ" baş harfi üretmek onu gerçek
  /// bir üye gibi gösteriyordu (web'in aynı kararı).
  final bool isAi;

  /// Misafir koltuk (yalnızca yerel oyunlarda mümkün; Canlı'da herkes
  /// kayıtlı). `GameState`'e literal "Misafir" gömüldüğünden baş harf "MI"
  /// çıkıp misafiri üye gibi gösteriyordu — bu bayrak `KAvatar`'ın boş-isim
  /// yedeğini ("?") seçtirir, yeni bir görsel icat edilmedi.
  final bool isGuest;

  const AvatarRowPlayer({
    required this.name,
    this.avatarUrl,
    this.isAi = false,
    this.isGuest = false,
  });
}

class PlayerAvatarRow extends StatelessWidget {
  final List<AvatarRowPlayer> players;

  /// Web'le aynı 20px: başlık satırının yerine geçtiğinden kartı neredeyse
  /// büyütmüyor, ama 16px'te baş harfler okunamaz hâle geliyor.
  final double size;

  const PlayerAvatarRow({super.key, required this.players, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return SizedBox(height: size);
    const overlap = 4.0;
    final step = size - overlap;
    return SizedBox(
      width: size + (players.length - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < players.length; i++)
            Positioned(
              left: i * step,
              child: _Avatar(player: players[i], size: size),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final AvatarRowPlayer player;
  final double size;
  const _Avatar({required this.player, required this.size});

  @override
  Widget build(BuildContext context) {
    if (player.isAi) {
      // Web `bg-void border-border` zemin + gerçek 🤖 emoji (Material
      // `Icons.smart_toy_outlined` ikonuyla İLK PORTTA yanlışlıkla
      // değiştirilmişti — tamamen farklı bir şekil; web'de font-fallback
      // gerektiren bir glyph değil, düz Unicode emoji, bu yüzden ★/✓
      // kararlarındaki gibi bir ikon ikamesine hiç gerek yoktu).
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _void,
          border: Border.all(color: _border),
          shape: BoxShape.circle,
        ),
        child: Text(
          '🤖',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (size * 0.55).roundToDouble(),
            height: 1,
            fontFamilyFallback: const [
              'Noto Color Emoji',
              'Apple Color Emoji',
            ],
          ),
        ),
      );
    }
    // Misafir koltuk (isGuest) da dahil — `KAvatar`'a boş isim geçirmek
    // onun zaten var olan "?" yedeğini (mavi zemin, web `Avatar.tsx`'in
    // fallback stiliyle BİREBİR) seçtiriyor; ayrı bir gri/nötr kopya
    // ARTIK YOK (KAvatar'ın kendi yedek rengi düzeltilince bu ikisinin
    // ayrışmaması için buraya delege edildi).
    return KAvatar(
      url: player.avatarUrl,
      name: player.isGuest ? '' : player.name,
      size: size,
    );
  }
}
