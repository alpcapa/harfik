// Oyun başlığı — src/components/GameHeader.tsx portu: solda logo (dokunuş =
// oyundan çık), sağda oyuncu skor kutuları + hesap kontrolü (AccountButton:
// GİRİŞ / avatar-menü — web UserMenu). Web'in akıcı clamp() sistemi
// (375px'te min → 465px'te max) burada fluidSize() ile birebir hesaplanır.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../../data/auth_service.dart';
import '../../data/chat_api.dart';
import '../../data/feedback_api.dart';
import '../../data/friends_api.dart';
import '../../data/games_api.dart';
import '../../data/stats_api.dart';
import '../auth/account_button.dart';
import '../tokens.dart';
import 'fluid.dart';
import 'logo_mark.dart';
import 'player_colors.dart';

/// "← Geri" etiketi — web `GameHeader.tsx`in BACK_FONT_SIZE/BACK_GAP'i.
/// İnce (normal ağırlık) ve KOYU (paletin ana metin rengi); kullanıcı
/// gri ve siyah varyantları yan yana görüp siyahı seçti (21 Ağustos 2026).
/// Web'le ELLE senkron — biri değişirse öteki de değişmeli.
const double kBackFontSize = 11;
const double kBackGap = 3;

class GameHeader extends StatelessWidget {
  final GameState state;
  final VoidCallback? onLogoTap;

  /// Hesap durumu — verilmezse ya da Supabase yapılandırılmamışsa hesap
  /// kontrolü hiç çizilmez (web'de UserMenu'nun `!configured → null`
  /// davranışı; testler/salt önizlemeler auth geçirmeyebilir).
  final AuthService? auth;

  /// Hesap menüsündeki k-lig/Skor Kartı satırları için (null ise
  /// gösterilmez — offline mod).
  final StatsRepo? stats;

  /// Hesap menüsünden açılan skor kartındaki geçmiş linki için.
  final Future<GamesRepo>? games;

  /// Hesap zincirindeki Terms/Privacy içi "Görüş Bildir formu" linki için
  /// (AccountButton → AuthModal'a iletilir).
  final FeedbackRepo? feedback;

  /// Hesap menüsündeki "Arkadaşlar" satırı + rozet için.
  final FriendsRepo? friends;
  final ChatRepo? chat;

  /// Verilirse insan koltuklarının kutuları tıklanabilir olur (Canlı oyunda
  /// skor kartı — web onPlayerClick'in eşleniği; yerel oyunda verilmez).
  final void Function(int index)? onPlayerTap;

