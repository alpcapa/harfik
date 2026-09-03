// Başka bir oyuncunun (salt-okunur) skor kartı — web `PlayerScoreCard.tsx`
// portu. k-lig satırına dokununca açılır; istatistik bölümü kendi kartınla
// AYNI bileşendir (web'de de öyle — iki kopya bir kez açılmış, kod
// incelemesiyle tek kaynağa çekilmişti).
//
// Web'deki arkadaşlık simgesi (7 Ağustos 2026'dan beri) BURADA DA VAR:
// [friends] verilirse isim yanında ilişkiye göre yeşil ✓ (dokun →
// arkadaşlıktan çık onayı) ya da + (dokun → duruma göre ekle / kabul et /
// isteği iptal onayı) — web `fetchFriendRelation` akışının eşleniği.
// [friends] null ise simge hiç çizilmez (offline/testler — önceki davranış).
// "Tüm Oyunları Gör" bağlı: o oyuncunun geçmişini açar (görüntülenen kişi
// SEN DEĞİLSİN, bu yüzden isMe=false — eski kayıtlardaki yedek satır "Sen"
// yerine o kişinin adını taşır, web'in aynı ayrımı).
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../../util/head_to_head.dart';
import '../auth/k_avatar.dart';
import '../friends/friends_modal.dart'
    show confirmFriendAction, showFriendInfoDialog;
import '../friends/relation_icons.dart';
import '../game/modal_shell.dart';
import '../rank/league_rank.dart';
import '../rank/rank_header_seal.dart';
import '../rank/rank_seal.dart';
import 'game_history_modal.dart';
import 'klig_mark.dart';
import 'leaderboard_modal.dart';
import 'score_stats_section.dart';
import '../tap_target.dart';
import '../tokens.dart';

const _text = kText;
const _muted = kMuted;
const _accent = kAccent;

Future<void> showPlayerScoreCard(
  BuildContext context, {
  required StatsRepo stats,
  required String userId,
  required String name,
  String? avatarUrl,
  Future<GamesRepo>? games,
  FriendsRepo? friends,
  AuthService? auth,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => PlayerScoreCardModal(
      stats: stats,
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      games: games,
      friends: friends,
      auth: auth,
    ),
  );
}

class PlayerScoreCardModal extends StatefulWidget {
  final StatsRepo stats;
  final String userId;
  final String name;
  final String? avatarUrl;

  /// null ise "Tüm Oyunlar" çizilmez (offline mod).
  final Future<GamesRepo>? games;

  /// null ise arkadaşlık simgesi çizilmez (offline/test).
  final FriendsRepo? friends;

  /// null ise k-lig satırı tıklanamaz (Leaderboard açmak için gerekiyor) —
  /// web'de bu satır koşulsuz görünür (`fetchMyLeaderboardRank` yalnızca
  /// `stats` istiyor), ama `showLeaderboard`'ı çağırmak `AuthService`
  /// gerektirdiğinden [auth] verilmemiş çağrı yerlerinde satır YİNE
  /// görünür (rank/puan bilgisi hâlâ faydalı) ama dokunuşu no-op kalır.
  final AuthService? auth;

  const PlayerScoreCardModal({
    super.key,
    required this.stats,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.games,
    this.friends,
    this.auth,
  });

  @override
  State<PlayerScoreCardModal> createState() => _PlayerScoreCardModalState();
}

class _PlayerScoreCardModalState extends State<PlayerScoreCardModal> {
  /// Kafa kafaya — yalnızca BAŞKASININ kartında ve giriş yapılmışken
  /// anlamlı. Sunucu kendi kartında zaten 0 döner, ama gereksiz istek de
  /// atmıyoruz (bkz. `_kafaKafayaYukle`).
  HeadToHead? _h2h;

  StatsTab _tab = StatsTab.all;
  final _statsByTab = <StatsTab, PlayerStats?>{};
  final _loaded = <StatsTab>{};

  // Arkadaşlık ilişkisi: null = ilişki yok ya da henüz yüklenmedi/kendi
  // kartın — `_relationLoaded` ikisini ayırır (yüklenmeden simge çizilmez).
  FriendRelation? _relation;
  bool _relationLoaded = false;

  // k-lig satırındaki "#sıra ·" öneki — web `rank` state'iyle aynı
  // (`fetchMyLeaderboardRank(member.id)`, burada `stats.myRank(userId)`).
  MyLeaderboardRank? _rank;

  /// "Y:59/C:E" — `profiles` RLS'i başkasının satırını okutmadığından ayrı bir
  /// RPC'den gelir (`StatsRepo.ageGenderLabel`). Yüklenene kadar ya da veri
  /// girilmemişse boş kalır ve satır hiç çizilmez (web ile aynı).
  String _ageGender = '';

