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
import '../../data/chat_api.dart';
import '../../data/feedback_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../data/friends_api.dart';
import '../friends/friends_modal.dart';
import '../game/count_badge.dart';
import '../game/help_modal.dart';
import '../game/neo_box.dart';
import '../rank/league_rank.dart';
import '../rank/rank_seal.dart';
import '../score/klig_mark.dart';
import '../score/leaderboard_modal.dart';
import '../score/score_card_modal.dart';
import 'account_settings_modal.dart';
import 'k_avatar.dart';
import 'auth_modal.dart';
import '../tokens.dart';

const Color _text = kText;
const Color _muted = kMuted;
const Color _panel = kPanel;
const Color _border = kBorder;

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

  /// Arkadaş satırındaki moderasyon (🚫/🚩) ikonu için — null ise ikon yok.
  final ChatRepo? chat;

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
    this.chat,
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
          color: kAccent,
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

  // Web: `w-56` (224px) sabit menü genişliği, satırlar `px-3 py-2.5`
  // (12/10px). Flutter'ın `PopupMenuItem`'ı bunları HİÇ paylaşmıyor —
  // varsayılan `padding` yatayda 16px VE varsayılan `height` (kaldırma
  // dokunma hedefi için `kMinInteractiveDimension`, 48px) satır başına
  // ZORUNLU bir minimum yükseklik dayatıyor; web'in gerçek satır boyu
  // (py-2.5 + 12px punto) bundan belirgin şekilde kısa. Aradaki fark
  // menüyü hem daha GENİŞ hem satırlar arası daha AÇIK gösteriyordu
  // (kullanıcı 9 Ağustos 2026'da iki ekran görüntüsüyle bildirdi — Parça
  // 29). Her `PopupMenuItem` artık bu ikisini elle web değerlerine
  // eziyor; `_menuItemWidth` de her satırın İÇERİK genişliğini sabitleyip
  // (`SizedBox`) menünün toplam genişliğinin web'in `w-56`sına yakınsamasını
  // sağlıyor (Flutter menü genişliğini en geniş satırın intrinsic
  // genişliğine göre hesaplıyor, sabit bir `width` API'si yok).
  //
  // **Parça 30 — Parça 29'un ardından hâlâ fazla boşluk kalıyordu, iki
  // ayrı kök sebep bulundu (ölçülerek, tahminle değil — `flutter test`te
  // gerçek satır Size'ları okundu):**
  // (1) "Nasıl Oynanır?"/"Hesap Ayarları" satırları 200px genişliğe
  //     SIĞMIYOR, İKİ SATIRA sarıyordu (ölçülen: 200×34 — diğer satırlar
  //     200×17) — kök sebep emoji glyph'inin (❓/⚙️) SpaceMono'da
  //     olmayıp bir yedek fonttan çizilmesi, o yedeğin karakter
  //     genişliğinin monospace hücreden BELİRGİN geniş olması. Web'de bu
  //     metinler asla sarmıyor (statik, kısa etiketler); `maxLines:1` +
  //     `softWrap:false` her satırı KOŞULSUZ tek satıra sabitliyor —
  //     genişlik hesabı ne olursa olsun ikinci satır oluşamaz.
  // (2) Çıkış Yap'ın üstündeki `PopupMenuDivider()` kendi başına 16px'lik
  //     AYRI bir satır ekliyordu — web'in `border-t border-border`ı ise
  //     düğmenin KENDİ kenarına oturan 1px'lik bir çizgi, ekstra bir satır
  //     YOK. Aynı yanlış varsayım başlıkta da vardı — isim başlığının
  //     altında hiç çizgi yoktu (web'de VAR: `border-b border-border`,
  //     yine 1px, ekstra satır değil). İkisi de artık `PopupMenuDivider`
  //     yerine `Container(decoration: BoxDecoration(border: ...))` ile
  //     — web'in border-box modeliyle aynı: çizgi menünün TAM genişliğinde
  //     (224px, `_menuItemWidth + 24`), ama dikey olarak neredeyse hiç yer
  //     kaplamıyor (yalnızca 1px çizgi kalınlığı).
  static const _menuItemPadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  static const _menuItemHeight = 0.0;
  static const _menuItemWidth = 200.0; // 224 (w-56) - 2*12 (px-3)
  static const _dividerBorder = BorderSide(color: _border, width: 1);

  // Emoji glyphi (👥📊❓⚙️🚪) SpaceMono'da yok — yedek font adıyla
  // referans verilmezse (help_modal.dart/player_avatar_row.dart'taki aynı
  // ders) glyph genişliği öngörülemez, bu da satırın 200px'e sığmayıp
  // ikinci satıra sarmasına yol açabiliyordu (bkz. Parça 30 notu, yukarı).
  static const itemStyle = TextStyle(
    fontFamily: 'SpaceMono',
    fontSize: 12,
    color: _text,
    fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji'],
  );

  static Widget _menuLabel(String text) => Text(
        text,
        style: itemStyle,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );

  Widget _avatarMenu(BuildContext context) {
    return PopupMenuButton<String>(
      // Uzun basınca çıkan ipucu kullanıcı isteğiyle kaldırıldı (9 Ağustos
      // 2026) — web'deki `title` attribute'u da aynı anda kaldırıldı.
      // Parametreyi tamamen SİLMEK yanlış olurdu: PopupMenuButton null
      // gelince MaterialLocalizations'ın İngilizce "Show menu" metnine
      // düşüyor. Boş dize doğru yol — Tooltip.build boş mesajda çocuğu
      // olduğu gibi döndürüp hiç overlay kurmuyor (SDK kaynağından
      // doğrulandı, tahmin değil).
      tooltip: '',
      // Avatar YUVARLAK ama Flutter'ın ink katmanı varsayılan olarak
      // DİKDÖRTGEN: `PopupMenuButton`, `child` verildiğinde onu
      // `InkWell(borderRadius: widget.borderRadius, …)` ile sarıyor
      // (`popup_menu.dart:1712`) ve bu parametrenin varsayılanı YOK — null
      // geliyor. Sonuç: hover/focus/basılı vurgusu 32×32 kutuyu boyayıp
      // dairenin dışında kalan dört köşeyi görünür kılıyordu (ölçüldü:
      // basılıyken daire dışında 120 piksel #efefef, dokunulmamışken 0).
      // Web'de bu hiç yaşanmıyor — `UserMenu.tsx`'in butonu `rounded-full`
      // + `focus:outline-none` ve HİÇ zemin vurgusu taşımıyor (tek geri
      // bildirim `active:scale-95`). Yarıçap = kutunun yarısı → kare kutu
      // için tam daire.
      borderRadius: BorderRadius.circular(avatarSize / 2),
      offset: Offset(0, avatarSize + 8),
      color: _panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      // Flutter'ın varsayılanı `EdgeInsets.symmetric(vertical: 8)` — kartın
      // İÇİNE (başlığın üstüne + Çıkış Yap'ın altına) 16px'lik görünmez bir
      // boşluk daha ekliyordu. Web'in kartı (`overflow-hidden` div) hiç
      // ekstra dolgu taşımıyor — içerik doğrudan başlığın kendi `py-3`ü ile
      // başlıyor. Sıfırlamak, satır aralığı/çizgi düzeltmelerinin (yukarı)
      // yanında "hâlâ çok boşluk var" şikayetine üçüncü bir katkıyı kapatıyor.
      menuPadding: EdgeInsets.zero,
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
                      games: games,
                      chat: widget.chat)
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
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          // Web: başlık bloğunun kendi `border-b border-border`ı —
          // isim/k-lig satırıyla "Arkadaşlar" arasında ince bir çizgi
          // (Parça 30, kullanıcı bildirdi — Parça 28'de bu çizgi hiç
          // taşınmamıştı). `padding` PopupMenuItem'dan bu Container'a
          // taşındı ki çizgi menünün TAM genişliğinde (224px) kenardan
          // kenara çizilsin — `PopupMenuDivider` KULLANILMADI, o 16px'lik
          // AYRI bir satır ekler, web'in border'ı ise (kendi 1px kalınlığı
          // dışında) hiç ekstra dikey yer kaplamaz.
          child: Container(
            width: _menuItemWidth + 24,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: _dividerBorder),
            ),
            child: Row(
              children: [
                KAvatar(
                    url: auth.profile?.avatarUrl,
                    name: auth.menuName,
                    size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Rütbe mührü ismin HEMEN YANINDA (web `UserMenu.tsx`
                      // ile aynı yer). Puan ZATEN elde (`_myRank`) —
                      // ekstra bir sorgu YOK. 18px, satırın 14px'lik
                      // puntosuna göre ölçüldü (web'de de aynı).
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              auth.menuName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _text),
                            ),
                          ),
                          if (_myRank != null) ...[
                            const SizedBox(width: 6),
                            RankSeal(
                                tier: tierFor(_myRank!.totalScore), size: 18),
                          ],
                        ],
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
                                    // Web `mx-0.5` = 2px; boşluk KARAKTERİ
                                    // Space Mono'da ~0.6em eder ve iki yanda
                                    // ~6px fazla açar (17 Ağustos 2026 görsel
                                    // turu — aynı sapma iki skor kartında da
                                    // vardı, ÜÇÜ BİRLİKTE düzeltildi).
                                    const WidgetSpan(
                                        child: SizedBox(width: 2)),
                                    const TextSpan(text: '·'),
                                    const WidgetSpan(
                                        child: SizedBox(width: 2)),
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
                                    color: kAccent,
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
        ),
        if (widget.friends != null)
          PopupMenuItem<String>(
            value: 'friends',
            height: _menuItemHeight,
            padding: _menuItemPadding,
            child: SizedBox(
              width: _menuItemWidth,
              child: Row(children: [
                _menuLabel('👥  Arkadaşlar'),
                if (_incomingRequests > 0) ...[
                  const SizedBox(width: 8),
                  CountBadge(count: _incomingRequests),
                ],
              ]),
            ),
          ),
        if (stats != null)
          PopupMenuItem<String>(
            value: 'score',
            height: _menuItemHeight,
            padding: _menuItemPadding,
            child: SizedBox(
              width: _menuItemWidth,
              child: _menuLabel('📊  Skor Kartı'),
            ),
          ),
        PopupMenuItem<String>(
          value: 'help',
          height: _menuItemHeight,
          padding: _menuItemPadding,
          child: SizedBox(
            width: _menuItemWidth,
            child: _menuLabel('❓  Nasıl Oynanır?'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          height: _menuItemHeight,
          padding: _menuItemPadding,
          child: SizedBox(
            width: _menuItemWidth,
            child: _menuLabel('⚙️  Hesap Ayarları'),
          ),
        ),
        // Web: `border-t border-border` — Çıkış Yap'ın kendi üstündeki
        // AYRI çizgi, admin bloğu olsun olmasın hep var (bkz. UserMenu.tsx).
        // `PopupMenuDivider` YERİNE `Container` üst-çizgisi (bkz. yukarıdaki
        // Parça 30 notu) — web'de bu çizgi ekstra bir satır DEĞİL, düğmenin
        // kendi kenarı.
        PopupMenuItem<String>(
          value: 'signout',
          height: _menuItemHeight,
          padding: EdgeInsets.zero,
          child: Container(
            width: _menuItemWidth + 24,
            padding: _menuItemPadding,
            decoration: const BoxDecoration(
              border: Border(top: _dividerBorder),
            ),
            child: _menuLabel('🚪  Çıkış Yap'),
          ),
        ),
      ],
      child: KAvatar(
        url: auth.profile?.avatarUrl,
        name: auth.menuName,
        size: avatarSize,
        // Web Avatar `badgeCount`: menü içindeki rozetlerin toplamı. Portta
        // admin paneli olmadığından (bilinçli, bkz. mobile/CLAUDE.md) tek
        // kaynak arkadaşlık isteği — web ayrıca admin bekleyen işini ekler.
        badgeCount: _incomingRequests,
      ),
    );
  }
}
