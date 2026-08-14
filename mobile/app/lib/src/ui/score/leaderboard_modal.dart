// k-lig sıralaması — web `Leaderboard.tsx` portu: ilk 10 satır, kaydırdıkça
// 20'şer lazy yükleme, kendi satırın vurgulu; yüklenenler arasında yoksan
// altta kesikli çizgiyle ayrılmış "senin sıran" kısayolu. Satıra dokunmak o
// oyuncunun (salt-okunur) skor kartını açar.
import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/k_avatar.dart';
import '../game/modal_shell.dart';
import '../rank/league_rank.dart';
import '../rank/rank_seal.dart';
import 'klig_mark.dart';
import 'player_score_card_modal.dart';
import '../tokens.dart';

const _muted = kMuted;
const _text = kText;
const _accent = kAccent;
const _gold = kGold;
const _border = kBorder;
const _panel = kPanel;

/// OHP = ortalama hamle puanı. Skor Kartı'ndaki "Ortalama Hamle Puanı" ile
/// AYNI değeri AYNI biçimde (2 basamak) gösterir — iki ekranın sessizce
/// ayrışmaması için tek bir biçimlendirici (web `formatOhp` ile aynı).
/// Veri yoksa, satırın "Puan" hücresiyle aynı kuralla, "—".
String formatOhp(double? v) => v == null ? '—' : v.toStringAsFixed(2);

/// OHP sütununun genişliği — DEĞERİN ink genişliğine eşit seçildi
/// (`12.78` = 5 monospace karakter × 11px × 0.612 ≈ 34). Sebebi hiza:
/// değerler sağa yaslı, başlık ise ORTALI çiziliyor; kutu tam değer
/// genişliğinde olunca ikisinin merkezi çakışıyor. Kutu 52 + başlık sağa
/// yaslı iken başlık, değerlerin ~7px SAĞINDA kalıyordu ("OHP" 3 karakter/
/// 9px, değer 5 karakter/11px — iki dize de sağa yaslıyken merkezleri
/// genişlik farkının yarısı kadar ayrışır). Sütunun SAĞ kenarı değişmedi
/// (daralma yalnızca sol kenarı sağa çeker, boşluk "Oyuncu"ya gider), yani
/// OHP↔Puan sağ-kenar mesafesi (44) korunuyor. Web `Leaderboard.tsx`'te
/// aynı sayı `w-[34px]` olarak duruyor — biri değişirse öteki de.
const double _kOhpColumnWidth = 34;

/// Başlığa dokununca/hover edince görünen açıklama (web ile birebir).
/// Metin sunucudaki hesabı BİREBİR tarif ediyor: `leaderboard.avg_move_score`
/// = sum(move_points_sum) / sum(move_count) — yani oyun başına ortalamaların
/// ortalaması DEĞİL, tüm hamlelerin tek havuzdaki ortalaması. İfade
/// değişirse bu cümle de değişmeli (web `OHP_HINT` ile ELLE senkron).
const ohpHint =
    'Ortalama Hamle Puanı tüm oyunlarda yapılan tüm hamlelerin ortalamasıdır.';

/// Web INITIAL_PAGE_SIZE / PAGE_SIZE — ilk açılışta "ilk 10", sonra 20'şer.
const _initialPageSize = 10;
const _pageSize = 20;

Future<void> showLeaderboard(
  BuildContext context, {
  required AuthService auth,
  required StatsRepo stats,
  Future<GamesRepo>? games,
  FriendsRepo? friends,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => LeaderboardModal(
        auth: auth, stats: stats, games: games, friends: friends),
  );
}

class LeaderboardModal extends StatefulWidget {
  final AuthService auth;
  final StatsRepo stats;

  /// Satırdan açılan oyuncu kartındaki "Tüm Oyunları Gör" için taşınır.
  final Future<GamesRepo>? games;

  /// Satırdan açılan oyuncu kartındaki arkadaşlık simgesi için taşınır.
  final FriendsRepo? friends;

  const LeaderboardModal({
    super.key,
    required this.auth,
    required this.stats,
    this.games,
    this.friends,
  });

  @override
  State<LeaderboardModal> createState() => _LeaderboardModalState();
}

