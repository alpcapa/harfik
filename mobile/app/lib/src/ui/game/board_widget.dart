// 13×13 oyun tahtası — src/components/Board.tsx'in render katmanı portu.
// Sürükle-bırak destekli: yerleştirilmiş (bu tur konmuş) taşlar, drag
// handler'ları verildiğinde GestureDetector yerine Listener taşır — dokunuş
// da sürükleme de ekran katmanının (GameScreen) pointer akışından geçer
// (web'de Tile'ın onPointerDown/Move/Up prop'larının eşleniği). Alt bilgi
// şeridi (solda "Hamleler" [+ Canlı oyunda "· Mesajlaşma"], sağda
// "Çevrimdışı" uyarısı ve "Nasıl Oynanır?") kartın alt bölümü olarak
// portlandı; "Mesajlaşma" butonu yalnızca Canlı oyunda çıkar (web'de de
// prop verilmezse hiç render edilmiyor).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'count_badge.dart';
import 'neo_box.dart';
import 'outline.dart';
import 'player_colors.dart';
import 'tile_widget.dart';
import '../tokens.dart';
import '../../util/online_status.dart';

/// Yalnızca testler için: `build()` her çağrıldığında bir artar. Sürükleme
/// sırasında `BoardWidget`'ın gereksiz yere yeniden inşa EDİLMEDİĞİNİ
/// kanıtlayan kalıcı bir performans regresyon testi bunu okur (8 Ağustos
/// 2026, mobile/CLAUDE.md Parça 23 — 169 hücre + territory hesabının her
/// pointer hareketinde sıfırdan çizilmesi kullanıcı tarafından cihazda
/// "titreme/takılma" olarak bildirilmişti). Üretim davranışını hiç
/// etkilemez, yalnızca bir sayaç.
@visibleForTesting
int debugBoardBuildCountForTests = 0;

/// Dış hat köşe yarıçapı (ızgara birimi) ve kalınlığı — web sabitleri.
const double _outlineRadius = 0.16;
const double _outlineStroke = 2.5;

const Color _boardBg = Color(0xFFDDE4EE);

const LinearGradient _goldZone = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFDE68A), Color(0xFFFBBF24)],
);
const LinearGradient _centerZone = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
);
const Color _centerText = Color(0xFF7C2D12);

/// Oyna'ya basmadan önceki anlık geçerlilik çerçevesi (web MoveStatus'un
/// tahtaya bakan yüzü) — hesaplama ekran katmanında.
class MoveOverlay {
  final bool valid;
  final List<Cell> cells;
  final int score;
  const MoveOverlay(
      {required this.valid, required this.cells, required this.score});
}

class BoardWidget extends StatelessWidget {
  final GameState state;
  final void Function(int r, int c)? onCellTap;
  final MoveOverlay? moveOverlay;
  final bool compact;

  /// Sürüklenen kaynağın hücresi — taş görünmez çizilir (web dragHiddenKey).
  /// Yalnızca sürükleme BAŞLADIĞINDA/BİTTİĞİNDE değişir (nadir) — hover
  /// hedefi (`dragOverKey`/`dragOverValid`, HER pointer hareketinde değişen)
  /// artık bu widget'ın parametresi DEĞİL; ekran katmanı onu ayrı, küçük bir
  /// overlay'de (`ValueListenableBuilder`) çiziyor ki her hareket bu
  /// widget'ın (169 hücre + territory hesabı) tamamını yeniden inşa
  /// ETMESİN (8 Ağustos 2026 performans düzeltmesi — bkz. mobile/CLAUDE.md
  /// Parça 23, `DashedBorderPainter`'ı ekran katmanı da kullanıyor).
  final String? dragHiddenKey;

  /// Verildiğinde, YERLEŞTİRİLMİŞ taş taşıyan hücreler GestureDetector
  /// yerine Listener olur — dokunuş/sürükleme ayrımını ekran katmanının
  /// pointer akışı yapar (web Tile onPointerDown zinciri). Boş/tahta
  /// hücreleri onCellTap'ta kalır.
  final void Function(int r, int c, PointerDownEvent e)? onTilePointerDown;
  final void Function(PointerMoveEvent e)? onTilePointerMove;
  final void Function(PointerUpEvent e)? onTilePointerUp;
  final VoidCallback? onTilePointerCancel;

