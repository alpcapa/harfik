// 13×13 oyun tahtası — src/components/Board.tsx'in render katmanı portu.
// Sürükle-bırak destekli: yerleştirilmiş (bu tur konmuş) taşlar, drag
// handler'ları verildiğinde GestureDetector yerine Listener taşır — dokunuş
// da sürükleme de ekran katmanının (GameScreen) pointer akışından geçer
// (web'de Tile'ın onPointerDown/Move/Up prop'larının eşleniği). Alt bilgi
// şeridi (solda "Hamleler" [+ Canlı oyunda "· Mesajlaşma"], sağda
// "Çevrimdışı" uyarısı ve "Yardım") kartın alt bölümü olarak
// portlandı; "Mesajlaşma" butonu yalnızca Canlı oyunda çıkar (web'de de
// prop verilmezse hiç render edilmiyor).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'board_zoom.dart';

import 'count_badge.dart';
import 'fluid.dart';
import 'neo_box.dart';
import 'outline.dart';
import 'player_colors.dart';
import 'tile_widget.dart';
import '../ai_level_badge.dart';
import '../tap_target.dart';
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

/// ⚠ Burada 1 Eylül 2026'dan 2 Eylül 2026'ya kadar bir `_zoomClipSlack`
/// (≈3.5 px) ve onu uygulayan `_ZoomClipSlackClipper` vardı. KALDIRILDI,
/// çünkü var olma sebebi ortadan kalktı: pay, "dış hat ızgara kutusunun
/// kenarında stroke'un yarısı kadar dışarı taşıyor ve tam kutudan kırpınca
/// inceliyor" diye konmuştu — o gün 10 px'lik dolgu kırpmanın DIŞINDAYDI.
/// Artık dolgu ölçeklenen içeriğin İÇİNDE (aşağıdaki `_zoomWrap` notu),
/// yani dış hattın taşması kırpma sınırından ≥10 px (zoom'da ≥20 px)
/// içeride kalıyor ve pay hiçbir şey korumuyor. Web ikizi de tam bu
/// gerekçeyle pay taşımıyor (`Board.tsx` → "Pay neden 0").

/// Tahtanın iç dolgusu ve kartın köşe yarıçapı — İKİSİ de birden fazla
/// yerde kullanılıyor (dolgu `_zoomWrap`te, yarıçap kartın dekorasyonunda
/// ve kırpıcılarda). Sabit olarak duruyorlar ki ayrışmasınlar.
///
/// [kBoardPad] PUBLIC: iki oyun ekranı da zoom odak noktasını ızgara
/// uzayından tahta uzayına çevirirken bunu ekliyor (ızgara, ölçeklenen
/// kutunun içinde bu kadar sağa/aşağı duruyor). Web'de böyle bir çeviri
/// yok çünkü orada `elementFromPoint` ve `getBoundingClientRect` aynı
/// elemanı okuyor; portta odak `grid.globalToLocal` ile alınıyor (ters
/// transform'u Flutter'ın kendisi yapsın diye) ve o eleman dolgunun
/// İÇİNDEKİ ızgara.
const double kBoardPad = 10;
const double _cardRadius = 18;

