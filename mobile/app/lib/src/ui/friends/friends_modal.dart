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

const Color _text = Color(0xFF1B2430);
const Color _muted = Color(0xFF5A6673);
const Color _accent = Color(0xFF2563EB);
const Color _border = Color(0xFFDCE2EA);
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

  Future<void> _handleSend(FriendCandidate u) async {
    setState(() => _busyId = u.id);
    try {
      final result = await widget.friends.sendRequest(u.id);
      _patchRelation(u.id, result);
      if (result == FriendRelation.accepted) _reloadFriends();
    } catch (e) {
      debugPrint('[Kelimeki] arkadaşlık isteği hatası: $e');
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
                  fontSize: 10,
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
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.stats == null
                    ? null
                    : () => showPlayerScoreCard(
                          context,
                          stats: widget.stats!,
                          userId: f.friendId,
                          name: f.name,
                          avatarUrl: f.avatarUrl,
                          games: widget.games,
                          friends: widget.friends,
                        ),
                child: Row(children: [
                  KAvatar(url: f.avatarUrl, name: f.name, size: 32),
                  const SizedBox(width: 10),
                  _name(f.name),
                ]),
              ),
            ),
            _smallButton(
              'Çıkar',
              neutral: true,
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
            KAvatar(url: r.avatarUrl, name: r.name, size: 32),
            const SizedBox(width: 10),
            _name(r.name),
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
              : _results.isEmpty
                  ? _emptyText("Kimse bulunamadı — Kelimeki'de değilse "
                      'yukarıdaki davet linkini gönderebilirsin.')
                  : Column(
                      children: [for (final u in _results) _candidateRow(u)])
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
          _allUsers == null
              ? _loading()
              : _allUsers!.isEmpty
                  ? _emptyText('Henüz başka üye yok.')
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView(
                        controller: _allUsersScroll,
                        shrinkWrap: true,
                        children: [
                          for (final u in _allUsers!) _candidateRow(u),
                          if (_allUsersHasMore)
                            _emptyText(_allUsersLoadingMore ? 'Yükleniyor…' : ''),
                        ],
                      ),
                    ),
        ],
      ],
    );
  }

  /// Web renderFriendRow — ilişkiye göre Ekle / İstek Gönderildi (iptal) /
  /// Kabul Et / Arkadaşsınız.
  Widget _candidateRow(FriendCandidate u) {
    final Widget action = switch (u.relation) {
      FriendRelation.accepted => const Text('ARKADAŞSINIZ',
          style: TextStyle(
              fontFamily: 'SpaceMono', fontSize: 9, color: _muted)),
      FriendRelation.pendingOutgoing => GestureDetector(
          onTap: _busyId == u.id ? null : () => _confirmThenCancel(u),
          child: const Text('İSTEK GÖNDERİLDİ',
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 9,
                  color: _muted,
                  decoration: TextDecoration.underline)),
        ),
      FriendRelation.pendingIncoming => _smallButton('Kabul Et',
          busy: _busyId == u.id,
          onTap: () => _handleRespond(u.id, accept: true)),
      null => _smallButton('Ekle',
          busy: _busyId == u.id, onTap: () => _handleSend(u)),
    };
    return _row(
      child: Row(children: [
        KAvatar(url: u.avatarUrl, name: u.name, size: 32),
        const SizedBox(width: 10),
        _name(u.name),
        action,
      ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      onPressed: busy ? null : onTap,
    );
  }

  // ── Onay/sonuç diyalogları (web ConfirmDialog/InfoDialog) ────────────────

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
      backgroundColor: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
      backgroundColor: const Color(0xFFF5F7FA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFB8C2D1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