  /// Izgara alanının (Stack) geometrisine dışarıdan erişim — ekran katmanı
  /// global noktayı hücreye çevirirken kullanır (web elementFromPoint'in
  /// geometri tabanlı eşleniği).
  final GlobalKey? gridKey;

  /// Alt bilgi şeridindeki "Hamleler" linki — verilmezse link çizilmez
  /// (web'de zorunlu prop; burada ileride salt-okunur önizleme için
  /// opsiyonel).
  final VoidCallback? onOpenHistory;

  /// "Mesajlaşma" butonu — yalnızca Canlı oyun ekranı geçirir (web
  /// `onOpenMessaging`); verilmezse (yerel/YZ oyun) buton hiç render
  /// edilmez, Oyun İçi Mesajlaşma yerelde kapsam dışı.
  final VoidCallback? onOpenMessaging;

  /// `onOpenMessaging` butonunun sağ üstünde okunmamış mesaj SAYISI
  /// (`CountBadge`). 16 Ağustos 2026'ya kadar sayısız bir kırmızı noktaydı;
  /// kullanıcı fark edilmediğini bildirince iki platformda birden projenin
  /// öteki rozetleriyle aynı görsele çekildi.
  final int unreadMessageCount;

  /// Alt şeridin SAĞ ucundaki "Nasıl Oynanır?" linki (14 Ağustos 2026,
  /// kullanıcı isteği) — buraya kadar X2/X3 açıklaması duruyordu. Bonus
  /// renkleri tahtada zaten büyük filigranlarla yazılı olduğundan legend'ın
  /// taşıdığı bilgi kaybolmuyor; kurallara her yerden erişim kazanılıyor.
  /// Verilmezse (salt-okunur önizlemeler) link hiç çizilmez.
  final VoidCallback? onOpenHelp;

  /// Alt bilgi şeridini tamamen gizler — salt-okunur önizlemeler (web
  /// hideFooter).
  final bool hideFooter;

  /// Bağlantı durumu — çevrimdışıyken şeridin sağında kırmızı bir
  /// "Çevrimdışı" uyarısı çıkar. Web'de `Board.tsx` bunu `useOnlineStatus()`
  /// ile KENDİ İÇİNDE okuyor; Flutter'da hook olmadığından enjekte ediliyor
  /// (verilmezse — önizlemeler, testlerin çoğu — uyarı hiç çizilmez).
  final OnlineStatus? onlineStatus;

  const BoardWidget({
    super.key,
    required this.state,
    this.onCellTap,
    this.moveOverlay,
    this.compact = false,
    this.dragHiddenKey,
    this.onTilePointerDown,
    this.onTilePointerMove,
    this.onTilePointerUp,
    this.onTilePointerCancel,
    this.gridKey,
    this.onOpenHistory,
    this.onOpenMessaging,
    this.unreadMessageCount = 0,
    this.onOpenHelp,
    this.hideFooter = false,
    this.onlineStatus,
  });

