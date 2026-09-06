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
// linki kurallar modalını açar; yanındaki "Tanıtım" `IntroScreen`'i yeniden
// gösterir (bayrağa dokunmadan).
//
// 17 Ağustos 2026 — GİRİŞLİ/MİSAFİR ekranı ikiye ayrıldı (web'deki aynı gün
// verilen kararla birebir): logonun altındaki tanıtım paragrafı + link satırı
// artık YALNIZCA MİSAFİRDE görünüyor; girişli kullanıcı doğrudan "OYUN TİPİ"
// başlığını görüyor.
//
// 19 Ağustos 2026 (kullanıcı isteği) — iki değişiklik: (a) misafir link
// satırındaki "Arkadaşınla paylaş" FOOTER'a taşındı ve oradaki "Paylaş"
// artık GİRİŞTEN BAĞIMSIZ (web `Setup.tsx` de onu `user &&` koşuluna
// bağlamıyor); boşalan yere "Tanıtım" linki kondu. (b) Footer'ın altına
// web'in "Son çağrı" bölümündeki gibi bir "© Kelimeki" satırı eklendi.
//
// "Arkadaşınla" sekmesi web'in `liveActionCount` rozetini taşır (bekleyen
// davet + sırası çağıranda olan aktif oyun) ve girişte, dikkat bekleyen bir
// şey varsa, sekme otomatik "Arkadaşınla"ya geçer (web
// `appliedLoginDefaultRef`, hesap başına bir kez) — 7 Ağustos 2026.
import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/analytics.dart';
import '../../bootstrap.dart';
import '../../config/env.dart';
import '../../data/cloud_save_repo.dart';
import '../../data/games_api.dart';
import '../../data/online_games_api.dart'
    show InitialMainView, PendingLiveGameCounts, decideInitialMainView;
import '../../data/friend_invite_inbox.dart' show inviteTokensFromEvents;
import '../../storage/pending_event_store.dart' show friendInviteTokenKind;
import '../../data/error_reporter.dart';
import '../../data/friends_api.dart'
    show inviteAcceptErrorText, inviteAcceptKaliciRet;
import '../friends/friends_modal.dart' show showFriendInfoDialog;
import '../../game/game_controller.dart';
import '../../game/local_game_repo.dart';
import '../../storage/local_save_store.dart' show abandonTimeout;
import '../../util/away_return.dart';
import '../../util/share_board.dart';
import '../rank/league_rank.dart';
import '../rank/rank_scores.dart';
import '../rank/rank_seal.dart';
import '../game/count_badge.dart';
import '../game/game_screen.dart';
import '../game/help_modal.dart';
import '../intro/intro_screen.dart';
import '../game/logo_mark.dart';
import '../game/neo_button.dart';
import '../game/player_badge.dart';
import '../game/player_avatar_row.dart';
import '../game/player_colors.dart';
import '../../util/game_list_order.dart';
import '../devam_eden_govde.dart';
import '../ai_level_badge.dart';
import '../../util/ai_level.dart';
import '../../util/score_line.dart';
import '../live/live_games_tab.dart';
import '../rank/league_rewards_host.dart';
import '../auth/account_button.dart';
import '../auth/k_avatar.dart';
import 'membership_perks_box.dart';
import 'recent_games_section.dart';
import '../tap_target.dart';
import '../tokens.dart';
import '../route_observer.dart';
import '../game/neo_box.dart';
import '../auth/auth_modal.dart';
import '../auth/legal_modals.dart';
import '../game/dialog_shell.dart';
import '../feedback/feedback_modal.dart';
import '../../data/feedback_api.dart';
import '../../util/offline_notice.dart';

const _panel = kPanel;
const _border = kBorder;
const _muted = kMuted;
const _text = kText;
const _accent = kAccent;

class SetupScreen extends StatefulWidget {
  final AppServices services;

  /// Test injection'ı için — bkz. `GameHistoryModal.share`'daki aynı
  /// desen. Verilmezse gerçek `shareBoard` (sistem paylaş sayfası) kullanılır.
  final ShareBoardFn? share;

  const SetupScreen({super.key, required this.services, this.share});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

/// "Yapay Zeka ile" liste görünümünün Devam Edenler/Son Oynananlar tabı —
/// web `localSubTab` ('active'|'recent'), `LiveGamesTab`'daki (Arkadaşınla)
/// BİREBİR AYNI çözüm (bkz. Setup.tsx: "çok sayıda devam eden YZ oyunu olan
/// biri için 'Son Oynadıklarım' listesi ekranın altına düşüp scroll
/// etmeden görünmüyordu"). "Oyun Davetleri" kavramı burada yok, yalnızca
/// iki sekme.
enum _LocalSubTab { active, recent }

class _SetupScreenState extends State<SetupScreen>
    with WidgetsBindingObserver, RouteAware {
  int _count = 2;

  /// ZORLUK (ROADMAP #23 Faz 4 — web `Setup.tsx`in `level` state'i): varsayılan
  /// Normal (bugünkü motor), her yeni oyun formu açılışında Normal'e döner;
  /// misafirde de var (misafir de YZ'ye karşı oynuyor: kaydı/puanı yok ama
  /// seçim yine anlamlı). Zor, Faz 5'e kadar seçenek listesinde YOK
  /// (`selectableAiLevels`). Oyun BAŞINDA kilitlenir, 4 kişilikte üç YZ'ye
  /// birden uygulanır.
  AiLevel _level = AiLevel.normal;

  /// Web `mainView` ('local' | 'live') — OYUN TİPİ sekmeleri. Canlı sekme
  /// yalnızca görünümü değiştirir; YZ tarafının state'i (kayıtlar/form)
  /// mount'ta kaldığından geçişte kaybolmaz.
  bool _liveView = false;

  /// Web: sekme değişiminde (Arkadaşınla ↔ Yapay Zeka ile) her zaman
  /// "Devam Edenler"e döner (`useEffect(() => setLocalSubTab('active'),
  /// [mainView])`) — `_liveView`'i değiştiren HER yer bunu da sıfırlamalı.
  _LocalSubTab _localSubTab = _LocalSubTab.active;

  /// "Arkadaşınla (N)" rozeti — bekleyen davet + sırası çağıranda olan
  /// aktif oyun toplamı (web `liveActionCount`). LiveGamesTab kendi
  /// listesini ayrıca çeker — küçük bir tekrar fetch pahası web'in de
  /// kabul ettiği bir ödün.
  int _liveActionCount = 0;

  /// Bitişini GÖRMEDİĞİ Canlı oyunlar (3 Eylül 2026, kullanıcı isteği).
  /// Sahibi burası, çünkü aynı liste İKİ yeri birden besliyor:
  /// "Arkadaşınla" ÜST sekmesinin rozeti ve `LiveGamesTab`'ın
  /// "Son Oynananlar" ALT sekmesinin rozeti + satırlardaki "YENİ".
  ///
  /// ⚠ Rozet yalnızca UYGULAMA İÇİNDE: girişte hangi sekmenin açılacağına
  /// ([decideInitialMainView]) BİLEREK karışmıyor — o "yapacak işin var"
  /// demek, biten bir oyun ise haber. Kullanıcı kararı. Web ikizi:
  /// `Setup.tsx` → `finishedUnseen`.
  List<String> _finishedUnseen = const [];

  /// Giriş varsayılanı kararının HAM girdisi (rozetten ayrı): karar bir de
  /// `_cloudSaves`in bilinmesini bekliyor, ama rozet ilk sayı gelir gelmez
  /// güncellenmeli. `_lastUserId` değişince sıfırlanır.
  PendingLiveGameCounts? _liveCounts;

  /// "Yapay Zeka ile (N)" rozeti — web `Setup.tsx`'teki `localSaveCount` ile
  /// BİREBİR aynı formül: girişli kullanıcıda devam eden bulut kaydı sayısı,
  /// misafirde tek slot olduğundan 0 ya da 1. Bu, "Devam Edenler" alt
  /// sekmesinin rozetiyle AYNI sayı olmak zorunda — kapsayan sekmenin
  /// rozeti kapsananların toplamıdır (kök `CLAUDE.md`, `CountBadge`
  /// "toplama kuralı"); ayrışırlarsa zincir kopar.
  int get _localSaveCount => widget.services.auth.user != null
      ? (_cloudSaves?.length ?? 0)
      : (_savedState != null ? 1 : 0);
  Timer? _liveBadgeDebounce;

  /// Öne dönüşte bulut senkronunun debounce'u — bekleyen timer dispose'ta
  /// iptal edilmezse widget söküldükten sonra ateşlenip "A Timer is still
  /// pending" flake'i üretir (Parça 11/21'in aynı dersi).
  Timer? _cloudSyncDebounce;
  void Function()? _unsubscribeLiveBadge;

  /// Girişte "Arkadaşınla"ya otomatik geçiş — yalnızca hesap başına BİR
  /// KEZ (web `appliedLoginDefaultRef`); `_lastUserId` değişince sıfırlanır.
  bool _appliedLoginDefault = false;

  /// Öne dönüşte "bu bir yeniden giriş mi?" sorusunu yanıtlar (web
  /// `awayTrackerRef`).
  final AwayTracker _awayTracker = AwayTracker();

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

  /// Teşhis satırı için: depolama katmanı gerçekten açıldı mı ve sunucuya
  /// itilmeyi bekleyen kaç ayna var (10 Ağustos 2026 — depo açılamadığında
  /// offline hamleler sessizce kayboluyordu, cihazda görünür bir iz yoktu).
  String _diagStorage = 'depo…';
  int _diagPendingMirrors = 0;

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

  /// Bulut kaydı listesi sunucuya ulaşamadı — YZ sekmesi elde gösterilecek
  /// kayıt yoksa çevrimdışı önerisini gösterir. (Kayıt VARSA liste aynen
  /// çizilir: devam eden YZ oyunları çevrimdışı da oynanabiliyor.)
  bool _cloudSavesFailed = false;
  String? _previewedInviteToken;

  /// Hesap sahibinin rütbe mührü için k-lig puanı (18 Ağustos 2026).
  /// `leaderboard` view'ından toplu okunur — ödül puanı DAHİL; 17
  /// Ağustos'ta kaldırılan parantezli `player_stats` toplamıyla
  /// KARIŞTIRMA (o, ödülleri saymadığı için gerçek puandan kopmuştu).
  late final RankScores _rankScores;

  @override
  void initState() {
    super.initState();
    _rankScores = RankScores(widget.services.stats)..addListener(_onRankScores);
    _lastUserId = widget.services.auth.user?.id;
    _lastAuthUserIdForLiveViewReset =
        _lastUserId; // React'in mount-anı effect'i
    widget.services.auth.addListener(_onAuthEvent);
    // "Canlı sekmesini aç" istekleri (Faz 3): bildirimdeki oyun tahta
    // olarak açılamadığında (davet beklemede / listede yok) _HomeGate bu
    // sayacı artırıyor — kullanıcı en azından doğru sekmeye insin.
    widget.services.liveTabRequests.addListener(_onLiveTabRequest);
    // Bağlantı durumu — çevrimdışı mesajı ANINDA çıksın (web
    // `useOnlineStatus`; portta önce ağ çağrısının düşmesi bekleniyordu).
    widget.services.onlineStatus.addListener(_onConnectivity);
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
        if (mounted) setState(() => _diagStorage = 'depo ok');
        final repo = LocalGameRepo(s);
        _repo = repo;
        await _refreshSaveStatus(); // load süresi dolanı olaya çevirir
        await _sweepLocalAbandoned(); // web'in Setup süpürme refleksi
        unawaited(_syncCloud()); // girişliyse migrasyon + liste + flush
        unawaited(_processInvites()); // kuyruklanmış davet token'ları
      }).catchError((Object e) {
        // Depo AÇILAMADI: kalıcılık yok. Sessiz kalmak, kullanıcının
        // hamlelerini kaybettiğini fark etmemesi demek — teşhis satırında
        // görünür kıl.
        debugPrint('[Kelimeki] depolama açılamadı: $e');
        if (mounted) setState(() => _diagStorage = 'DEPO YOK');
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
    // İkinci geçiş, kanalın KOPUP yeniden bağlanması: kopukken yayınlanan
    // olaylar KAYIPTIR, o yüzden yeniden bağlanmanın kendisi bir tazeleme
    // sinyalidir. `LiveGamesTab` bu kancayı baştan beri taşıyordu, rozet
    // taşımıyordu — 27 Ağustos 2026'da bunun bedeli ölçüldü (aşağı bkz.).
    _unsubscribeLiveBadge = widget.services.onlineGames?.gateway.subscribe(
        _scheduleLiveBadgeRefresh,
        onResubscribe: _scheduleLiveBadgeRefresh);
    // Bağlantı geri geldiğinde de tazele — web `Setup.tsx` bunun için
    // `window.addEventListener('online', …)` kuruyor (visibilitychange/focus
    // ile birlikte); portta yalnızca öne dönüş taşınmıştı, `online` karşılığı
    // EKSİKTİ. Yani bu bir parite kırılmasıydı.
    widget.services.onlineStatus.addListener(_onLiveBadgeConnectivity);
    unawaited(_refreshLiveBadge());
  }

  void _onInviteEvent() => unawaited(_processInvites());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rota aboneliği initState'te KURULAMAZ — `ModalRoute.of` InheritedWidget
    // okuduğundan orada henüz hazır değil. Tekrar tekrar çağrılması zararsız:
    // `RouteObserver.subscribe` aynı (abone, rota) çiftini bir kez tutuyor.
    final route = ModalRoute.of(context);
    if (route is PageRoute) kRouteObserver.subscribe(this, route);
  }