class _LeaderboardModalState extends State<LeaderboardModal> {
  List<LeaderboardRow>? _rows;
  bool _hasMore = true;
  bool _loadingMore = false;
  MyLeaderboardRank? _myRank;

  /// "OHP" açıklama balonu — başlığın TAM ÜSTÜNDE, aşağı bakan kuyruklu.
  /// İki ayrı kaynak, çünkü kapanma kuralları farklı (web ile aynı ayrım):
  /// hover (masaüstü) fare çekilince kendiliğinden kapanır; dokunuş
  /// (mobilde hover DİYE BİR ŞEY YOK) bir daha dokunulana ya da dışarı
  /// dokunulana kadar açık kalır. Tek bayrakla ikisi birden doğru olamıyor.
  bool _ohpHintPinned = false;
  bool _ohpHintHover = false;
  bool get _ohpHintOpen => _ohpHintPinned || _ohpHintHover;
  final _ohpLink = LayerLink();
  final _ohpPortal = OverlayPortalController();
  final _scrollController = ScrollController();

  /// Balonun görünürlüğünü iki bayrağın BİRLEŞİMİNDEN türetir — çağıranlar
  /// yalnızca bayrağı değiştirip bunu çağırır, "kim açtı/kim kapatır"
  /// mantığı tek yerde kalsın diye.
  void _syncOhpHint() {
    if (_ohpHintOpen) {
      _ohpPortal.show();
    } else {
      _ohpPortal.hide();
    }
  }

