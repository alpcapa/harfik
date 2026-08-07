// Kurulum ekranı — src/components/Setup.tsx'in portu. İskelet HomeScreen'in
// yerine geçer; kalıcılık akışı (LocalGameRepo süpürmesi, tek slot,
// anti-kaçış) oradan buraya taşındı.
//
// Web paritesi: logo + tanıtım metni, "Oyun Tipi" sekmeleri (Arkadaşınla =
// LiveGamesTab, davet/kabul akışı — 7 Ağustos 2026), Oyuncu Sayısı 2/4,
// renkli Oyuncular
// listesi (Misafir + "Yapay Zeka N"), sözlük hazır olana dek "HAZIRLANIYOR…"
// gösteren Oyunu Başlat; misafirin tekil kaydı varsa form yerine "Devam Eden
// Oyun" satırı (avatarlar + Sıra: + kalan süre) ve 7 gün paragrafı; misafirin
// her iki görünümünde de (Devam Eden Oyun / boş form) "Neden Ücretsiz Üye
// Olmalıyım?" kutusu (`MembershipPerksBox`, 7 Ağustos 2026). "Nasıl oynanır?"
// linki kurallar modalını açar; yanındaki "Arkadaşınla paylaş" web'in
// `handleShare`'i (`?ref=arkadas` linki, sistem paylaş sayfası). "Arkadaşınla"
// sekmesi web'in `liveActionCount` rozetini taşır (bekleyen davet + sırası
// çağıranda olan aktif oyun) ve girişte, dikkat bekleyen bir şey varsa, sekme
// otomatik "Arkadaşınla"ya geçer (web `appliedLoginDefaultRef`, hesap başına
// bir kez) — 7 Ağustos 2026.
import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../bootstrap.dart';
import '../../config/env.dart';
import '../../data/cloud_save_repo.dart';
import '../../data/games_api.dart';
import '../../storage/pending_event_store.dart' show friendInviteTokenKind;
import '../friends/friends_modal.dart' show showFriendInfoDialog;
import '../../game/game_controller.dart';
import '../../game/local_game_repo.dart';
import '../../storage/local_save_store.dart' show abandonTimeout;
import '../../util/share_board.dart';
import '../game/count_badge.dart';
import '../game/game_screen.dart';
import '../game/help_modal.dart';
import '../game/logo_mark.dart';
import '../game/neo_button.dart';
import '../game/player_badge.dart';
import '../game/player_avatar_row.dart';
import '../game/player_colors.dart';
import '../live/live_games_tab.dart';
import '../auth/account_button.dart';
import '../auth/k_avatar.dart';
import 'membership_perks_box.dart';
import 'recent_games_section.dart';

const _panel = Color(0xFFF5F7FA);
const _border = Color(0xFFDCE2EA);
const _muted = Color(0xFF5A6673);
const _text = Color(0xFF1B2430);

class SetupScreen extends StatefulWidget {
  final AppServices services;

  /// Test injection'ı için — bkz. `GameHistoryModal.share`'daki aynı
  /// desen. Verilmezse gerçek `shareBoard` (sistem paylaş sayfası) kullanılır.
  final ShareBoardFn? share;