  @override
  void initState() {
    super.initState();
    _loadRelation();
    widget.stats.myRank(widget.userId).then((r) {
      if (mounted) setState(() => _rank = r);
    });
    widget.stats.ageGenderLabel(widget.userId).then((label) {
      if (mounted) setState(() => _ageGender = label);
    });
    // Kendi kartında kafa kafaya anlamsız — sunucu da 0 döndürür ama
    // isteği hiç atmıyoruz.
    // ⚠ Ayrı bir `myUserId`/`myAvatarUrl` parametresi EKLENMEDİ: modal
    // zaten `auth` alıyor. Yeni parametre beş imzayı da değiştirir ve
    // birinde unutulursa blok o ekranda SESSİZCE kaybolurdu.
    // ⚠⚠ Ve tam olarak bu SESSİZ kayıp bir kez yaşandı: beş çağrı yerinin
    // DÖRDÜ `auth` geçiyordu, "Beğenenler" listesinden açılan kart
    // (`game_history_modal.dart`) geçmiyordu — çubuk yalnızca orada
    // çizilmiyordu ve hiçbir şey bunu söylemiyordu. `showGameHistory`
    // artık `auth`u da taşıyor. Web'de bu tuzak YOK: orada "ben kimim"
    // `useAuth()` bağlamından geliyor, parametreyle taşınmıyor.
    final benId = widget.auth?.user?.id;
    if (benId != null && benId != widget.userId) {
      widget.stats.headToHead(widget.userId).then((h) {
        if (mounted) setState(() => _h2h = h);
      });
    }
    for (final t in StatsTab.values) {
      widget.stats.playerStats(widget.userId, t).then((s) {
        if (!mounted) return;
        setState(() {
          _statsByTab[t] = s;
          _loaded.add(t);
        });
      });
    }
  }

  void _loadRelation() {
    final friends = widget.friends;
    if (friends == null) return;
    friends.relationWith(widget.userId).then((r) {
      if (!mounted) return;
      setState(() {
        _relation = r;
        _relationLoaded = true;
      });
    });
  }

  /// Web PlayerScoreCard davranışı: DÖRT dal da önce bir onay diyaloğu
  /// açar, hiçbiri anında iş yapmaz. Hangi dal hangi ikon: `_relationGlyph`.
  Future<void> _onRelationTap() async {
    final friends = widget.friends;
    if (friends == null) return;
    final name = widget.name;
    try {
      switch (_relation) {
        case FriendRelation.accepted:
          final ok = await confirmFriendAction(context,
              title: 'Arkadaşlıktan Çıkar',
              message:
                  '$name ile arkadaşsınız. Arkadaşlıktan çıkmak mı istiyorsunuz?',
              confirmLabel: 'Çıkar');
          if (!ok || !mounted) return;
          await friends.removeOrCancel(widget.userId);
          if (mounted) {
            setState(() => _relation = null);
            await showFriendInfoDialog(context, 'Arkadaşlıktan çıkarıldı.');
          }
        case FriendRelation.pendingOutgoing:
          final ok = await confirmFriendAction(context,
              title: 'İsteği İptal Et',
              message: '$name oyuncusuna gönderdiğin arkadaşlık isteğini '
                  'iptal etmek istiyor musun?',
              confirmLabel: 'İptal Et');
          if (!ok || !mounted) return;
          await friends.removeOrCancel(widget.userId);
          if (mounted) {
            setState(() => _relation = null);
            await showFriendInfoDialog(
                context, 'Arkadaşlık isteği iptal edildi.');
          }
        case FriendRelation.pendingIncoming:
          // Metinler web `friendDialogCopy` ile BİREBİR — aynı gün
          // `FriendsModal._confirmThenAdd` de bu sözleri kullandığından
          // uygulama içinde de tek bir dil kaldı (bu iki dal daha önce
          // web'den sessizce ayrışmıştı).
          final ok = await confirmFriendAction(context,
              title: 'Arkadaşlık İsteği',
              message: '$name oyuncusu sana arkadaşlık isteği gönderdi. '
                  'Kabul etmek istiyor musun?',
              confirmLabel: 'Kabul Et');
          if (!ok || !mounted) return;
          await friends.respond(widget.userId, accept: true);
          if (mounted) {
            setState(() => _relation = FriendRelation.accepted);
            await showFriendInfoDialog(context, 'Arkadaş oldunuz.');
          }
        case null:
          final ok = await confirmFriendAction(context,
              title: 'Arkadaş Ekle',
              message: '$name oyuncusunu arkadaş olarak eklemek istiyor musun?',
              confirmLabel: 'Ekle');
          if (!ok || !mounted) return;
          final r = await friends.sendRequest(widget.userId);
          if (mounted) {
            setState(() => _relation = r);
            await showFriendInfoDialog(
                context,
                r == FriendRelation.accepted
                    ? '$name ile artık arkadaşsınız.'
                    : 'Arkadaşlık isteğiniz iletilmiştir.');
          }
      }
    } catch (e) {
      debugPrint('[Kelimeki] arkadaşlık işlemi hatası: $e');
    }
  }