  /// Üstümüzdeki tam ekran rota kapandı — Setup yeniden görünür.
  ///
  /// Web'in Setup'ı unmount edip remount ederek BEDAVA aldığı tazeleme; port
  /// Setup'ı `MaterialApp.home`da tuttuğundan onu elle vermek zorunda (gerekçe:
  /// `ui/route_observer.dart`). Canlı tahtayı açan HANGİ kapı olursa olsun —
  /// liste, ya da Sürüm B'nin bildirim kapısı — dönüş bu noktadan geçer.
  @override
  void didPopNext() => _scheduleLiveBadgeRefresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _awayTracker.markAway();
      return;
    }
    // Uzun bir aradan sonra dönüş = ekrana yeniden giriş: varsayılan sekme
    // kararı yeniden silahlanır (bkz. `util/away_return.dart`). Tek başına
    // sekmeyi DEĞİŞTİRMEZ — `_refreshLiveBadge` hâlâ yalnızca bekleyen bir
    // iş varsa Canlı'ya geçiriyor, yani boş dönüşte kullanıcı yerinde kalır.
    // Üstte bir oyun ekranı varsa bu dönüş Setup'a bir GİRİŞ değil: sekmeyi
    // kullanıcının arkasında sessizce değiştirmemek için karar atlanır (yine
    // de tüketilir — bir sonraki dönüş kendi süresini ölçsün). Webde bunun
    // karşılığı yapısal: orada Setup oyun sırasında zaten unmount oluyor,
    // yani ref'ler her dönüşte kendiliğinden tazeleniyor.
    final setupVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_awayTracker.takeLongAway() && setupVisible) {
      _appliedLoginDefault = false;
    }
    _scheduleLiveBadgeRefresh();
    // Bulut senkronu da öne dönüşte tazelenmeli — web'in `refreshCloudSaves`
    // için kurduğu visibilitychange/focus/online dinleyicilerinin karşılığı
    // (App.tsx, 4 Ağustos 2026). Mobilde bu HİÇ taşınmamıştı: Setup'ta
    // otururken ağ geri gelirse hiçbir şey `_syncCloud`u tetiklemiyordu,
    // yani offline'da biriken ayna ancak kullanıcı bir oyuna girip çıkınca
    // ya da uygulamayı yeniden başlatınca sunucuya itiliyordu. 10 Ağustos
    // 2026'da TESTING.md 8.3 koşulurken görüldü: oyun cihazda listedeydi
    // ama web'de dakikalarca görünmedi (veri kaybı değil, gecikme).
    // Ayrıca web'deki asıl gerekçe de geçerli: uygulama Setup'ta günlerce
    // arka planda kalırsa 7 günlük terk süpürmesi hiç çalışmıyordu.
    _scheduleCloudSync();
    // Geri bildirim kuyruğu da aynı gerekçeyle: initState'teki flush YALNIZCA
    // uygulama açılışında koşuyor (SetupScreen `MaterialApp.home`, oyunlar
    // `Navigator.push` ile açıldığından ekran hiç unmount OLMUYOR — "Setup'a
    // her geliş" notu bu yüzden yanıltıcıydı). Yani Setup'ta otururken ağ
    // dönerse kuyruk uygulama yeniden başlatılana kadar bekliyordu. Kuyruk
    // boşken `flushPending` ağa hiç dokunmadan erken dönüyor, bu yüzden her
    // öne dönüşte çağırmak bedelsiz — ayrı bir debounce'a gerek yok.
    unawaited(widget.services.feedback?.flushPending());
    // Davet kuyruğu da aynı gerekçeyle: ağ hatasında token geri konuyor
    // (bkz. `_processInvites`), ama onu yeniden deneyecek bir şey yoksa
    // kuyruk uygulama yeniden başlatılana kadar bekler. Kuyruk boşken
    // `takeAll` hiçbir şey döndürmeden çıkıyor, yani bu çağrı bedelsiz.
    unawaited(_processInvites());
  }

  /// KAÇIRILAN OLAY KALICI KAYBA DÖNÜŞÜYORDU (27 Ağustos 2026, kullanıcı
  /// bildirdi): zayıf bağlantıda Realtime kanalı kopunca kendi hamlelerinin
  /// yayınladığı olaylar kayboluyor; `pendingCounts()` de ağ hatasında `null`
  /// döndüğünden (bilinçli — bkz. `_refreshLiveBadge`) SON BİLİNEN rozet
  /// korunuyordu. Sonuç: "Arkadaşınla" rozeti 8'de takılı kalırken listedeki
  /// her satır "Rakibin hamlesi bekleniyor" diyordu — rozet ile liste
  /// birbiriyle ÇELİŞİYORDU, çünkü liste bu iki kancayı taşıyor, rozet
  /// taşımıyordu.
  ///
  /// Bu, bu projede kaçırılan olayın kalıcı kayba dönüştüğü DÖRDÜNCÜ yer
  /// (sohbet Realtime'ı, bulut senkronu, `useOnlineStatus` aynı çareyi
  /// almıştı). Olay tabanlı yeni bir durum eklerken ilk soru şu olmalı:
  /// "olay kaçarsa ne olur ve onu kim geri getirir?"
  void _onLiveBadgeConnectivity() {
    if (!mounted) return;
    if (widget.services.onlineStatus.online) _scheduleLiveBadgeRefresh();
  }

  void _scheduleLiveBadgeRefresh() {
    _liveBadgeDebounce?.cancel();
    _liveBadgeDebounce = Timer(const Duration(milliseconds: 300),
        () => unawaited(_refreshLiveBadge()));
  }

  void _scheduleCloudSync() {
    _cloudSyncDebounce?.cancel();
    _cloudSyncDebounce =
        Timer(const Duration(milliseconds: 300), () => unawaited(_syncCloud()));
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
    // `null` = sayılar bilinmiyor (ağ): son bilinen rozet KORUNUR ve tek
    // seferlik giriş kararı TÜKETİLMEZ — bir sonraki başarılı tazeleme
    // (foreground/Realtime) hâlâ uygulayabilsin (21 Ağustos 2026).
    if (counts == null) return;
    setState(() {
      _liveCounts = counts;
      _liveActionCount = counts.inviteCount + counts.myTurnCount;
      // ⚠ `null` = bilinmiyor → son bilineni KORU (yukarıdaki iki sayının
      // aynı doktrini). Boş liste yazmak rozeti sessizce kaybettirirdi.
      final unseen = counts.finishedUnseenIds;
      if (unseen != null) _finishedUnseen = unseen;
    });
    _applyInitialTab();
  }

  /// Tek seferlik giriş varsayılanı. İKİ yerden çağrılıyor — sayılar
  /// geldiğinde ve `_cloudSaves` geldiğinde — çünkü hangisinin önce
  /// döneceği belli değil ve karar İKİSİNİ birden gerektiriyor. Sonradan
  /// gelen taraf kararı tetiklemezse, ilk turda ertelenen karar bir daha
  /// hiç uygulanmazdı (yalnızca foreground/Realtime tazelemesini
  /// bekleyerek).
  void _applyInitialTab() {
    if (_appliedLoginDefault || !mounted) return;
    final hedef = decideInitialMainView(_liveCounts, _cloudSaves);
    if (hedef == null) return; // veri eksik — karar TÜKETİLMEZ
    _appliedLoginDefault = true;
    if (hedef != InitialMainView.live) return;
    setState(() {
      _liveView = true;
      _localSubTab = _LocalSubTab.active;
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
  /// Terms/Privacy içindeki "Görüş Bildir formu" linki — AuthModal'daki
  /// aynı desen (web'de her iki modal da FeedbackModal'ı `general` ile açar).
  void _openFeedback() {
    final repo = widget.services.feedback;
    if (repo == null) return;
    showFeedbackModal(context,
        auth: widget.services.auth,
        feedback: repo,
        source: FeedbackSource.general);
  }

  /// Footer'daki "Paylaş" linkinin kendi kutusu — iPad popover ankrajı
  /// BURADAN alınmalı. `State.context` kullanmak ekranın TAMAMINI ankraj
  /// yapıyordu ve iPad'de paylaşım sessizce asılı kalıyordu (2 Eylül 2026,
  /// ölçüldü — bkz. `shareOriginFrom`). Desen oyun geçmişindeki
  /// `_captureKey.currentContext ?? context` ile aynı.
  final GlobalKey _shareLinkKey = GlobalKey();

  Future<void> _handleShare() {
    // GA4 `invite_link_shared` {source: setup_footer} — gerekçe ve ölçüm
    // sınırı friends_modal'daki eş çağrının yorumunda.
    analytics.log('invite_link_shared', {'source': 'setup_footer'});
    return (widget.share ?? shareBoard)(
      png: null,
      text: 'Hemen ücretsiz dene!',
      url: '$webOrigin/?ref=arkadas',
      origin: shareOriginFrom(_shareLinkKey.currentContext ?? context),
    );
  }

  /// Tanıtım ekranını YENİDEN açar (19 Ağustos 2026, kullanıcı isteği:
  /// menüdeki "Tanıtım" maddesi kaldırılıp logo altındaki link satırına
  /// taşındı — "Arkadaşınla paylaş"ın yerine).
  ///
  /// `seenIntro` bayrağına DOKUNMAZ: bayrak "ilk açılışta gösterildi mi"
  /// sorusunun cevabı, buradan açmak kullanıcının kendi isteği. `onDone`
  /// bu yolda yalnızca pop eder — Setup'a "geçiş" yok, zaten Setup'tayız.
  void _openIntro() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        // Telemetrideki `route` alanı — bkz. `ErrorReporterRouteObserver`.
        settings: const RouteSettings(name: 'intro'),
        builder: (ctx) => IntroScreen(onDone: () => Navigator.of(ctx).pop()),
      ),
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
      if (!mounted) return;
      if (name != null) {
        await showFriendInfoDialog(context,
            "$name seni Kelimeki'de arkadaş eklemek istiyor. Giriş yaptığında otomatik olarak ekleneceksiniz.");
        return;
      }
      // `inviteInfo` null döndü — SEBEBİ BİLİNMİYOR (`FriendsRepo.inviteInfo`
      // her hatayı null'a çeviriyor: geçersiz token de, düşen istek de).
      // Bu yüzden teşhis UYDURULMUYOR; bilinen tek sinyal olan bağlantı
      // durumuna bakılıyor — `offline_notice.dart`'ın "çevrimdışı DEĞİL,
      // yükleyemedik" ayrımıyla aynı disiplin. Öncesinde bu dal HİÇBİR ŞEY
      // göstermiyordu: misafir linke dokunuyor, ekranda hiçbir şey olmuyordu.
      if (!widget.services.onlineStatus.online) {
        // Çevrimdışıyken "bu token'ı zaten gösterdim" damgasını GERİ AL:
        // aksi halde bağlantı dönse bile aynı linke bir daha bakılmaz ve
        // kullanıcı çıkışsız bir uyarıda kalırdı (damga bu satırın üstünde,
        // istekten ÖNCE konuyor — mükerrer diyalogları önlemek için).
        _previewedInviteToken = null;
        await showFriendInfoDialog(
            context, 'Davet linkini açmak için internet bağlantısı gerekiyor.');
        return;
      }
      await showFriendInfoDialog(context,
          'Bu davet linki açılamadı — süresi dolmuş ya da geçersiz olabilir.');
      return;
    }
    _processingInvites = true;
    try {
      final s = await storage;
      // Mükerrer/bozuk kayıt elemesi saf yardımcıda (gerekçe orada —
      // soğuk başlangıçta aynı token iki kez kuyruğa girebiliyor).
      final events =
          inviteTokensFromEvents(await s.events.takeAll(friendInviteTokenKind));
      for (final token in events) {
        try {
          final name = await friends.acceptInvite(token);
          if (mounted) {
            await showFriendInfoDialog(
                context, '${name ?? 'Bir oyuncu'} ile artık arkadaşsınız.');
          }
        } catch (err) {
          // 26 Ağustos 2026 — ROADMAP madde 1'in "portta davet kabulü
          // SESSİZCE düşüyor" maddesi. Burası yalnızca `debugPrint`liyordu:
          // kişi kendi davet linkine (ya da süresi geçmiş bir linke)
          // dokununca ekranda HİÇBİR ŞEY olmuyordu. Web `FriendInvitePage`
          // bunu 25 Ağustos'ta çözdü; karar mantığı `inviteAcceptErrorText`e
          // çıkarıldı, iki taraf artık aynı kuralı okuyor.
          debugPrint('[Kelimeki] davet kabul edilemedi (token düştü): $err');
          // Beklenen retler (P0001 — "Kendi linkinle arkadaş olamazsın.") ve
          // ağ hataları telemetriye GİTMEZ: gürültü sinyali boğar
          // (`ErrorReporter`in "NE KAYDEDİLMEZ" kuralı; `report` varsayılan
          // `manual` türünde ağ filtresini kendisi UYGULAMAZ).
          if (!inviteAcceptKaliciRet(err) && !isNetworkError(err)) {
            errorReporter.report(err, context: 'setup._processInvites');
          }
          // AĞ HATASINDA TOKEN KUYRUĞA GERİ KONUYOR (26 Ağustos 2026,
          // kullanıcı kararı). `takeAll` YIKICI — okurken siliyor (tek
          // transaction: SELECT + DELETE) — yani istek tam o anda düşerse
          // davet hem kurulmuyor hem token kayboluyordu; kullanıcının tek
          // çaresi linke yeniden dokunmaktı, link elinde yoksa davet
          // tamamen kayıptı.
          //
          // YALNIZCA ağ hatası geri konuyor: sunucunun KALICI reddini
          // (P0001 — "Kendi linkinle arkadaş olamazsın.") geri koymak,
          // her açılışta aynı diyaloğu gösteren ölümsüz bir kayıt üretirdi.
          // Bilinmeyen hatalar da geri KONMUYOR — sebebini bilmediğimiz
          // bir şeyi sonsuza dek tekrarlatmak yanlış taraf; onlar zaten
          // telemetriye düşüyor (yukarıda).
          if (isNetworkError(err)) {
            await s.events.add(friendInviteTokenKind, {'token': token});
          }
          if (mounted) {
            await showFriendInfoDialog(context, inviteAcceptErrorText(err));
          }
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
    // `games` ÖNCE çözülüyor: drain yıkıcı (takeAll = SELECT+DELETE), yani
    // önce boşaltıp sonra "games yoksa dön" demek olayları kaybettirirdi.
    final games = _games ?? await widget.services.games;
    if (games == null) return;
    final events = await repo.drainAbandonedGames();
    if (events.isEmpty) return;
    for (final e in events) {
      await games.recordAbandoned(e.state, endedAtMs: e.savedAtMs);
    }
  }

  @override
  void dispose() {
    kRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.services.auth.removeListener(_onAuthEvent);
    widget.services.liveTabRequests.removeListener(_onLiveTabRequest);
    widget.services.onlineStatus.removeListener(_onConnectivity);
    widget.services.inviteInbox?.removeListener(_onInviteEvent);
    _liveBadgeDebounce?.cancel();
    _cloudSyncDebounce?.cancel();
    widget.services.onlineStatus.removeListener(_onLiveBadgeConnectivity);
    _unsubscribeLiveBadge?.call();
    _rankScores.removeListener(_onRankScores);
    _rankScores.dispose();
    super.dispose();
  }

  void _onRankScores() {
    if (mounted) setState(() {});
  }

  /// Faz 3 — bildirim yönlendirmesinin sekme dalı. Sayaç her arttığında
  /// Arkadaşınla'ya geç; alt sekme kuralı (`_liveView` değişen her yer
  /// `_localSubTab`ı sıfırlar) burada da geçerli. "Oyun Davetleri" alt
  /// sekmesini AYRICA seçmek gerekmiyor: bekleyen davet varken LiveGamesTab
  /// zaten o alt sekmeyle açılıyor (kendi varsayılan-kova kuralı, testli).
  void _onLiveTabRequest() {
    if (!mounted) return;
    setState(() {
      _liveView = true;
      _localSubTab = _LocalSubTab.active;
    });
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
      if (mounted) {
        setState(() {
          _liveView = false;
          _localSubTab = _LocalSubTab.active;
        });
      }
    }

    if (id != _lastUserId) {
      // Çıkış ya da hesap değişimi: önceki hesabın listesi/form durumu
      // yeni hesaba sızmasın (web mainView/cloudSaves sıfırlama dersleri).
      _lastUserId = id;
      _appliedLoginDefault = false;
      if (mounted) {
        setState(() {
          _cloudSaves = null;
          _liveCounts = null;
          _creatingLocal = false;
          _liveActionCount = 0;
          _finishedUnseen = const [];
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
    // ⚠ BU ADIMLARIN HİÇBİRİ LİSTEYİ ENGELLEYEMEZ.
    // Web'de bunlar ÜÇ AYRI effect (misafir migrasyonu, `flushPendingGames`,
    // `refreshCloudSaves`); port hepsini tek fonksiyonda ardışık koşturuyor.
    // 13 Ağustos 2026'da bunun bedeli görüldü: kullanıcı "Yapay Zeka ile"
    // sekmesinde kalıcı "Yükleniyor…" bildirdi (hesabın SIFIR bulut kaydı
    // vardı, yani başarılı bir liste boş liste dönmeliydi). Buradaki bir
    // istisna `_syncCloud`'u yarıda kesiyor, `_cloudSaves` sonsuza dek null
    // kalıyor ve "Yükleniyor…" TERMİNAL bir duruma dönüşüyordu — üstelik
    // çağrı `unawaited` olduğundan hata da görünmüyordu.
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
      } catch (e) {
        debugPrint('[Kelimeki] misafir kaydı taşınamadı, listeye devam: $e');
      } finally {
        _migratingGuest = false;
      }
    }
    // Kuyrukta bekleyen bitmiş/terk edilmiş oyun kayıtlarını (misafirken
    // ya da offline'da biriken) bu hesaba işle — web'in `flushPendingGames`
    // refleksi (açılış + giriş durumu değişimi).
    // `services.games` bir Future — açılışta çözülmediyse/fırladıysa liste
    // yine çekilmeli (yukarıdaki nota bkz.).
    GamesRepo? games;
    try {
      games = _games ?? await widget.services.games;
    } catch (e) {
      debugPrint('[Kelimeki] games deposu alınamadı, listeye devam: $e');
    }
    if (games != null) unawaited(games.flushPending());

    // Offline'da yerel aynada biriken devam eden oyunları ÖNCE sunucuya it
    // (Parça 38) — listeleme bunu beklemeli ki taze satırları görsün.
    // Başarısız olanlar aynada kalır; `list(userId:)` onları zaten
    // bindirdiğinden kullanıcı offline'da da güncel oyununu görür.
    // Flush FIRLARSA liste yine çekilmeli (10 Ağustos 2026): depo
    // açılamadığında `flushMirrored` hata veriyor ve bu satır tüm senkronu
    // — 7 günlük süpürme dahil — bloke ediyordu. Repo artık hatayı kendi
    // içinde yutuyor, bu try ikinci bir güvenlik ağı.
    try {
      await cloud.flushMirrored(user.id);
    } catch (e) {
      debugPrint('[Kelimeki] ayna itilemedi, listeye devam: $e');
    }
    CloudSaveList? list;
    try {
      list = await cloud.list(userId: user.id);
      if (list != null) {
        // 7 günü dolup bu turda iddia edilen kayıtlar → -2 cezalı teslim
        // (web refreshCloudSaves'in claim dalı). Ceza yazımı FIRLARSA liste
        // yine çizilmeli — aksi halde tek bir başarısız `games` yazması
        // ekranı kalıcı "Yükleniyor…"da bırakırdı.
        for (final a in list.abandoned) {
          await games?.recordAbandoned(a.state, endedAtMs: a.updatedAtMs);
        }
      }
    } catch (e) {
      debugPrint('[Kelimeki] bulut kaydı listesi/cezası hata verdi: $e');
    }
    if (!mounted || widget.services.auth.user?.id != user.id) return;
    var pending = 0;
    try {
      pending = await cloud.pendingMirrorCount(user.id);
    } catch (e) {
      debugPrint('[Kelimeki] bekleyen ayna sayısı alınamadı: $e');
    }
    if (!mounted) return;
    if (list == null && _cloudSaves != null) {
      setState(() {
        _cloudSavesFailed = true;
        _diagPendingMirrors = pending; // ağ hatası eskiyi ezmesin
      });
      return;
    }
    setState(() {
      _cloudSavesFailed = list == null;
      _cloudSaves = list?.saves;
      _diagPendingMirrors = pending;
    });
    // YZ listesi artık biliniyor — sayılar önce geldiyse ertelenen karar
    // burada uygulanır.
    _applyInitialTab();
  }

  /// Normal biten oyunun `games` kaydı + anonim bitiş telemetrisi
  /// (web'in oyun-bitti effect'i). Misafirse kayıt kuyruğa girer.
  Future<void> _recordFinishedGame(GameState state) async {
    final games = _games ?? await widget.services.games;
    await games?.recordFinished(state);
    // Kayıt sunucuya düştüğü an k-lig ödül kontrolü — `games` INSERT
    // trigger'ı (`games_award_league_rewards`) ödülü AYNI transaction'da
    // açtığından hemen ardından çekmek güvenli (web App.tsx'teki
    // `saveGameDurable(...).then(requestLeagueRewardCheck)` deseni). O anda
    // etkin host oyun ekranınınki; misafirde kayıt kuyruğa girer, kontrol
    // boş döner ve ödül girişten sonraki ilk kontrolde görünür.
    requestLeagueRewardCheck();
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
      if (!controller.state.isGameOver) {
        // Yeni bir oyun başladı — bayrak SIFIRLANMAK ZORUNDA. Ekran
        // eskiden yalnızca Setup'a dönerek terk edilebildiğinden (o da bu
        // closure'ı bitirdiğinden) tek seferlik bir bool yetiyordu; "TEKRAR
        // OYNA" (Parça 60) aynı ekranda ikinci bir oyun başlatabildiğinden
        // bayrak sıfırlanmazsa o oyun HİÇ kaydedilmezdi — ne `games` satırı
        // ne k-lig puanı (bkz. mobile/CLAUDE.md Parça 60).
        recorded = false;
        return;
      }
      if (recorded) return;
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
      settings: const RouteSettings(name: 'game'),
      builder: (_) => GameScreen(
        controller: controller,
        words: words,
        meanings: widget.services.meanings,
        auth: widget.services.auth,
        // Zoom tanıtım balonunun bayrakları (1 Eylül 2026) — verilmezse
        // balon hiç çıkmaz, yani bu satır özelliğin AÇMA anahtarı.
        storage: widget.services.storage,
        stats: widget.services.stats,
        games: widget.services.games,
        feedback: widget.services.feedback,
        friends: widget.services.friends,
        chat: widget.services.chat,
        leagueRewards: widget.services.leagueRewards,
        onlineStatus: widget.services.onlineStatus,
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

  /// Web `handleStart` paritesi (14 Ağustos 2026 — porta hiç geçmemişti):
  /// misafir "OYUNU BAŞLAT"a bastığında önce bir giriş uyarısı çıkar.
  /// `loading` (kimlik henüz çözülüyor) iken uyarı GÖSTERİLMEZ — web'in
  /// `!loading && !user` koşulu; aksi halde girişli kullanıcı, oturum
  /// okunurken bastığında haksız yere uyarı görürdü.
  Future<void> _handleStart(SetWordSource words) async {
    final auth = widget.services.auth;
    if (!auth.loading && auth.user == null) {
      final proceed = await _showGuestWarning();
      if (!proceed || !mounted) return;
    }
    await _startNewGame(words);
  }

  /// `true` → "Oyna" (misafir olarak başlat).
  ///
  /// ÜÇ ayrı sonuç var ve ikisi de oyunu başlatMIYOR, o yüzden `bool`
  /// yetmiyor: "Giriş Yap" giriş penceresini açar, ✕/dışarı dokunuş ise
  /// kullanıcıyı sessizce kurulum ekranında bırakır (web'de de Escape/✕
  /// ne oyunu başlatıyor ne giriş açıyor).
  Future<bool> _showGuestWarning() async {
    final auth = widget.services.auth;
    final choice = await showDialog<_GuestChoice>(
      context: context,
      // `KModal` DEĞİL `KDialogCard` — 17 Ağustos 2026, cihaz testinde
      // bulundu (kullanıcı: *"çıkan popup başlıksız"*). Web'de İKİ ayrı
      // kabuk var (bkz. `dialog_shell.dart` başlığı) ve bu uyarı ortak
      // `Modal.tsx`'i KULLANMIYOR: `Setup.tsx` içinde elle kurulmuş
      // 384px'lik onay kartı (`max-w-sm`/`rounded-2xl`/`p-6`, ✕ köşede
      // `absolute`). Port başlangıçta `KModal`a `title: ''` geçmişti —
      // niyet doğruydu ("web'de başlıksız") ama kabuk başlık bandını yine
      // de çizdiğinden üstte boş bir alan + ayraç kalıyordu.
      builder: (ctx) => KDialogCard(
        onClose: () => Navigator.of(ctx).pop(_GuestChoice.dismiss),
        content: const Text(
          'Oyunların istatistikleri, k-lig ve arkadaşınla canlı oyun '
          'için lütfen giriş yapın.',
          style: kDialogBodyStyle,
        ),
        // Kabul butonu SOLDA — web'in düz flex sırası (Parça 25).
        actions: [
          kDialogButton(
            label: 'GİRİŞ YAP',
            variant: NeoButtonVariant.accent,
            onPressed: () => Navigator.of(ctx).pop(_GuestChoice.login),
          ),
          kDialogButton(
            // "DEVAM" DEĞİL "OYNA" (18 Ağustos 2026, kullanıcı bildirdi;
            // web `Setup.tsx` ile AYNI turda değişti): uyarı metni
            // üyeliğin faydalarını anlattığından "Devam" cümlenin devamı
            // gibi okunup "üyeliğe devam et" izlenimi veriyordu.
            label: 'OYNA',
            onPressed: () => Navigator.of(ctx).pop(_GuestChoice.proceed),
          ),
        ],
      ),
    );
    // "Giriş Yap" dalı: popup kapandıktan SONRA giriş penceresini aç (web
    // de önce uyarıyı kapatıp sonra AuthModal'ı açıyor).
    if (choice == _GuestChoice.login && mounted) {
      await showLoginModal(context, auth, feedback: widget.services.feedback);
    }
    return choice == _GuestChoice.proceed;
  }

  /// `game_starts` sayaç satırı. `StartAction` dispatch eden İKİ ekran var
  /// (burası ve oyun sonu "Tekrar Oyna" → `game_screen.dart`); ikisi de
  /// `GamesRepo.logStart`e gider — biri atlanırsa huninin "Başlayan" adımı
  /// sessizce eksik sayar.
  /// `logStart`in kendi try/catch'i gateway hatasını yutuyor; buradaki
  /// ikinci sarmalayıcı `services.games` FUTURE'ININ reddedilme ihtimali
  /// için — `unawaited` hatayı yutmaz, yakalanmamış bir async hata doğardı.
  Future<void> _logGameStart(int playerCount) async {
    try {
      final games = _games ?? await widget.services.games;
      await games?.logStart(playerCount: playerCount);
    } catch (_) {
      // Telemetri hiçbir koşulda oyun başlatmayı etkilemez.
    }
  }

  Future<void> _startNewGame(SetWordSource words) async {
    final controller = GameController(words: words);
    // Web doStart paritesi: 1. oyuncu her zaman gerçek kişi — oturum
    // açıksa hesap sahibi (accountName), değilse misafir; diğerleri
    // "Yapay Zeka N" adıyla YZ.
    final me = widget.services.auth.accountName ?? guestPlayerName;
    controller.dispatch(StartAction(
      [
        PlayerSetup(name: me, isAI: false),
        for (var i = 1; i < _count; i++)
          PlayerSetup(name: 'Yapay Zeka ${i + 1}', isAI: true),
      ],
      // Zorluk (ROADMAP #23 Faz 4): Normal payload'a GİRMEZ — web
      // `App.startLocalGame` ile aynı sözleşme ("alan yok = Normal": eski
      // kayıtlar, golden'lar, bulut kaydı, `games.ai_level` null). `normal`
      // yazmak aynı şeyi ikinci bir biçimde söylemek olurdu. Yalnızca
      // Kolay/Zor state'e yazılır; oyun boyunca değişmez.
      aiLevel: _level == AiLevel.normal ? null : _level,
    ));
    // Anonim başlangıç sayacı (web `logGameStart` paritesi, ROADMAP #9).
    // Fire-and-forget ve AWAIT EDİLMEZ: telemetri oyunun açılmasını
    // geciktiremez, hatası da `logStart`ın içinde yutuluyor.
    unawaited(_logGameStart(_count));
    await _openGame(controller, words);
  }

  Future<void> _resumeSavedGame(SetWordSource words) async {
    final repo = _repo;
    if (repo == null) return;
    final state = await repo.loadSave();
    if (state == null) {
      // Tam bu anda süresi dolmuş/karantinaya düşmüş — görünümü tazele.
      // `_sweepLocalAbandoned()` çağrılmak ZORUNDA, çıplak
      // `drainAbandonedGames()` DEĞİL: drain `takeAll` ile olayları ATOMİK
      // olarak SİLİP döndürüyor, yani dönüşü atmak terk edilen oyunun tam
      // GameState'ini ve ondan üretilecek -2'li `games` kaydını kalıcı
      // olarak çöpe atardı (13 Ağustos 2026 denetimi, Parça 89).
      await _sweepLocalAbandoned();
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
    //
    // TEK sapma (16 Ağustos 2026): açmadan hemen önce, bu satır için aynada
    // DAHA YENİ bir state bekliyor mu diye sorulur. `_cloudSaves` bir anlık
    // görüntü; oyundan çıkışta tazelenmesi `_syncCloud`un ağ adımlarını
    // bekliyor ve uçak modunda o adımlar saniyelerce zaman aşımına oynuyor.
    // O pencerede aynı satıra tekrar dokunmak oyunu BAYAT state'le açıyor,
    // `CloudGameSession` da kurulur kurulmaz o bayat state'i aynaya geri
    // yazıp offline hamleleri KALICI olarak siliyordu (bkz.
    // `CloudSaveRepo.newerPendingState`). Liste tazeyse bu çağrı null döner
    // ve hiçbir şey değişmez.
    final user = widget.services.auth.user;
    final cloud = widget.services.cloudSaves;
    var state = save.state;
    if (user != null && cloud != null) {
      try {
        final fresher = await cloud.newerPendingState(
            save.id, user.id, save.updatedAtMs);
        if (fresher != null) state = fresher;
      } catch (e) {
        // Depo okunamadıysa elimizdekiyle devam — oyunu açmayı engelleme.
        debugPrint('[Kelimeki] taze ayna okunamadı, listedeki state ile: $e');
      }
    }
    if (!mounted) return;
    final controller = GameController(words: words);
    controller.restore(state);
    await _openGame(controller, words, resumeCloudId: save.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.services.auth;
    // Rütbe mührü için puan iste — `ensure` yalnızca EKSİK id'ler için ağa
    // gider ve `notifyListeners`ı bir sonraki microtask'a erteler, bu
    // yüzden build içinden çağrılması güvenli.
    _rankScores.ensure([auth.user?.id]);
    // k-lig kutlama banner'ı — Setup'ta bastırma YOK (girişte / geçmişe
    // dönük backfill'de bekleyen ödüller burada çıkar). Oyun ekranları bu
    // ekranın ÜZERİNE push edildiğinden ve host'lar yığının en üstekini
    // etkin saydığından, oyun sırasında buradaki host kendiliğinden susar
    // (bkz. league_rewards_host.dart'ın mimari notu).
    return LeagueRewardsHost(
      rewards: widget.services.leagueRewards,
      auth: auth,
      stats: widget.services.stats,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // Oturum/profil değişince (giriş, çıkış, profil gelmesi) tüm ekran
          // tazelenir — web'de useAuth context'inin yeniden render etmesiyle
          // aynı; auth yapılandırılmamışsa hiç notify etmez, maliyeti yok.
          child: ListenableBuilder(
            listenable: auth,
            builder: (context, _) => SingleChildScrollView(
              // YATAY dolgu BURADA DEĞİL, 460'lık kutunun İÇİNDE (aşağı bkz.).
              //
              // Dikey ASİMETRİK, çünkü web'de bu ekran İKİ ayrı kutu
              // (`App.tsx`): üstte `px-3.5 pt-3` ile GİRİŞ/avatar satırı
              // (12), altında `px-4 py-6` ile Setup içeriği (24). Portta
              // tek sütun olduğundan ÜST 12 (GİRİŞ satırının payı), ALT 24.
              // 13 Ağustos 2026: burada `vertical: 24` yazıyordu, yani GİRİŞ
              // web'dekinden 12px aşağıda duruyordu (kullanıcı yan yana
              // karşılaştırmayla bildirdi).
              padding: const EdgeInsets.only(top: 12, bottom: 24),
              child: Center(
                child: ConstrainedBox(
                  // Web: `w-full max-w-[460px] px-4 py-6` (Setup.tsx ~536) —
                  // GameHeader/Board'un 680px'iyle KARIŞTIRILMAMALI, Setup
                  // kendi (daha dar) sabitini kullanıyor.
                  //
                  // ⚠ 460 PADDING'İ İÇERİR. Tailwind'in `box-sizing:
                  // border-box`'ı altında `max-w-[460px] px-4` demek "dış kutu
                  // en fazla 460, İÇERİK 460−32 = 428" demek. Port bunu iki
                  // turda da yanlış anladı: önce sabit 480'di (Parça 29'da
                  // 460'a çekildi), ama yatay dolgu kutunun DIŞINDA kaldığı
                  // için içerik hâlâ 460'tı — yani web'den 32px (%7.5) geniş.
                  // Kullanıcı aynı şikâyeti 13 Ağustos 2026'da tekrarladı
                  // ("hala düzelmedi"); ekran görüntüsünden ölçülen oran
                  // (780/725 = 1.076) bu 32px'le birebir örtüştü.
                  //
                  // Dar ekranda davranış değişmiyor: kutu ekran kadar (≤460),
                  // dolgu içeride → içerik = min(ekran, 460) − 32; web de aynı.
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16), // px-4
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Web: Setup'ın üstünde sağa yaslı UserMenu (App.tsx,
                        // kurulum dalı) — GİRİŞ / avatar burada da sağ üstte.
                        if (auth.configured)
                          Align(
                            alignment: Alignment.centerRight,
                            child: AccountButton(
                                feedback: widget.services.feedback,
                                friends: widget.services.friends,
                                chat: widget.services.chat,
                                auth: auth,
                                stats: widget.services.stats,
                                games: widget.services.games),
                          ),
                        // GİRİŞ/avatar satırı ile logo arası: 0 (17 Ağustos 2026).
                        // Kullanıcı isteği: *"az boşluk bize alt kısımda
                        // daha fazla yer kazandırır"*. 13 Ağustos'ta 4'e
                        // çekilmişti; İKİ taraf birlikte 0'a indi — yalnız
                        // biri indirilse kodda eşit olan iki sayı gerçekten
                        // ayrışırdı. Web karşılığı: logo bloğunun `-mt-6`sı.
                        //
                        // Web'de bu sayı Setup kutusunun `py-6`sı (24) ile
                        // logo bloğunun negatif üst margin'inin farkı — o
                        // margin gözden kaçarsa hesap 24 çıkar. 13 Ağustos
                        // 2026'da margin `-mt-3` (−12, arası 12) iken
                        // `-mt-5`e (−20, arası 4) çekildi: kullanıcı portun
                        // 4'ünü tercih etti ("web'de ekstra boşluk var"),
                        // yani bu sefer WEB porta uyduruldu. İki taraf da
                        // 4; biri değişirse öteki de değişmeli.
                        //
                        // KOŞULSUZ: `auth.configured` false iken web'de de
                        // GİRİŞ satırı boş bir kutu olarak render edilir
                        // (yalnızca `pt-3`ü kalır), yani logonun üstü yine
                        // 12 + 4 = 16.
                        const Center(child: LogoMark(height: 52)),
                        // 17 Ağustos 2026 — GİRİŞLİ kullanıcıda bu blok
                        // (tanıtım paragrafı + "Nasıl oynanır? · Arkadaşınla
                        // paylaş" satırı) HİÇ gösterilmiyor: web'in aynı
                        // gün verdiği kararla birebir (kök CLAUDE.md, Setup
                        // notu — kullanıcı: "Girişli kullanıcılarda Kelimeki
                        // logosunun altındaki tanıtım yazısı ve linkler
                        // kalksın"). Bu SizedBox (ve içindeki paragraf/link
                        // satırı) yalnızca MİSAFİRDE render edilir — web'de
                        // `gap-1` (4px) + paragrafın `mt-4`ü (16px) üst üste
                        // binerek 20px veriyor (Chromium'da ölçüldü).
                        if (auth.user == null) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Kelimeler kurarak bölgeni genişlet, rakiplerini kuşat. '
                            'Ama dikkat et: Hamlen rakibinin bölgesine temas ederse, '
                            'kazandığın puanın bir kısmını onunla paylaşmak zorunda '
                            'kalırsın. Her hamle bir strateji, her kelime bir mücadele.',
                            // Web'de bu blok `text-center flex flex-col items-center`
                            // içinde — paragraf da altındaki link satırı da ORTALI.
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 12,
                              // Web `text-xs` = 12px/16px satır (1.333) — 1.5
                              // dört satırlık bu blokta 8px fazla yer kaplıyordu.
                              height: 16 / 12,
                              // Material 3'ün `bodyMedium` varsayılanı 0.25 harf
                              // aralığı taşıyor ve `letterSpacing` yazmayan HER
                              // metne miras kalıyor; web'de bu paragrafta
                              // tracking YOK (`text-xs font-mono` hiçbir
                              // letter-spacing kurmuyor, hesaplanan değer
                              // `normal`). 0.25 × ~57 karakter = ~14px, yani
                              // "Ama" alt satıra düşüp blok 4 yerine 5 satır
                              // oluyordu (ölçüldü: 80px'e karşı web'de 64px).
                              letterSpacing: 0,
                              color: _muted,
                            ),
                          ),
                          // Web: `gap-1` (4px) + link satırının `mt-3`ü (12px).
                          const SizedBox(height: 16),
                          // Web Setup'taki "Nasıl oynanır?" · <ikinci link>
                          // satırı — ikisi de font-mono/11px/kalın/accent
                          // linkler.
                          Align(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _InlineLink(
                                  'Nasıl oynanır?',
                                  onTap: () => showHelpModal(context),
                                ),
                                // Web'de ayraç `gap-2` (8+8) ile ayrılmış bir
                                // `·`; buradaki boşluklu ' · ' ölçülerek aynı
                                // yere düşüyor (19.8'e karşı web 19.67) —
                                // yeniden yapılandırmaya gerek yok.
                                const Text(' · ',
                                    style: TextStyle(
                                        fontFamily: 'SpaceMono',
                                        fontSize: 11,
                                        letterSpacing: 0,
                                        color: _muted)),
                                // 19 Ağustos 2026 (kullanıcı isteği):
                                // buradaki "Arkadaşınla paylaş" footer'a
                                // taşındı (aşağı bkz.), yerine tanıtıma
                                // dönüş linki kondu. Bu yol `seenIntro`
                                // bayrağına DOKUNMAZ — kullanıcının kendi
                                // isteğiyle açılan bir tekrar gösterim,
                                // "ilk açılış" değil (bkz. FlagsStore).
                                _InlineLink('Tanıtım', onTap: _openIntro),
                              ],
                            ),
                          ),
                        ],
                        // Girişli kullanıcıda yukarıdaki blok tamamen
                        // KALKTIĞINDAN, logo ile "OYUN TİPİ" arasında kalan
                        // TEK boşluk bu SizedBox — Chromium'da ÖLÇÜLDÜ: web'de
                        // paragraf/link satırı kalkınca logo→"OYUN TİPİ" arası
                        // TAM 20.00px (kapsayıcının kendi `gap-5`i). Buraya
                        // TELAFİ EDİCİ bir marj EKLEMEDİK — çocukları kaldırmak
                        // otomatik olarak bu değeri veriyor, elle ayarlanmadı.
                        const SizedBox(height: 20),
                        const _SectionLabel('OYUN TİPİ'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _ChoiceButton(
                                label: 'YAPAY ZEKA İLE',
                                selected: !_liveView,
                                badge: _localSaveCount,
                                onTap: () => setState(() {
                                  _liveView = false;
                                  _localSubTab = _LocalSubTab.active;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ChoiceButton(
                                label: 'ARKADAŞINLA',
                                selected: _liveView,
                                // 3 Eylül 2026: bekleyen iş (davet + sırası
                                // sende) YANINDA bitişini görmediğin oyunlar
                                // da sayılıyor — "Son Oynananlar" bir ALT
                                // sekme olduğundan, üst sekmede görünmezse
                                // kullanıcı "Yapay Zeka ile" tarafında
                                // açılıp haberi hiç görmeyebilirdi
                                // (kullanıcı kararı).
                                badge:
                                    _liveActionCount + _finishedUnseen.length,
                                onTap: () => setState(() {
                                  _liveView = true;
                                  _localSubTab = _LocalSubTab.active;
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_liveView)
                          // Dönüşte rozet tazelemesi ARTIK BURADAN GEÇMİYOR:
                          // `didPopNext` (kRouteObserver) hangi kapıdan
                          // dönülürse dönülsün yakalıyor — gerekçe
                          // `ui/route_observer.dart`.
                          LiveGamesTab(
                            services: widget.services,
                            newlyFinishedIds: _finishedUnseen,
                            onFinishesSeen: () {
                              if (mounted) {
                                setState(() => _finishedUnseen = const []);
                              }
                            },
                          )
                        else
                          FutureBuilder<SetWordSource>(
                            future: widget.services.dictionary,
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return Text('Sözlük yüklenemedi: ${snap.error}',
                                    style: const TextStyle(color: kRed));
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
                        const SizedBox(height: 20),
                        // Web Setup'ın en altındaki hukuki link satırı
                        // (`text-[10px] font-mono text-muted gap-2`). Port bunu
                        // hiç taşımamıştı — modaller vardı ama Setup'tan
                        // ulaşılamıyordu, yalnızca kayıt formundan.
                        //
                        // 17 Ağustos 2026 — üçüncü bir madde eklendi: GİRİŞLİ
                        // kullanıcı için "Paylaş" (bkz. aşağı). Web'in flex-wrap
                        // güvenlik ağının Flutter karşılığı: `Row` yerine `Wrap`
                        // kullanılıyor ki üç madde de sığmayan dar bir ekranda
                        // satır TAŞMASI (Flutter'da bu debug'da sarı/siyah
                        // çubuk, release'de kırpma demek — web'in sessizce
                        // kaydırdığı bir taşmadan çok daha görünür bir hata)
                        // yerine ikinci satıra sarsın.
                        Wrap(
                          alignment: WrapAlignment.center,
                          // Linkler artık 48px'lik dokunma hedefi
                          // (`TapTarget`); aradaki `·` `start` hizasında
                          // kalsaydı satırın ÜST kenarına yapışırdı.
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _LegalLink('Kullanım Koşulları',
                                onTap: () => showTermsModal(context,
                                    onFeedback: _openFeedback)),
                            const Text('·',
                                style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    color: _muted)),
                            _LegalLink('Gizlilik Politikası',
                                onTap: () => showPrivacyModal(context,
                                    onFeedback: _openFeedback)),
                            // 19 Ağustos 2026: "Paylaş" artık GİRİŞTEN
                            // BAĞIMSIZ — web `Setup.tsx` de onu `user &&`
                            // gibi bir koşula BAĞLAMIYOR (`handleShare`
                            // oturumdan bağımsız çalışıyor), yani misafir de
                            // girişli de aynı üç maddeli satırı görüyor.
                            // Ad BİLEREK "Arkadaşını Davet Et" DEĞİL — o,
                            // FriendsModal'daki AYRI bir özelliğin (kalıcı
                            // davet token'ı) adı; burada web'in mevcut
                            // `handleShare`'i (aynen çağrılıyor, yeni bir
                            // paylaşım fonksiyonu YAZILMADI) `?ref=arkadas`
                            // UTM'li genel bir tahta/site linki paylaşıyor —
                            // admin panelindeki "Kaynak Hunisi" bu parametreye
                            // bağlı, korunması şart. Ayraç stili yukarıdaki
                            // ilk ayraçla birebir aynı — yeni bir stil yazma.
                            const Text('·',
                                style: TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    color: _muted)),
                            // ⚠ Bu satır 24 Ağustos 2026'da bir kez ATLANDI:
                            // taramam "GestureDetector'ın DOĞRUDAN çocuğu
                            // Text mi" diye baktığından, çocuğu bir `Row`
                            // (ikon + metin) olan bu link gözden kaçtı ve
                            // kullanıcı Android'de tekrar bildirdi ("hâlâ
                            // yukarısına dokunmak gerekiyor"). Ders: hedef
                            // taraması çocuğun TÜRÜNE değil, kutuya bir
                            // ölçü veren bir şey olup olmadığına bakmalı.
                            TapTarget(
                              key: _shareLinkKey,
                              onTap: _handleShare,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.share, size: 12, color: _muted),
                                  SizedBox(width: 4),
                                  Text(
                                    'Paylaş',
                                    style: TextStyle(
                                      fontFamily: 'SpaceMono',
                                      fontSize: 10,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Web'in "Son çağrı" footer'ıyla aynı telif satırı
                        // (`font-mono text-[10px] text-muted`). Hukuki
                        // satırla arası web'de `gap-3` = 12px (ÖLÇÜLDÜ) —
                        // aşağıdaki teşhis satırı web'de hiç yok, onun
                        // boşluğu eskisi gibi 12px kalıyor.
                        const SizedBox(height: 12),
                        // `textAlign` ŞART: kapsayıcı Column
                        // `CrossAxisAlignment.stretch` olduğundan bu Text tam
                        // genişliği kaplıyor ve varsayılan hizası `start`,
                        // yani SOLA yapışıyor (19 Ağustos 2026, kullanıcı
                        // cihazda bildirdi — web'de satır ortalı). Üstündeki
                        // hukuki satır `WrapAlignment.center` ile, altındaki
                        // teşhis satırı da `TextAlign.center` ile zaten
                        // ortalıydı; atlanan tek satır buydu.
                        const Text(
                          '© Kelimeki',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 10,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Teşhis alt satırı (iskelet HomeScreen'in durum
                        // panelinden kalan tek iz — cihazda ilk açılış doğrulaması
                        // için faydalı, göze batmayan tek satır).
                        FutureBuilder<SetWordSource>(
                          future: widget.services.dictionary,
                          builder: (context, snap) => Text(
                            [
                              // Derleme kimliği SÜRÜMDEN ÖNCE geliyor:
                              // ekran görüntüsünde ilk okunan şey "hangi
                              // kod çalışıyor" olmalı (bkz. env.dart,
                              // `buildSha`'nın varlık gerekçesi).
                              'Derleme $buildLabel',
                              'Sürüm $appVersion',
                              snap.hasData
                                  ? 'Sözlük: ${snap.data!.length} kelime'
                                  : 'Sözlük: yükleniyor…',
                              widget.services.supabase != null
                                  ? 'sunucu bağlı'
                                  : 'offline mod',
                              _diagStorage,
                              // -1 = sayaç OKUNAMADI (depo erişilemedi).
                              // "bekleyen 0" ile karıştırılmamalı: ilk
                              // sürümde ikisi de 0 görünüyordu ve cihazda
                              // "ayna gerçekten boş mu?" sorusu
                              // yanıtlanamıyordu (16 Ağustos 2026).
                              if (_diagPendingMirrors < 0) 'bekleyen ?',
                              if (_diagPendingMirrors > 0)
                                'bekleyen $_diagPendingMirrors',
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
        ),
      ),
    );
  }

  /// Misafirin tekil kaydı — web'in anti-kaçış kuralı: bu görünümde yeni
  /// oyun formu HİÇ yok, kayıt bitene/silinene kadar tek yol devam etmek.
  Widget _buildSavedGameView(SetWordSource? words) {
    final state = _savedState!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('DEVAM EDEN OYUN'),
        const SizedBox(height: 8),
        _SavedGameRow(
          state: state,
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
        // Web'de bu paragrafla kutu arasında iç kapsayıcının (`gap-2`, 8px)
        // verdiği taban boşluk var, `topMargin`in eklediği `mt-2` (8px) bunun
        // ÜSTÜNE biniyor (toplam 16px) — Flutter'da bu taban boşluk hiç
        // taşınmamıştı, yalnızca `topMargin`in kendi 8px'i uygulanıyordu.
        const SizedBox(height: 8),
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

  /// "Yapay Zeka ile" sekmesinin çevrimdışı hâli — Canlı sekmesinin düz
  /// "İnternet bağlantısı yok"undan (live_games_tab) BİLİNÇLİ olarak farklı:
  /// burada gerçekten oynanabilir bir şey var, o yüzden kullanıcı bir
  /// çıkmaza değil bir seçeneğe yönlendiriliyor (14 Ağustos 2026, kullanıcı
  /// isteği). Link "+ YENİ YAPAY ZEKA OYUNU AÇ" ile AYNI şeyi yapar —
  /// ikisi de `_creatingLocal = true`; biri değişirse öteki de.
  void _onConnectivity() {
    if (mounted) setState(() {});
  }

  Widget _offlineAiNotice() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              kOfflineAiSuggestion,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 11,
                  height: 1.6,
                  color: _muted),
            ),
            const SizedBox(height: 16),
            // Metin-içi link DEĞİL gerçek buton (kullanıcı isteği,
            // 14 Ağustos 2026) — dokunma hedefi tam boy ve "+ YENİ YAPAY
            // ZEKA OYUNU AÇ" ile aynı görsel ağırlıkta/varyantta.
            NeoButton(
              label: trUpper(kOfflineAiCta),
              variant: NeoButtonVariant.orange,
              onPressed: () => setState(() => _creatingLocal = true),
            ),
          ],
        ),
      );

  /// Girişli kullanıcının varsayılan görünümü — web Setup'ın `user &&
  /// !creatingLocal` dalı: üstte turuncu "+ Yeni Yapay Zeka Oyunu Aç",
  /// altında "Devam Edenler / Son Oynananlar" sekmeleri — `LiveGamesTab`
  /// (Arkadaşınla) ile BİREBİR AYNI çözüm (bkz. Setup.tsx, `_subTabBtn`
  /// deseni). 9 Ağustos 2026'da kullanıcı cihaz testinde eski (sekmesiz,
  /// listenin altına eklenmiş) sürümü bildirdi — Parça 28.
  Widget _buildCloudListView(SetWordSource? words) {
    // Silinmeye en yakın kayıt ÜSTTE (3 Eylül 2026, kullanıcı isteği).
    // Yerel kaydın 7 günü `updated_at`ten işliyor, yani EN ESKİ güncellenen
    // en yakın olandır — depo sorgusu `updated_at desc` döndüğü için burada
    // TERS çevriliyor. Kural web/port ortak: `util/game_list_order.dart`.
    final saves = _cloudSaves == null
        ? null
        : orderByExpiry(_cloudSaves!, (s) => s.updatedAtMs);
    final auth = widget.services.auth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Web: `text-sm` (14) + `py-2.5` (10) + satır 20 → kutu tam 40
        // (port 44'lük bir SizedBox'a sarıyordu); aradaki boşluklar
        // kapsayıcının `gap-5`inden (20), sekmelerin kendi arası `gap-2`
        // (8). `LiveGamesTab`'daki ikiziyle BİREBİR aynı (Parça 80).
        NeoButton(
          label: '+ YENİ YAPAY ZEKA OYUNU AÇ',
          variant: NeoButtonVariant.orange,
          fontSize: 14,
          lineHeight: 20 / 14,
          letterSpacing: 1.5,
          padding: const EdgeInsets.symmetric(vertical: 10),
          onPressed: () => setState(() => _creatingLocal = true),
        ),
        const SizedBox(height: 20),
        Row(children: [
          _localSubTabBtn(_LocalSubTab.active, 'Devam Edenler',
              badge: saves?.length ?? 0),
          const SizedBox(width: 8),
          _localSubTabBtn(_LocalSubTab.recent, 'Son Oynananlar'),
        ]),
        const SizedBox(height: 20),
        switch (_localSubTab) {
          // Çevrimdışıyken GÖSTERİLECEK KAYIT VARSA liste aynen çizilir —
          // devam eden YZ oyunları çevrimdışı da oynanabiliyor (cloud save
          // aynası), o listeyi uyarıyla değiştirmek gerçek bir yeteneği
          // gizlerdi. Mesaj yalnızca elde bir şey yokken.
          // `saves == null` BİLEREK dışarıda: liste henüz bilinmiyorken
          // "hiç oyunun yok, yeni aç" demek erken bir yargı — çevrimdışıyken
          // ağ denemesi bitip AYNADAN gerçek liste geliyor ve kullanıcı önce
          // öneriyi, sonra listeyi görüyordu (14 Ağustos 2026, cihaz testi).
          _LocalSubTab.active
              when (_cloudSavesFailed ||
                      !widget.services.onlineStatus.online) &&
                  saves != null &&
                  saves.isEmpty =>
            _offlineAiNotice(),
          _LocalSubTab.active => saves == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Yükleniyor…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          color: _muted)),
                )
              : saves.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Devam eden bir Yapay Zeka oyunun yok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 11,
                              color: _muted)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionLabel('DEVAM EDEN OYUNLAR'),
                        const SizedBox(height: 8),
                        for (final save in saves) ...[
                          _SavedGameRow(
                            state: save.state,
                            savedAtMs: save.updatedAtMs,
                            // Web: girişli kullanıcıda gerçekten başlamış
                            // oyun için süre dolunca -2'li teslim gerçek/
                            // anında sonuç → "teslim sayılacak".
                            willSurrender: save.state.turnCount >= 2,
                            accountAvatarUrl: auth.profile?.avatarUrl,
                            onTap: words == null
                                ? null
                                : () => _resumeCloudSave(save, words),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
          _LocalSubTab.recent => _games != null && auth.user != null
              ? RecentGamesSection(
                  games: _games!,
                  userId: auth.user!.id,
                  onlineOnly: false,
                  currentName: auth.accountName,
                  stats: widget.services.stats,
                  emptyMessage: 'Henüz bitmiş bir Yapay Zeka oyunun yok.',
                  // Yerel oyunda tek insan koltuk HER ZAMAN hesap sahibi —
                  // ada bakmadan kendi avatarı verilebiliyor (bkz.
                  // `util/recent_game_avatars.dart`).
                  ownAvatarUrl: auth.profile?.avatarUrl,
                  offlineNode: _offlineAiNotice(),
                  isOffline: !widget.services.onlineStatus.online,
                )
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Yükleniyor…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          color: _muted)),
                ),
        },
      ],
    );
  }

  /// `LiveGamesTab._subTabBtn` ile BİREBİR AYNI görsel — iki bağımsız
  /// kod tekrarı çifti (bkz. dosya başındaki "Etki Analizi" tablosu), biri
  /// değişirse öteki de güncellenmeli.
  Widget _localSubTabBtn(_LocalSubTab t, String label, {int badge = 0}) {
    final active = _localSubTab == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _localSubTab = t),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: ShapeDecorationWithCssShadows(
                color: active ? _accent : _panel,
                borderColor: active ? _accent : _border,
                radius: 6,
                // Web: seçili `btn-raised`, seçili değil `btn-raised-neutral`.
                shadows: active ? kRaisedAccentShadows : kRaisedShadows,
              ),
              alignment: Alignment.center,
              child: Text(
                trUpper(label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Web `text-[11px] ... tracking-[0.5px] py-2.5` — ölçüldü:
                  // 11px punto, 16.5px satır (gövdeden miras 1.5), 38.5px
                  // kutu (bkz. Parça 37). `LiveGamesTab`'daki ikizi de aynı.
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: active ? Colors.white : _text,
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

  /// Zorluk seçici butonu — `_localSubTabBtn` ile AYNI kutu/punto/gölge
  /// (rozetsiz); iki yer birlikte değişir. Web ikizi `Setup.tsx` ZORLUK
  /// radyogrubu (`LiveGamesTab` alt-sekme sınıfı).
  Widget _zorlukBtn(AiLevel lv) {
    final active = _level == lv;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _level = lv),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: ShapeDecorationWithCssShadows(
            color: active ? _accent : _panel,
            borderColor: active ? _accent : _border,
            radius: 6,
            shadows: active ? kRaisedAccentShadows : kRaisedShadows,
          ),
          alignment: Alignment.center,
          child: Text(
            // Web `uppercase` — buton etiketi büyük, rozet küçük harf.
            trUpper(aiLevelLabel[lv]!),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: active ? Colors.white : _text,
            ),
          ),
        ),
      ),
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
        // ZORLUK (ROADMAP #23 Faz 4, web Faz 3'ün ikizi) — `OYUNCU SAYISI`
        // bloğunun altında, aynı sıra. Buton stili büyük `_ChoiceButton`
        // DEĞİL, Arkadaşınla sekmesinin alt-sekme pilleri (`_localSubTabBtn`
        // / `LiveGamesTab._subTabBtn`: 11px, dikey 10 dolgu) — kullanıcı
        // kararı (6 Eylül 2026 gece), web `Setup.tsx` aynı sınıf dizesine
        // geçti. Terminoloji TEK: "Zorluk: Kolay · Normal · Zor" (23.4).
        // Zor Faz 5'e kadar gösterilmez — her buton `Expanded`, üçüncüsü
        // gelince yerleşim kendiliğinden üçe bölünür (web `flex-1`).
        const _SectionLabel('ZORLUK'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final lv in selectableAiLevels) ...[
              if (lv != selectableAiLevels.first) const SizedBox(width: 8),
              _zorlukBtn(lv),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Her seviyenin altında kullanıcıya hitap eden açıklama + o seviyenin
        // k-lig puanı (4 kişilikte ikincilik de). Metin `aiLevelDescription`
        // (core `leaguePoints`ten türetilir), web ikizi aynı şablon. Stil:
        // web `text-[11px] text-muted font-mono leading-relaxed` — misafir
        // formundaki "7 gün saklanır" paragrafıyla aynı.
        Text(
          aiLevelDescription(_level, _count),
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 11,
            height: 1.5,
            color: _muted,
          ),
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
            accountRankTier:
                _rankScores.tierOf(widget.services.auth.user?.id),
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
                  onPressed: words == null ? null : () => _handleStart(words),
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
        // Web'de bu kutu ile üstündeki buton satırı arasında dıştaki flex
        // kapsayıcının (`gap-5`, 20px) verdiği boşluk var — Flutter'da diğer
        // TÜM bölüm geçişlerinde bu 20px elle SizedBox'la taşınmıştı, yalnızca
        // bu son geçiş unutulmuştu (kutu butona "yapışık" duruyordu, kullanıcı
        // web derlemesinde bizzat bulup bildirdi).
        const SizedBox(height: 20),
        // Web: `!user && <MembershipPerksBox .../>` — bu fonksiyon hem
        // misafirin boş formunda (showCancel:false) hem girişli kullanıcının
        // "+ Yeni" formunda (showCancel:true) çağrıldığından gate widget'ın
        // kendi içinde (`auth.user == null`); girişli çağrıda sessizce
        // gizli kalır.
        MembershipPerksBox(
            auth: widget.services.auth, feedback: widget.services.feedback),
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
      // Web `text-sm font-bold tracking-[1px] py-3` — Chromium'da derlenmiş
      // CSS ile ÖLÇÜLDÜ: 14px punto, 20px satır, 46px kutu (bkz. Parça 37).
      // Önceki 13px + doğal satır yüksekliği kutuyu ~41px'e düşürüyordu.
      fontSize: 14,
      lineHeight: 20 / 14,
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
/// linkleri — "Nasıl oynanır?" / "Tanıtım" satırında paylaşılıyor.
/// Setup'ın en altındaki hukuki linkler — web `text-[10px] font-mono
/// text-muted` (accent DEĞİL, `_InlineLink`'ten bu yüzden ayrı).
class _LegalLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _LegalLink(this.text, {required this.onTap});

  @override
  Widget build(BuildContext context) => TapTarget(
        onTap: onTap,
        child: Text(text,
            style: const TextStyle(
                fontFamily: 'SpaceMono', fontSize: 10, color: _muted)),
      );
}

class _InlineLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _InlineLink(this.text, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          // Web'de bu linklerde de tracking yok — bkz. paragrafın notu (M3
          // `bodyMedium` varsayılanı 0.25'i sessizce miras bırakıyor).
          letterSpacing: 0,
          color: kAccent,
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

  /// Hesap sahibinin rütbesi — puan henüz bilinmiyorsa null (mühür
  /// çizilmez). "0 puan" ile "henüz yüklenmedi" AYRI şeyler.
  final RankTier? accountRankTier;

  const _PlayerRow({
    required this.index,
    this.accountName,
    this.accountAvatarUrl,
    this.accountPending = false,
    this.accountRankTier,
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
      decoration: ShapeDecorationWithCssShadows(
        color: col.tint, borderColor: col.base, radius: 6,
        shadows: kRaisedShadows, // web shadow-raised
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
            child: Row(
              children: [
                Flexible(
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
                if (isAccount && accountRankTier != null) ...[
                  const SizedBox(width: 4),
                  RankSeal(tier: accountRankTier!, size: 18),
                ],
              ],
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

/// Web SavedGameRow portu: solda katılımcı avatarları (misafir "?" + robot),
/// sağda yeşil "SIRA SENDE", altta kalan süre.
///
/// **"Sıra: X" alt satırı KALDIRILDI (2 Eylül 2026, kullanıcı isteği):**
/// yanındaki `SIRA SENDE` ile aynı şeyi söylüyordu. ⚠ Canlı oyun kartının
/// aynı yerdeki "X açtı" satırı buna BENZEMEZ ve kalır — o kimin açtığını
/// söylüyor, sıra bilgisi değil.
class _SavedGameRow extends StatelessWidget {
  final GameState state;
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
    // ⚠ Fiil (`verb`) YALNIZCA süre dolduğunda görünüyor — 30 Ağustos 2026,
    // kullanıcı isteği; gerekçe web ikizinde (Setup.tsx `remainingTime`).
    if (ms <= 0) return (text: 'Bugün $verb', urgent: true);
    final totalMinutes = (ms / (60 * 1000)).ceil();
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;
    final hours = totalHours % 24;
    final minutes = totalMinutes % 60;
    // ⚠ İki dal AYRI: `willSurrender` false iken -2 diye bir ceza YOK,
    // o kayıt yalnızca siliniyor (gerekçe web ikizinde).
    final sonuc = willSurrender ? 'teslim (-2 puan)' : 'silinecek';
    final text = days > 0
        ? '$days gün $hours saat sonra $sonuc'
        : '$hours saat $minutes dk sonra $sonuc';
    return (text: text, urgent: days < 1);
  }

  /// Sol sütun: avatar şeridi + hemen sağında zorluk rozeti (ROADMAP #23
  /// Faz 4 — web `SavedGameRow`ın `flex items-center gap-1.5` bloğu; 6 Eylül
  /// gece: alt satırdaydı, kullanıcı "avatarların yanına" dedi), altında
  /// koltuk sırasıyla PUAN SATIRI (6 Eylül 2026, kullanıcı isteği; stil
  /// kalan-süre satırıyla aynı — `util/score_line.dart`). Yerel kayıt
  /// her zaman YZ oyunu → rozet her seviyede (Normal turuncu da çizilir).
  /// ⚠ Aynı gövdeyi paylaşan Canlı oyun kartı (`live_games_tab.dart`)
  /// rozetten ETKİLENMEZ (orada seviye yok) ama puan satırını O DA çizer.
  Widget _solBlok() {
    final avatarlar = PlayerAvatarRow(players: [
      for (final p in state.players)
        AvatarRowPlayer(
          name: p.name,
          isAi: p.isAI,
          // Yerel oyunda insan koltuk HER ZAMAN bu cihazdaki kişi;
          // misafirse profil/ad yok → "?" yedeği.
          isGuest: !p.isAI && isGuest,
          avatarUrl: p.isAI ? null : accountAvatarUrl,
        ),
    ]);
    final ustSatir = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatarlar,
        const SizedBox(width: 6), // web gap-1.5
        // SINIF 3 (sarma/taşma) koruması: sol sütun dar ekranda + yazı
        // ölçeği tavanında 92 px'e iniyor (setup_screen_test "isim alanı
        // sıkışmaz"); rozet sığmazsa `FittedBox` küçültür, satır kırmaz,
        // taşmaz — `mobile/CLAUDE.md` "Sistem Yazı Boyutu" kuralı.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AiLevelBadge(
                level: aiLevelForBadge(state.aiLevel, isAiGame: true)),
          ),
        ),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ustSatir,
        const SizedBox(height: 2), // web gap-0.5
        Text(scoreLine([for (final p in state.players) p.score]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: devamEdenSureStil(_muted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const ShapeDecorationWithCssShadows(
          color: _panel, borderColor: _border, radius: 6,
          shadows: kRaisedShadows, // web shadow-raised
        ),
        // Düzenin GEREKÇESİ ve ölçümleri ortak gövdenin kendisinde
        // (`devam_eden_govde.dart`) — Canlı oyun kartı da aynı dosyadan
        // besleniyor, açıklamanın tek kopyası orada.
        child: DevamEdenGovde(
          sol: _solBlok(),
          // Koşul YOK: yerel kayıt her zaman hesap sahibinin sırasında
          // duruyor (Canlı kartının aksine, orası "SIRA RAKİPTE" de olabilir).
          durum: Text.rich(
            TextSpan(
                text: 'SIRA SENDE', children: [turnTriangleSpan(kGreen)]),
            style: devamEdenDurumStil(kGreen),
          ),
          sure: Text(
            // trUpper ŞART — native toUpperCase 'dakika'yı noktasız I ile
            // 'DAKIKA' yapar (test yakaladı; web'de CSS uppercase tr locale
            // ile doğruydu). Süre dolunca metne geri gelen 'silinecek' de
            // aynı tuzağı taşıyor.
            trUpper(remaining.text),
            textAlign: TextAlign.right,
            style: devamEdenSureStil(remaining.urgent ? kRed : _muted),
          ),
        ),
      ),
    );
  }
}

/// Misafir giriş uyarısının üç sonucu — ikisi de oyunu başlatmıyor, bu
/// yüzden `bool` yetmiyor (bkz. `_showGuestWarning`).
enum _GuestChoice { login, proceed, dismiss }