  const GameHeader({
    super.key,
    required this.state,
    this.onLogoTap,
    this.onPlayerTap,
    this.auth,
    this.stats,
    this.games,
    this.feedback,
    this.friends,
    this.chat,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Web sabitleri (GameHeader.tsx) — aynı katsayılar.
    final playerBoxWidth = fluidSize(w, 43, -52.83, 25.56, 66);
    final yzBoxWidth = fluidSize(w, 28, -34.5, 16.67, 43);
    final labelFontSize = fluidSize(w, 6, -2.33, 2.22, 8);
    final scoreFontSize = fluidSize(w, 13, -7.83, 5.56, 18);
    final boxPaddingX = fluidSize(w, 1.5, -6.83, 2.22, 3.5);
    final boxGap = fluidSize(w, 4, -4.33, 2.22, 6);
    final boxPaddingY = fluidSize(w, 2.7, -0.63, 0.89, 3.5);
    final logoHeight = fluidSize(w, 28, -5.33, 8.89, 36);
    // UserMenu.tsx'in GIRIS_* sabitleri — Giriş butonu skor kutularıyla aynı
    // satırda/aynı akıcı sistemde büyür.
    final girisFontSize = fluidSize(w, 8, -4.5, 3.33, 11);
    final girisPaddingX = fluidSize(w, 6, -2.33, 2.22, 8);
    final girisPaddingY = fluidSize(w, 8.7, -5.05, 3.67, 12);

    // Web `GameHeader.tsx`: etiket akışın DIŞINDA (absolute), header'ın
    // yüksekliğine hiç dokunmuyor. Flutter'da bunun birebir karşılığı YOK —
    // kutusunun DIŞINA taşan bir çocuk dokunuş ALMAZ (`RenderBox.hitTest`
    // önce `size.contains`e bakıyor), oysa etiketin de tıklanabilir olması
    // kullanıcının şartı ("logo alanı da dahil"). Bu yüzden port bir Stack
    // kullanıyor.
    //
    // ⚠ Row'a `Positioned(height: logoHeight)` VERİLMİYOR ve bu bilinçli:
    // `AccountButton`ın avatarı 32px, logo ise 465px'in altında 32'den KISA
    // (390px'te 29.33) — Row o yüksekliğe kilitlenseydi taşardı. Row
    // Stack'in KONUMLANMAMIŞ çocuğu olarak duruyor, yani kendi doğal
    // yüksekliğini ve kendi iç hizasını AYNEN koruyor; Stack'in yüksekliğini
    // gerektiğinde büyüten şey yanındaki görünmez taban kutusu.
    // Etiketin konumu Row'un değil LOGONUN altına göre hesaplanıyor.
    //
    // Bedeli: header'ın alt dolgusu 10 → 0'a indirildikten sonra kalan
    // ~4px'lik büyüme (webde 0). Bilinçli ve ölçülü bir sapma.
    final stackHeight = logoHeight + kBackGap + kBackFontSize;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 10),
      child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Yalnızca TABAN yükseklik için — Stack konumlanmamış
            // çocuklarının en büyüğüne göre boyutlanır.
            SizedBox(height: stackHeight),
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onLogoTap,
                    child: LogoMark(height: logoHeight),
                  ),
                  const SizedBox(width: 8),
                  // Web justify-between'in ikinci çocuğu tek bir SAĞ GRUP: kutular +
                  // GİRİŞ/avatar birbirine bitişik (gap-2) ve sağa yaslı — artan
                  // boşluk logo ile kutuların ARASINA düşer, kutuların sağına değil
                  // (kullanıcı iPhone karşılaştırmasıyla bildirdi).
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Web güvenlik ağıyla aynı: sığmazsa şerit görünmez biçimde
                        // yatay kaydırılır (satır kırmak yerine), 0. kutu her zaman
                        // erişilebilir. GİRİŞ/avatar bu kaydırma kabının DIŞINDA —
                        // web'deki aynı ders (UserMenu overflow kabının içindeyken
                        // dropdown'ı kırpılıyordu).
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: false,
                            child: Row(
                              children: [
                                for (var i = 0; i < state.players.length; i++) ...[
                                  if (i > 0) SizedBox(width: boxGap),
                                  _PlayerBox(
                                    player: state.players[i],
                                    index: i,
                                    active: i == state.current,
                                    width: state.players[i].isAI
                                        ? yzBoxWidth
                                        : playerBoxWidth,
                                    paddingX: boxPaddingX,
                                    paddingY: boxPaddingY,
                                    labelFontSize: labelFontSize,
                                    scoreFontSize: scoreFontSize,
                                    onTap:
                                        (onPlayerTap != null && !state.players[i].isAI)
                                            ? () => onPlayerTap!(i)
                                            : null,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (auth != null && auth!.configured) ...[
                          const SizedBox(width: 8),
                          AccountButton(
                            auth: auth!,
                            stats: stats,
                            games: games,
                            feedback: feedback,
                            friends: friends,
                            chat: chat,
                            girisFontSize: girisFontSize,
                            girisPaddingX: girisPaddingX,
                            girisPaddingY: girisPaddingY,
                            avatarSize: 32,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ⚠ ÖLÇÜLEN KÜÇÜK SAPMA: konum Stack'in ÜSTÜNDEN hesaplanıyor,
            // logonun gerçek alt kenarından değil. Row logodan uzun bir
            // çocuk taşıyorsa (girişli hesapta avatar 32px, logo 465px'in
            // altında daha kısa) logo Row içinde ORTALANDIĞINDAN birkaç px
            // aşağı kayar ve aradaki boşluk 3 yerine ~1.7'ye düşer. Webde
            // etiket butonun `top-full`ü olduğundan bu sapma YOK. Row'un
            // yüksekliği çalışma anında bilinemediği için kabul edildi;
            // çakışma hiçbir genişlikte oluşmuyor (testle sabit).
            //
            // Etiket logoyla AYNI dokunuş hedefinde değil ama AYNI eylemi
            // yapıyor (web'de tek bir <button>, burada iki GestureDetector) —
            // Flutter'da tek bir hedef, Row'un yüksekliğini büyütmeden
            // kurulamıyor. `left: 0`: header'ın 12px'lik yatay dolgusu
            // Board'unkiyle aynı, yani etiket tahtanın sol kenarıyla hizalı.
            // ⚠ Board'un yatay dolgusu değişirse bu hiza sessizce bozulur.
            Positioned(
              left: 0,
              top: logoHeight + kBackGap,
              child: GestureDetector(
                onTap: onLogoTap,
                child: Text(
                  '← Geri',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: kBackFontSize,
                    height: 1,
                    color: kText,
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _PlayerBox extends StatelessWidget {
  final Player player;
  final int index;
  final bool active;
  final double width;
  final double paddingX;
  final double paddingY;
  final double labelFontSize;
  final double scoreFontSize;
  final VoidCallback? onTap;

  const _PlayerBox({
    required this.player,
    required this.index,
    required this.active,
    required this.width,
    required this.paddingX,
    required this.paddingY,
    required this.labelFontSize,
    required this.scoreFontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = playerColors[player.colorIndex % playerColors.length];
    final label = player.isAI ? 'YZ ${index + 1}' : trUpper(player.name);

    // Teslim gösterimi (kullanıcı kararı, 6 Ağustos 2026 — web'le BİRLİKTE
    // netleştirildi, iki taraf aynı): kutu diğerleriyle aynı boy/renk/
    // çerçevede kalır, puan alanında skor satırını dolduran boyutta TESLİM
    // yazar (yükseklik SizedBox'la skora sabit, metin FittedBox'la sığar)
    // ve kutunun tamamı %45 soluklaştırılır (aşağıdaki Opacity).
    final box = Container(
      key: ValueKey('player-box-$index'),
      width: width,
      padding: EdgeInsets.symmetric(horizontal: paddingX, vertical: paddingY),
      decoration: BoxDecoration(
        color: col.tint,
        borderRadius: BorderRadius.circular(6),
      ),
      // Çerçeve foregroundDecoration'da: web'deki `outline` dersiyle aynı
      // sebep — aktif/pasif kalınlık farkı (2/0.5px) iç içerik genişliğini
      // değiştirirse dar YZ kutusunda 3 haneli skor kırpılır. Flutter'da
      // BoxDecoration.border da içeriden yer kapladığından çerçeve layout'a
      // hiç dokunmayan ön katmana çizilir.
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: col.base, width: active ? 2 : 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.bold,
              fontSize: labelFontSize,
              letterSpacing: 1,
              color: col.base,
            ),
          ),
          SizedBox(
            height: scoreFontSize, // skor satırıyla (height:1) aynı boy
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  player.surrendered ? 'TESLİM' : '${player.score}',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontWeight: FontWeight.bold,
                    fontSize: scoreFontSize,
                    height: 1,
                    color: col.base,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final dimmed = player.surrendered
        ? Opacity(opacity: 0.45, child: box) // web'le aynı soluklaştırma
        : box;
    return onTap == null
        ? dimmed
        : GestureDetector(onTap: onTap, child: dimmed);
  }
}
