// Hesap kontrolü — web `UserMenu`nun (src/components/UserMenu.tsx) bu fazda
// portlanan çekirdeği. Dört durum, web'le aynı:
//   yapılandırılmamış → hiç çizilmez (web `null` döner — offline mod)
//   kimlik yükleniyor → "…" dairesi (dokunulamaz)
//   oturum yok       → GİRİŞ (btn-raised accent) → giriş penceresi
//   oturum var       → avatar → açılır menü
// Menü YALNIZCA gerçekten çalışan maddeleri taşıyor: isim başlığı, k-lig
// satırı (rank+puan, sıralamayı açar), Skor Kartı, Arkadaşlar (7 Ağustos
// 2026 — bekleyen istek sayısı CountBadge'le, avatarda web'in `dot`
// noktası), "Nasıl Oynanır?", "Hesap Ayarları" (7 Ağustos 2026 —
// AccountSettingsModal, web sırasındaki gibi Çıkış Yap'ın hemen üstünde)
// ve "Çıkış Yap". k-lig/Skor Kartı `stats`, Arkadaşlar `friends` verildiğinde
// (Supabase yapılandırılmışsa) görünür. Bekleyen istek sayısı web
// UserMenu'yle aynı anlarda tazelenir: mount + FriendsModal kapanınca
// (içeride yanıtlanmış olabilir); Realtime aboneliği web'de de bilinçli
// yok (friend_requests publication'da değil).
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/feedback_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../data/friends_api.dart';
import '../friends/friends_modal.dart';
import '../game/count_badge.dart';
import '../game/help_modal.dart';
import '../game/neo_box.dart';
import '../score/klig_mark.dart';
import '../score/leaderboard_modal.dart';
import '../score/score_card_modal.dart';
import 'account_settings_modal.dart';
import 'k_avatar.dart';
import 'auth_modal.dart';

const Color _text = Color(0xFF1B2430);
const Color _muted = Color(0xFF5A6673);
const Color _panel = Color(0xFFF5F7FA);
const Color _border = Color(0xFFDCE2EA);

class AccountButton extends StatefulWidget {
  final AuthService auth;

  /// null ise k-lig/Skor Kartı satırları hiç çizilmez (Supabase
  /// yapılandırılmamış ya da testte verilmemiş).
  final StatsRepo? stats;

  /// Skor kartından açılan "Tüm Geçmiş Oyunlar" için — null ise o link
  /// çizilmez (kartın kendisi yine açılır).
  final Future<GamesRepo>? games;

  /// Giriş/kayıt modalı → Terms/Privacy → "Görüş Bildir formu" zinciri için.
  final FeedbackRepo? feedback;

  /// null ise "Arkadaşlar" satırı hiç çizilmez.
  final FriendsRepo? friends;

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
    this.feedback,
    this.friends,
    this.girisFontSize = 11,
    this.girisPaddingX = 8,
    this.girisPaddingY = 12,
    this.avatarSize = 32,
  });

  @override
  State<AccountButton> createState() => _AccountButtonState();
}

class _AccountButtonState extends State<AccountButton> {
  AuthService get auth => widget.auth;
  StatsRepo? get stats => widget.stats;
  Future<GamesRepo>? get games => widget.games;
  FeedbackRepo? get feedback => widget.feedback;
  double get girisFontSize => widget.girisFontSize;
  double get girisPaddingX => widget.girisPaddingX;
  double get girisPaddingY => widget.girisPaddingY;
  double get avatarSize => widget.avatarSize;

  int _incomingRequests = 0;
  String? _lastUserId;

  /// Menü başlığındaki (isim satırının altındaki) tıklanabilir k-lig
  /// satırı için — web `UserMenu`'nün `myRank` state'iyle aynı: `useEffect`
  /// yalnızca `user` değişince tetiklenir (`fetchMyLeaderboardRank`),
  /// burada da `_onAuthEvent`'in aynı hesap-değişimi kilidiyle tazeleniyor.
  MyLeaderboardRank? _myRank;