  /// Web `friendIconFor` (PlayerScoreCard.tsx) — isim yanındaki ilişki
  /// simgesi. DÖRT dal, `_onRelationTap`in dört dalıyla birebir.
  ///
  /// ⚠ **BULUNAN HATA (30 Ağustos 2026, kullanıcı bildirdi):** burası (web
  /// ikizi gibi) İKİ dala ayrılmıştı — `accepted` ve "diğer her şey" — yani
  /// istek gönderilmiş bir kişinin kartında "arkadaş ekle" ikonu çıkıyordu;
  /// aynı kişi "Ara & Ekle" listesinde kum saatiyle görünürken. Onay
  /// diyaloğu baştan beri dördünü ayırıyordu, yalnızca ikon geride kalmıştı.
  /// Ders: bir DURUM birden çok yüzeyde gösteriliyorsa yüzeylerin dal
  /// SAYILARI da eşit olmalı.
  ///
  /// `accepted` dalı `friends_modal`dan BİLEREK ayrılıyor (yeşil
  /// `how_to_reg`, kırmızı `person_remove` değil) — 11 Ağustos 2026
  /// kullanıcı kararı: listede ikon bir AKSİYON sütununda durur, burada
  /// ismin yanında durup kimliğin parçası gibi okunur; "adam-" orada bir
  /// uyarı gibi görünüyordu. Dokunuş yine çıkarma onayını açıyor, yani
  /// "ikon ne yapacağını söyler" kuralı onay diyaloğuyla korunuyor. Aynı
  /// glyph listede "gelen isteği kabul et" (mavi) demek — renk ayrımı bu
  /// yüzden zorunlu, ikisini aynı renge çekme.
  /// (Yeşil, tailwind `green` token'ı: #16A34A. Web'de İKİ ayrı yeşil
  /// olduğu notu hâlâ geçerli — `Board.tsx`'in hardcoded #1FA05C'si başka
  /// bir yer; bkz. mobile/CLAUDE.md Parça 42.)
  Widget _relationGlyph() => switch (_relation) {
        FriendRelation.accepted =>
          const Icon(Icons.how_to_reg, size: 20, color: kGreen),
        FriendRelation.pendingOutgoing =>
          const PersonPendingIcon(color: kMuted),
        FriendRelation.pendingIncoming =>
          const Icon(Icons.how_to_reg, size: 20, color: kAccent),
        null => const Icon(Icons.person_add_alt_1, size: 20, color: kAccent),
      };