  const SetupScreen({super.key, required this.services, this.share});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with WidgetsBindingObserver {
  int _count = 2;

  /// Web `mainView` ('local' | 'live') — OYUN TİPİ sekmeleri. Canlı sekme
  /// yalnızca görünümü değiştirir; YZ tarafının state'i (kayıtlar/form)
  /// mount'ta kaldığından geçişte kaybolmaz.
  bool _liveView = false;

  /// "Arkadaşınla (N)" rozeti — bekleyen davet + sırası çağıranda olan
  /// aktif oyun toplamı (web `liveActionCount`). LiveGamesTab kendi
  /// listesini ayrıca çeker — küçük bir tekrar fetch pahası web'in de
  /// kabul ettiği bir ödün.
  int _liveActionCount = 0;
  Timer? _liveBadgeDebounce;
  void Function()? _unsubscribeLiveBadge;

  /// Girişte "Arkadaşınla"ya otomatik geçiş — yalnızca hesap başına BİR
  /// KEZ (web `appliedLoginDefaultRef`); `_lastUserId` değişince sıfırlanır.
  bool _appliedLoginDefault = false;

  /// Web `lastAuthUserIdRef` (`useRef<string|null>(null)`) — React'te bu
  /// ref'in effect'i mount'tan HEMEN sonra bir kez kendiliğinden çalışıp
  /// `current`'ı gerçek mount id'sine eşitliyor (`prev===null` olduğundan
  /// sıfırlamıyor). `ChangeNotifier.addListener` mount'ta ASLA otomatik
  /// tetiklenmediğinden, bu ilk-çalışma `initState`'te elle taklit ediliyor
  /// (aşağı bkz.) — aksi halde İLK gerçek `_onAuthEvent` (ör. gerçek bir
  /// çıkış) `prevAuthId==null` görüp yanlışlıkla "ilk çalışma" sanılırdı.
  /// Yalnızca GİRİŞLİDEN başka bir şeye geçiş (çıkış/hesap değişimi)
  /// `_liveView`'i sıfırlar — misafirken "Arkadaşınla"ya girip login olan
  /// kullanıcı (`prevAuthId==null`) o sekmede BİLEREK bırakılır (web 5
  /// Ağustos 2026 dersi: aksi halde biten bir hesabın "Arkadaşınla" seçimi
  /// bomboş bir sonraki hesaba taşınır).
  String? _lastAuthUserIdForLiveViewReset;

  LocalGameRepo? _repo;
  GamesRepo? _games;
  bool _saveChecked = false;
  GameState? _savedState; // null = kayıt yok
  int? _savedAtMs;

  // Girişli kullanıcının bulut kayıtları (web cloudSaves state'i) —
  // null: henüz çekilmedi/alınamadı. `_creatingLocal` web'in aynı adlı
  // state'i: kurulum formu yalnızca "+ Yeni Yapay Zeka Oyunu Aç" ile açılır.
  List<CloudSave>? _cloudSaves;
  bool _creatingLocal = false;
  // Misafir kaydını hesaba taşıyan akışın mükerrer-çalışma kilidi (web
  // migratingSavedGameRef).
  bool _migratingGuest = false;
  // Hesap değişimi kararı `user` REFERANSINA değil id'ye bakar — web dersi:
  // her onAuthStateChange (TOKEN_REFRESHED dahil) yeni bir User nesnesi
  // verir; referansa bakmak "bir kez"lik sıfırlamaları saatlik tekrara
  // çevirirdi. Mount'ta mevcut id ile başlar (mount yolu dokunulmaz).
  String? _lastUserId;

  // Davet linki işleme kilidi + girişsiz önizlemenin tek seferlik bayrağı.
  bool _processingInvites = false;
  String? _previewedInviteToken;

  @override
  void initState() {
    super.initState();
    _lastUserId = widget.services.auth.user?.id;
    _lastAuthUserIdForLiveViewReset = _lastUserId; // React'in mount-anı effect'i
    widget.services.auth.addListener(_onAuthEvent);
    // Kuyruktaki geri bildirimleri tekrar dene — web App.tsx'in mount +
    // 'online' olayındaki flushPendingFeedback refleksi; mobil karşılığı
    // Setup'a her geliş. Oyun kayıtlarının aksine oturum BEKLEMEZ
    // (feedback_api.dart'taki not), bu yüzden _syncCloud'a değil buraya.
    unawaited(widget.services.feedback?.flushPending());
    final storage = widget.services.storage;
    // setState şart: "Son Oynadıklarım" bölümü bu repoya bağlı çizildiğinden
    // (5c), repo geldiğinde ekranın yeniden kurulması gerekiyor. Önceki
    // kullanımlar (kaydet/sürdür akışları) alanı yalnızca olay anında
    // okuduğundan bunu gerektirmiyordu.
    unawaited(widget.services.games?.then((g) {
      if (mounted) setState(() => _games = g);
    }));
    if (storage != null) {
      storage.then((s) async {
        final repo = LocalGameRepo(s);
        _repo = repo;
        await _refreshSaveStatus(); // load süresi dolanı olaya çevirir
        await _sweepLocalAbandoned(); // web'in Setup süpürme refleksi
        unawaited(_syncCloud()); // girişliyse migrasyon + liste + flush
        unawaited(_processInvites()); // kuyruklanmış davet token'ları
      });
    } else {
      _saveChecked = true; // depo yok (test ortamı) — kalıcılıksız çalış
      unawaited(_syncCloud());
    }
    // Uygulama açıkken gelen davet linki (deep link) — inbox haber verir.
    widget.services.inviteInbox?.addListener(_onInviteEvent);

    // "Arkadaşınla (N)" rozeti — web `subscribeMyOnlineGames` + foreground
    // dinleyicileri deseni (LiveGamesTab'daki aynı desen); Realtime olayları
    // 300ms debounce ile tek tazelemeye iner.
    WidgetsBinding.instance.addObserver(this);
    _unsubscribeLiveBadge =
        widget.services.onlineGames?.gateway.subscribe(_scheduleLiveBadgeRefresh);
    unawaited(_refreshLiveBadge());
  }

  void _onInviteEvent() => unawaited(_processInvites());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleLiveBadgeRefresh();
  }

  void _scheduleLiveBadgeRefresh() {
    _liveBadgeDebounce?.cancel();
    _liveBadgeDebounce = Timer(
        const Duration(milliseconds: 300), () => unawaited(_refreshLiveBadge()));
  }

