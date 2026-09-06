// "Son Oynadıklarım" — web `RecentGamesSection.tsx` portu.
//
// Sekmenin türüne uygun (yerel/Canlı) son 5 BİTEN oyunu kompakt satırlar
// hâlinde gösterir. Bir satıra dokunmak Tüm Oyunlarım'ı (`GameHistoryModal`)
// doğrudan o oyunun tahtası açık hâlde açar — ayrı bir mini tahta/paylaşım
// gösterimi yazmak yerine mevcut modalın tüm davranışını (beğen/paylaş/
// sohbet arşivi) olduğu gibi devralır.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../util/recent_game_avatars.dart';
import '../game/player_avatar_row.dart';
import '../ai_level_badge.dart';
import '../../util/ai_level.dart';
import '../../util/score_line.dart';
import '../devam_eden_govde.dart' show devamEdenSureStil;
import '../text_scale.dart';
import '../score/game_history_modal.dart';
import '../tap_target.dart';
import '../tokens.dart';
import '../game/neo_box.dart';

const _panel = kPanel;
const _border = kBorder;
const _muted = kMuted;
const _text = kText;
const _accent = kAccent;
const _green = kGreen;
const _red = kRed;

/// `userId:onlineOnly` → son çekilen liste. Bileşen sekme değişiminde
/// unmount/mount olduğundan (web'de de öyle) her dönüşte "Yükleniyor…"
/// göstermemek için modül seviyesinde tutuluyor; effect yine de her
/// mount'ta taze veriyi arka planda çekip hem state'i hem bunu günceller.
final _recentCache = <String, List<GameHistoryEntry>>{};

@visibleForTesting
void clearRecentGamesCache() => _recentCache.clear();

/// Web `rankFor`: rank hiç yazılmamış eski kayıtlarda puan karşılaştırması.
int _rankFor(GameHistoryEntry e) =>
    e.rank ?? (e.playerScore >= e.aiScore ? 1 : 2);

/// Web `titleFor` — yalnızca snapshot'ı OLMAYAN eski kayıtlar için yedek
/// başlık (snapshot varsa avatar şeridi geçer).
String _titleFor(GameHistoryEntry e) {
  if (e.players.length < 2) return '${e.playerCount} Kişilik Oyun';
  final meIdx = _rankFor(e) - 1;
  final others = [
    for (var i = 0; i < e.players.length; i++)
      if (i != meIdx) e.players[i]
  ];
  if (e.playerCount == 2 && others.length == 1) {
    return others.first.isAi ? 'Yapay Zeka' : others.first.name;
  }
  if (e.onlineGameId != null && others.isNotEmpty) {
    return [for (final p in others) p.isAi ? 'Yapay Zeka' : p.name].join(', ');
  }
  return '${e.playerCount} Kişilik Oyun';
}

String _formatDate(String iso) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

class RecentGamesSection extends StatefulWidget {
  final GamesRepo games;
  final String userId;

  /// Görüntüleyenin güncel adı — açılan geçmiş modalında kendi satırında
  /// dondurulmuş ad yerine bu gösterilir.
  final String? currentName;

  /// true: yalnızca Canlı, false: yalnızca Yapay Zeka oyunları.
  final bool onlineOnly;

  /// "Beğenenler" zincirini açabilmek için geçilir (null ise isimler
  /// tıklanmaz).
  final StatsRepo? stats;

  /// Web `emptyMessage` (RecentGamesSection.tsx) — verilirse yükleme
  /// sırasında "Yükleniyor…", liste boşken bu metin gösterilir; null ise
  /// (varsayılan davranış DEĞİŞMEDİ) ikisinde de bölüm SESSİZCE gizlenir.
  /// Kendi başına bir sekmenin İÇERİĞİ olarak kullanıldığında (Setup'ın
  /// "Son Oynananlar"ı, LiveGamesTab'ın "Son Oynananlar"ı — Parça 28)
  /// verilmesi ZORUNLU, aksi halde boş bir sekme hiçbir geri bildirim
  /// vermeden tamamen boş kalır; başka bir listenin ALTINA sessizce
  /// eklenen eski kullanım biçiminde (artık yok) hâlâ null bırakılabilir.
  final String? emptyMessage;