/// Tahta kartının kutusu, ÜST iki köşesi yuvarlanmış — zoom'da hem ızgarayı
/// hem rozet katmanını kırpar. Web ikizi: `inset(0 round 18px 18px 0 0)`.
/// Alt köşeler bilerek KARE: kartın altında alt bilgi şeridi var, onları
/// yuvarlamak tahtanın alt köşelerini keserdi.
class _CardClipper extends CustomClipper<Path> {
  const _CardClipper();
  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: const Radius.circular(_cardRadius),
      topRight: const Radius.circular(_cardRadius),
    ));
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Hamle rozeti KATMANININ kırpması — web ikizinin BİREBİR karşılığı
/// (`Board.tsx` → `clipPath: inset(0 round 18px 18px 0 0)`).
///
/// 2 Eylül 2026, kullanıcı cihazda: *"Web'deki aynı taşma mobilde de var.
/// Onu da web ile birebir hâle getir."* Rozet katmanı zoom matrisini
/// izliyor ama hiç kırpılmıyordu, yani hücresi görünür kareden çıkınca
/// kartın üstüne — başlığın içine — çiziliyordu. ÖLÇÜLDÜ (piksel):
/// tahtanın dışına 268 piksel.
///
/// ⚠ "Stack zaten kırpıyor" SANILMIŞTI ve yanlıştı: `Transform` boyama
/// zamanı çalıştığından Stack layout'ta taşma görmüyor ve kırpmıyor.
/// Yapısal iddia yetmez; kapı `board_badge_clip_test.dart` PİKSEL ölçüyor.
///
/// Katmanın kutusu ızgaranın DOLGULU alanı, kırpma ise TAHTANIN kutusu
/// olmalı — bu yüzden dolgu kadar genişletiliyor. Pay YOK: rozet kartın
/// içinde kalır, kenarda gerekirse kesilir (kullanıcı kararı, web ile aynı).
///
/// ⚠ 2 Eylül 2026'dan beri YALNIZCA zoom'suz dalda (salt-okunur önizlemeler,
/// `zoom` verilmemiş testler). Zoom'lu dalda katmanın kutusu artık tahtanın
/// KENDİSİ olduğundan orada genişletmesiz `_CardClipper` kullanılıyor —
/// ikisini birleştirmek, biri genişletmeli biri değil oldukları için
/// rozeti bir dalda 10 px yanlış kırpardı.
class _BadgeCardClipper extends CustomClipper<Path> {
  const _BadgeCardClipper();
  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndCorners(
      Rect.fromLTRB(-kBoardPad, -kBoardPad, size.width + kBoardPad,
          size.height + kBoardPad),
      topLeft: const Radius.circular(_cardRadius),
      topRight: const Radius.circular(_cardRadius),
    ));
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

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

  /// Dokunuşun GLOBAL noktası da veriliyor — ekran katmanı taslak
  /// sürerken ıskalanan dokunuşu en yakın taslak taşına yönlendirirken
  /// kullanıyor (bkz. `game_screen.dart` → `_nearbyDraftCell`).
  final void Function(int r, int c, Offset globalPosition)? onCellTap;
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

  /// Sürükleme sürüyor mu — değeri `null` DEĞİLSE bir taş havadadır.
  ///
  /// Neden `bool` bir prop DEĞİL: Parça 23 sürükleme boyunca bu widget'ın
  /// (169 hücre + bölge hesabı) yeniden inşa edilmesini bilerek durduruyor.
  /// Bir bool prop, sürüklemenin başında/sonunda ekranın `setState`'ini
  /// gerektirirdi. Dinlenebilir olarak geçirilince yalnızca "Buradan başla"
  /// katmanı dinliyor, tahta hiç yeniden inşa edilmiyor.
  ///
  /// Tipi `Object?`: ekran katmanının `_Ghost`u private, ve Dart'ın jenerikleri
  /// kovaryant olduğundan `ValueNotifier<_Ghost?>` buraya doğrudan geçiyor.
  final ValueListenable<Object?>? dragListenable;

  /// Izgara alanının (Stack) geometrisine dışarıdan erişim — ekran katmanı
  /// global noktayı hücreye çevirirken kullanır (web elementFromPoint'in
  /// geometri tabanlı eşleniği).
  ///
  /// ⚠ ZOOM AÇIKKEN bu kutunun `globalToLocal`ı transformu da tersine
  /// çevirir (SANAL ızgara uzayı) — ekranlardaki stride matematiğinin
  /// zoom'da değişmeden doğru kalmasının sebebi tam olarak bu.
  final GlobalKey? gridKey;

  /// Zoom tanıtım balonu (1 Eylül 2026, kullanıcı isteği) — MERKEZ kareyi
  /// işaret eden tek seferlik ipucu. Ne zaman çizileceğine ekranlar karar
  /// verir (`FlagsStore.shouldShowZoomHint`); burada yalnızca çizim var.
  final bool zoomHint;

  /// Tahta yakınlaştırması (1.0.5). Verilmezse davranış eski hâliyle
  /// birebir aynı — hiçbir sarmalayıcı kurulmaz.
  final BoardZoomController? zoom;

  /// Izgaranın GÖRÜNÜR karesi (ClipRect) — zoom'luyken sanal ızgara bu
  /// karenin dışına taştığından, ekran katmanı bırakma noktalarını hücreye
  /// çevirmeden ÖNCE bu kutuyla kapılıyor (rafın üstüne bırakılan taşın
  /// ters transform yüzünden "görünmez bir hücreye" inmesini önler —
  /// board_zoom_test bunu kilitliyor).
  final GlobalKey? viewportKey;

  /// Tahta alanının HAM pointer akışı (pan + çift dokunuş altyapısı).
  /// Translucent Listener: çocuk taş Listener'ları hit-test sırasında ÖNCE
  /// çalışır, yani ekran katmanı `_dragRef`e bakarak taş sürüklemesiyle
  /// pan'i ayırt edebilir.
  final void Function(PointerDownEvent e)? onBoardPointerDown;
  final void Function(PointerMoveEvent e)? onBoardPointerMove;
  final void Function(PointerUpEvent e)? onBoardPointerUp;
  final VoidCallback? onBoardPointerCancel;

  /// Alt şeritte "Hamleler"in yanındaki zorluk rozeti (6 Eylül 2026, kullanıcı
  /// isteği: rozet "Mesajlaşma"nın olduğu yerde de dursun). Yalnızca YZ
  /// ekranı geçirir (her seviyede); Canlı ekran geçirmez → rozet yok.
  /// Dokunulamaz — `TapTarget` DEĞİL, şeridin "üç TapTarget" sayımına
  /// (`layout_parity_test`) girmez; 48 px satırda kendiliğinden ortalanır.
  final AiLevel? aiLevel;

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

  /// Alt şeridin SAĞ ucundaki "Yardım" linki (14 Ağustos 2026,
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

  /// Zoom sarmalayıcısı (1.0.5): ızgara Stack'i ClipPath + Transform +
  /// translucent Listener ile sarılır.
  ///
  /// ⚠ KATMAN SIRASI WEB'İN BİREBİR AYNISI OLMAK ZORUNDA (2 Eylül 2026,
  /// kullanıcı APK'da bildirdi: *"zoomdayken kenarlarda çerçeve duruyor.
  /// Web'deki gibi yuvarlak kenarlı alanın tamamına kadar gitmeli."*).
  /// Doğru sıra — dıştan içe: `Listener → ClipPath(kart) → Transform →
  /// Padding(10) → ızgara`. Yani **dolgu ölçeklenen içeriğin İÇİNDE**,
  /// kırpma ise kartın TAMAMI.
  ///
  /// Öncesinde dolgu en DIŞTAydı (`Listener → Padding → ClipRect →
  /// Transform → ızgara`) ve sonuç ölçüldü: kart 390×390 iken kırpan kutu
  /// 10..380, yani dört kenarda ölçeklenmeyen 10 px'lik kalıcı bir çerçeve.
  /// Web'de o kutu (`data-board-viewport`) `absolute inset-0`, yani kartın
  /// tamamı; dolgu `data-board-grid`in İÇİNDE (`p-[10px]`) ve transform
  /// onun üzerinde. Bu yüzden web'de çerçeve zoom'la birlikte ölçeklenip
  /// kaydırmayla ekrandan çıkıyor, portta ise sabit duruyordu.
  ///
  /// ⚠ Bunun matematiksel yan etkisi VAR ve ekranlar buna göre çağırıyor:
  /// ölçeklenen kutu artık ızgara (kart−20) değil KARTIN kendisi, yani
  /// `toggleAt`/`panBy`e verilen boyut görünür kare olmalı (web `boxOf`
  /// ile aynı) ve odak noktası ızgara uzayından tahta uzayına `kBoardPad`
  /// eklenerek çevrilmeli. Boyut ızgaradan verilseydi izinli öteleme 20 px
  /// kısa kalırdı — 1 Eylül'de web'de tam bu sınıftan bir hata yaşandı
  /// (`useBoardZoom.ts`'teki "`/ BOARD_ZOOM_SCALE` YOK ve OLMAMALI" notu). `zoom` verilmemişse ESKİ DAVRANIŞ
  /// BİREBİR — hiçbir sarmalayıcı kurulmaz (salt-okunur önizlemeler,
  /// mevcut testler).
  ///
  /// Perf: `AnimatedBuilder.child` ızgarayı BİR kez inşa eder; pan/zoom her
  /// karede yalnızca Transform'u yeniler — 169 hücre pan sırasında yeniden
  /// inşa edilmez (Parça 23 / `_dragNotifier` kuralının aynısı). Pahalı
  /// blur'lar NeoBox'ın raster önbelleğinde olduğundan kaydırma karesi ucuz;
  /// bilinçli olarak RepaintBoundary KONMUYOR — konsaydı harfler 2×'te
  /// bitmap gibi bulanıklaşırdı (metin, transform altında vektörel kalmalı).
  /// [unclipped]: ızgarayla AYNI matrisi alan ama KIRPILMAYAN katman —
  /// bugün yalnızca hamle puanı rozeti. Rozet, konumlandığı hücrenin sol
  /// üstüne `FractionalTranslation(-0.35,-0.35)` ile taşar, yani ızgara
  /// kutusunun DIŞINA çıkıp 10 px'lik dolguya çizilir (eski davranış).
  /// Kırpılan katmanda bıraksaydık kenardaki rozetin bir kenarı kesilirdi —
  /// 1 Eylül 2026'da APK'da tam bu oldu, kullanıcı bildirdi: *"kenarda
  /// kalan deneme sayıları kesiliyor"*. Kırpma payını rozeti kapsayacak
  /// kadar (zoom'da ~22 px) büyütmek YANLIŞ çözüm olurdu: aynı pay kadar
  /// zoom'lu ızgara da taşar ve kartın gövdesine sızardı.
  Widget _zoomWrap(Widget grid, {Widget? unclipped}) {
    final z = zoom;
    const pad = EdgeInsets.all(kBoardPad);
    // Kırpılan gövde + kırpılmayan rozet TEK matrisi paylaşır (iki ayrı
    // tween ikisini animasyon boyunca ayrıştırırdı).
    Widget katmanla(Widget govde, Matrix4? m, {required bool zoomlu}) {
      final u = unclipped;
      if (u == null) return govde;
      return Stack(
        fit: StackFit.expand,
        children: [
          govde,
          IgnorePointer(
            // Kırpma HER İKİ hâlde de var (web ile aynı): duruma bağlamak
            // kapatma animasyonu boyunca rozeti kartın dışından süzülerek
            // geçirirdi. Dinlenmede zaten kesmiyor — rozetin 1×'teki
            // taşması tahtanın 10 px dolgusundan küçük.
            //
            // ⚠ Rozet katmanı ızgarayla AYNI kutuyu ve AYNI dolguyu almak
            // ZORUNDA: rozet hücre indeksinden yüzdeyle konumlanıyor
            // (`_moveBadge` → LayoutBuilder), yani kutusu ızgaranınkinden
            // 10 px kayarsa rozet de kayar.
            child: zoomlu
                ? ClipPath(
                    clipper: const _CardClipper(),
                    child: Transform(
                        transform: m!,
                        child: Padding(padding: pad, child: u)),
                  )
                : ClipPath(
                    clipper: const _BadgeCardClipper(),
                    child: m == null ? u : Transform(transform: m, child: u),
                  ),
          ),
        ],
      );
    }

    // 10 px'lik iç dolgu ARTIK bu sarmalayıcının içinde: dokunma yüzeyi
    // (aşağıdaki Listener) çerçeveyi de kapsasın diye (1 Eylül 2026,
    // kullanıcı APK'da bildirdi: "zoom sadece karelerde çalışıyor,
    // kenarlar da dahil olmalı"). zoom verilmemişken ağaç ESKİSİYLE aynı.
    if (z == null) {
      return Padding(
          padding: pad,
          child: katmanla(
              viewportKey == null
                  ? grid
                  : KeyedSubtree(key: viewportKey, child: grid),
              null,
              zoomlu: false));
    }
    Widget w = AnimatedBuilder(
      animation: z,
      child: grid,
      builder: (context, child) => TweenAnimationBuilder<Matrix4>(
        tween: Matrix4Tween(begin: Matrix4.identity(), end: z.matrix),
        duration: z.animate ? kZoomAnimDuration : Duration.zero,
        curve: Curves.easeOutCubic,
        // ValueKey testler için: zoom matrisinin ızgaraya GERÇEKTEN
        // uygulandığı tek yer burası. ClipRect = görünür kare; anahtarını
        // ekran katmanının bırakma kapısı kullanıyor (bkz. viewportKey
        // dokümantasyonu — kapı kutunun BOYUTUNU okur, clipper'ın payı onu
        // değiştirmez).
        builder: (context, m, c) => katmanla(
          ClipPath(
            key: viewportKey,
            clipper: const _CardClipper(),
            child: Transform(
                key: const ValueKey('board-zoom-transform'),
                transform: m,
                child: Padding(padding: pad, child: c)),
          ),
          m,
          zoomlu: true,
        ),
        child: child,
      ),
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onBoardPointerDown,
      onPointerMove: onBoardPointerMove,
      onPointerUp: onBoardPointerUp,
      onPointerCancel:
          onBoardPointerCancel == null ? null : (_) => onBoardPointerCancel!(),
      child: w,
    );
  }

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
    this.dragListenable,
    this.gridKey,
    this.zoomHint = false,
    this.zoom,
    this.viewportKey,
    this.onBoardPointerDown,
    this.onBoardPointerMove,
    this.onBoardPointerUp,
    this.onBoardPointerCancel,
    this.onOpenHistory,
    this.aiLevel,
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
    // Filigranların (köşe numarası / X2 / X3) puntosu web'de EKRAN
    // GENİŞLİĞİNE bağlı (`clamp(min, N vw, max)`, Board.tsx) — kutuya
    // sığdırılmış DEĞİL. Aynı `vw` girdisi burada da MediaQuery'den okunur
    // (tile_widget.dart'ın board harf/puan puntosuyla birebir aynı desen).
    final screenWidth = MediaQuery.sizeOf(context).width;

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

    // "Buradan başla" balonu — web `Board.tsx`'in `startHint`i, BİREBİR aynı
    // koşullarla (kullanıcı isteği, 26 Ağustos 2026).
    //
    // NEDEN VAR: kapalı testte insanların kuralı değil İLK HAMLEYİ nereye
    // yapacaklarını bulamadıkları görüldü. `HomeMark` zaten duruyor ama ne
    // olduğunu söyleyen bir şey yok — tanıtımda okunan cümle, tahtaya
    // bakarken hatırlanmıyor.
    //
    // Koşulun üç parçası da bilinçli: (1) tahtada tek taş yok, (2) bu turda
    // konmuş TASLAK taş da yok — oyuncu oynamaya başladıysa ipucu görevini
    // bitirmiştir ve balon taslağın üstünü kapatmamalı, (3) sıra bir
    // İNSANDA. Kalıcı "görüldü" bayrağı YOK: koşul kendi kendini
    // sınırlıyor (ilk taş konunca kayboluyor), her yeni oyunda yeniden
    // görünmesi zararsız, ve bir bayrak cihaz değiştiren oyuncuyu ipuçsuz
    // bırakırdı.
    final startHint = _startHintFor(players);

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

    // Filigranın ALTINDA kalması gereken hücreler: taş bulunan her hücre.
    // `dragHiddenKey` bilerek dışarıda — o hücre boş çiziliyor (bkz.
    // `_buildCell`), dolayısıyla filigran orada GÖRÜNMELİ.
    final occupiedCells = <({int r, int c})>[
      for (var r = 0; r < boardSize; r++)
        for (var c = 0; c < boardSize; c++)
          if (state.board[r][c] != null ||
              (cellKey(r, c) != dragHiddenKey &&
                  state.placed[cellKey(r, c)] != null))
            (r: r, c: c),
    ];

    // Web: kart (zemin + gölge) ızgarayı VE alt bilgi şeridini birlikte
    // sarar — şerit ayrı/asılı bir beyaz bant değil, kartın alt bölümü.
    return Container(
      decoration: const ShapeDecorationWithCssShadows(
        color: _boardBg,
        radius: _cardRadius,
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
            child: _zoomWrap(
                unclipped: moveOverlay != null && moveOverlay!.cells.isNotEmpty
                    ? _moveBadge()
                    : null,
                Stack(
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
                                lastMoveSet, currentColor, screenWidth),
                      ],
                    ),
                    // KATMAN SIRASI web'in z-index'lerinden geliyor (Board.tsx):
                    // hücre arka planları → filigran (z-auto) → TAŞLAR
                    // (`relative z-[5]`) → dış hatlar (`z-10`). Flutter'da
                    // z-index yok, sıra boyama sırasıdır; filigran ızgaradan
                    // SONRA çizildiğinden taşların üstüne biniyordu (kullanıcı
                    // 17 Ağustos 2026'da iki ekranı yan yana koyup bildirdi).
                    // Taşları ayrı bir katmana taşımak yerine filigran, taş
                    // bulunan hücreler KESİLEREK çiziliyor — sonuç "taşın
                    // altında" ile görsel olarak aynı, ızgara tek geçişte
                    // kalıyor (169 hücre iki kez inşa edilmiyor).
                    if (!compact)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ClipPath(
                            key: const ValueKey('board-watermarks'),
                            clipper: _WatermarkClipper(occupiedCells),
                            child: _watermarks(
                                cornerColor, cornerNumber, screenWidth),
                          ),
                        ),
                      ),
                    // Bölge/hamle dış hatları — ızgara alanının tamamını kaplayan
                    // tek katman (web'deki tek SVG'nin eşleniği), dokunuşları
                    // engellemez. Web'de `z-10`, yani taşların VE filigranın
                    // üstünde; bu yüzden filigrandan SONRA geliyor.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _OutlinesPainter(outlines)),
                      ),
                    ),
                    // Zoom tanıtım balonu — MERKEZ kareyi işaret eder. Ayrı bir
                // katman: "Buradan başla"dan bağımsız (ikisi aynı anda
                // görünebilir, farklı köşelerdeler) ve sürükleme başlayınca
                // ikisi de kaybolur.
                if (zoomHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: dragListenable == null
                          ? _zoomHintBubble(screenWidth)
                          : ValueListenableBuilder<Object?>(
                              valueListenable: dragListenable!,
                              builder: (context, drag, _) => drag != null
                                  ? const SizedBox.shrink()
                                  : _zoomHintBubble(screenWidth),
                            ),
                    ),
                  ),
                if (startHint != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: dragListenable == null
                              ? _startHint(startHint, screenWidth)
                              : ValueListenableBuilder<Object?>(
                                  valueListenable: dragListenable!,
                                  // Sürükleme başlayınca balon kaybolur.
                                  // Yalnızca BU katman dinliyor — tahtanın
                                  // kendisi sürükleme boyunca hiç yeniden
                                  // inşa edilmiyor (Parça 23).
                                  builder: (context, drag, _) => drag != null
                                      ? const SizedBox.shrink()
                                      : _startHint(startHint, screenWidth),
                                ),
                        ),
                      ),
                  ],
                )),
          ),
          if (!hideFooter) _footer(),
        ],
      ),
    );
  }

  /// "Buradan başla" balonunun hedefi: (satır, sütun, renk, sağa mı uzasın).
  /// `null` = balon gösterilmez. Ayrı bir metot olmasının sebebi yalnızca
  /// düzen değil: `final` bir yerele atanınca Dart'ın tip yükseltmesi
  /// widget ağacının içinde de garanti oluyor.
  (int, int, PlayerColor, bool)? _startHintFor(List<Player> players) {
    if (compact) return null;
    // Taş rafta SEÇİLİ (dokunup kaldırıldı) — sürükleme dalı ayrı, aşağıdaki
    // `dragListenable`da. Kullanıcı isteği (26 Ağustos 2026): "taşı
    // kaldırdığı anda yok olsun"; ilk sürüm yalnızca taş KONUNCA gizliyordu.
    if (state.selectedTile != null) return null;
    if (state.placed.isNotEmpty) return null;
    if (state.board.any((row) => row.any((c) => c != null))) return null;
    if (players.isEmpty) return null;
    final p = players[state.current];
    if (p.isAI || p.surrendered || p.corners.isEmpty) return null;
    final cc = cornerCell(p.corners.first);
    return (cc.$1, cc.$2, _colorOfIndex(state.current), cc.$2 < boardSize / 2);
  }

  /// Zoom tanıtım balonu: tahtanın MERKEZ karesinin (6,6) hemen ÜSTÜNDE,
  /// kuyruğu aşağı (kareye) bakan çok satırlı bir kutu.
  ///
  /// "Buradan başla"dan üç farkı var ve üçü de bilinçli: (1) metin uzun,
  /// tek satıra sığmaz → kutu genişliği tahtanın %78'iyle sınırlı ve metin
  /// sarılıyor; (2) oyuncuya özgü değil → renk oyuncu rengi değil `kAccent`;
  /// (3) hedefi ev karesi değil merkez, çünkü ipucu "herhangi bir boş kare"
  /// hakkında ve merkez her düzende görünür.
  ///
  /// Konum yine HÜCRE GEOMETRİSİYLE (yüzdeyle DEĞİL) — `_startHint`teki
  /// aynı `stride = (en + gap)/13` formülü.
  Widget _zoomHintBubble(double screenWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        const merkez = boardSize ~/ 2; // 6 — X3 karesi
        // Yalnızca DİKEY stride gerekiyor: balon yatayda ortalanıyor
        // (`left: 0, right: 0`), tek bir hücreye yaslanmıyor.
        final strideY = (constraints.maxHeight + gap) / boardSize;
        return Stack(
          children: [
            Positioned(
              // Merkez karenin ÜST kenarı; balon kendi yüksekliği kadar
              // yukarı çekiliyor (punto akışkan, yükseklik önceden bilinmez).
              top: merkez * strideY,
              left: 0,
              right: 0,
              child: FractionalTranslation(
                translation: const Offset(0, -1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth * 0.78),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: kAccent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x470F172A),
                              offset: Offset(0, 2),
                              blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        'Boş kareye veya çerçevesine çift tıklama tahtayı '
                        'büyütür. Hemen dene!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'SpaceGrotesk',
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                          fontSize: fluidSize(screenWidth, 9, 0, 2.4, 13),
                        ),
                      ),
                    ),
                    // Kuyruk: merkez kareye bakan küçük üçgen.
                    CustomPaint(
                      size: const Size(10, 6),
                      painter: const _HintTailDownPainter(kAccent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Balonun kendisi. Konum HÜCRE GEOMETRİSİYLE hesaplanıyor, yüzdeyle
  /// DEĞİL: ızgarada 12 adet 3px boşluk var, yani hücre `en/13` değil
  /// `(en - 36)/13`. Web'de yüzde yaklaşımı ölçüldüğünde balonu dikeyde
  /// ~9px kaydırıyordu (Chromium, 656px ızgara) — burada da aynı formül
  /// (`stride = (en + gap)/13`, `game_screen.dart`'ın dokunuş→hücre
  /// çevrimiyle AYNI).
  Widget _startHint((int, int, PlayerColor, bool) hint, double screenWidth) {
    final (hr, hc, col, toRight) = hint;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        final strideX = (constraints.maxWidth + gap) / boardSize;
        final strideY = (constraints.maxHeight + gap) / boardSize;
        final cellH = strideY - gap;
        final bubble = Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: toRight ? TextDirection.ltr : TextDirection.rtl,
          children: [
            CustomPaint(
              size: const Size(6, 10),
              painter: _HintTailPainter(col.base, toRight),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: col.base,
                borderRadius: BorderRadius.circular(7),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x470F172A),
                      offset: Offset(0, 2),
                      blurRadius: 6),
                ],
              ),
              child: Text(
                'Buradan başla',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.bold,
                  height: 1,
                  fontSize: fluidSize(screenWidth, 9, 0, 2.4, 13),
                ),
              ),
            ),
          ],
        );
        return Stack(
          children: [
            Positioned(
              top: hr * strideY + cellH / 2,
              left: toRight ? (hc + 1) * strideX : null,
              right: toRight ? null : constraints.maxWidth - hc * strideX,
              // Balonun KENDİ yüksekliğinin yarısı kadar yukarı — yüksekliği
              // önceden bilmeye gerek kalmıyor (punto akışkan).
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: bubble,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Alt bilgi şeridi — solda "Hamleler" (+ Canlı oyunda "· Mesajlaşma"),
  /// sağda "Çevrimdışı" uyarısı (yalnızca bağlantı yokken) ve
  /// "Yardım".
  /// Dokunulabilir öğeler `TapTarget` içinde — yani kutuları en az
  /// 48×48 (`kMinTapTarget`). 22 Ağustos 2026'da buraya bir dolgu
  /// (`top: 4, bottom: 10`) konmuştu ama YETMEDİ: CI'da ölçülen gerçek
  /// kutu 31.0 px kaldı ve kullanıcı aynı şikayeti (*"biraz üstüne
  /// basınca çalışıyor"*) 24 Ağustos'ta tekrarladı. Ders, sayının
  /// kendisinde: dolgu "biraz büyüttük" diye değil, ÖLÇÜLEN kutu
  /// asgariyi geçtiği için yeterlidir (`test/tap_target_test.dart`).
  ///
  /// Şerit bu yüzden 32 → 48 px'e yükseldi; tahta bir `SingleChildScrollView`
  /// içinde olduğundan bu yalnızca kaydırma boyunu değiştirir.
  /// Tıklanamaz öğelerin (ayraç, "Çevrimdışı") dolgusu artık yalnızca
  /// YATAY — 48 px'lik satırda kendiliğinden ortalanıyorlar; eskisi gibi
  /// asimetrik dikey dolgu taşısalardı ~3 px kayarlardı.

  /// "Mesajlaşma" butonunun içeriği. `etiketli: false` → yalnızca ikon
  /// (çevrimdışı; gerekçe `_footer`daki nota yazılı). Okunmamış sayacı bu
  /// widget'ın DIŞINDA, `Stack`te duruyor — yani etiket düşse de rozet
  /// kaybolmaz, yalnızca çapası ikonun sağ üstüne kayar.
  static Widget _mesajlasmaIcerik({required bool etiketli}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Anahtar TESTİN kancası: sınıf private olduğundan tip olarak
          // aranamıyor, ve çevrimdışıyken kontrolün İKON olarak ayakta
          // kaldığı iddiası tam da bu yüzden bir anahtara bağlı.
          const _ChatBubbleIcon(key: ValueKey('chat-icon')),
          if (etiketli) ...[
            const SizedBox(width: 4),
            const Text(
              'Mesajlaşma',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: kAccent,
              ),
            ),
          ],
        ],
      );

  Widget _footer() {
    return Container(
      // `Padding` DEĞİL `Container`: dolgunun yanında GENİŞLİĞİ de zorluyor
      // (aşağıdaki `Wrap` notu) — ikisini tek widget'ta yapabildiğinden
      // fazladan bir sarmalayıcı katmanı gerekmiyor.
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      // `Row` DEĞİL `Wrap` (28 Ağustos 2026): iki grup da `shrink-0`
      // olduğundan (web'de de öyle) `Row` sığmadığı anda taşar. Sistem yazı
      // boyutu büyütülünce tam bu oluyordu — ÖLÇÜLDÜ: ölçek 1,3'te 8,3-14 px
      // sağdan taşma, 2,0'da 150-181 px. Bu, uygulamadaki taşmaların
      // ölçek 1,3'te KALAN TEK noktasıydı (`kMaxTextScale` tavanından sonra).
      //
      // `Wrap` + `spaceBetween`, genişliği doldurduğu sürece (aşağı bkz.)
      // tek satırda `Row`la aynı görünür; sığmadığında sağ grubu alt satıra
      // indirir. Eşik/ölçek kontrolü YOK — kural genişlikten çıkıyor, yani
      // dar bir telefonda uzun bir metin için de çalışır.
      //
      // ⚠ Yukarıdaki `width: double.infinity` ŞART VE 30 Ağustos 2026'ya
      // kadar YOKTU — bir kullanıcı cihazda bildirdi: *"Hamleler,
      // Mesajlaşma satırı Android'de ortaya kümelenmiş, iPhone'da (web)
      // kenarlara yaslı."* Sebep: `Row` (mainAxisSize.max) gelen genişliği
      // DOLDURUR, `Wrap` ise gevşek kısıt altında içeriğine KÜÇÜLÜR
      // (`constraints.constrain(...)` doğal genişliği döndürür). Küçülen
      // kutuda dağıtılacak boşluk kalmadığından `spaceBetween` no-op olur;
      // üstteki `Column`un varsayılan `crossAxisAlignment: center`'ı da
      // kümeyi ortaya alır. Yani Row→Wrap dönüşümü tek satırda "birebir
      // aynı" DEĞİLDİR — ancak genişlik zorlanırsa öyle olur.
      // ÖLÇÜLDÜ (390 px, gerçek `BoardWidget`): şerit 38,4..351,6 arasına
      // sıkışıyordu (kenar boşluğu 10 yerine 38,4); düzeltmeden sonra
      // 10,0..380,0. Regresyon: `test/text_scale_test.dart` → "tahta alt
      // şeridi ŞERİDİ DOLDURUR".
      // PUNTO 12 → 11 (2 Eylül 2026, kullanıcı cihazda: *"Board altındaki
      // Hamleler, Mesajlaşma, Nasıl Oynanır? alt bölümü çok büyütmüş"*).
      // Sistem yazı ölçeği 1,3'te 12 px → 15,6 px oluyordu ve şerit iki
      // satıra sarıp kartın altını yiyordu; 11'de 14,3.
      // ⚠ Ekran başına ölçek TAVANI konmadı — `mobile/CLAUDE.md` kural 1
      // bunu yasaklıyor (tavan TEK yerde). Değişen taban punto.
      // ⚠ BEŞ kardeş de aynı puntoda olmak ZORUNDA (Hamleler · ayraç ·
      // Mesajlaşma · sayaç · Yardım) ve web `Board.tsx` ikizi de —
      // biri değişirse hepsi.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onOpenHistory != null)
                TapTarget(
                  onTap: onOpenHistory,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DocumentIcon(),
                      SizedBox(width: 4),
                      Text(
                        'Hamleler',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: kAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              // Zorluk rozeti — YZ oyununda "Hamleler"in sağında, Canlı'daki
              // "· Mesajlaşma"nın yerinde; ayraç aynı görünümde (web
              // `Board.tsx` ikizi).
              if (aiLevel != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child:
                      Text('·', style: TextStyle(fontSize: 11, color: kMuted)),
                ),
                AiLevelBadge(level: aiLevel, size: AiLevelBadgeSize.sm),
              ],
              if (onOpenMessaging != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child:
                      Text('·', style: TextStyle(fontSize: 11, color: kMuted)),
                ),
                TapTarget(
                  onTap: onOpenMessaging,
                  // Rozet `Positioned(top: -4, right: -4)` ile Row'un
                  // kutusuna çapalı — TapTarget çocuğu ORTALADIĞI için
                  // (dolgu eklemediği için) rozetin çapası bozulmuyor.
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ÇEVRİMDIŞIYKEN ETİKET DÜŞER, ikon ve sayaç kalır
                      // (2 Eylül 2026, kullanıcı sordu: *"Çevrimdışı da
                      // gelince 2 satıra gelip o alanı büyütüyor mu?"*).
                      // ÖLÇÜLDÜ — şeridin tek satırda kalması için gereken
                      // en az genişlik: yerel oyun çevrimdışı+tavan 282 px
                      // (her telefonda sığar), ama CANLI oyun
                      // çevrimdışı+tavan **405 px** → 320/360/390'da şerit
                      // 48 → 96 px'e çıkıyordu. `Wrap` taşmaz SARAR, yani
                      // ne hata basılır ne de "taşma yok" diyen test görür.
                      // Etiketi düşürmek eşiği ~348 px'e indiriyor: 360 ve
                      // 390 kurtulur. ⚠ 320 px'te tavanda HÂLÂ iki satır —
                      // bilinen ve kabul edilen sınır, gizlenmesin.
                      // Neden ETİKET seçildi: çevrimdışıyken mesaj zaten
                      // gönderilemiyor; ikon okumak için duruyor ve
                      // okunmamış sayacı (asıl bilgi) hiç kaybolmuyor.
                      // ⚠ WEB İKİZİ BİLEREK DEĞİŞMEDİ — parite "aynı kod"
                      // değil "aynı sonuç": web'de sistem yazı ölçeği yok
                      // ve ölçüldü ki `Board.tsx` şeridi 320 px'te bile
                      // çevrimdışıyken tek satır (48 px). Orada çözülecek
                      // bir sorun olmadığı için etiket kaldırmak yalnızca
                      // bilgi kaybı olurdu.
                      if (onlineStatus == null)
                        _mesajlasmaIcerik(etiketli: true)
                      else
                        ListenableBuilder(
                          listenable: onlineStatus!,
                          builder: (context, _) =>
                              _mesajlasmaIcerik(etiketli: onlineStatus!.online),
                        ),
                      // Konum web'de ölçülerek seçildi (`-top-1 -right-1`):
                      // rozet satır içi olsaydı şeride ~20px eklerdi ve dar
                      // telefonlarda "Nasıl Oynanır?" ile çakışırdı (⚠ o
                      // ölçüm ESKİ etiketle; 2 Eylül 2026'da "Yardım" olunca
                      // boşluk arttı — gerekçe duruyor, rakam yeniden
                      // ölçülmeden alıntılanmamalı). Beyaz
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
                          // (Hamleler · Mesajlaşma · Yardım) birebir
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
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: kRed,
                            ),
                          ),
                        ),
                ),
              if (onOpenHelp != null)
                TapTarget(
                  onTap: onOpenHelp,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HelpIcon(),
                      SizedBox(width: 4),
                      Text(
                        // ETİKET 'Nasıl Oynanır?' → 'Yardım' (2 Eylül 2026,
                        // kullanıcı fikri). Sebep ölçüm: 14 karakterlik
                        // etiket ölçek tavanında şeridi İKİ SATIRA
                        // düşürüyordu (48 → 96 px) ve punto indirimi bunu
                        // engellemiyordu; tek satırda kalabilen en yüksek
                        // ölçek 360 px'te yalnızca 1,10 idi. 'Yardım' ile
                        // 320/360/390 px'in ÜÇÜNDE de tavanda tek satır.
                        // ⚠ Yalnızca ŞERİT etiketi değişti: HelpModal'ın
                        // başlığı, hesap menüsü maddesi ve /nasil-oynanir/
                        // sayfası 'Nasıl Oynanır?' olarak kaldı.
                        // Web ikizi: `Board.tsx` — biri değişirse öteki de.
                        'Yardım',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
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
    double screenWidth,
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
        // Web: `text-[clamp(9px,2.6vw,16px)]` (Board.tsx, merkez hücrenin
        // kendi etiketi) — İKİSİ BİRLİKTE DEĞİŞİR.
        //
        // ÖNCEDEN `FittedBox` ile hücreyi dolduruyordu — 48px'lik bir hücrede
        // bu ~37px'e denk geliyor, o zamanki azami 12px'in üç katı (kullanıcı
        // cihazda "boyut/tasarım farklı" diye bildirdi, 17 Ağustos 2026).
        // O düzeltme DOĞRUYDU ve duruyor: punto hâlâ hücreye değil EKRAN
        // genişliğine bağlı, yani iki platform aynı hesabı yapıyor.
        //
        // 28 Ağustos 2026, kullanıcı isteği ("en ortadaki X3 yazısını biraz
        // büyütelim"): 7/1.9vw/12 → 9/2.6vw/16. 420 px'lik bir telefonda
        // 7,98 px → 10,9 px. Tahtanın en önemli tek hücresi okunmuyordu.
        content = Center(
          child: Text(
            'X3',
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: _centerText,
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.bold,
              fontSize: fluidSize(screenWidth, 9, 0, 2.6, 16),
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
      onTapUp:
          onCellTap == null ? null : (d) => onCellTap!(r, c, d.globalPosition),
      child: body,
    );
  }

  /// Köşe numarası + X2 filigranları (web'deki soluk arka yazılar).
  ///
  /// Web (`Board.tsx`) bu iki yazıyı kutuya SIĞDIRMIYOR: punto ekran
  /// genişliğine bağlı bir `clamp` (köşe `clamp(80px,32vw,220px)`, X2
  /// `clamp(60px,24vw,165px)`), yazı tipi `font-mono` (Space Mono) ve satır
  /// yüksekliği `leading-none` (=1). Port 17 Ağustos 2026'ya kadar
  /// `FittedBox` kullanıyordu — yani punto kutunun oranına göre çıkıyor,
  /// üstelik `fontFamily` hiç verilmediğinden yazı tipi de temanın
  /// SpaceGrotesk'i oluyordu; kullanıcı iki ekranı yan yana koyup farkı
  /// bildirdi. Ölçülen web değerleri (derlenmiş CSS + Chromium): 390px'te
  /// 124.8/93.6, 834px ve üstünde 220/165.
  ///
  /// `Center` + `OverflowBox`: köşe rakamının satır kutusu (220) kendi
  /// 4/13'lük alanından (680px'lik tahtada ~203) büyük olabiliyor — web'de
  /// de taşıyor. `FractionallySizedBox` çocuğuna TIGHT kısıt verdiğinden,
  /// araya konmazsa yazı ortalanmak yerine kutunun üstünden çizilirdi.
  /// Köşe numarası + "X2" bölge filigranları.
  ///
  /// ⚠ `textScaler: TextScaler.noScaling` — sistem yazı boyutundan MUAF
  /// (2 Eylül 2026, kullanıcı cihazda bildirdi: *"en büyük fontta bölge
  /// watermarklar da büyüyüp bölgenin dışına taşıyor"*).
  ///
  /// **Bu, `mobile/CLAUDE.md` kural 1'in ("ekran başına ölçek kısıtı
  /// YAZMA") ihlali DEĞİL.** O kural OKUNAN metni korur; buradakiler
  /// okunacak metin değil, punto'su tahtanın GEOMETRİSİNDEN türeyen
  /// dekoratif zemin şekilleri (`fluidSize(screenWidth, …)` — ekran
  /// genişliğinin fonksiyonu, tıpkı bir ikon gibi). Büyütmek okunurluğa
  /// hiçbir şey katmıyor, yalnızca bölge sınırını bozuyor. Ve asıl ölçüt
  /// şu: **web bunları hiç ölçeklemiyor** (CSS `clamp()` px tabanlı,
  /// tarayıcı tüm SAYFAYI zoom'lar), yani sabitlemek pariteyi KURUYOR.
  ///
  /// ÖLÇÜLDÜ (tavan 1,3; köşe rakamı ↔ 4×4 bloğun kenarı):
  ///   320 px → 104,0 / 90,2 = **%115 (taşıyor)**
  ///   360 px → 104,0 / 102,5 = **%101 (taşıyor)**
  ///   390 px → %93 · 412 px → %88 · 430 px → %84
  /// "X2" (en fazla %69) ve "X3" (en fazla %84) tavanda taşmıyordu ama
  /// %30 büyüyorlardı; üçü de aynı sınıf olduğundan üçü de sabitlendi —
  /// yalnızca taşanı düzeltmek, ikisini web'den ayrık bırakmak olurdu.
  Widget _watermarks(List<PlayerColor?> cornerColor, List<int?> cornerNumber,
      double screenWidth) {
    const cornerFrac = cornerSize / boardSize;
    const zoneFrac = (boardSize - 2 * cornerSize) / boardSize;
    final cornerFont = fluidSize(screenWidth, 80, 0, 32, 220);
    final zoneFont = fluidSize(screenWidth, 60, 0, 24, 165);
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
                  child: Center(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Text(
                        '${cornerNumber[i]}',
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          color: cornerColor[i]!.base,
                          fontFamily: 'SpaceMono',
                          fontWeight: FontWeight.bold,
                          fontSize: cornerFont,
                          height: 1,
                        ),
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
              child: Center(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Text(
                    'X2',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF92660A),
                      fontFamily: 'SpaceMono',
                      fontWeight: FontWeight.bold,
                      fontSize: zoneFont,
                      height: 1,
                    ),
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
                  // Dolgu 3/6 → 1.5/3 (29 Ağustos 2026, test kullanıcıları
                  // bildirdi: rozet harfleri kapatıyor). Ölçüm 384px'de:
                  // 30.7px = 1.22 hücre → 24.7px = 0.98 hücre. Rakamın
                  // puntosu bilerek AYNI kaldı. Web ikizi: Board.tsx
                  // `buildBadge`.
                  //
                  // AYRIŞMA KAPANDI (29 Ağustos 2026, kullanıcı kararı:
                  // "web'i porta getir"): web de artık sabit 11px +
                  // `font-sans` (Space Grotesk). Öncesinde web
                  // `clamp(8px,2vw,11px)` + `font-mono` idi ve `2vw` her
                  // telefonda 8px'e kırpıldığından (11px'e ancak 550px'te
                  // ulaşıyordu) burası pratikte %19 geniş çiziyordu.
                  // Küçültme yönü BİLEREK seçilmedi — hamle puanı "Oyna"dan
                  // önce bakılan tek sayı. Ölçümler ve 320px'te kabul edilen
                  // taşma: Board.tsx'in aynı bloğundaki yorum.
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
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

/// Filigran katmanını, TAŞ BULUNAN hücreleri dışarıda bırakacak şekilde
/// kırpar — web'de taşların `relative z-[5]` ile filigranın üstüne çıkması
/// buna karşılık geliyor (Board.tsx).
///
/// Delik `Path.combine`/PathOps ile DEĞİL `PathFillType.evenOdd` ile ifade
/// ediliyor: Parça 18'de ölçüldü, PathOps CanvasKit'te deliği sessizce
/// kaybedebiliyor (native Skia'da sorunsuz çalışırken) — yani `flutter test`
/// bu hata sınıfını göremez.
class _WatermarkClipper extends CustomClipper<Path> {
  const _WatermarkClipper(this.occupied);

  /// Taş bulunan hücrelerin (satır, sütun) çiftleri.
  final List<({int r, int c})> occupied;

  /// `GridView`in `mainAxisSpacing`/`crossAxisSpacing` değeriyle AYNI olmak
  /// zorunda — biri değişirse öteki de değişmeli, aksi halde kesilen kutular
  /// hücrelerden kayar.
  static const _gap = 3.0;

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    final cellW = (size.width - _gap * (boardSize - 1)) / boardSize;
    final cellH = (size.height - _gap * (boardSize - 1)) / boardSize;
    for (final o in occupied) {
      path.addRect(Rect.fromLTWH(
        o.c * (cellW + _gap),
        o.r * (cellH + _gap),
        cellW,
        cellH,
      ));
    }
    return path;
  }

  @override
  bool shouldReclip(_WatermarkClipper old) =>
      !listEquals(old.occupied, occupied);
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
  const _ChatBubbleIcon({super.key});

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

/// "Yardım" linkinin başındaki soru işareti ikonu — web `HelpIcon`
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

/// "Buradan başla" balonunun ev karesine bakan kuyruğu.
/// Aşağı bakan kuyruk (zoom tanıtım balonu) — `_HintTailPainter`ın dikey
/// eşi; ayrı bir sınıf, çünkü o yataydaki iki yönü parametreliyor ve üçüncü
/// bir yön eklemek onun okunurluğunu bozardı.
class _HintTailDownPainter extends CustomPainter {
  final Color color;
  const _HintTailDownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HintTailDownPainter old) => old.color != color;
}

class _HintTailPainter extends CustomPainter {
  final Color color;
  final bool toRight;
  const _HintTailPainter(this.color, this.toRight);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (toRight) {
      // Uç SOLDA (ev karesine bakar), taban sağda (balona yapışır).
      path.moveTo(0, size.height / 2);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, size.height / 2);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HintTailPainter old) =>
      old.color != color || old.toRight != toRight;
}
