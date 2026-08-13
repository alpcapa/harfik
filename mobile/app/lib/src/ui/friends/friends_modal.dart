// Arkadaşlar modalı — src/components/FriendsModal.tsx portu: üç sekme
// (Arkadaşlarım / İstekler / Ara & Ekle) + kalıcı davet linkini sistem
// paylaş sayfasıyla gönderme.
//
// Web'den taşınan davranışlar:
// - Varsayılan sekme: bekleyen istek varsa "İstekler" (appliedDefaultTabRef
//   deseni — çağıran initialTab belirttiyse o niyet ezilmez).
// - Arama 350ms debounce + en az 2 karakter; kutu boşken "Tüm Üyeler"
//   sayfalı listesi (20'şer), HER yeni sayfadan sonra TÜM birikmiş liste
//   trCompare ile yeniden sıralanır (Türkçe collation sayfa sınırı dersi).
// - İlişki değişince arama + tüm-üyeler listesi birlikte yamalanır
//   (patchRelation).
// - Çıkar / Reddet / İptal üçlüsü onay diyaloğundan geçer, sonuç
//   diyaloğuyla biter (web ConfirmDialog/InfoDialog).
//
// Bilinçli sapmalar: davet paylaşımı her zaman sistem paylaş sayfası
// (web'in clipboard fallback'i mobilde gereksiz — paylaş sayfası her
// platformda var); 🔗 emoji yerine Icons.link (bundled fontlarda glyph
// yok dersi ×3).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show trCompare, trUpper;
import 'package:share_plus/share_plus.dart';

import '../../data/auth_service.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../game/count_badge.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import '../score/player_score_card_modal.dart';
import '../tokens.dart';

const Color _text = kText;
const Color _muted = kMuted;
const Color _accent = kAccent;
// Web tailwind `red` — arkadaşlıktan çıkar ikonu.
const Color _red = kRed;
const Color _border = kBorder;
const Color _bg = Colors.white;

enum FriendsTab { friends, requests, search }

/// Web ALL_USERS_PAGE_SIZE.
const int kAllUsersPageSize = 20;

Future<void> showFriendsModal(
  BuildContext context, {
  required FriendsRepo friends,
  required AuthService auth,
  StatsRepo? stats,
  Future<GamesRepo>? games,
  FriendsTab? initialTab,
  Future<void> Function(String text)? sharer,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => FriendsModal(
      friends: friends,
      auth: auth,
      stats: stats,
      games: games,
      initialTab: initialTab,
      sharer: sharer,
    ),
  );
}

class FriendsModal extends StatefulWidget {
  final FriendsRepo friends;
  final AuthService auth;

  /// Arkadaş satırına dokununca açılan skor kartı için — null ise dokunuş
  /// pasif (pratikte friends varsa stats de var, ikisi de Supabase ister).
  final StatsRepo? stats;
  final Future<GamesRepo>? games;

  /// null: varsayılan-sekme kuralı çalışır (bekleyen istek → İstekler).
  /// Açıkça verilirse (web `initialTab`) o niyet ezilmez.
  final FriendsTab? initialTab;

  /// Davet metnini paylaşan uç — testler sahte geçer; üretimde share_plus.
  final Future<void> Function(String text)? sharer;

  const FriendsModal({
    super.key,
    required this.friends,
    required this.auth,
    this.stats,
    this.games,
    this.initialTab,
    this.sharer,
  });

  @override
  State<FriendsModal> createState() => _FriendsModalState();
}

class _FriendsModalState extends State<FriendsModal> {
  late FriendsTab _tab = widget.initialTab ?? FriendsTab.friends;
  late bool _appliedDefaultTab = widget.initialTab != null;

  List<FriendRow>? _friends;
  List<IncomingFriendRequest>? _requests;

  final _query = TextEditingController();
  Timer? _searchTimer;
  int _searchSeq = 0;
  List<FriendCandidate> _results = const [];
  bool _searching = false;

