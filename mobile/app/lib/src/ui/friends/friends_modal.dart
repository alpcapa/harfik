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
import '../../data/chat_api.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../game/count_badge.dart';
import '../game/dialog_shell.dart';
import '../game/modal_shell.dart';
import '../game/neo_button.dart';
import '../rank/league_rank.dart';
import '../rank/rank_scores.dart';
import '../rank/rank_seal.dart';
import '../score/player_score_card_modal.dart';
import '../tokens.dart';
import '../loading_note.dart';
import '../form_input.dart';
import '../../util/share_board.dart' show shareOriginFrom;
import 'friend_moderation_sheet.dart';
import '../text_scale.dart';

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

/// Onaydan sonra ağ işlemi düşerse gösterilen metin — `chat_settings_modal`
/// aynı dizeyi kullanıyor, yenisi icat edilmedi. Bir onay diyaloğundan
/// GEÇMİŞ bir eylemin sessizce (ya da daha kötüsü, sahte bir "başarılı"
/// mesajıyla) düşmemesi için var.
const String kFriendActionFailed = 'İşlem başarısız oldu.';

Future<void> showFriendsModal(
  BuildContext context, {
  required FriendsRepo friends,
  required AuthService auth,
  StatsRepo? stats,
  Future<GamesRepo>? games,
  ChatRepo? chat,
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
      chat: chat,
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

  /// Arkadaş satırındaki 🚫/🚩 yönetim ikonu için. null ise ikon hiç
  /// çizilmez — "çalışmayan kontrol koymuyoruz" deseni.
  final ChatRepo? chat;

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
    this.chat,
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

  /// Modalın GÖVDE kaydırması (KModal'a `bodyController` olarak verilir) —
  /// "Ara & Ekle" sayfalaması buna bakar. Eskiden listenin KENDİ
  /// `ListView`'ıydı; 27 Ağustos 2026'da bir kullanıcı "scroll bir yerde
  /// takılıyor, sonuna kadar gitmiyor" diye bildirdi ve ölçüldü: modal
  /// gövdesi 119→518 arasını gösterirken 320 px'e sabitlenmiş iç liste
  /// 326→646'ya uzanıyordu, yani alt 128 px (son ~2,5 satır + "Yükleniyor…"
  /// nöbetçisi) ekranın altında kalıyordu. Flutter iç içe kaydırmayı
  /// ZİNCİRLEMEDİĞİNDEN (tarayıcının aksine — web'in `max-h-[50vh]
  /// overflow-y-auto`'su bu yüzden orada sorun çıkarmıyor) parmağını listeye
  /// koyan kullanıcı dış gövdeyi HİÇ kaydıramıyordu: 60 sürüklemeden sonra
  /// dış offset ölçülen değeriyle 0.0'dı. Çözüm iç kaydırılabiliri tamamen
  /// KALDIRMAK — liste artık "Arkadaşlarım"/"İstekler" gibi düz bir Column
  /// ve modalda tek bir kaydırılabilir var.
  final _bodyScroll = ScrollController();

  String? _busyId;
  bool _inviteBusy = false;

  /// Üç sekmedeki isimlerin yanındaki rütbe mührü için k-lig puanı
  /// (18 Ağustos 2026). `ensure` yalnızca eksik id'leri sorar.
  late final RankScores _rankScores;

  void _onRankScores() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _rankScores = RankScores(widget.stats)..addListener(_onRankScores);
    _reloadFriends();
    _reloadRequests();
    unawaited(_reloadModeration());
    _bodyScroll.addListener(() {
      if (_bodyScroll.position.extentAfter < 80) _loadMoreAllUsers();
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _query.dispose();
    _bodyScroll.dispose();
    _rankScores.removeListener(_onRankScores);
    _rankScores.dispose();
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
    // Dinleyici artık MODALIN gövdesinde (bkz. `_bodyScroll`), yani üç
    // sekmede de ateşleniyor — sayfayı yalnızca liste GERÇEKTEN ekrandayken
    // iste: başka bir sekmedeyken ya da arama sonuçları gösterilirken
    // "tüm üyeler" listesi hiç çizilmiyor, boşuna sayfa çekmenin anlamı yok.
    if (_tab != FriendsTab.search) return;
    if (_query.text.trim().length >= 2) return;
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
  /// tamamı arkadaş çıktı) `_bodyScroll` dinleyicisi HİÇ ateşlenmez ve
  /// sonraki sayfa asla istenmez — Parça 31'deki k-lig hatasının aynısı.
  /// Her yüklemeden sonra bir kare bekleyip elle kontrol ediyoruz.
  void _autoLoadIfNotScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_allUsersHasMore) return;
      if (!_bodyScroll.hasClients) return;
      if (_bodyScroll.position.maxScrollExtent <= 0) _loadMoreAllUsers();
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

  /// Başarılıysa `true`. Dönüş değeri ÖNEMLİ: çağıranlar sonuç diyaloğunu
  /// buna göre seçiyor — eskiden hata yutulup "Arkadaş oldunuz."/"İstek
  /// reddedildi." KOŞULSUZ gösteriliyordu, yani ağ hatasında kullanıcıya
  /// gerçekleşmemiş bir sonuç bildiriliyordu (13 Ağustos 2026, Parça 89).
  Future<bool> _handleRespond(String requesterId, {required bool accept}) async {
    setState(() => _busyId = requesterId);
    try {
      await widget.friends.respond(requesterId, accept: accept);
      _patchRelation(requesterId, accept ? FriendRelation.accepted : null);
      _reloadRequests();
      if (accept) _reloadFriends();
      return true;
    } catch (e) {
      debugPrint('[Kelimeki] istek yanıtlama hatası: $e');
      return false;
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _handleInvite() async {
    setState(() => _inviteBusy = true);
    try {
      final url = await widget.friends.inviteUrl();
      if (url == null) return;
      if (!mounted) return;
      final anchor = shareOriginFrom(context);
      final share = widget.sharer ??
          (String text) async {
            await SharePlus.instance
                .share(ShareParams(text: text, sharePositionOrigin: anchor));
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
      bodyController: _bodyScroll,
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

  Widget _loading() => const KLoadingNote(vertical: 16);

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

  /// Ad + (biliniyorsa) rütbe mührü. Boy 18, satırın 14px puntosuna göre —
  /// ölçüm web tarafında yapıldı, iki platform aynı değeri kullanıyor.
  Widget _name(String s, RankTier? tier) => Expanded(
        child: Row(
          children: [
            Flexible(
              child: Text(s,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _text)),
            ),
            if (tier != null) ...[
              const SizedBox(width: 4),
              RankSeal(tier: tier, size: 18),
            ],
          ],
        ),
      );

  /// Sessize aldığım/şikayet ettiğim kişiler → kaynak oyun id'si.
  /// "Arkadaşlarım" satırındaki 🚫/🚩 ikonunu besliyor.
  Map<String, String> _modMuted = const {};
  Map<String, String> _modReported = const {};

  Future<void> _reloadModeration() async {
    final chat = widget.chat;
    if (chat == null) return;
    final m = await chat.myModeration();
    if (!mounted) return;
    setState(() {
      _modMuted = m.muted;
      _modReported = m.reported;
    });
  }

  Future<void> _openModeration(FriendRow f) async {
    final chat = widget.chat;
    if (chat == null) return;
    final changed = await showFriendModeration(
      context,
      chat: chat,
      target: FriendModerationTarget(
        userId: f.friendId,
        name: f.name,
        avatarUrl: f.avatarUrl,
        mutedGameId: _modMuted[f.friendId],
        reported: _modReported.containsKey(f.friendId),
      ),
    );
    // Durum değiştiyse ikon HEMEN kaybolmalı — aksi halde kullanıcı
    // "geri çektim ama bayrak duruyor" görürdü.
    if (changed) await _reloadModeration();
  }

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
            // Moderasyon durumu VARSA yönetim ikonu — "arkadaşlıktan çıkar"
            // ikonunun SOLUNDA (kullanıcı isteği, 14 Ağustos 2026). Durum
            // yoksa hiç çizilmez: bu bir "geri al" kısayolu, moderasyon
            // menüsü değil (yeni şikayet sohbette açılır).
            if (widget.chat != null &&
                (_modReported.containsKey(f.friendId) ||
                    _modMuted.containsKey(f.friendId)))
              _moderationIconButton(f),
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
    // ⚠ BÜYÜK YAZI ÖLÇEĞİNDE SATIR İKİYE BÖLÜNÜR (28 Ağustos 2026, kullanıcı
    // cihazda bildirdi: *"arkadaşlık davetinde davetin kimden geldiği
    // görünmüyor"* — ekran görüntüsünde avatar ve rütbe mührü duruyor, isim
    // hiç yok). Sebep taşma DEĞİL: satırdaki tek esnek öğe isim
    // (`_personButton` → `Expanded`), "Kabul Et"/"Reddet" ise METİN butonu,
    // yani ölçekle BÜYÜYOR ve ismi eziyor. ÖLÇÜLDÜ (360 px ekran): isim
    // ölçek 1,0'da 77,6 px · 1,3'te 53,2 px · 2,0'da **0,0 px**.
    //
    // Bir gelen kutusunda kırpılacak EN SON şey kimden geldiğidir — web'in
    // `CARD_HEADER` düzeltmesinin (23 Ağustos 2026) taşıdığı ilke bu. Eşik
    // aşılınca isim kendi satırını alıyor, butonlar altta sağa yaslanıyor.
    //
    // YALNIZCA BU LİSTE bölünüyor: "Arkadaşlarım" ve "Ara & Ekle"
    // satırlarının aksiyonu 44 px'lik SABİT ikon butonları, metin değil —
    // onlar ölçekle büyümediğinden ismi de ezmiyorlar. Gereksiz yere
    // bölmek o iki listeyi çirkinleştirirdi.
    final genis = buyukOlcek(context);
    return Column(children: [
      for (final r in requests)
        _row(
          child: () {
            final kisi = Row(children: [
              _personButton(r.requesterId, r.name, r.avatarUrl),
            ]);
            final butonlar = [
              _smallButton('Kabul Et',
                  busy: _busyId == r.requesterId,
                  onTap: () => _handleRespond(r.requesterId, accept: true)),
              const SizedBox(width: 6),
              _smallButton('Reddet',
                  neutral: true,
                  busy: _busyId == r.requesterId,
                  onTap: () => _confirmThenReject(r)),
            ];
            if (!genis) {
              return Row(children: [
                _personButton(r.requesterId, r.name, r.avatarUrl),
                const SizedBox(width: 6),
                ...butonlar,
              ]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kisi,
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: butonlar),
              ],
            );
          }(),
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
          style: kInputTextStyle,
          decoration: kInputDecoration(hint: 'İsim ya da takma ad ara…'),
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
            // Kendi kaydırması YOK (bkz. `_bodyScroll`) — modalın gövdesiyle
            // birlikte kayar, tıpkı diğer iki sekmenin listeleri gibi.
            Column(
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
    _rankScores.ensure([id]);
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
          _name(name, _rankScores.tierOf(id)),
        ]),
      ),
    );
  }

  /// 44px dokunma hedefi (iOS asgarisi) içinde 20px ikon. Metin kalktığı
  /// için `Semantics.label` artık ekran okuyucunun TEK bilgi kaynağı — boş
  /// bırakma. Web'deki aynı buton `w-11 h-11` + `aria-label` taşıyor.
  /// Bayrak, yasak işaretini EZER — sohbetteki rozet mantığının aynısı
  /// (şikayet otomatik sessize de alıyor, iki ikon birden göstermek
  /// gürültü). Emoji: gömülü fontta yok, fallback ŞART (bkz. Parça 70).
  Widget _moderationIconButton(FriendRow f) {
    final reported = _modReported.containsKey(f.friendId);
    return Semantics(
      button: true,
      label: '${f.name} — ${reported ? 'şikayet edildi' : 'sessize alındı'},'
          ' ayarları aç',
      child: GestureDetector(
        onTap: () => _openModeration(f),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Text(
              reported ? '🚩' : '🚫',
              style: const TextStyle(
                fontSize: 15,
                fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji'],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
      message = await _handleRespond(u.id, accept: true)
          ? 'Arkadaş oldunuz.'
          : kFriendActionFailed;
    } else {
      final result = await _handleSend(u);
      // Karşı taraftan zaten bekleyen bir istek varsa sunucu trigger'ı
      // ilişkiyi anında accepted yapar — mesaj bunu yansıtmalı.
      // `null` = istek HİÇ gitmedi (bkz. `_handleSend`'in catch dalı);
      // "iletilmiştir" demek yalan olurdu.
      message = switch (result) {
        FriendRelation.accepted => 'Arkadaş oldunuz.',
        null => kFriendActionFailed,
        _ => 'Arkadaşlık isteğiniz iletilmiştir.',
      };
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
    final done = await _handleRespond(r.requesterId, accept: false);
    if (mounted) {
      await showFriendInfoDialog(
          context, done ? 'İstek reddedildi.' : kFriendActionFailed);
    }
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
}) {
  // Web `ConfirmDialog` (FriendsModal.tsx) App.tsx'in onay popup'larıyla
  // BİREBİR AYNI sınıfları taşıyor — yani tek kanonik kart var, o da
  // `dialog_shell.dart`. Bu dosya bir dönem kartı ELLE çizdi ve değerleri
  // sapmıştı (başlık 15/gövde 13/buton 11, gölge yok); 15 Ağustos 2026'da
  // ortak kabuğa bağlandı.
  return showKConfirm(
    context,
    title: title,
    message: message,
    confirmLabel: trUpper(confirmLabel),
  );
}

/// Web InfoDialog — tek "Tamam" butonlu sonuç mesajı.
Future<void> showFriendInfoDialog(BuildContext context, String message) {
  return showKInfo(context, message: message);
}