  /// Web `fetchPendingLiveGameCounts` + rozet/varsayılan-sekme birleşimi
  /// (`Setup.tsx`'teki aynı effect). `_appliedLoginDefault` yalnızca bu
  /// hesap için İLK başarılı sonuçta bir kez tetiklenir — sonraki her
  /// tazeleme (Realtime/foreground) kullanıcıyı elle seçtiği sekmeden
  /// zorla çekmez.
  Future<void> _refreshLiveBadge() async {
    final repo = widget.services.onlineGames;
    final user = widget.services.auth.user;
    if (repo == null || user == null) {
      if (mounted && _liveActionCount != 0) {
        setState(() => _liveActionCount = 0);
      }
      return;
    }
    final counts = await repo.pendingCounts();
    if (!mounted || widget.services.auth.user?.id != user.id) return;
    final applyDefault = !_appliedLoginDefault &&
        (counts.inviteCount > 0 || counts.myTurnCount > 0);
    _appliedLoginDefault = true;
    setState(() {
      _liveActionCount = counts.inviteCount + counts.myTurnCount;
      if (applyDefault) _liveView = true;
    });
  }

  /// Web `handleShare` — `?ref=arkadas` UTM etiketli site linki, sistem
  /// paylaş sayfasıyla. `shareBoard(png: null, ...)` zaten dosyasız/
  /// metin+link paylaşımını (`shareMessage`in web karşılığı burada sabit
  /// bir davet metni) yerleşik destekliyor — ikinci bir yardımcı yazmaya
  /// gerek yok. Web'in clipboard-fallback + "Link kopyalandı!" geçici
  /// durumu BİLİNÇLİ taşınmadı: `share_plus` iOS/Android'de her zaman
  /// native paylaş sayfasına düşer, "paylaşım API'si yok" durumu (yalnızca
  /// masaüstü tarayıcılara özgü) mobilde hiç oluşmaz.
  Future<void> _handleShare() {
    return (widget.share ?? shareBoard)(
      png: null,
      text: 'Hemen ücretsiz dene!',
      url: '$webOrigin/?ref=arkadas',
    );
  }

  /// Kuyruklanmış arkadaş daveti token'larını işler — web App.tsx'in
  /// `takePendingInviteToken` + `acceptFriendInvite` akışının karşılığı.
  /// Girişsizken kuyruk TÜKETİLMEZ (token giriş yapılana dek bekler; web'in
  /// e-posta-doğrulaması-açık senaryosuyla aynı gerekçe) — yalnızca son
  /// gelen link için bir kez "X seni eklemek istiyor" önizlemesi gösterilir
  /// (web'de bu önizleme /davet sayfasının işiydi; mobilde sayfa yok).
  /// Kabul BAŞARISIZSA token web'deki gibi DÜŞER (App.tsx da yalnızca
  /// loglar) — geçersiz/tükenmiş bir token'ın her açılışta yeniden
  /// denenmesi kilitlenme üretirdi. Kabulde web'in sessiz App.tsx yolundan
  /// BİLİNÇLİ sapma: sonuç diyaloğu gösterilir (linke tıklayan kullanıcı
  /// mobilde başka hiçbir geri bildirim almazdı; web'de onu /davet sayfası
  /// gösteriyor).
  Future<void> _processInvites() async {
    final friends = widget.services.friends;
    final storage = widget.services.storage;
    if (friends == null || storage == null || _processingInvites) return;
    final user = widget.services.auth.user;
    if (user == null) {
      final token = widget.services.inviteInbox?.lastToken;
      if (token == null || token == _previewedInviteToken) return;
      _previewedInviteToken = token;
      final name = await friends.inviteInfo(token);
      if (name != null && mounted) {
        await showFriendInfoDialog(context,
            "$name seni Kelimeki'de arkadaş eklemek istiyor. Giriş yaptığında otomatik olarak ekleneceksiniz.");
      }
      return;
    }
    _processingInvites = true;
    try {
      final s = await storage;
      final events = await s.events.takeAll(friendInviteTokenKind);
      for (final e in events) {
        final token = e['token'];
        if (token is! String || token.isEmpty) continue;
        try {
          final name = await friends.acceptInvite(token);
          if (mounted) {
            await showFriendInfoDialog(
                context, '${name ?? 'Bir oyuncu'} ile artık arkadaşsınız.');
          }
        } catch (err) {
          debugPrint('[Kelimeki] davet kabul edilemedi (token düştü): $err');
        }
      }
    } finally {
      _processingInvites = false;
    }
  }