  Widget? _relationIcon() {
    if (widget.friends == null || !_relationLoaded) return null;
    return GestureDetector(
      onTap: _onRelationTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: _relationGlyph(),
      ),
    );
  }

  // k-lig satırı — web `PlayerScoreCard.tsx`nin koşulsuz görünen butonu
  // (bkz. dosya başı yorumu): KLigMark + "?" bilgi rozeti + "#sıra · puan
  // puan". `auth` verilmemiş çağrı yerlerinde (bkz. showPlayerScoreCard'ın
  // AYRI çağrıldığı game_history_modal.dart) satır yine görünür ama dokunuş
  // no-op kalır — bilgi kaybı yok, yalnızca Leaderboard'u açan aksiyon yok.
  Widget _kligButton() {
    final totalScore = _statsByTab[StatsTab.all]?.totalScore ?? 0;
    final auth = widget.auth;
    return TapTarget(
      onTap: auth == null
          ? null
          : () => showLeaderboard(context,
              auth: auth,
              stats: widget.stats,
              games: widget.games,
              friends: widget.friends),
      minWidth: 0,
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Web `KLigMark`'ın `color` prop varsayılanı mavi (`KLIG_COLOR`) —
          // kapsayan `text-muted` div'i yalnızca "?" rozetini/puan metnini
          // etkiliyor, SVG fill'ini değil (bkz. score_card_modal.dart'taki
          // aynı düzeltmenin gerekçesi).
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KLigMark(height: 16),
              SizedBox(width: 4),
              KLigInfoBadge(),
            ],
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(children: [
              if (_rank != null) ...[
                TextSpan(text: '#${_rank!.rank}'),
                // Web `mx-0.5` = 2px. Boşluk KARAKTERİ DEĞİL: Space Mono'da
                // bir boşluk ~0.6em (13px'te ~7.8) eder ve iki yanda ~6px
                // fazla açar — 17 Ağustos 2026 görsel turunda kullanıcı
                // "nokta sağı ve solu web'e göre daha açık" diye bildirdi.
                const WidgetSpan(child: SizedBox(width: 2)),
                const TextSpan(text: '·'),
                const WidgetSpan(child: SizedBox(width: 2)),
              ],
              TextSpan(text: '$totalScore'),
              const TextSpan(
                text: ' puan',
                style: TextStyle(
                    fontWeight: FontWeight.normal, color: _muted),
              ),
            ]),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KModal(
      title: 'Skor Kartı',
      // Skor Kartı'ndaki AYNI mühür (tek kaynak) — bu kartın sahibinin
      // güncel puanından türetilir.
      headerCenter: rankHeaderSeal(context,
          overall: _statsByTab[StatsTab.all],
          loaded: _loaded.contains(StatsTab.all)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KAvatar(url: widget.avatarUrl, name: widget.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(widget.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _text)),
                        ),
                        // Rütbe mührü ismin YANINDA (Skor Kartı ile aynı
                        // kural/boy) — arkadaşlık ikonundan ÖNCE, yani isme
                        // bitişik. Başlıktaki 34px'lik mühür duruyor.
                        if (_loaded.contains(StatsTab.all)) ...[
                          const SizedBox(width: 4),
                          RankSeal(
                              tier: tierFor(
                                  _statsByTab[StatsTab.all]?.totalScore ?? 0),
                              size: 20),
                        ],
                        if (_relationIcon() case final icon?) icon,
                      ],
                    ),
                    // Yaş/cinsiyet — ismin ALTINDA, Skor Kartı'ndaki (kendi
                    // kartın) satırla birebir aynı biçim. Arkadaşlık
                    // simgesinin olduğu Row'un DIŞINDA ki ikon hizası
                    // bozulmasın (web'in aynı ayrımı).
                    if (_ageGender.isNotEmpty)
                      Text(_ageGender,
                          style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 12,
                              color: _muted)),
                  ],
                ),
              ),
              _kligButton(),
            ],
          ),
          const SizedBox(height: 16),
          ScoreTabsBar(
            tab: _tab,
            onChanged: (t) => setState(() => _tab = t),
            statsByTab: _statsByTab,
          ),
          const SizedBox(height: 12),
          ScoreStatsSection(
            stats: _statsByTab[_tab],
            loaded: _loaded.contains(_tab),
            emptyText: _tab == StatsTab.all
                ? 'Bu oyuncunun henüz oyun kaydı yok.'
                : 'Bu oyuncunun ${_tab.playerCount} oyunculu oyun kaydı yok.',
          ),
          if (widget.games != null) ...[
            const SizedBox(height: 8),
            // 3 Eylül 2026 (kullanıcı isteği): satır SOLA dayandı, etiket
            // "TÜM OYUNLARI GÖR" → "TÜM OYUNLAR" oldu (web'de de aynı ad;
            // öncesinde web "Tüm Geçmiş Oyunlar" diyordu) ve sağ tarafa
            // aramızdaki kafa kafaya oran çubuğu geldi.
            // Kullanıcı aynı gün "Hepsinde Tüm oyunlar olsun / Ve sola
            // yapışsın" dedi: KENDİ skor kartının butonu
            // (`score_card_modal.dart`) ve geçmiş modalının BAŞLIĞI da
            // aynı ada çekildi, o buton da sola yaslandı. Yani bugün
            // projede tek ad var: "Tüm Oyunlar".
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              GestureDetector(
                onTap: () async {
                  final games = await widget.games!;
                  if (!context.mounted) return;
                  await showGameHistory(
                    context,
                    games: games,
                    userId: widget.userId,
                    playerCount: _tab.playerCount,
                    currentName: widget.name,
                    isMe: false,
                    stats: widget.stats,
                    auth: widget.auth,
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'TÜM OYUNLAR',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: kAccent),
                  ),
                ),
              ),
              if (hasHeadToHead(_h2h))
                _KafaKafaya(
                  data: _h2h!,
                  theirAvatarUrl: widget.avatarUrl,
                  theirName: widget.name,
                  myAvatarUrl: widget.auth?.profile?.avatarUrl,
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Kafa kafaya oran çubuğu — kullanıcı tarifi (3 Eylül 2026): *"Sağ tarafa
/// dayalı bir % çubuğu, üstünde oyun sayısı, barın sol tarafına bakılan kişi
/// avatar, sağ tarafına bakan kişi avatar. İsim yazmayacak."*
///
/// ⚠ **Yön TERS okunuyor:** RPC çağıranın (BAKANIN) bakış açısından dönüyor
/// (`wins` = bakan kazandı), ama barın SOL ucu BAKILAN kişiye ait — yani
/// sol dilim `losses`. Kural `util/head_to_head.dart`ta ve web ikizi de
/// onu okuyor.
///
/// İsim yazılmıyor ama `Semantics` etiketi var: iki yuvarlak arasındaki
/// farkı anlatan başka hiçbir işaret yok.
class _KafaKafaya extends StatelessWidget {
  final HeadToHead data;
  final String? theirAvatarUrl;
  final String theirName;
  final String? myAvatarUrl;
  const _KafaKafaya({
    required this.data,
    required this.theirAvatarUrl,
    required this.theirName,
    required this.myAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bar = headToHeadBar(data);
    // Üç satır ORTAK bir eksende: yüzdeler ve oyun sayısı BARIN genişliğinde
    // (96) şeritler. Avatar satırı 18+6+96+6+18 = 144 olduğundan bar zaten
    // satırın tam ortasında — `center` üç şeridi barla hizalar, ayrı bir
    // dolgu hesabı gerekmiyor.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Yüzdeler barın ÜSTÜNDE, kendi alanlarının üzerinde: kırmızı hep
        // sol uçtan başlar, yeşil hep sağ uçta biter, o yüzden uçlara
        // yaslamak etiketi her zaman kendi diliminin üzerinde tutar.
        // ⚠ Beraberlik dilimi ortada DURUR ama yüzdesi YAZILMAZ (kullanıcı
        // kararı). Sıfır olan uç etiketi de yazılmaz ama `Opacity` ile
        // yerini korur — `SizedBox.shrink` olsaydı tek kalan etiket
        // `spaceBetween` altında ortaya kayardı.
        SizedBox(
          width: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Yuzde(deger: bar.left, renk: kRed),
              _Yuzde(deger: bar.right, renk: kGreen),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          KAvatar(url: theirAvatarUrl, name: theirName, size: 18),
          const SizedBox(width: 6),
          Semantics(
            label: '$theirName ${data.losses} - ${data.wins} sen',
            child: Container(
              width: 96,
              height: 8,
              decoration: BoxDecoration(
                color: kVoid,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              // Sol = bakılan kişi, orta = beraberlik (nötr), sağ = bakan.
              //
              // ⚠ SIFIR dilimler hiç ÇİZİLMİYOR: `Expanded(flex: 0)` bu
              // düzende güvenilir değil (esnek olmayan çocuk kendi
              // ölçüsüne düşer, `ColoredBox`ın ölçüsü yok). Üç dilim
              // toplamı 100 olduğundan en az biri > 0 ve oranlar bozulmaz.
              // Web'de karşılığı zararsız (`width: 0%`), yani bu koruma
              // PORTA ÖZGÜ — ikizde aramaya gerek yok.
              child: Row(children: [
                if (bar.left > 0)
                  Expanded(flex: bar.left, child: const ColoredBox(color: kRed)),
                if (bar.middle > 0)
                  Expanded(
                      flex: bar.middle, child: const ColoredBox(color: kMuted)),
                if (bar.right > 0)
                  Expanded(
                      flex: bar.right, child: const ColoredBox(color: kGreen)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          KAvatar(url: myAvatarUrl, name: 'Sen', size: 18),
        ]),
        const SizedBox(height: 2),
        SizedBox(
          width: 96,
          child: Text('${data.games} oyun',
              textAlign: TextAlign.center,
              // Sistem yazı boyutu tavanda (1,3) bile 96'ya sığıyor, ama
              // sarma sınıfı hatasına (kök CLAUDE.md → "Sistem Yazı
              // Boyutu", sınıf 3) hiç kapı bırakmıyoruz.
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                  fontFamily: 'SpaceMono', fontSize: 9, color: kMuted)),
        ),
      ],
    );
  }
}

/// Barın ucundaki yüzde etiketi. Sıfırsa GÖRÜNMEZ ama yerini korur.
class _Yuzde extends StatelessWidget {
  final int deger;
  final Color renk;
  const _Yuzde({required this.deger, required this.renk});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: deger > 0 ? 1 : 0,
        child: Text('%$deger',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: renk)),
      );
}