  @override
  void initState() {
    super.initState();
    _lastUserId = auth.user?.id;
    _refreshRequestCount();
    _refreshMyRank();
    auth.addListener(_onAuthEvent);
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthEvent);
    super.dispose();
  }

  // Hesap değişimi kararı user.id ile (web "user referansı hesap değişimi
  // değildir" dersi) — değişimde eski hesabın rozeti sıfırlanıp yenisi çekilir.
  void _onAuthEvent() {
    final id = auth.user?.id;
    if (id == _lastUserId) return;
    _lastUserId = id;
    if (mounted) {
      setState(() {
        _incomingRequests = 0;
        _myRank = null;
      });
    }
    _refreshRequestCount();
    _refreshMyRank();
  }

  void _refreshRequestCount() {
    final friends = widget.friends;
    if (friends == null || auth.user == null) return;
    friends.incomingRequests().then((r) {
      if (mounted && r != null) setState(() => _incomingRequests = r.length);
    });
  }

  void _refreshMyRank() {
    final stats = widget.stats;
    final userId = auth.user?.id;
    if (stats == null || userId == null) return;
    stats.myRank(userId).then((r) {
      if (mounted) setState(() => _myRank = r);
    });
  }

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
      onTap: () => showLoginModal(context, auth, feedback: feedback),
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
        final friends = widget.friends;
        switch (value) {
          case 'friends':
            if (friends != null) {
              showFriendsModal(context,
                      friends: friends,
                      auth: auth,
                      stats: stats,
                      games: games)
                  // Web UserMenu deseni: modal kapanınca sayaç tazelenir
                  // (içeride istek yanıtlanmış olabilir).
                  .then((_) => _refreshRequestCount());
            }
          case 'league':
            if (stats != null) {
              showLeaderboard(context,
                  auth: auth, stats: stats, games: games, friends: friends);
            }
          case 'score':
            if (stats != null) {
              showScoreCard(context,
                  auth: auth, stats: stats, games: games, friends: friends);
            }
          case 'help':
            showHelpModal(context);
          case 'settings':
            showAccountSettingsModal(context, auth);
          case 'signout':
            auth.signOut();
        }
      },
      itemBuilder: (context) => [
        // İsim başlığı — web dropdown'ının üst bölümü. Web'de bu, TEK bir
        // tıklanamaz blok DEĞİL: avatar+isim satırı sabit dururken, hemen
        // altındaki KLigMark+"#sıra · puan" satırı AYRI, KENDİ başına
        // tıklanabilir bir `<button>` (bkz. UserMenu.tsx satır ~197-216) —
        // "k-lig Sıralama" web'de bu listenin ayrı bir maddesi DEĞİL, isim
        // başlığının bir PARÇASI (kullanıcı 9 Ağustos 2026'da cihaz
        // testinde "k-lig Sıralama diye ayrı bir madde çıkmış, o aslında
        // isim altında yer alan bir özellik" diye bildirdi). Dış öğe
        // `enabled: false` (kendi seçimi yok) ama içteki k-lig satırı
        // `Navigator.pop(context, 'league')`'i ELLE çağırıp PopupMenuButton
        // ile AYNI mekanizmayı (showMenu'nün route'unu bir değerle kapatıp
        // `onSelected`i tetiklemek) tetikliyor — bu, devre dışı bir
        // `PopupMenuItem`in İÇİNDE bağımsız tıklanabilir bir alt-widget
        // kurmanın standart yolu.
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              KAvatar(
                  url: auth.profile?.avatarUrl, name: auth.menuName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.menuName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _text),
                    ),
                    if (stats != null && _myRank != null) ...[
                      const SizedBox(height: 2),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop('league'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const KLigMark(height: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text.rich(
                                TextSpan(children: [
                                  TextSpan(text: '#${_myRank!.rank}'),
                                  const TextSpan(text: ' · '),
                                  TextSpan(text: '${_myRank!.totalScore}'),
                                  const TextSpan(
                                    text: ' puan',
                                    style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        color: _muted),
                                  ),
                                ]),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.friends != null)
          PopupMenuItem<String>(
            value: 'friends',
            child: Row(children: [
              const Text('👥  Arkadaşlar', style: itemStyle),
              if (_incomingRequests > 0) ...[
                const SizedBox(width: 8),
                CountBadge(count: _incomingRequests),
              ],
            ]),
          ),
        if (stats != null)
          const PopupMenuItem<String>(
            value: 'score',
            child: Text('📊  Skor Kartı', style: itemStyle),
          ),
        const PopupMenuItem<String>(
          value: 'help',
          child: Text('❓  Nasıl Oynanır?', style: itemStyle),
        ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Text('⚙️  Hesap Ayarları', style: itemStyle),
        ),
        // Web: `border-t border-border` — Çıkış Yap'ın kendi üstündeki
        // AYRI çizgi, admin bloğu olsun olmasın hep var (bkz. UserMenu.tsx).
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Text('🚪  Çıkış Yap', style: itemStyle),
        ),
      ],
      child: KAvatar(
        url: auth.profile?.avatarUrl,
        name: auth.menuName,
        size: avatarSize,
        // Web Avatar `dot`: bekleyen iş VAR/YOK göstergesi (sayı değil).
        dot: _incomingRequests > 0,
      ),
    );
  }
}