  /// Süresi dolan MİSAFİR kaydından doğan terk olaylarını -2 cezalı teslim
  /// kayıtlarına çevirir (girişsizken kayıt kuyruğa girer, kişi 7 gün içinde
  /// bu cihazda giriş yaparsa hesabına işlenir — web'in aynı akışı).
  Future<void> _sweepLocalAbandoned() async {
    final repo = _repo;
    if (repo == null) return;
    final events = await repo.drainAbandonedGames();
    if (events.isEmpty) return;
    final games = _games ?? await widget.services.games;
    if (games == null) return;
    for (final e in events) {
      await games.recordAbandoned(e.state, endedAtMs: e.savedAtMs);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.services.auth.removeListener(_onAuthEvent);
    widget.services.inviteInbox?.removeListener(_onInviteEvent);
    _liveBadgeDebounce?.cancel();
    _unsubscribeLiveBadge?.call();
    super.dispose();
  }

  void _onAuthEvent() {
    final id = widget.services.auth.user?.id;

    // Web `lastAuthUserIdRef`: yalnızca GİRİŞLİDEN başka bir şeye (çıkış/
    // hesap değişimi) geçişte `_liveView`'i sıfırlar — `prev == null` iken
    // (misafirken login olan kullanıcı) BİLEREK dokunmaz, o kişi zaten
    // "Arkadaşınla"yı görmek istediğinden orada bırakılır.
    final prevAuthId = _lastAuthUserIdForLiveViewReset;
    _lastAuthUserIdForLiveViewReset = id;
    if (prevAuthId != null && prevAuthId != id && _liveView) {
      if (mounted) setState(() => _liveView = false);
    }

    if (id != _lastUserId) {
      // Çıkış ya da hesap değişimi: önceki hesabın listesi/form durumu
      // yeni hesaba sızmasın (web mainView/cloudSaves sıfırlama dersleri).
      _lastUserId = id;
      _appliedLoginDefault = false;
      if (mounted) {
        setState(() {
          _cloudSaves = null;
          _creatingLocal = false;
          _liveActionCount = 0;
        });
      }
    }
    // Aynı hesapta tekrarlanan bildirimlerde yeniden çekim zararsız (web
    // dersi: fazladan fetch zararsız, ref sıfırlamak zararlı) — profil
    // yüklenince de burası tetiklenip bekleyen migrasyonu tamamlar.
    unawaited(_syncCloud());
    // Giriş gerçekleşince kuyrukta bekleyen davet token'ları işlenir
    // (web'in `useEffect([user])` + takePendingInviteToken karşılığı).
    unawaited(_processInvites());
    unawaited(_refreshLiveBadge());
  }

  /// Girişliyse: önce misafir kaydını hesaba taşımayı dener (profil hazır
  /// olduğunda — accountName kesinleşmeden yüklenirse "Sıra: Misafir" kalıcı
  /// kalırdı, web'in profileLoading beklemesi), sonra listeyi tazeler.
  Future<void> _syncCloud() async {
    final auth = widget.services.auth;
    final cloud = widget.services.cloudSaves;
    final user = auth.user;
    if (user == null || cloud == null) return;
    final repo = _repo;
    if (repo != null && !auth.profileLoading && !_migratingGuest) {
      _migratingGuest = true;
      try {
        final moved = await cloud.migrateGuestSave(
          guestRepo: repo,
          userId: user.id,
          accountName: auth.accountName,
        );
        if (moved && mounted) await _refreshSaveStatus();
      } finally {
        _migratingGuest = false;
      }
    }
    // Kuyrukta bekleyen bitmiş/terk edilmiş oyun kayıtlarını (misafirken
    // ya da offline'da biriken) bu hesaba işle — web'in `flushPendingGames`
    // refleksi (açılış + giriş durumu değişimi).
    final games = _games ?? await widget.services.games;
    if (games != null) unawaited(games.flushPending());

    final list = await cloud.list();
    if (list != null) {
      // 7 günü dolup bu turda iddia edilen kayıtlar → -2 cezalı teslim
      // (web refreshCloudSaves'in claim dalı).
      for (final a in list.abandoned) {
        await games?.recordAbandoned(a.state, endedAtMs: a.updatedAtMs);
      }
    }
    if (!mounted || widget.services.auth.user?.id != user.id) return;
    if (list == null && _cloudSaves != null) return; // ağ hatası eskiyi ezmesin
    setState(() => _cloudSaves = list?.saves);
  }

  /// Normal biten oyunun `games` kaydı + anonim bitiş telemetrisi
  /// (web'in oyun-bitti effect'i). Misafirse kayıt kuyruğa girer.
  Future<void> _recordFinishedGame(GameState state) async {
    final games = _games ?? await widget.services.games;
    await games?.recordFinished(state);
  }

  Future<void> _refreshSaveStatus() async {
    final repo = _repo;
    if (repo == null) return;
    final state = await repo.loadSave();
    final at = state != null ? await repo.savedAtMs() : null;
    if (!mounted) return;
    setState(() {
      _saveChecked = true;
      _savedState = state;
      _savedAtMs = at;
    });
  }

  Future<void> _openGame(GameController controller, SetWordSource words,
      {String? resumeCloudId}) async {
    // Girişli kullanıcının oyunu SUNUCUYA yazılır (CloudGameSession),
    // misafir slotuna HİÇ dokunulmaz — web'in "girişliyken localStorage'a
    // yazılmaz" kuralının eşleniği (mükerrer terk cezası önlemi; giriş
    // öncesi eski misafir kaydı zaten migrasyonla taşınıp silinmiş olur).
    final user = widget.services.auth.user;
    final cloud = widget.services.cloudSaves;
    // Oyun bittiği AN kaydı tutulur — web'in `[state.isGameOver]` effect'i
    // gibi (ekran açıkken, GameOver modalı kapatılmasa bile). Uygulama o
    // anda kill edilse bile kayıt kuyruğa/sunucuya çoktan gitmiş olur.
    var recorded = false;
    void recordOnGameOver() {
      if (recorded || !controller.state.isGameOver) return;
      recorded = true;
      unawaited(_recordFinishedGame(controller.state));
    }

    controller.addListener(recordOnGameOver);

    GameSession? guestSession;
    CloudGameSession? cloudSession;
    if (user != null && cloud != null) {
      cloudSession = CloudGameSession(controller, cloud, user.id,
          resumeSaveId: resumeCloudId);
    } else {
      guestSession = _repo?.attach(controller);
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        controller: controller,
        words: words,
        meanings: widget.services.meanings,
        auth: widget.services.auth,
        stats: widget.services.stats,
        games: widget.services.games,
        feedback: widget.services.feedback,
        friends: widget.services.friends,
      ),
    ));
    await guestSession?.end();
    await cloudSession?.end();
    controller.removeListener(recordOnGameOver);
    // Güvenlik ağı: dinleyici bir şekilde kaçırdıysa (ör. restore edilmiş
    // zaten bitmiş bir state) çıkışta bir kez daha denenir — `recorded`
    // bayrağı çift kaydı engeller (her çağrı YENİ bir id üretirdi).
    recordOnGameOver();
    controller.dispose();
    // Web'de oyun başlayınca Setup unmount olup `creatingLocal` kendiliğinden
    // sıfırlanıyor; burada ekran mount'ta kaldığından dönüşte elle sıfırlanır
    // — dönüş her zaman listeye (web "sonraki mount'ta sıfırlanır" davranışı).
    if (mounted && _creatingLocal) setState(() => _creatingLocal = false);
    await _refreshSaveStatus();
    await _syncCloud();
  }

  Future<void> _startNewGame(SetWordSource words) async {
    final controller = GameController(words: words);
    // Web doStart paritesi: 1. oyuncu her zaman gerçek kişi — oturum
    // açıksa hesap sahibi (accountName), değilse misafir; diğerleri
    // "Yapay Zeka N" adıyla YZ.
    final me = widget.services.auth.accountName ?? guestPlayerName;
    controller.dispatch(StartAction([
      PlayerSetup(name: me, isAI: false),
      for (var i = 1; i < _count; i++)
        PlayerSetup(name: 'Yapay Zeka ${i + 1}', isAI: true),
    ]));
    await _openGame(controller, words);
  }

  Future<void> _resumeSavedGame(SetWordSource words) async {
    final repo = _repo;
    if (repo == null) return;
    final state = await repo.loadSave();
    if (state == null) {
      // Tam bu anda süresi dolmuş/karantinaya düşmüş — görünümü tazele.
      await repo.drainAbandonedGames();
      await _refreshSaveStatus();
      return;
    }
    final controller = GameController(words: words);
    controller.restore(state);
    await _openGame(controller, words);
  }

  Future<void> _resumeCloudSave(CloudSave save, SetWordSource words) async {
    // Web handleResumeCloudSave: satır id'si session'a DIŞARIDAN verilir ki
    // autosave yeni satır açmak yerine aynı satırı güncellesin. State olduğu
    // gibi uygulanır — web RESUME_SAVED de multiSession İŞARETLEMEZ (yalnızca
    // misafirin localStorage yükleyicisi işaretliyor; bilinçli aynı davranış).
    final controller = GameController(words: words);
    controller.restore(save.state);
    await _openGame(controller, words, resumeCloudId: save.id);
  }


  @override
  Widget build(BuildContext context) {
    final auth = widget.services.auth;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        // Oturum/profil değişince (giriş, çıkış, profil gelmesi) tüm ekran
        // tazelenir — web'de useAuth context'inin yeniden render etmesiyle
        // aynı; auth yapılandırılmamışsa hiç notify etmez, maliyeti yok.
        child: ListenableBuilder(
          listenable: auth,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Web: Setup'ın üstünde sağa yaslı UserMenu (App.tsx,
                    // kurulum dalı) — GİRİŞ / avatar burada da sağ üstte.
                    if (auth.configured)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AccountButton(
                            feedback: widget.services.feedback,
                            friends: widget.services.friends,
                              auth: auth,
                              stats: widget.services.stats,
                              games: widget.services.games),
                        ),
                      ),
                    const Center(child: LogoMark(height: 52)),
                    const SizedBox(height: 16),
                    const Text(
                      'Kelimeler kurarak bölgeni genişlet, rakiplerini kuşat. '
                      'Ama dikkat et: Hamlen rakibinin bölgesine temas ederse, '
                      'kazandığın puanın bir kısmını onunla paylaşmak zorunda '
                      'kalırsın. Her hamle bir strateji, her kelime bir mücadele.',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 12,
                        height: 1.5,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Web Setup'taki "Nasıl oynanır?" · "Arkadaşınla paylaş"
                    // satırı — ikisi de font-mono/11px/kalın/accent linkler.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _InlineLink(
                            'Nasıl oynanır?',
                            onTap: () => showHelpModal(context),
                          ),
                          const Text(' · ',
                              style: TextStyle(
                                  fontFamily: 'SpaceMono',
                                  fontSize: 11,
                                  color: _muted)),
                          _InlineLink('Arkadaşınla paylaş', onTap: _handleShare),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('OYUN TİPİ'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceButton(
                            label: 'YAPAY ZEKA İLE',
                            selected: !_liveView,
                            onTap: () => setState(() => _liveView = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChoiceButton(
                            label: 'ARKADAŞINLA',
                            selected: _liveView,
                            badge: _liveActionCount,
                            onTap: () => setState(() => _liveView = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_liveView)
                      LiveGamesTab(services: widget.services)
                    else
                    FutureBuilder<SetWordSource>(
                      future: widget.services.dictionary,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text('Sözlük yüklenemedi: ${snap.error}',
                              style: const TextStyle(color: Color(0xFFDC2626)));
                        }
                        final words = snap.data;
                        // Girişli kullanıcı: liste varsayılan görünüm, form
                        // yalnızca "+ Yeni" ile açılır (web creatingLocal).
                        if (auth.user != null &&
                            widget.services.cloudSaves != null) {
                          return _creatingLocal
                              ? _buildNewGameForm(words, showCancel: true)
                              : _buildCloudListView(words);
                        }
                        if (!_saveChecked) {
                          return const _SectionLabel(
                              'KAYITLAR KONTROL EDİLİYOR…');
                        }
                        return _savedState != null
                            ? _buildSavedGameView(words)
                            : _buildNewGameForm(words);
                      },
                    ),
                    const SizedBox(height: 32),
                    // Teşhis alt satırı (iskelet HomeScreen'in durum
                    // panelinden kalan tek iz — cihazda ilk açılış doğrulaması
                    // için faydalı, göze batmayan tek satır).
                    FutureBuilder<SetWordSource>(
                      future: widget.services.dictionary,
                      builder: (context, snap) => Text(
                        [
                          'Sürüm $appVersion',
                          snap.hasData
                              ? 'Sözlük: ${snap.data!.length} kelime'
                              : 'Sözlük: yükleniyor…',
                          widget.services.supabase != null
                              ? 'sunucu bağlı'
                              : 'offline mod',
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          color: Color(0xFF8A93A2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Misafirin tekil kaydı — web'in anti-kaçış kuralı: bu görünümde yeni
  /// oyun formu HİÇ yok, kayıt bitene/silinene kadar tek yol devam etmek.
  Widget _buildSavedGameView(SetWordSource? words) {
    final state = _savedState!;
    final current =
        state.players.isNotEmpty ? state.players[state.current].name : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('DEVAM EDEN OYUN'),
        const SizedBox(height: 8),
        _SavedGameRow(
          state: state,
          subtitle: 'Sıra: $current',
          savedAtMs: _savedAtMs ?? 0,
          isGuest: true,
          onTap: words == null ? null : () => _resumeSavedGame(words),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bu oyun 7 gün boyunca cihazınızın hafızasında saklanır ve bir '
          'sonraki gelişinizde devam edilebilir. Üye değilseniz bu oyunu '
          'bitirmeden yeni oyun açamazsınız.',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 11,
            height: 1.5,
            color: _muted,
          ),
        ),
        // Widget kendi içinde `auth.user == null` kontrolü yapıyor — bu
        // görünüme yalnızca misafirken düşüldüğünden burada koşul gerekmez,
        // ama üstteki tek çağıranla (auth) tutarlı kalsın diye geçiliyor.
        MembershipPerksBox(
            auth: widget.services.auth,
            feedback: widget.services.feedback,
            topMargin: true),
      ],
    );
  }

  /// Girişli kullanıcının varsayılan görünümü — web Setup'ın `user &&
  /// !creatingLocal` dalı: üstte turuncu "+ Yeni Yapay Zeka Oyunu Aç",
  /// altında Devam Eden Oyunlar listesi. Web'deki "Devam Edenler / Son
  /// Oynananlar" alt sekmeleri BİLİNÇLİ eksik — "Son Oynananlar" bitmiş
  /// oyun geçmişi (`games` tablosu) ister, o skor kartı/kayıt parçasının işi.
  Widget _buildCloudListView(SetWordSource? words) {
    final saves = _cloudSaves;
    final auth = widget.services.auth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: NeoButton(
            label: '+ YENİ YAPAY ZEKA OYUNU AÇ',
            variant: NeoButtonVariant.orange,
            fontSize: 14,
            letterSpacing: 1.5,
            onPressed: () => setState(() => _creatingLocal = true),
          ),
        ),
        const SizedBox(height: 16),
        if (saves == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Yükleniyor…',
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
              ),
            ),
          )
        else if (saves.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Devam eden bir Yapay Zeka oyunun yok.',
                style: TextStyle(
                    fontFamily: 'SpaceMono', fontSize: 12, color: _muted),
              ),
            ),
          )
        else ...[
          const _SectionLabel('DEVAM EDEN OYUNLAR'),
          const SizedBox(height: 8),
          for (final save in saves) ...[
            _SavedGameRow(
              state: save.state,
              subtitle:
                  'Sıra: ${save.state.players.isNotEmpty ? save.state.players[save.state.current].name : '—'}',
              savedAtMs: save.updatedAtMs,
              // Web: girişli kullanıcıda gerçekten başlamış oyun için süre
              // dolunca -2'li teslim gerçek/anında sonuç → "teslim sayılacak".
              willSurrender: save.state.turnCount >= 2,
              accountAvatarUrl: auth.profile?.avatarUrl,
              onTap: words == null ? null : () => _resumeCloudSave(save, words),
            ),
            const SizedBox(height: 8),
          ],
        ],
        // "Son Oynadıklarım" — BİTEN oyunlar (devam edenlerden ayrı bir
        // kaynak: `games` tablosu). Web'de kendi alt sekmesinde duruyor;
        // burada henüz alt sekme yok, listenin altına ekleniyor. Hiç bitmiş
        // oyun yoksa bileşen kendini sessizce gizliyor.
        if (_games != null && auth.user != null) ...[
          const SizedBox(height: 8),
          RecentGamesSection(
            games: _games!,
            userId: auth.user!.id,
            onlineOnly: false,
            currentName: auth.accountName,
            stats: widget.services.stats,
          ),
        ],
      ],
    );
  }

  Widget _buildNewGameForm(SetWordSource? words, {bool showCancel = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('OYUNCU SAYISI'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final n in const [2, 4]) ...[
              if (n != 2) const SizedBox(width: 8),
              Expanded(
                child: _ChoiceButton(
                  label: '$n OYUNCULU',
                  selected: _count == n,
                  onTap: () => setState(() => _count = n),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        const _SectionLabel('OYUNCULAR'),
        const SizedBox(height: 8),
        for (var i = 0; i < _count; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _PlayerRow(
            index: i,
            accountName: widget.services.auth.accountName,
            accountAvatarUrl: widget.services.auth.profile?.avatarUrl,
            accountPending: widget.services.auth.accountPending,
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                // Web: `btn-raised bg-accent ... disabled:opacity-35` —
                // NeoButton disabled durumu birebir aynı görünümü verir.
                child: NeoButton(
                  label: words == null ? 'HAZIRLANIYOR…' : 'OYUNU BAŞLAT',
                  variant: NeoButtonVariant.accent,
                  fontSize: 14,
                  letterSpacing: 2,
                  onPressed: words == null ? null : () => _startNewGame(words),
                ),
              ),
            ),
            // Yalnızca girişli kullanıcının "+ Yeni" ile açtığı formda —
            // web'in creatingLocal "Vazgeç" butonu (Devam Eden Oyunlar
            // listesine döner); misafirde form tek yol, hiç çizilmez.
            if (showCancel) ...[
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: NeoButton(
                    label: 'VAZGEÇ',
                    variant: NeoButtonVariant.neutral,
                    fontSize: 14,
                    letterSpacing: 2,
                    onPressed: () => setState(() => _creatingLocal = false),
                  ),
                ),
              ),
            ],
          ],
        ),
        // Web: `!user && <MembershipPerksBox .../>` — bu fonksiyon hem
        // misafirin boş formunda (showCancel:false) hem girişli kullanıcının
        // "+ Yeni" formunda (showCancel:true) çağrıldığından gate widget'ın
        // kendi içinde (`auth.user == null`); girişli çağrıda sessizce
        // gizli kalır.
        MembershipPerksBox(
            auth: widget.services.auth,
            feedback: widget.services.feedback),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'SpaceMono',
        fontSize: 10,
        letterSpacing: 1.5,
        color: _muted,
      ),
    );
  }
}