  /// "OHP" başlığı + üstünde açılan açıklama balonu.
  ///
  /// Balon `OverlayPortal` ile çiziliyor: başlık satırı kendi `Row`unun
  /// içinde ve modalın kaydırma kabında yaşıyor, yani normal bir `Stack`
  /// çocuğu olarak konsa hem kırpılır hem satırın yüksekliğini değiştirirdi.
  /// Konum `CompositedTransformFollower` ile başlığın SAĞ ÜST köşesine
  /// bağlı — balon sağa hizalı, aşağı bakan kuyruğu OHP'yi gösteriyor.
  Widget _buildOhpHeader() {
    return CompositedTransformTarget(
      link: _ohpLink,
      child: OverlayPortal(
        controller: _ohpPortal,
        overlayChildBuilder: (context) => Stack(
          children: [
            // Bariyer YALNIZCA dokunuşla açıldığında var: hover'da da
            // olsaydı fare başlığın üstündeyken tüm modalı tıklanamaz
            // yapardı. Bariyer başlığın kendisini de kapladığından
            // "tekrar dokununca kapanır" kuralı da bundan geliyor.
            if (_ohpHintPinned)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _ohpHintPinned = false);
                    _syncOhpHint();
                  },
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _ohpLink,
                targetAnchor: Alignment.topRight,
                followerAnchor: Alignment.bottomRight,
                offset: const Offset(0, -6),
                child: const _OhpHintBalloon(),
              ),
            ),
          ],
        ),
        child: MouseRegion(
          onEnter: (_) {
            setState(() => _ohpHintHover = true);
            _syncOhpHint();
          },
          onExit: (_) {
            setState(() => _ohpHintHover = false);
            _syncOhpHint();
          },
          child: GestureDetector(
            onTap: () {
              setState(() => _ohpHintPinned = !_ohpHintPinned);
              _syncOhpHint();
            },
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(
              // Kutu genişliği OHP DEĞERİNİN ink genişliğine eşit
              // (`12.78` = 5 monospace karakter × 11px × 0.612 ≈ 34) —
              // sağa hizalı değerlerle ORTALI başlık aynı merkeze düşsün
              // diye. Bkz. `_kOhpColumnWidth`.
              width: _kOhpColumnWidth,
              child: _HeadLabel('OHP',
                  align: TextAlign.center, underline: true),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.stats
        .leaderboard(limit: _initialPageSize, offset: 0)
        .then((rows) {
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _hasMore = rows.length == _initialPageSize;
      });
      _maybeAutoLoadIfNotScrollable();
    });
    final user = widget.auth.user;
    if (user != null) {
      widget.stats.myRank(user.id).then((r) {
        if (mounted) setState(() => _myRank = r);
      });
    }
    // Web IntersectionObserver'ın karşılığı — sona yaklaşınca sonraki sayfa.
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 80) _loadMore();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Web'in `IntersectionObserver`ı sentinel açılışta ZATEN görünürse (liste
  // 50vh'a sığacak kadar kısaysa) hiç kaydırma gerekmeden ANINDA tetiklenir
  // — sentinel "görünür" olmayı bekler, "kaydırıldı" olmayı DEĞİL. Flutter'ın
  // `ScrollController.addListener`ı ise yalnızca kaydırma POZİSYONU
  // DEĞİŞTİĞİNDE çağrılıyor; içerik zaten sığıp `maxScrollExtent==0` kalırsa
  // (kaydırılacak hiçbir şey olmadığından) listener HİÇ ateşlenmiyor ve
  // sonraki sayfa asla otomatik yüklenmiyordu (9 Ağustos 2026'da kullanıcı
  // web/mobil ekran görüntüsü karşılaştırmasıyla bildirdi — mobilde liste
  // ilk 10'da/"senin sıran" kısayolunda takılı kalıyordu, web'de aynı kısa
  // liste anında tam listeye tamamlanıyordu). Düzeltme: her sayfa
  // yüklemesinden SONRA (post-frame, layout'un gerçekten bitmesini bekleyip)
  // içerik hâlâ kaydırılamıyor mu diye elle kontrol edilip gerekirse bir
  // sonraki sayfa da hemen istenir — `_hasMore` tükenene ya da liste
  // gerçekten kaydırılabilir hâle gelene kadar zincirlenir.
  void _maybeAutoLoadIfNotScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasMore || _loadingMore) return;
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) _loadMore();
    });
  }

  void _loadMore() {
    if (_loadingMore || !_hasMore || _rows == null) return;
    setState(() => _loadingMore = true);
    widget.stats
        .leaderboard(limit: _pageSize, offset: _rows!.length)
        .then((page) {
      if (!mounted) return;
      setState(() {
        _rows = [...?_rows, ...page];
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
      });
      _maybeAutoLoadIfNotScrollable();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final user = widget.auth.user;
    final meInList =
        user != null && rows != null && rows.any((r) => r.userId == user.id);

    return KModal(
      title: '',
      // Web'de başlık bir JSX parçası: 🏆 + wordmark (bkz. KModal.titleWidget).
      // Emoji için fontFamilyFallback ŞART — yüklenen aile ADIYLA referans
      // verilmedikçe kullanılmıyor (help_modal'da öğrenilen ders; ilk
      // sürümde ekran görüntüsünde kutu çıktı).
      titleWidget: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏆 ',
              style: TextStyle(
                fontSize: 20,
                fontFamilyFallback: ['Noto Color Emoji', 'Apple Color Emoji'],
              )),
          KLigMark(height: 28),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'k-lig, senin gibi kayıtlı kullanıcıların aldığı puanlara göre '
            'oluşan bir yarışmadır.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                height: 1.5,
                color: _muted),
          ),
          const SizedBox(height: 12),
          if (rows == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Yükleniyor…',
                    style: TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
              ),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Henüz skor yok. İlk sen ol!',
                    style: TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 12, color: _muted)),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                // 28: "SIRA" 9px SpaceMono + 1px letter-spacing'te 24'e
                // sığmayıp alt satıra kayıyordu (ekran görüntüsü yakaladı).
                const SizedBox(width: 28, child: _HeadLabel('SIRA')),
                const Expanded(child: _HeadLabel('OYUNCU')),
                _buildOhpHeader(),
                const SizedBox(width: 44, child: _HeadLabel('PUAN', align: TextAlign.right)),
              ]),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: rows.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= rows.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(_loadingMore ? 'Yükleniyor…' : '',
                            style: const TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 10,
                                color: _muted)),
                      ),
                    );
                  }
                  final r = rows[i];
                  return _Row(
                    rank: i + 1,
                    name: r.shortName,
                    avatarUrl: r.avatarUrl,
                    score: r.totalScore,
                    avgMoveScore: r.avgMoveScore,
                    isMe: user != null && r.userId == user.id,
                    onTap: () => showPlayerScoreCard(
                      context,
                      stats: widget.stats,
                      userId: r.userId,
                      name: r.shortName,
                      avatarUrl: r.avatarUrl,
                      games: widget.games,
                      friends: widget.friends,
                      auth: widget.auth,
                    ),
                  );
                },
              ),
            ),
            if (user != null && !meInList && _myRank != null) ...[
              const SizedBox(height: 8),
              const Row(children: [
                Expanded(child: Divider(color: _border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('SENİN SIRAN',
                      style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 9,
                          letterSpacing: 1,
                          color: _muted)),
                ),
                Expanded(child: Divider(color: _border)),
              ]),
              _Row(
                rank: _myRank!.rank,
                name: 'Sen',
                avatarUrl: widget.auth.profile?.avatarUrl,
                score: _myRank!.totalScore,
                avgMoveScore: _myRank!.avgMoveScore,
                isMe: true,
                onTap: () => showPlayerScoreCard(
                  context,
                  stats: widget.stats,
                  userId: user.id,
                  name: widget.auth.menuName,
                  avatarUrl: widget.auth.profile?.avatarUrl,
                  games: widget.games,
                  friends: widget.friends,
                  auth: widget.auth,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// OHP açıklama balonu — kutu + aşağı bakan kuyruk (web'in `absolute
/// bottom-full` balonu + 45° döndürülmüş kare kuyruğunun karşılığı).
class _OhpHintBalloon extends StatelessWidget {
  const _OhpHintBalloon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 224, // web `w-56`
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _panel,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(ohpHint,
                style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    height: 1.5,
                    letterSpacing: 0,
                    color: _muted)),
          ),
          // Kuyruk kutunun alt çerçevesinin 1px ÜSTÜNDEN başlıyor ki
          // aradaki çizgi kesintisiz görünsün (kuyruğun kendi üst kenarı
          // çizilmiyor — o kutunun çerçevesiyle çakışıyor).
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Transform.translate(
              offset: const Offset(0, -1),
              child: CustomPaint(
                size: const Size(10, 6),
                painter: _BalloonTailPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalloonTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tip = Offset(size.width / 2, size.height);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _panel);
    // Yalnızca iki EĞİK kenar — üst kenar kutunun çerçevesiyle çakışıyor.
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(size.width, 0),
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeadLabel extends StatelessWidget {
  final String text;
  final TextAlign align;

  /// Noktalı alt çizgi — başlığın dokunulabilir olduğunu belli eder
  /// (web'deki `underline decoration-dotted` ile aynı).
  final bool underline;
  const _HeadLabel(this.text,
      {this.align = TextAlign.left, this.underline = false});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 9,
          letterSpacing: 1,
          color: _muted,
          decoration: underline ? TextDecoration.underline : null,
          decorationStyle: underline ? TextDecorationStyle.dotted : null,
          decorationColor: underline ? _muted : null,
        ),
      );
}

class _Row extends StatelessWidget {
  final int rank;
  final String name;
  final String? avatarUrl;
  final int score;
  final double? avgMoveScore;
  final bool isMe;
  final VoidCallback onTap;

  const _Row({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.score,
    required this.avgMoveScore,
    required this.isMe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Web: 1. altın, 2-3. accent, kalanı muted.
    final rankColor = rank == 1 ? _gold : (rank <= 3 ? _accent : _muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isMe ? _accent.withValues(alpha: 0.1) : Colors.white,
            border: Border.all(color: isMe ? _accent : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('$rank',
                    style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: rankColor)),
              ),
              KAvatar(url: avatarUrl, name: name, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 14,
                              color: _text)),
                    ),
                    const SizedBox(width: 6), // web gap-1.5
                    // Rütbe mührü — GÜNCEL puandan türetilir (düşmeli sürüm),
                    // ismin hemen yanında. Bu boyda RankSeal KOMPAKT çizer
                    // (iç halkasız, büyük harf) — 12 Ağustos 2026 okunurluk
                    // düzeltmesi.
                    RankSeal(tier: tierFor(score), size: 18),
                  ],
                ),
              ),
              // OHP düz gri, KALIN DEĞİL ve satırın kendi 14px'inden küçük
              // (kullanıcı isteği) — asıl sıralama ölçütü olan "Puan"la
              // görsel olarak yarışmasın diye.
              SizedBox(
                width: _kOhpColumnWidth,
                child: Text(formatOhp(avgMoveScore),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono', fontSize: 11, color: _muted)),
              ),
              SizedBox(
                width: 44,
                child: Text('$score',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