  List<FriendCandidate>? _allUsers;
  bool _allUsersHasMore = true;
  bool _allUsersLoadingMore = false;
  final _allUsersScroll = ScrollController();

  String? _busyId;
  bool _inviteBusy = false;

  @override
  void initState() {
    super.initState();
    _reloadFriends();
    _reloadRequests();
    _allUsersScroll.addListener(() {
      if (_allUsersScroll.position.extentAfter < 80) _loadMoreAllUsers();
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _query.dispose();
    _allUsersScroll.dispose();
    super.dispose();
  }

  void _reloadFriends() {
    widget.friends.friends().then((f) {
      if (mounted && f != null) setState(() => _friends = f);
      // null (ağ hatası): eski liste korunur — mobil null-on-error kararı.
      if (mounted && f == null && _friends == null) {
        setState(() => _friends = const []);
      }
    });
  }

  void _reloadRequests() {
    widget.friends.incomingRequests().then((r) {
      if (!mounted) return;
      setState(() {
        if (r != null) {
          _requests = r;
        } else {
          _requests ??= const [];
        }
        // Varsayılan sekme: bekleyen istek varsa "İstekler" — yalnızca
        // GERÇEK sunucu verisiyle ve bir kez (web hasFreshGames dersi:
        // karar bayat/boş veriyle verilirse kalıcı yanlış kalır).
        if (!_appliedDefaultTab && r != null) {
          _appliedDefaultTab = true;
          if (r.isNotEmpty) _tab = FriendsTab.requests;
        }
      });
    });
  }

  void _onQueryChanged(String raw) {
    _searchTimer?.cancel();
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final seq = ++_searchSeq;
    _searchTimer = Timer(const Duration(milliseconds: 350), () async {
      final r = await widget.friends.search(q);
      if (mounted && _searchSeq == seq) {
        setState(() {
          _results = r ?? const [];
          _searching = false;
        });
      }
    });
  }

  void _ensureAllUsers() {
    if (_allUsers != null) return;
    widget.friends.listUsers(0, kAllUsersPageSize).then((page) {
      if (!mounted || page == null) return;
      setState(() {
        _allUsers = [...page]..sort((a, b) => trCandidate(a, b));
        _allUsersHasMore = page.length == kAllUsersPageSize;
      });
      _autoLoadIfNotScrollable();
    });
  }

  void _loadMoreAllUsers() {
    final cur = _allUsers;
    if (cur == null || !_allUsersHasMore || _allUsersLoadingMore) return;
    _allUsersLoadingMore = true;
    widget.friends.listUsers(cur.length, kAllUsersPageSize).then((page) {
      if (!mounted) return;
      setState(() {
        _allUsersLoadingMore = false;
        if (page == null) return;
        // Web dersi: her sayfadan sonra TÜM birikmiş liste yeniden sıralanır.
        _allUsers = [...cur, ...page]..sort((a, b) => trCandidate(a, b));
        _allUsersHasMore = page.length == kAllUsersPageSize;
      });
      _autoLoadIfNotScrollable();
    });
  }

  void _patchRelation(String id, FriendRelation? relation) {
    setState(() {
      _results = [
        for (final u in _results) u.id == id ? u.withRelation(relation) : u
      ];
      final all = _allUsers;
      if (all != null) {
        _allUsers = [
          for (final u in all) u.id == id ? u.withRelation(relation) : u
        ];
      }
    });
  }

  /// "Ara & Ekle" listeleri zaten arkadaş olunanları GÖSTERMEZ (kullanıcı
  /// isteği, 11 Ağustos 2026) — onlar "Arkadaşlarım" sekmesinde. Eleme
  /// fetch'te değil RENDER'da: (1) `_allUsers.length` sayfalama offset'i
  /// olduğundan diziden atmak sayfaları kaydırıp üye atlatırdı; (2) satır
  /// ekrandayken arkadaş olunursa `_patchRelation` ilişkiyi accepted yapar
  /// ve satır kendiliğinden düşer.
  static bool _notFriend(FriendCandidate u) =>
      u.relation != FriendRelation.accepted;

  List<FriendCandidate> get _visibleResults =>
      _results.where(_notFriend).toList();

  List<FriendCandidate>? get _visibleAllUsers =>
      _allUsers?.where(_notFriend).toList();

  /// Elemeden sonra liste kaydırılamayacak kadar kısaysa (ör. bir sayfanın
  /// tamamı arkadaş çıktı) `_allUsersScroll` dinleyicisi HİÇ ateşlenmez ve
  /// sonraki sayfa asla istenmez — Parça 31'deki k-lig hatasının aynısı.
  /// Her yüklemeden sonra bir kare bekleyip elle kontrol ediyoruz.
  void _autoLoadIfNotScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_allUsersHasMore) return;
      if (!_allUsersScroll.hasClients) return;
      if (_allUsersScroll.position.maxScrollExtent <= 0) _loadMoreAllUsers();
    });
  }

  Future<FriendRelation?> _handleSend(FriendCandidate u) async {
    setState(() => _busyId = u.id);
    try {
      final result = await widget.friends.sendRequest(u.id);
      _patchRelation(u.id, result);
      if (result == FriendRelation.accepted) _reloadFriends();
      return result;
    } catch (e) {
      debugPrint('[Kelimeki] arkadaşlık isteği hatası: $e');
      return null;
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _handleRespond(String requesterId, {required bool accept}) async {
    setState(() => _busyId = requesterId);
    try {
      await widget.friends.respond(requesterId, accept: accept);
      _patchRelation(requesterId, accept ? FriendRelation.accepted : null);
      _reloadRequests();
      if (accept) _reloadFriends();
    } catch (e) {
      debugPrint('[Kelimeki] istek yanıtlama hatası: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _handleInvite() async {
    setState(() => _inviteBusy = true);
    try {
      final url = await widget.friends.inviteUrl();
      if (url == null) return;
      final share = widget.sharer ??
          (String text) async {
            await SharePlus.instance.share(ShareParams(text: text));
          };
      await share('$inviteShareText\n$url');
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KModal(
      title: 'Arkadaşlar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          NeoButton(
            label: _inviteBusy ? '…' : 'ARKADAŞINI DAVET ET',
            variant: NeoButtonVariant.accent,
            fontSize: 12,
            letterSpacing: 1.5,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
            onPressed: _inviteBusy ? null : _handleInvite,
          ),
          const SizedBox(height: 6),
          const Text(
            "Kelimeki'de henüz olmayan arkadaşlarını davet et",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'SpaceMono', fontSize: 10, color: _muted),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              _tabBtn(FriendsTab.friends, 'Arkadaşlarım'),
              _tabBtn(FriendsTab.requests, 'İstekler',
                  badge: _requests?.length ?? 0),
              _tabBtn(FriendsTab.search, 'Ara & Ekle'),
            ]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            FriendsTab.friends => _friendsList(),
            FriendsTab.requests => _requestsList(),
            FriendsTab.search => _searchTab(),
          },
        ],
      ),
    );
  }

  Widget _tabBtn(FriendsTab t, String label, {int badge = 0}) {
    final active = _tab == t;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Elle seçim varsayılan-sekme kararını kalıcı devre dışı bırakır
          // (web guard'ı: istekler sonradan gelince seçimi ezmesin).
          _appliedDefaultTab = true;
          setState(() => _tab = t);
          if (t == FriendsTab.search) _ensureAllUsers();
        },
        // Rozet web'deki gibi SEKME KUTUSUNUN sağ üst köşesinde (`absolute
        // -top-1 -right-1` = -4px) — Stack metni değil kutuyu sarmalı
        // (LiveGamesTab'la aynı düzeltme, kullanıcı bildirdi).
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                trUpper(label), // web tabBtn CSS `uppercase`
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11, // web text-[11px]
                  height: 1.5, // web: gövdeden miras (16.5px satır)
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: active ? Colors.white : _muted,
                ),
              ),
            ),
            if (badge > 0)
              Positioned(top: -4, right: -4, child: CountBadge(count: badge)),
          ],
        ),
      ),
    );
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Yükleniyor…',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
      );

  Widget _emptyText(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(s,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
      );

  Widget _row({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      );

  Widget _name(String s) => Expanded(
        child: Text(s,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: _text)),
      );

  Widget _friendsList() {
    final friends = _friends;
    if (friends == null) return _loading();
    if (friends.isEmpty) {
      return _emptyText('Henüz arkadaşın yok — "Ara & Ekle" sekmesinden ya '
          'da yukarıdaki davet linkiyle ekleyebilirsin.');
    }
    return Column(children: [
      for (final f in friends)
        _row(
          child: Row(children: [
            _personButton(f.friendId, f.name, f.avatarUrl),
            _relationIconButton(
              icon: Icons.person_remove,
              color: _red,
              label: '${f.name} — arkadaşlıktan çıkar',
              busy: _busyId == f.friendId,
              onTap: () => _confirmThenRemoveFriend(f),
            ),
          ]),
        ),
    ]);
  }

  Widget _requestsList() {
    final requests = _requests;
    if (requests == null) return _loading();
    if (requests.isEmpty) return _emptyText('Bekleyen istek yok.');
    return Column(children: [
      for (final r in requests)
        _row(
          child: Row(children: [
            _personButton(r.requesterId, r.name, r.avatarUrl),
            const SizedBox(width: 6),
            _smallButton('Kabul Et',
                busy: _busyId == r.requesterId,
                onTap: () => _handleRespond(r.requesterId, accept: true)),
            const SizedBox(width: 6),
            _smallButton('Reddet',
                neutral: true,
                busy: _busyId == r.requesterId,
                onTap: () => _confirmThenReject(r)),
          ]),
        ),
    ]);
  }

  Widget _searchTab() {
    _ensureAllUsers();
    final q = _query.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          onChanged: _onQueryChanged,
          autofocus: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _bg,
            hintText: 'İsim ya da takma ad ara…',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF8A93A2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _accent)),
          ),
        ),
        const SizedBox(height: 10),
        if (q.length >= 2)
          _searching
              ? _emptyText('Aranıyor…')
              : _visibleResults.isEmpty
                  ? _emptyText(_results.isEmpty
                      ? "Kimse bulunamadı — Kelimeki'de değilse "
                          'yukarıdaki davet linkini gönderebilirsin.'
                      : 'Bulunanların hepsi zaten arkadaşın — '
                          '"Arkadaşlarım" sekmesine bak.')
                  : Column(
                      children: [
                        for (final u in _visibleResults) _candidateRow(u)
                      ])
        else ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('TÜM ÜYELER',
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    letterSpacing: 1,
                    color: _muted)),
          ),
          if (_visibleAllUsers == null)
            _loading()
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                controller: _allUsersScroll,
                shrinkWrap: true,
                children: [
                  for (final u in _visibleAllUsers!) _candidateRow(u),
                  // Boş mesajı yalnızca liste GERÇEKTEN tükendiyse — bir
                  // sayfanın tamamı arkadaş çıkarsa daha yüklenecek üye var.
                  if (_visibleAllUsers!.isEmpty && !_allUsersHasMore)
                    _emptyText('Eklenecek başka üye yok.'),
                  if (_allUsersHasMore)
                    _emptyText(_allUsersLoadingMore ? 'Yükleniyor…' : ''),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Web renderFriendRow — ilişkiye göre ekle / bekliyor (iptal) / kabul /
  /// çıkar. **Metin butonları 11 Ağustos 2026'da ikonlara indirildi**
  /// (web `RelationIcons.tsx` ile aynı sözlük): ikon, dokunuşun NE YAPACAĞINI
  /// söyler, ilişkinin adını değil — bu yüzden "arkadaşsınız" durumu yeşil
  /// onay değil kırmızı `person_remove`. Flutter fontu gömülü taşıdığından
  /// `Icons.*` doğrudan kullanılıyor; web aynı glyph'leri bu fonttan
  /// çıkarılmış SVG path'leriyle çiziyor, yani iki platform BENZER değil
  /// AYNI vektörü gösteriyor.
  ///
  /// Dört dalın DÖRDÜ de önce bir onay diyaloğu açar, hiçbiri anında iş
  /// yapmaz. `accepted` dalı pratikte ULAŞILAMAZ (bu satır yalnızca
  /// "Ara & Ekle" listelerinde çiziliyor ve orası arkadaşları eliyor, bkz.
  /// `_notFriend`) — savunma amaçlı duruyor: silinirse bir gün eleme
  /// atlanınca arkadaşa "ekle" ikonu gösterilirdi. "Arkadaşlarım" sekmesi
  /// bu satırı kullanmaz, kendi çıkarma butonu var.
  Widget _candidateRow(FriendCandidate u) {
    final (IconData ikon, Color renk, String etiket, VoidCallback aksiyon) =
        switch (u.relation) {
      FriendRelation.accepted => (
          Icons.person_remove,
          _red,
          'Arkadaşlıktan çıkar',
          () => _confirmThenRemoveCandidate(u),
        ),
      FriendRelation.pendingOutgoing => (
          Icons.hourglass_top,
          _muted,
          'İstek gönderildi — iptal et',
          () => _confirmThenCancel(u),
        ),
      FriendRelation.pendingIncoming => (
          Icons.how_to_reg,
          _accent,
          'Arkadaşlık isteğini kabul et',
          () => _confirmThenAdd(u),
        ),
      null => (
          Icons.person_add_alt_1,
          _accent,
          'Arkadaş ekle',
          () => _confirmThenAdd(u),
        ),
    };
    final Widget action = _relationIconButton(
      icon: ikon,
      color: renk,
      label: '${u.name} — $etiket',
      busy: _busyId == u.id,
      onTap: aksiyon,
    );
    return _row(
      child: Row(children: [
        _personButton(u.id, u.name, u.avatarUrl),
        action,
      ]),
    );
  }

  /// Avatar+isim: dokununca o kişinin skor kartı. "Arkadaşlarım"da baştan
  /// beri vardı, ÜÇ listede de olmalı (kullanıcı isteği, 11 Ağustos 2026) —
  /// hele "İstekler"de, isteği yanıtlamadan önce kimin gönderdiğine bakmak
  /// tam da orada gerekiyor. Kart kapanınca ilişki yeniden okunuyor: kullanıcı
  /// kartın İÇİNDEN arkadaş ekleyip çıkabildiğinden (`PlayerScoreCardModal`'ın
  /// kendi simgesi) arkadaki satırın ikonu yoksa bayat kalırdı.
  Widget _personButton(String id, String name, String? avatarUrl) {
    final stats = widget.stats;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: stats == null
            ? null
            : () async {
                await showPlayerScoreCard(
                  context,
                  stats: stats,
                  userId: id,
                  name: name,
                  avatarUrl: avatarUrl,
                  games: widget.games,
                  friends: widget.friends,
                  auth: widget.auth,
                );
                if (!mounted) return;
                final r = await widget.friends.relationWith(id);
                if (!mounted) return;
                _patchRelation(id, r);
                _reloadFriends();
                _reloadRequests();
              },
        child: Row(children: [
          KAvatar(url: avatarUrl, name: name, size: 32),
          const SizedBox(width: 10),
          _name(name),
        ]),
      ),
    );
  }

  /// 44px dokunma hedefi (iOS asgarisi) içinde 20px ikon. Metin kalktığı
  /// için `Semantics.label` artık ekran okuyucunun TEK bilgi kaynağı — boş
  /// bırakma. Web'deki aynı buton `w-11 h-11` + `aria-label` taşıyor.
  Widget _relationIconButton({
    required IconData icon,
    required Color color,
    required String label,
    required bool busy,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Opacity(
              opacity: busy ? 0.4 : 1,
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallButton(String label,
      {bool neutral = false, bool busy = false, VoidCallback? onTap}) {
    return NeoButton(
      // Web smallBtn CSS `uppercase` — Türkçe-farkındalı karşılığı trUpper.
      label: busy ? '…' : trUpper(label),
      variant: neutral ? NeoButtonVariant.neutral : NeoButtonVariant.accent,
      fontSize: 10,
      letterSpacing: 0.5,
      // web `py-1.5 px-3`
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      onPressed: busy ? null : onTap,
    );
  }

  // ── Onay/sonuç diyalogları (web ConfirmDialog/InfoDialog) ────────────────

  /// "Ekle" ve "Kabul Et" de onaydan geçer (11 Ağustos 2026): metin butonları
  /// ikonlara indiği için etiketsiz bir ikona kazara dokunmak çok daha kolay,
  /// üstelik `PlayerScoreCard` dört ilişki dalının HEPSİNDE zaten onay
  /// soruyordu — iki ekran arasındaki asimetri kapatıldı. Metin ilişkiden
  /// türetiliyor; sözler `player_score_card_modal.dart` ile BİREBİR aynı.
  Future<void> _confirmThenAdd(FriendCandidate u) async {
    final incoming = u.relation == FriendRelation.pendingIncoming;
    final ok = await confirmFriendAction(
      context,
      title: incoming ? 'Arkadaşlık İsteği' : 'Arkadaş Ekle',
      message: incoming
          ? '${u.name} oyuncusu sana arkadaşlık isteği gönderdi. '
              'Kabul etmek istiyor musun?'
          : '${u.name} oyuncusunu arkadaş olarak eklemek istiyor musun?',
      confirmLabel: incoming ? 'Kabul Et' : 'Ekle',
    );
    if (!ok || !mounted) return;
    String message;
    if (incoming) {
      await _handleRespond(u.id, accept: true);
      message = 'Arkadaş oldunuz.';
    } else {
      final result = await _handleSend(u);
      // Karşı taraftan zaten bekleyen bir istek varsa sunucu trigger'ı
      // ilişkiyi anında accepted yapar — mesaj bunu yansıtmalı.
      message = result == FriendRelation.accepted
          ? 'Arkadaş oldunuz.'
          : 'Arkadaşlık isteğiniz iletilmiştir.';
    }
    if (!mounted) return;
    await showFriendInfoDialog(context, message);
  }

  /// "Ara & Ekle" listesindeki `accepted` satırından çıkarma. Web'de bu satır
  /// eskiden tıklanamaz bir "Arkadaşsınız" metniydi; ikona dönünce çıkarma
  /// yolu buradan da açıldı. `_confirmThenRemoveFriend` FriendRow istediği
  /// için ayrı bir sarmalayıcı — onay/sonuç metinleri BİREBİR aynı.
  Future<void> _confirmThenRemoveCandidate(FriendCandidate u) async {
    final ok = await confirmFriendAction(
      context,
      title: 'Arkadaşlıktan Çıkar',
      message:
          '${u.name} ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?',
      confirmLabel: 'Çıkar',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = u.id);
    try {
      await widget.friends.removeOrCancel(u.id);
      // Listedeki ikon anında person_add'e dönsün + Arkadaşlarım tazelensin.
      _patchRelation(u.id, null);
      _reloadFriends();
      if (mounted) {
        await showFriendInfoDialog(context, 'Arkadaşlıktan çıkarıldı.');
      }
    } catch (e) {
      debugPrint('[Kelimeki] arkadaş çıkarma hatası: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmThenRemoveFriend(FriendRow f) async {
    final ok = await confirmFriendAction(
      context,
      title: 'Arkadaşlıktan Çıkar',
      message:
          '${f.name} ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?',
      confirmLabel: 'Çıkar',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = f.friendId);
    try {
      await widget.friends.removeOrCancel(f.friendId);
      _reloadFriends();
      if (mounted) {
        await showFriendInfoDialog(context, 'Arkadaşlıktan çıkarıldı.');
      }
    } catch (e) {
      debugPrint('[Kelimeki] arkadaş çıkarma hatası: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmThenReject(IncomingFriendRequest r) async {
    final ok = await confirmFriendAction(
      context,
      title: 'İsteği Reddet',
      message:
          '${r.name} oyuncusunun arkadaşlık isteğini reddetmek mi istiyorsunuz?',
      confirmLabel: 'Reddet',
    );
    if (!ok || !mounted) return;
    await _handleRespond(r.requesterId, accept: false);
    if (mounted) await showFriendInfoDialog(context, 'İstek reddedildi.');
  }

  Future<void> _confirmThenCancel(FriendCandidate u) async {
    final ok = await confirmFriendAction(
      context,
      title: 'İsteği İptal Et',
      message: '${u.name} oyuncusuna gönderdiğin arkadaşlık isteğini iptal '
          'etmek istiyor musun?',
      confirmLabel: 'İptal Et',
    );
    if (!ok || !mounted) return;
    setState(() => _busyId = u.id);
    try {
      await widget.friends.removeOrCancel(u.id);
      _patchRelation(u.id, null);
      if (mounted) {
        await showFriendInfoDialog(context, 'Arkadaşlık isteği iptal edildi.');
      }
    } catch (e) {
      debugPrint('[Kelimeki] istek iptal hatası: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

int trCandidate(FriendCandidate a, FriendCandidate b) =>
    trCompare(a.name, b.name);

/// Web ConfirmDialog — Onayla/Vazgeç; true = onaylandı. PlayerScoreCard'ın
/// arkadaşlık simgesi de aynı diyaloğu kullanır (paylaşılan).
Future<bool> confirmFriendAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: kPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      // Web `ConfirmDialog`: `max-w-sm` (384px) — Flutter'ın `Dialog`ı
      // VARSAYILAN OLARAK yalnızca `minWidth: 280` taşıyor, üst sınır YOK
      // (kaynak: dialog.dart, `constraints ?? ... ?? BoxConstraints
      // (minWidth: 280.0)`). Geniş bir ekranda (iPad) bu, `insetPadding`in
      // bıraktığı TÜM genişliğe yayılıp diyaloğu "upuzun" gösteriyordu
      // (9 Ağustos 2026, kullanıcı ekran görüntüsüyle bildirdi).
      constraints: const BoxConstraints(maxWidth: 384),
      child: Padding(
        // web `p-6` = 24 (13 Ağustos 2026: port 20 kullanıyordu — dolgu
        // kutunun İÇİNDE olduğundan yapı doğruydu ama DEĞER sapmıştı,
        // içerik 344 yerine 336 olmalı).
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: _text)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: NeoButton(
                  label: trUpper(confirmLabel),
                  variant: NeoButtonVariant.accent,
                  fontSize: 11,
                  letterSpacing: 1,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: NeoButton(
                  label: 'VAZGEÇ',
                  variant: NeoButtonVariant.neutral,
                  fontSize: 11,
                  letterSpacing: 1,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// Web InfoDialog — tek "Tamam" butonlu sonuç mesajı.
Future<void> showFriendInfoDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: kPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      // bkz. confirmFriendAction'daki aynı gerekçe — Dialog'un varsayılan
      // üst genişlik sınırsızlığı.
      constraints: const BoxConstraints(maxWidth: 384),
      child: Padding(
        // web `p-6` = 24 (13 Ağustos 2026: port 20 kullanıyordu — dolgu
        // kutunun İÇİNDE olduğundan yapı doğruydu ama DEĞER sapmıştı,
        // içerik 344 yerine 336 olmalı).
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: _text)),
            const SizedBox(height: 16),
            NeoButton(
              label: 'TAMAM',
              variant: NeoButtonVariant.accent,
              fontSize: 11,
              letterSpacing: 1,
              padding: const EdgeInsets.symmetric(vertical: 10),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