/// Web'in btn-raised/btn-raised-neutral sekme/seçim butonu: seçili = accent
/// zemin + beyaz, değil = panel zemin + çerçeve — gölgeler NeoButton'dan
/// (index.css btn-raised / btn-raised-neutral değerleri).
class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.label,
    required this.selected,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = NeoButton(
      label: label,
      variant: selected ? NeoButtonVariant.accent : NeoButtonVariant.neutral,
      fontSize: 13,
      letterSpacing: 1,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      onPressed: onTap,
    );
    if (badge <= 0) return button;
    // Stack TÜM tıklanabilir kutuyu sarmalı (yalnızca metni değil) — web
    // `relative`/`absolute -top-1 -right-1` referansı buton, `LiveGamesTab`/
    // `FriendsModal`'daki aynı düzeltmenin dersi (bkz. mobile/CLAUDE.md).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(top: -4, right: -4, child: CountBadge(count: badge)),
      ],
    );
  }
}

/// Web'in `font-mono text-[11px] font-bold text-accent hover:underline`
/// linkleri — "Nasıl oynanır?" / "Arkadaşınla paylaş" satırında paylaşılıyor.
class _InlineLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _InlineLink(this.text, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

/// Oyuncular listesindeki renkli satır — web: tint zemin + base çerçeve,
/// PlayerBadge + ad + sağda "Sen"/"YZN" etiketi.
class _PlayerRow extends StatelessWidget {
  final int index;

  /// Oturum açıksa 1. koltuk hesap sahibidir (web isAccount): avatar +
  /// kilitli isim. Profil beklenirken (accountPending) nötr "Yükleniyor…"
  /// gösterilir — bir anlık "Misafir" yazıp gerçek adla değişmesin (web'de
  /// yaşanmış kimlik-değişimi hatası).
  final String? accountName;
  final String? accountAvatarUrl;
  final bool accountPending;

  const _PlayerRow({
    required this.index,
    this.accountName,
    this.accountAvatarUrl,
    this.accountPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final col = playerColors[index % playerColors.length];
    final isAccount = index == 0 && accountName != null;
    final isPending = index == 0 && accountPending;
    final name = index == 0
        ? (accountName ?? (isPending ? 'Yükleniyor…' : guestPlayerName))
        : 'Yapay Zeka ${index + 1}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.tint,
        border: Border.all(color: col.base),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (isAccount)
            KAvatar(url: accountAvatarUrl, name: accountName, size: 20)
          else if (isPending)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _panel,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
            )
          else
            PlayerBadge(index: index),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPending ? _muted : _text,
              ),
            ),
          ),
          Text(
            index == 0 ? 'SEN' : 'YZ${index + 1}',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 9,
              letterSpacing: 1,
              color: col.base,
            ),
          ),
        ],
      ),
    );
  }
}