  /// Son yükleme sunucuya ULAŞAMADIĞINDA ve gösterilecek oyun YOKKEN
  /// [emptyMessage]/hata metni yerine render edilir (web `offlineNode`,
  /// 14 Ağustos 2026). Düğüm olarak alınıyor çünkü kullanım yerine göre
  /// farklı konuşuluyor: Canlı sekmesi düz "İnternet bağlantısı yok" derken
  /// Yapay Zeka sekmesi tıklanabilir bir "Hemen oyun aç." önerisi sunuyor.
  /// Önbellekten gelen bir liste VARSA o gösterilmeye devam eder.
  final Widget? offlineNode;

  /// Çağıran "şu an çevrimdışıyız" diyor mu (web `useOnlineStatus`)? Bu
  /// sinyal HIZLI; `_loadFailed` YAVAŞ ama kesin — ikisinden biri yeterli.
  final bool isOffline;

  /// Çevrimiçi oyunların CANLI koltukları — avatar çözümü için (2 Eylül
  /// 2026). `LiveGamesTab` bu listeyi zaten `list_my_online_games` ile
  /// çekiyor ve o RPC durum filtresi TAŞIMIYOR (bitmiş oyunlar da içinde),
  /// yani ikinci bir istek yok. Yerel (YZ) kullanımında boş geçilir —
  /// orada tek insan koltuk hesabın kendisidir ve [ownAvatarUrl] yeter.
  final List<({String id, List<AvatarSlot> slots})> onlineGames;

  /// Hesap sahibinin avatarı — yerel oyunlarda tek insan koltuk odur.
  final String? ownAvatarUrl;

  /// Bitişini kullanıcının GÖRMEDİĞİ oyunların `games.id`'leri — o
  /// satırlarda etiketin YANINA kırmızı "YENİ" düşer (3 Eylül 2026).
  ///
  /// ⚠ Yalnızca Canlı tarafta dolu geçilir: YZ oyunlarında bitişi zaten
  /// görüyorsun (oyun senin cihazında bitiyor), orada "yeni" diye bir kavram
  /// yok — kullanıcı kapsamı bilerek Canlı ile sınırladı.
  ///
  /// ⚠ Sekme AÇIKKEN sabit kalmalı: sunucudaki işaret sekmeye girer girmez
  /// temizleniyor (sayı sıfırlansın diye), ama satır rozetleri ziyaret
  /// boyunca DURMALI — yoksa kullanıcı tam bakarken gözünün önünde kaybolur.
  /// Bu yüzden çağıran anlık listeyi değil bir ENSTANTANEyi geçiyor.
  final Set<String> newlyFinishedIds;

  const RecentGamesSection({
    super.key,
    required this.games,
    required this.userId,
    required this.onlineOnly,
    this.currentName,
    this.stats,
    this.emptyMessage,
    this.offlineNode,
    this.isOffline = false,
    this.onlineGames = const [],
    this.ownAvatarUrl,
    this.newlyFinishedIds = const {},
  });

  @override
  State<RecentGamesSection> createState() => _RecentGamesSectionState();
}

class _RecentGamesSectionState extends State<RecentGamesSection> {
  static const _limit = 5;

  late final String _cacheKey = '${widget.userId}:${widget.onlineOnly}';

  /// `online_game_id → (isim → avatar)`. Sözlük BİR KEZ kuruluyor: satır
  /// eşlemesinin içinde kurmak her oyuncu için yeniden inşa ederdi.
  late Map<String, Map<String, String>> _avatarIndex =
      buildOnlineAvatarIndex(widget.onlineGames);
  late List<GameHistoryEntry>? _games = _recentCache[_cacheKey];