  PlayerColor _colorOfIndex(int playerIndex) =>
      playerColors[state.players[playerIndex].colorIndex % playerColors.length];

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) debugBoardBuildCountForTests++;
    final players = state.players;

    // Bölgeler: köşe + kendi taşlarıyla genişleyen alan (core'dan).
    final territories = computeAllTerritories(state.board, players);
    final territoryOwner = <String, int>{};
    for (var i = 0; i < territories.length; i++) {
      for (final k in territories[i]) {
        territoryOwner[k] = i;
      }
    }

    final homeCellColor = <String, PlayerColor>{};
    final cornerColor = List<PlayerColor?>.filled(4, null);
    final cornerNumber = List<int?>.filled(4, null);
    for (var i = 0; i < players.length; i++) {
      for (final corner in players[i].corners) {
        cornerColor[corner] = _colorOfIndex(i);
        cornerNumber[corner] = i + 1;
        final cc = cornerCell(corner);
        homeCellColor[cellKey(cc.$1, cc.$2)] = _colorOfIndex(i);
      }
    }

    final lastMoveSet = {
      for (final c in state.lastMoveCells) cellKey(c.$1, c.$2)
    };
    final currentColor =
        players.isEmpty ? playerColors.first : _colorOfIndex(state.current);

    final outlines = <(Path, Color)>[
      for (var i = 0; i < players.length; i++)
        if (territories[i].isNotEmpty)
          (
            buildRoundedOutlinePath(
              [for (final k in territories[i]) parseKey(k)],
              _outlineRadius,
            ),
            _colorOfIndex(i).base,
          ),
      if (moveOverlay != null && moveOverlay!.cells.isNotEmpty)
        (
          buildRoundedOutlinePath(moveOverlay!.cells, _outlineRadius),
          moveOverlay!.valid ? kMoveValid : kMoveInvalid,
        ),
    ];

    // Web: kart (zemin + gölge) ızgarayı VE alt bilgi şeridini birlikte
    // sarar — şerit ayrı/asılı bir beyaz bant değil, kartın alt bölümü.
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: _boardBg,
        radius: 18,
        // Web Board.tsx'in gölge üçlüsü — CSS değerleriyle: koyu sağ-alt,
        // beyaz sol-üst parlama, altta geniş yumuşak gölge. Flutter'ın
        // BoxShadow'u CSS'ten hem daha koyu/kısa boyuyor hem katman sırası
        // ters; bu decoration gölgeleri CSS matematiğiyle (sigma=blur/2,
        // ilk yazılan en üstte) kendisi çizer — kullanıcı web/app
        // karşılaştırması, 6 Ağustos 2026.
        shadows: [
          CssShadow(color: Color(0xB3A3B1C6), offset: Offset(8, 8), blur: 20),
          CssShadow(color: Color(0xE6FFFFFF), offset: Offset(-4, -4), blur: 14),
          CssShadow(color: Color(0x80A3B1C6), offset: Offset(0, 20), blur: 60),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Stack(
                key: gridKey,
                children: [
                  GridView.count(
                    crossAxisCount: boardSize,
                    mainAxisSpacing: 3,
                    crossAxisSpacing: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var r = 0; r < boardSize; r++)
                        for (var c = 0; c < boardSize; c++)
                          _buildCell(r, c, territoryOwner, homeCellColor,
                              lastMoveSet, currentColor),
                    ],
                  ),
                  // Bölge/hamle dış hatları — ızgara alanının tamamını kaplayan
                  // tek katman (web'deki tek SVG'nin eşleniği), dokunuşları
                  // engellemez.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _OutlinesPainter(outlines)),
                    ),
                  ),
                  if (!compact)
                    Positioned.fill(
                        child: IgnorePointer(
                            child: _watermarks(cornerColor, cornerNumber))),
                  if (moveOverlay != null && moveOverlay!.cells.isNotEmpty)
                    Positioned.fill(child: IgnorePointer(child: _moveBadge())),
                ],
              ),
            ),
          ),
          if (!hideFooter) _footer(),
        ],
      ),
    );
  }

  /// Alt bilgi şeridi — solda "Hamleler" (+ Canlı oyunda "· Mesajlaşma"),
  /// sağda "Çevrimdışı" uyarısı (yalnızca bağlantı yokken) ve
  /// "Nasıl Oynanır?".
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpenHistory != null)
                GestureDetector(
                  onTap: onOpenHistory,
                  behavior: HitTestBehavior.opaque,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DocumentIcon(),
                      SizedBox(width: 4),
                      Text(
                        'Hamleler',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: kAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              if (onOpenMessaging != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·',
                      style: TextStyle(fontSize: 12, color: kMuted)),
                ),
                GestureDetector(
                  onTap: onOpenMessaging,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChatBubbleIcon(),
                          SizedBox(width: 4),
                          Text(
                            'Mesajlaşma',
                            style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                      // Konum web'de ölçülerek seçildi (`-top-1 -right-1`):
                      // rozet satır içi olsaydı şeride ~20px eklerdi ve dar
                      // telefonlarda "Nasıl Oynanır?" ile çakışırdı. Beyaz
                      // halka web'in `ring-2 ring-panel`i — rozet altındaki
                      // mavi etiketten ayrışsın diye.
                      if (unreadMessageCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            key: const ValueKey('chat-unread-badge'),
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CountBadge(count: unreadMessageCount),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Sağ grup — web `flex items-center gap-2 justify-end` (8px).
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onlineStatus != null)
                ListenableBuilder(
                  listenable: onlineStatus!,
                  builder: (context, _) => onlineStatus!.online
                      ? const SizedBox.shrink()
                      : const Padding(
                          padding: EdgeInsets.only(right: 8),
                          // Punto/aralık, şeritteki KARDEŞ kontrollerle
                          // (Hamleler · Mesajlaşma · Nasıl Oynanır?) birebir
                          // aynı — yalnızca rengi farklı. Web'de bu bir kez
                          // 8px'e düşmüş ve kullanıcı cihazda "belli
                          // olmuyor" diye bildirmişti (14 Ağustos 2026): tam
                          // da çevrimdışıyken okunması gereken tek gösterge,
                          // şeridin en küçük yazısı olmamalı. Bir kardeşin
                          // puntosu değişirse bu da değişmeli.
                          child: Text(
                            'Çevrimdışı',
                            style: TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: kRed,
                            ),
                          ),
                        ),
                ),
              if (onOpenHelp != null)
                GestureDetector(
                  onTap: onOpenHelp,
                  behavior: HitTestBehavior.opaque,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HelpIcon(),
                      SizedBox(width: 4),
                      Text(
                        'Nasıl Oynanır?',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: kAccent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCell(
    int r,
    int c,
    Map<String, int> territoryOwner,
    Map<String, PlayerColor> homeCellColor,
    Set<String> lastMoveSet,
    PlayerColor currentColor,
  ) {
    final k = cellKey(r, c);
    final boardTile = state.board[r][c];
    // Sürüklenen taşın kaynağı boş çizilir (web: k === dragHiddenKey).
    final placedTile = k == dragHiddenKey ? null : state.placed[k];
    final isCenter = state.bonuses[k] == BonusType.tw;
    final inZone = inBonusZone(r, c);
    final zoneOwner = territoryOwner[k];
    final homeColor = homeCellColor[k];

    Widget? content;
    Widget Function(Widget? child)? cellBox;

    if (boardTile != null) {
      final tileColor = boardTile.owner != null
          ? _colorOfIndex(boardTile.owner!)
          : currentColor;
      final isLastMove = lastMoveSet.contains(k);
      content = TileWidget(
        tile: boardTile,
        variant: TileVariant.board,
        compact: compact,
        color: isLastMove
            ? PlayerColor(
                base: darken(tileColor.base, 0.12),
                tint: darken(tileColor.tint, 0.14),
                zone: tileColor.zone,
                text: tileColor.text,
              )
            : tileColor,
      );
    } else if (placedTile != null) {
      content = TileWidget(
        tile: placedTile,
        variant: TileVariant.placed,
        color: placedTile.owner != null
            ? _colorOfIndex(placedTile.owner!)
            : currentColor,
      );
    } else if (inZone) {
      // Web GOLD_ZONE_STYLE/CENTER_ZONE_STYLE — iç gölgeler + hafif dış gölge.
      final radius = BorderRadius.circular(5);
      cellBox = (child) => NeoBox(
            borderRadius: radius,
            gradient: isCenter ? _centerZone : _goldZone,
            insetShadows: isCenter
                ? const [
                    InsetShadow(
                        color: Color(0x59B4500A),
                        offset: Offset(2, 2),
                        blur: 5),
                    InsetShadow(
                        color: Color(0xB3FFFFFF),
                        offset: Offset(-1, -1),
                        blur: 3),
                  ]
                : const [
                    InsetShadow(
                        color: Color(0x4DB4820A),
                        offset: Offset(2, 2),
                        blur: 5),
                    InsetShadow(
                        color: Color(0xB3FFFFFF),
                        offset: Offset(-1, -1),
                        blur: 3),
                  ],
            outerShadows: isCenter
                ? const [
                    BoxShadow(
                        color: Color(0x40B4500A),
                        offset: Offset(0, 2),
                        blurRadius: 4),
                  ]
                : const [
                    BoxShadow(
                        color: Color(0x33B4820A),
                        offset: Offset(0, 2),
                        blurRadius: 4),
                  ],
            child: child,
          );
      if (isCenter && !compact) {
        content = const Center(
          child: FittedBox(
            child: Text(
              'X3',
              style: TextStyle(
                color: _centerText,
                fontFamily: 'SpaceMono',
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        );
      }
    } else if (zoneOwner != null) {
      // Web: bölge hücresi — oyuncu tonu + içe gömülü gölge (base%13 + beyaz).
      final zone = _colorOfIndex(zoneOwner);
      cellBox = (child) => NeoBox(
            borderRadius: BorderRadius.circular(5),
            color: zone.tint,
            insetShadows: [
              InsetShadow(
                  color: zone.base.withValues(alpha: 0.133),
                  offset: const Offset(2, 2),
                  blur: 5),
              const InsetShadow(
                  color: Color(0x99FFFFFF), offset: Offset(-1, -1), blur: 3),
            ],
            child: child,
          );
    } else {
      // Web: tarafsız boş kare — tahta zemin rengi + nömorfik içe gömülü.
      cellBox = (child) => NeoBox(
            borderRadius: BorderRadius.circular(5),
            color: _boardBg,
            insetShadows: const [
              InsetShadow(
                  color: Color(0x99A3B1C6), offset: Offset(3, 3), blur: 6),
              InsetShadow(
                  color: Color(0xCCFFFFFF), offset: Offset(-2, -2), blur: 5),
            ],
            child: child,
          );
    }

    if (homeColor != null && boardTile == null && placedTile == null) {
      content = Center(
        child: FractionallySizedBox(
          widthFactor: 0.55,
          heightFactor: 0.55,
          child: CustomPaint(painter: _HomeMarkPainter(homeColor.base)),
        ),
      );
    }

    Widget body =
        cellBox != null ? cellBox(content) : SizedBox.expand(child: content);

    // Bırakma hedefi vurgusu (kesikli yeşil/kırmızı çerçeve) artık BURADA
    // çizilmiyor — ekran katmanının hover overlay'i (`_hoverHighlight`,
    // `DashedBorderPainter`'ı yeniden kullanıyor) hücrenin üstüne ayrı bir
    // Positioned katman olarak çiziyor (bkz. yukarıdaki dragHiddenKey notu).

    // Yerleştirilmiş taş + drag handler'ları: Listener (dokunuş da
    // sürükleme de ekran katmanında ayrışır); diğer hücreler GestureDetector.
    if (placedTile != null && onTilePointerDown != null) {
      return Listener(
        key: ValueKey('cell-$r-$c'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) => onTilePointerDown!(r, c, e),
        onPointerMove: onTilePointerMove,
        onPointerUp: onTilePointerUp,
        onPointerCancel:
            onTilePointerCancel == null ? null : (_) => onTilePointerCancel!(),
        child: body,
      );
    }
    return GestureDetector(
      key: ValueKey('cell-$r-$c'),
      behavior: HitTestBehavior.opaque,
      onTap: onCellTap == null ? null : () => onCellTap!(r, c),
      child: body,
    );
  }

  /// Köşe numarası + X2 filigranları (web'deki soluk arka yazılar).
  Widget _watermarks(List<PlayerColor?> cornerColor, List<int?> cornerNumber) {
    const cornerFrac = cornerSize / boardSize;
    const zoneFrac = (boardSize - 2 * cornerSize) / boardSize;
    return Stack(
      children: [
        for (var i = 0; i < 4; i++)
          if (cornerColor[i] != null && cornerNumber[i] != null)
            Align(
              alignment: Alignment(
                (i == 0 || i == 2) ? -1 : 1,
                (i == 0 || i == 1) ? -1 : 1,
              ),
              child: FractionallySizedBox(
                widthFactor: cornerFrac,
                heightFactor: cornerFrac,
                child: Opacity(
                  opacity: 0.20,
                  child: FittedBox(
                    child: Text(
                      '${cornerNumber[i]}',
                      style: TextStyle(
                        color: cornerColor[i]!.base,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        Center(
          child: FractionallySizedBox(
            widthFactor: zoneFrac,
            heightFactor: zoneFrac,
            child: Opacity(
              opacity: 0.28,
              child: FittedBox(
                child: const Text(
                  'X2',
                  style: TextStyle(
                    color: Color(0xFF92660A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Hamle çerçevesinin puan rozeti — kümenin en üst-sol hücresinde
  /// (taşın kendi puan üst simgesiyle çakışmasın diye, web ile aynı kural).
  Widget _moveBadge() {
    final overlay = moveOverlay!;
    Cell? badge;
    for (final cell in overlay.cells) {
      if (badge == null ||
          cell.$1 < badge.$1 ||
          (cell.$1 == badge.$1 && cell.$2 < badge.$2)) {
        badge = cell;
      }
    }
    final color = overlay.valid ? kMoveValid : kMoveInvalid;
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = badge!.$2 / boardSize * constraints.maxWidth;
        final top = badge.$1 / boardSize * constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              child: FractionalTranslation(
                translation: const Offset(-0.35, -0.35),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Text(
                    '+${overlay.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bırakma hedefinin 2px kesikli çerçevesi (web `outline: 2px dashed`) —
/// PUBLIC: ekran katmanlarının (`game_screen.dart`/`online_game_screen.dart`)
/// hover overlay'i de bunu kullanıyor (bkz. yukarıdaki dragHiddenKey notu).
class DashedBorderPainter extends CustomPainter {
  final Color color;
  DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final rrect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(1), const Radius.circular(5));
    final path = Path()..addRRect(rrect);
    const dash = 4.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

class _OutlinesPainter extends CustomPainter {
  /// Izgara birimi (0..13) cinsinden path + renk çiftleri.
  final List<(Path, Color)> outlines;
  _OutlinesPainter(this.outlines);

  @override
  void paint(Canvas canvas, Size size) {
    final m = Matrix4.diagonal3Values(
        size.width / boardSize, size.height / boardSize, 1);
    for (final (path, color) in outlines) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color;
      canvas.drawPath(path.transform(m.storage), paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinesPainter oldDelegate) => true;
}

/// Başlangıç hücresindeki ev işareti — web'deki HomeMark SVG path'inin portu
/// (M12 2.5 L1.5 11 H4.5 V21 H10.5 V15 H13.5 V21 H19.5 V11 H22.5 Z).
class _HomeMarkPainter extends CustomPainter {
  final Color color;
  _HomeMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 24;
    final path = Path()
      ..moveTo(12 * sx, 2.5 * sy)
      ..lineTo(1.5 * sx, 11 * sy)
      ..lineTo(4.5 * sx, 11 * sy)
      ..lineTo(4.5 * sx, 21 * sy)
      ..lineTo(10.5 * sx, 21 * sy)
      ..lineTo(10.5 * sx, 15 * sy)
      ..lineTo(13.5 * sx, 15 * sy)
      ..lineTo(13.5 * sx, 21 * sy)
      ..lineTo(19.5 * sx, 21 * sy)
      ..lineTo(19.5 * sx, 11 * sy)
      ..lineTo(22.5 * sx, 11 * sy)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_HomeMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// "Hamleler" linkinin başındaki küçük döküman ikonu — web'deki aynı SVG
/// path'lerinin (dosya + kıvrık köşe + iki satır) portu.
///
/// PUBLIC, çünkü ikinci bir tüketicisi var: "Tüm Oyunlarım"daki her kartın
/// hamle dökümü rozeti (`game_history_modal.dart`). Path verisi
/// KOPYALANMAMALI — aynı şeyi açan iki kontrol aynı görünmeli (bkz.
/// `RelationIcons` ilkesi, kök CLAUDE.md).
class DocumentIcon extends StatelessWidget {
  final double size;
  final Color color;

  const DocumentIcon({super.key, this.size = 12, this.color = kAccent});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _DocumentIconPainter(color)),
      );
}

class _DocumentIconPainter extends CustomPainter {
  final Color color;
  const _DocumentIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    // M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z
    final body = Path()
      ..moveTo(14 * s, 2 * s)
      ..lineTo(6 * s, 2 * s)
      ..arcToPoint(Offset(4 * s, 4 * s), radius: Radius.circular(2 * s))
      ..lineTo(4 * s, 20 * s)
      ..arcToPoint(Offset(6 * s, 22 * s), radius: Radius.circular(2 * s))
      ..lineTo(18 * s, 22 * s)
      ..arcToPoint(Offset(20 * s, 20 * s), radius: Radius.circular(2 * s))
      ..lineTo(20 * s, 8 * s)
      ..close();
    canvas.drawPath(body, paint);
    // M14 2v6h6
    canvas.drawPath(
        Path()
          ..moveTo(14 * s, 2 * s)
          ..lineTo(14 * s, 8 * s)
          ..lineTo(20 * s, 8 * s),
        paint);
    // M9 13h6M9 17h6
    canvas.drawLine(Offset(9 * s, 13 * s), Offset(15 * s, 13 * s), paint);
    canvas.drawLine(Offset(9 * s, 17 * s), Offset(15 * s, 17 * s), paint);
  }

  @override
  bool shouldRepaint(_DocumentIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Web `ChatBubbleIcon` — "Mesajlaşma" butonunun konuşma balonu SVG'si
/// (`M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z`).
class _ChatBubbleIcon extends StatelessWidget {
  const _ChatBubbleIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 12,
        height: 12,
        child: CustomPaint(painter: _ChatBubbleIconPainter()),
      );
}

class _ChatBubbleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = kAccent;
    final path = Path()
      ..moveTo(21 * s, 15 * s)
      ..arcToPoint(Offset(19 * s, 17 * s), radius: Radius.circular(2 * s))
      ..lineTo(7 * s, 17 * s)
      ..lineTo(3 * s, 21 * s)
      ..lineTo(3 * s, 5 * s)
      ..arcToPoint(Offset(5 * s, 3 * s), radius: Radius.circular(2 * s))
      ..lineTo(19 * s, 3 * s)
      ..arcToPoint(Offset(21 * s, 5 * s), radius: Radius.circular(2 * s))
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChatBubbleIconPainter oldDelegate) => false;
}

/// "Nasıl Oynanır?" linkinin başındaki soru işareti ikonu — web `HelpIcon`
/// SVG'sinin (daire + soru işareti kancası + nokta) portu. Path verisi
/// KOPYALANMAMALI; aynı şeyi açan iki kontrol aynı görünmeli.
class _HelpIcon extends StatelessWidget {
  const _HelpIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 12,
        height: 12,
        child: CustomPaint(painter: _HelpIconPainter(kAccent)),
      );
}

class _HelpIconPainter extends CustomPainter {
  final Color color;
  const _HelpIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    // <circle cx="12" cy="12" r="10" />
    canvas.drawCircle(Offset(12 * s, 12 * s), 10 * s, paint);
    // M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3
    final hook = Path()
      ..moveTo(9.09 * s, 9 * s)
      ..arcToPoint(Offset(14.92 * s, 10 * s),
          radius: Radius.circular(3 * s), clockwise: true)
      ..cubicTo(14.92 * s, 12 * s, 11.92 * s, 13 * s, 11.92 * s, 13 * s);
    canvas.drawPath(hook, paint);
    // M12 17h.01 — yuvarlak uçlu sıfır uzunlukta çizgi = nokta.
    canvas.drawLine(Offset(12 * s, 17 * s), Offset(12.01 * s, 17 * s), paint);
  }

  @override
  bool shouldRepaint(_HelpIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