/// Web SavedGameRow portu: solda katılımcı avatarları (misafir "?" + robot)
/// ve "Sıra: X", sağda yeşil "SENİN HAMLEN BEKLENİYOR" + kalan süre.
class _SavedGameRow extends StatelessWidget {
  final GameState state;
  final String subtitle;
  final int savedAtMs;

  /// Web remainingTime'ın aynı ayrımı: misafirde kesin sonuç silinme
  /// ("silinecek"); girişli kullanıcının başlamış (turnCount>=2) oyununda
  /// süre dolunca -2'li teslim gerçek/anında sonuç ("teslim sayılacak").
  final bool willSurrender;

  /// Girişli kullanıcının satırında insan koltuğun avatarı (web
  /// savedGameAvatars: profil fotoğrafı ya da baş harfler); null + misafir
  /// satırında "?" çemberi.
  final String? accountAvatarUrl;
  final bool isGuest;
  final VoidCallback? onTap;
  const _SavedGameRow({
    required this.state,
    required this.subtitle,
    required this.savedAtMs,
    this.willSurrender = false,
    this.accountAvatarUrl,
    this.isGuest = false,
    this.onTap,
  });

  /// Web remainingTime portu (<24 saatte kırmızı + dakika hassasiyeti).
  ({String text, bool urgent}) _remaining() {
    final verb = willSurrender ? 'teslim sayılacak' : 'silinecek';
    final ms = savedAtMs +
        abandonTimeout.inMilliseconds -
        DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return (text: 'Bugün $verb', urgent: true);
    final totalMinutes = (ms / (60 * 1000)).ceil();
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    final minutes = totalMinutes % 60;
    final text = days > 0
        ? '$days gün $hours saat sonra $verb'
        : '$hours saat $minutes dakika sonra $verb';
    return (text: text, urgent: days < 1);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ortak bileşen (parça 5c'de çıkarıldı) — "Son
                  // Oynadıklarım" satırı da aynısını kullanıyor; ikisi
                  // sessizce ayrışmasın diye tek kaynak.
                  PlayerAvatarRow(players: [
                    for (final p in state.players)
                      AvatarRowPlayer(
                        name: p.name,
                        isAi: p.isAI,
                        // Yerel oyunda insan koltuk HER ZAMAN bu cihazdaki
                        // kişi; misafirse profil/ad yok → "?" yedeği.
                        isGuest: !p.isAI && isGuest,
                        avatarUrl: p.isAI ? null : accountAvatarUrl,
                      ),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'SENİN HAMLEN BEKLENİYOR',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // trUpper ŞART — native toUpperCase 'silinecek'i noktasız
                  // I ile 'SILINECEK' yapar (test yakaladı; web'de CSS
                  // uppercase tr locale ile doğruydu).
                  trUpper(remaining.text),
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    letterSpacing: 0.5,
                    color: remaining.urgent ? const Color(0xFFDC2626) : _muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

