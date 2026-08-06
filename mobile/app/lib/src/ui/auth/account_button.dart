// Hesap kontrolü — web `UserMenu`nun (src/components/UserMenu.tsx) bu fazda
// portlanan çekirdeği. Dört durum, web'le aynı:
//   yapılandırılmamış → hiç çizilmez (web `null` döner — offline mod)
//   kimlik yükleniyor → "…" dairesi (dokunulamaz)
//   oturum yok       → GİRİŞ (btn-raised accent) → giriş penceresi
//   oturum var       → avatar → açılır menü
// Menü YALNIZCA gerçekten çalışan maddeleri taşıyor: isim başlığı, k-lig
// satırı (rank+puan, sıralamayı açar), Skor Kartı, "Nasıl Oynanır?" ve
// "Çıkış Yap". Web'deki kalanlar (Arkadaşlar, Hesap Ayarları) kendi
// ekranları portlanınca eklenecek — çalışmayan madde koymuyoruz
// (ARKADAŞINLA dürüstlük deseni). k-lig/Skor Kartı yalnızca `stats`
// verildiğinde (Supabase yapılandırılmışsa) görünür.
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../game/help_modal.dart';
import '../game/neo_box.dart';
import '../score/klig_mark.dart';
import '../score/leaderboard_modal.dart';
import '../score/score_card_modal.dart';
import 'k_avatar.dart';
import 'auth_modal.dart';

const Color _text = Color(0xFF1B2430);
const Color _muted = Color(0xFF5A6673);
const Color _panel = Color(0xFFF5F7FA);
const Color _border = Color(0xFFDCE2EA);

class AccountButton extends StatelessWidget {
  final AuthService auth;

  /// null ise k-lig/Skor Kartı satırları hiç çizilmez (Supabase
  /// yapılandırılmamış ya da testte verilmemiş).
  final StatsRepo? stats;

  /// Skor kartından açılan "Tüm Geçmiş Oyunlar" için — null ise o link
  /// çizilmez (kartın kendisi yine açılır).
  final Future<GamesRepo>? games;

  /// GİRİŞ butonunun akıcı ölçüleri — GameHeader kendi clamp değerlerini
  /// geçer; Setup varsayılan (maksimum) değerleri kullanır (web UserMenu
  /// iki ekranda da aynı bileşen/aynı akıcı sistem).
  final double girisFontSize;
  final double girisPaddingX;
  final double girisPaddingY;
  final double avatarSize;

  const AccountButton({
    super.key,
    required this.auth,
    this.stats,
    this.games,
    this.girisFontSize = 11,
    this.girisPaddingX = 8,
    this.girisPaddingY = 12,
    this.avatarSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (!auth.configured) return const SizedBox.shrink();
        if (auth.identityLoading) {
          return Container(
            width: avatarSize,
            height: avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _panel,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Text('…',
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 10, color: _muted)),
          );
        }
        if (auth.user == null) return _girisButton(context);
        return _avatarMenu(context);
      },
    );
  }

  Widget _girisButton(BuildContext context) {
    return GestureDetector(
      onTap: () => showLoginModal(context, auth),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: girisPaddingX, vertical: girisPaddingY),
        // Web: `btn-raised bg-accent` (bkz. game_header.dart'taki eski
        // _GirisButton — görsel birebir korunarak buraya taşındı).
        decoration: const ShapeDecorationWithCssShadows(
          color: Color(0xFF2563EB),
          radius: 6,
          shadows: [
            CssShadow(color: Color(0x8CA3B1C6), offset: Offset(3, 3), blur: 8),
            CssShadow(
                color: Color(0xB3FFFFFF), offset: Offset(-2, -2), blur: 6),
            CssShadow(color: Color(0x59647489), offset: Offset(0, 6), blur: 14),
          ],
        ),
        child: Text(
          'GİRİŞ',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontWeight: FontWeight.bold,
            fontSize: girisFontSize,
            letterSpacing: 0.5,
            height: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _avatarMenu(BuildContext context) {
    const itemStyle =
        TextStyle(fontFamily: 'SpaceMono', fontSize: 12, color: _text);
    return PopupMenuButton<String>(
      tooltip: 'Hesap menüsü',
      offset: Offset(0, avatarSize + 8),
      color: _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      onSelected: (value) {
        final stats = this.stats;
        switch (value) {
          case 'league':
            if (stats != null) {
              showLeaderboard(context, auth: auth, stats: stats, games: games);
            }
          case 'score':
            if (stats != null) {
              showScoreCard(context, auth: auth, stats: stats, games: games);
            }
          case 'help':
            showHelpModal(context);
          case 'signout':
            auth.signOut();
        }
      },
      itemBuilder: (context) => [
        // İsim başlığı — web dropdown'ının üst bölümü (tıklanamaz).
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              KAvatar(
                  url: auth.profile?.avatarUrl, name: auth.menuName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  auth.menuName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: _text),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (stats != null) ...[
          // Web dropdown'ının en üstündeki tıklanabilir "k-lig" satırı.
          const PopupMenuItem<String>(
            value: 'league',
            child: Row(children: [
              KLigMark(height: 14),
              SizedBox(width: 8),
              Text('Sıralama', style: itemStyle),
            ]),
          ),
          const PopupMenuItem<String>(
            value: 'score',
            child: Text('📊  Skor Kartı', style: itemStyle),
          ),
        ],
        const PopupMenuItem<String>(
          value: 'help',
          child: Text('❓  Nasıl Oynanır?', style: itemStyle),
        ),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Text('🚪  Çıkış Yap', style: itemStyle),
        ),
      ],
      child: KAvatar(
        url: auth.profile?.avatarUrl,
        name: auth.menuName,
        size: avatarSize,
      ),
    );
  }
}