  /// Ağ hatası mı, yoksa gerçekten hiç oyun mu yok? İkisi de boş liste
  /// üretiyor ama kullanıcıya söylenecek şey farklı — "oyunun yok" demek
  /// çevrimdışı bir kullanıcıya YANLIŞ bilgi.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecentGamesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Canlı liste tazelendiğinde (yeni avatar, yeni oyun) sözlük de tazelensin.
    if (!identical(oldWidget.onlineGames, widget.onlineGames)) {
      _avatarIndex = buildOnlineAvatarIndex(widget.onlineGames);
    }
  }

  Future<void> _load() async {
    final res = await widget.games.history(
      userId: widget.userId,
      playerCount: null,
      offset: 0,
      limit: _limit,
      onlineOnly: widget.onlineOnly,
    );
    if (!mounted) return;
    // Başarısız çekim önbelleği EZMEMELİ — bir önceki mount'un listesi
    // (varsa) çevrimdışıyken göstermeye devam edilebilir.
    if (!res.failed) _recentCache[_cacheKey] = res.games;
    setState(() {
      _loadFailed = res.failed;
      if (!res.failed || _games == null) _games = res.games;
    });
  }

  Future<void> _openHistory({String? focusId}) => showGameHistory(
        context,
        games: widget.games,
        userId: widget.userId,
        playerCount: null,
        currentName: widget.currentName,
        stats: widget.stats,
        initialExpandedId: focusId,
      );

  Widget _emptyOrHidden(String text) {
    final msg = widget.emptyMessage;
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    // Web: `emptyMessage` verilmemişse (başka bir listenin altına sessizce
    // eklenen eski kullanım biçimi) bölüm SESSİZCE gizlenir; verilmişse
    // (kendi başına bir sekme içeriği — Parça 28) "Yükleniyor…"/mesaj
    // gösterilir.
    // Çevrimdışıyken "yüklenemedi" teknik olarak doğru ama ne yapılacağını
    // söylemiyor — çağıran bir düğüm verdiyse o konuşur.
    final offline = widget.offlineNode;
    if (offline != null &&
        (_loadFailed || widget.isOffline) &&
        (games == null || games.isEmpty)) {
      return offline;
    }
    if (games == null) {
      return _emptyOrHidden(_loadFailed
          ? 'Oyun geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.'
          : 'Yükleniyor…');
    }
    if (games.isEmpty) {
      return _emptyOrHidden(_loadFailed
          ? 'Oyun geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.'
          : (widget.emptyMessage ?? ''));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('SON OYNADIKLARIM',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: _muted)),
            ),
            TapTarget(
              onTap: () => _openHistory(),
              child: const Text('TÜM OYUNLARIM',
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: _accent)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final g in games)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentRow(
              entry: g,
              onTap: () => _openHistory(focusId: g.id),
              avatarIndex: _avatarIndex,
              ownAvatarUrl: widget.ownAvatarUrl,
              yeni: widget.newlyFinishedIds.contains(g.id),
              onlineOnly: widget.onlineOnly,
            ),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final GameHistoryEntry entry;
  final VoidCallback onTap;

  /// Avatar çözümü için — kural `util/recent_game_avatars.dart`'ta.
  ///
  /// ⚠ İkisi de PARAMETRE, çünkü bu satır ayrı bir `StatelessWidget`:
  /// `_RecentGamesSectionState`in alanlarına (`widget`, `_avatarIndex`)
  /// buradan ERİŞİLEMEZ. İlk yazımda doğrudan onlara başvurdum ve
  /// `dart analyze` iki hatayla düşürdü — web ikizinde satır inline
  /// olduğundan orada aynı hata doğmuyor.
  final Map<String, Map<String, String>> avatarIndex;
  final String? ownAvatarUrl;

  /// Bitişini kullanıcı GÖRMEDİ → "OYUN BİTTİ"nin altına kırmızı "YENİ"
  /// (3 Eylül 2026). Aynı sebeple parametre: bu satır ayrı bir widget.
  final bool yeni;

  /// "OYUN BİTTİ" etiketi YALNIZCA Canlı tarafta çizilir — YZ oyunları senin
  /// cihazında bittiği için orada bilgi taşımaz. Aynı sebeple parametre.
  final bool onlineOnly;

  const _RecentRow({
    required this.entry,
    required this.onTap,
    required this.avatarIndex,
    required this.ownAvatarUrl,
    required this.yeni,
    required this.onlineOnly,
  });

  @override
  Widget build(BuildContext context) {
    final points = leaguePoints(_rankFor(entry), entry.playerCount,
        surrendered: entry.surrendered, aiLevel: entry.aiLevel);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const ShapeDecorationWithCssShadows(
          color: _panel, borderColor: _border, radius: 6,
          shadows: kRaisedShadows, // web shadow-raised
        ),
        child: Row(
          children: [
            // ⚠ HER İKİ DURUMDA `Expanded` — `Flexible` DEĞİL, ve bu bir
            // GERİLEME DÜZELTMESİ (3 Eylül 2026, kullanıcı cihazda
            // bildirdi: "puan ve k-lig bozulmuş, sağda hizalı olmaları
            // lazım").
            //
            // Önce Canlı'da `Flexible` (loose fit) kullanılmıştı ki ortadaki
            // etiket boşluğu alsın. Bedeli ölçülünce çıktı: loose fit sol
            // sütunu İÇERİĞİNE küçültüyor, avatar sayısı satırdan satıra
            // değişiyor (2 kişilik 46 px, 4 kişilik 86 px) ve artan boşluk
            // `MainAxisAlignment.start` gereği EN SAĞDA kalıyor — yani skor
            // bloğu her satırda başka bir yerde bitiyor. ÖLÇÜLDÜ (412 px):
            // 4 kişilik satır ötekilerden **30,9 px** sağdaydı.
            //
            // İki `Expanded` (flex 1) genişliği İÇERİKTEN BAĞIMSIZ kılıyor,
            // yani sağdaki sütunlar her satırda AYNI x'te. Ortadaki etiket
            // yine boşluğun yarısını alıyor — 360 px'te 135 px, "TESLİM
            // OLDUN + YENİ" için gereken ~124 px'ten fazla, yani rozet
            // yanda kalmaya devam ediyor (test bunu kilitliyor).
            //
            // ⚠ FLEX 2:3, 1:1 DEĞİL. Eşit bölüşüm ölçüldü ve ortadaki
            // etiketi 320 px / ölçek 1,3'te 0,4 px KIRPIYORDU (111,0
            // isteniyor, 110,6 veriliyordu) — `Flexible`den `Expanded`e
            // geçmek sol sütuna içeriğinden fazlasını verdiği için. 2:3'te
            // 320 px'te sol 92 px (4 avatar 86 px sığıyor), orta 138 px
            // (etiket 111 px sığıyor). İki test birden kilitliyor: hiza VE
            // kırpılmama.
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 6 Eylül 2026 — TARİH (+ zorluk rozeti) AVATARLARIN
                  // ÜSTÜNE çıktı, altına PUAN SATIRI girdi (kullanıcı: *"Son
                  // oynananlarda da aynı şekilde bitiş puanlarını koy.
                  // Oradaki tarihi avatarların üstüne koy. (Kutu biraz
                  // büyüyebilir, sorun değil)"*). Devam eden kartlarla aynı
                  // düzen; web ikizi `RecentGamesSection.tsx`.
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_formatDate(entry.createdAt),
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 9,
                            color: _muted)),
                    // Zorluk rozeti (ROADMAP #23 Faz 4): tarihin yanında, YZ
                    // oyununda her seviyede (Normal turuncu); Canlı kartlarda
                    // hiç çıkmaz.
                    if (entry.onlineGameId == null) ...[
                      const SizedBox(width: 6), // web gap-1.5
                      AiLevelBadge(
                          level: aiLevelForBadge(entry.aiLevel,
                              isAiGame: true)),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  if (entry.players.isNotEmpty)
                    PlayerAvatarRow(players: [
                      for (final p in entry.players)
                        AvatarRowPlayer(
                          name: p.name,
                          isAi: p.isAi,
                          // Misafirken oynanıp bitirilen, sonra üye olunca
                          // hesaba taşınan yerel oyunlarda snapshot'taki ad
                          // kalıcı olarak "Misafir" kalıyor → baş harf "MI"
                          // çıkıp misafiri gerçek bir üye gibi gösterirdi.
                          // `onlineGameId` kontrolü yanlış pozitifi
                          // daraltıyor: Canlı'da misafir koltuk YOK.
                          isGuest: !p.isAi &&
                              entry.onlineGameId == null &&
                              p.name == guestPlayerName,
                          // 2 Eylül 2026: bu liste avatarları HİÇ
                          // göstermiyordu. Kural ve gerekçesi
                          // `util/recent_game_avatars.dart`'ta — snapshot'a
                          // da migration'a da dokunulmadı.
                          avatarUrl: avatarForRecentPlayer(
                            isAi: p.isAi,
                            isGuest: !p.isAi &&
                                entry.onlineGameId == null &&
                                p.name == guestPlayerName,
                            name: p.name,
                            onlineGameId: entry.onlineGameId,
                            onlineIndex: avatarIndex,
                            ownAvatarUrl: ownAvatarUrl,
                          ),
                        ),
                    ])
                  else
                    Text(_titleFor(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _text)),
                  // Bitiş puanları — snapshot sırası avatar sırasıyla AYNI
                  // dizi (`entry.players`), yani N'inci sayı N'inci yüzün
                  // altında; stil devam-eden kartların kalan-süre satırıyla
                  // aynı. Snapshot'sız eski kayıtta satır çizilmez.
                  if (entry.players.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(scoreLine([for (final p in entry.players) p.score]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: devamEdenSureStil(_muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // "Oyun Bitti" — 3 Eylül 2026, kullanıcı isteği.
            // ⚠ YALNIZCA Canlı tarafta. YZ oyunları senin cihazında bitiyor,
            // yani bitişi zaten gözünle görüyorsun; orada bu etiket bilgi
            // taşımaz, yalnızca gürültü olurdu (kullanıcı aynı gün ikinci
            // turda bunu istedi). Canlı'da ise tam tersi: hamleni yapıp
            // gittiğinde oyun SEN YOKKEN bitiyor ve bugün bunu hiçbir yer
            // söylemiyor. Web ikizi `RecentGamesSection.tsx` ile aynı koşul.
            if (onlineOnly) ...[
              Expanded(
                flex: 3,
                // ⚠ `Row` DEĞİL `Wrap` — ve bu bir GERİLEME DÜZELTMESİ:
                // ölçek 1,3'te (kMaxTextScale) 320 px'lik bir ekranda etiket
                // 111 px istiyor, `Row`da yalnızca 74,9 px alıyordu ve
                // `TESLİ…` diye KIRPILIYORDU (kullanıcı sordu: "ekran
                // büyütenler için en büyük font nasıl davranıyor?" — ölçüldü,
                // kırpılıyordu). `Wrap` sığdığı sürece rozeti YANDA tutuyor
                // (normal durum), sığmadığında ALTA indiriyor: satır bir
                // miktar uzuyor ama hiçbir harf kaybolmuyor. Kök CLAUDE.md
                // "Sistem Yazı Boyutu" bölümünün önerdiği çare de bu
                // (sıkışan satırı BÖLMEK).
                //
                // `Expanded` genişliği TIGHT verdiğinden `alignment: center`
                // gerçekten ortalıyor — gevşek kısıtta `Wrap` içeriğine
                // küçülür ve hizalama sessizce no-op olurdu (repo dersi).
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    // Teslimle biten oyunda metin "TESLİM OLDUN" (3 Eylül
                    // 2026, kullanıcı isteği). AYRI bir sütun EKLENMEDİ:
                    // satır zaten avatar+tarih | etiket | skor | k-lig,
                    // dördüncü bir metin sütunu küçük ekranda sıkışırdı.
                    // ⚠ Bayrak SATIR SAHİBİNE ait: `games.surrendered` kişi
                    // başına, yani rakibin süresi dolduysa BENİM satırım
                    // "OYUN BİTTİ" kalır (ben kazandım). `GameHistoryModal`
                    // da "Teslim Oldu"yu yalnızca teslim olanın kendi
                    // satırında gösteriyor — aynı kural.
                    // Renk BİLEREK nötr: teslimin kırmızısı zaten sağdaki
                    // -2 k-lig puanında; ikinci bir kırmızı yanındaki
                    // "YENİ" rozetiyle yarışırdı.
                    //
                    // ⚠ Metin KAYNAKTA büyük harf. Native
                    // `toUpperCase()`/`text-transform` Türkçe'de "Bitti"nin
                    // i'sini noktasız I'ya çevirebiliyor; bu repo native
                    // dönüşümü zaten yasaklıyor (`trUpper`) — burada
                    // dönüşüme hiç gerek yok.
                    //
                    // ⚠ PUNTO 11 px, ve bu bir OKUNABİLİRLİK ZORUNLULUĞU,
                    // tercih değil: `İ`nin noktası Space Mono'da 8-9 px'te
                    // harfin gövdesine yapışıyor ve "YENI" diye okunuyor
                    // (kullanıcı bildirdi; web'de 6× büyütmeyle ölçüldü —
                    // nokta ancak 10 px'ten sonra ayrılıyor). Karakter HER
                    // ZAMAN doğruydu: U+0130 olduğu doğrulandı, kaybolan
                    // şey GLİF. ⚠ Bu iki puntoyu düşürürsen hata geri gelir.
                    // ⚠ `Flexible` YOK: `Wrap` çocuklarına esneklik
                    // verilemez (assertion atar). Kırpma koruması yine
                    // duruyor — ama artık son çare: `Wrap` önce rozeti alta
                    // indirip etikete TÜM genişliği veriyor.
                    Text(entry.surrendered ? 'TESLİM OLDUN' : 'OYUN BİTTİ',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'SpaceMono',
                            fontSize: 11,
                            letterSpacing: 0.5,
                            color: _muted)),
                    // Rozet YANDA (kullanıcı: "yeni rozeti hemen yanına
                    // gelsin") — yalnızca sığmadığında alta iner.
                    if (yeni) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: kRed,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('YENİ',
                            style: TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            // ⚠ SABİT GENİŞLİK + SAĞA YASLI, ve bu bir GERİLEME DÜZELTMESİ
            // (3 Eylül 2026, kullanıcı cihazda bildirdi: "puan ve k-lig
            // bozulmuş, sağda hizalı olmaları lazım").
            //
            // Öncesinde ikisi de düz `Text`ti, yani genişlikleri İÇERİĞE
            // göre değişiyordu ("0" bir karakter, "253" üç) ve satırın
            // sonundaki grup her satırda başka bir yerde bitiyordu.
            // ÖLÇÜLDÜ (412 px, kullanıcının beş satırı): k-lig sağ kenarı
            // 289,9 / 289,9 / **320,8** / **283,2** / 289,9 — dört farklı
            // yerde. 4 kişilik satır 31 px sağa kaçıyordu.
            //
            // `SizedBox` DEĞİL `ScaledCell`: repo kuralı (kök CLAUDE.md →
            // "Sistem Yazı Boyutu", sınıf 3) sabit genişlikli sütunlarda
            // bunu zorunlu kılıyor — kutu yazı ölçeğiyle büyür, metin
            // sarmaz, sığmazsa `FittedBox` küçültür.
            ScaledCell(
              width: 28, // "369" 20,1 px; dört haneye de yer var
              child: Text('${entry.playerScore}',
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _text)),
            ),
            const SizedBox(width: 8),
            ScaledCell(
              width: 18, // "+2" / "-2" / "-"
              child: Text(formatLeaguePoints(points),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: points > 0 ? _green : (points < 0 ? _red : _muted))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sol sütunun esneklik sarmalayıcısı: [genisle] ise `Expanded` (boşluğu
/// alır), değilse `Flexible` (içeriğine küçülür, boşluğu ortadaki etikete
/// bırakır). Ayrı bir widget, çünkü koşulu satırın içine yazmak aynı
/// `Column`u iki kez kopyalamak demek olurdu.
