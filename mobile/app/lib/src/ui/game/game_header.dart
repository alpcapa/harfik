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
import '../tap_target.dart';
import '../tokens.dart';
import 'fluid.dart';
import 'logo_mark.dart';
import 'player_colors.dart';

/// "← Geri" etiketi — web `GameHeader.tsx`in BACK_FONT_SIZE/BACK_GAP'i.
/// İnce (normal ağırlık) ve KOYU (paletin ana metin rengi); kullanıcı
/// gri ve siyah varyantları yan yana görüp siyahı seçti (21 Ağustos 2026).
/// Web'le ELLE senkron — biri değişirse öteki de değişmeli.
const double kBackFontSize = 11;
/// Etiketin ALTINDAKİ dokunma payı — header ile tahta arasında zaten var
/// olan boşluğun tıklanabilir hâle gelmiş kısmı (bkz. build()'deki not).
/// Web'de karşılığı YOK: orada etiket `<button>`ın içinde bir `<span>` ve
/// tıklama ataya kabardığından ayrı bir paya ihtiyaç duymuyor.
const double kBackBottomPad = 13;

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

    // "← Geri" KENDİ SATIRI — header satırının ALTINDA, tahtanın hemen
    // üstünde. Web'den bilinçli bir SAPMA ve gerekçesi yapısal:
    //
    // ⚠ 24 AĞUSTOS 2026, İKİ TUR. Önce etiket bir `Stack(clipBehavior:
    // Clip.none)` içinde `Positioned` ile logonun kutusunun DIŞINA
    // taşırılmıştı; Flutter'da böyle bir çocuk hiç dokunuş ALMAZ
    // (`RenderBox.hitTest` önce `size.contains`e bakar) — ölçülen kutu
    // 90.8 × 29.3, yani sadece logo. Kullanıcı bildirdi: *"logo altındaki
    // geri de basınca çalışmıyor"*. Webde AYNI yapı çalışıyor çünkü etiket
    // `<button>`ın İÇİNDE bir `<span>` ve DOM'da tıklama ataya KABARIYOR.
    //
    // İkinci tur: etiketi logoyla aynı `TapTarget`e alan Column çözümü
    // çalıştı ama pahalıydı — blok Row'da dikey ORTALANDIĞINDAN, logonun
    // skor kutularıyla hizasını korumak için etiketin altta kapladığı kadar
    // ÜSTTE de boşluk gerekiyordu; yani etiketin altına eklenen her 1 px
    // header'a 2 px ekliyordu (ölçüldü: header 52 → 77 px). Kullanıcı
    // cihazda bunu gördü: *"Geri tuşu tam üstüne basarsan ok ama biraz
    // altına gelirse çalışmıyor. Geri ile board arasındaki boşluğu biraz
    // kısarsak hem daha iyi çalışır hem de header'ı bu kadar büyütmüş
    // olmayız"* — ve seçimi bu düzen oldu.
    //
    // Şimdi: logo satırı yalnızca logo + skor kutuları + hesap (48 px'lik
    // hedefler, hiza korunuyor), etiket ise ayrı bir satır olarak tahtanın
    // üstündeki boşluğu KULLANIYOR — o boşluk zaten vardı, artık
    // tıklanabilir. Bedeli logo ↔ etiket arasının 3 px'ten ~9 px'e açılması
    // (etiket artık logonun kutusuna değil SATIRIN altına çapalı; satırın
    // boyunu 48'lik hedefler belirliyor).
    //
    // Etiketin dokunma kutusu 48 GENİŞ ama yalnızca ~24 YÜKSEK (bilinçli
    // istisna, `TapTarget.minHeight`): 48'lik bir yükseklik header ile
    // tahta arasına 20 px'lik boş bir bant açardı ve aynı eylem için hemen
    // üstündeki logo zaten tam boy bir hedef.
    //
    // Sol kenar hâlâ tahtanınkiyle hizalı: 12 px, Board'unkiyle aynı.
    // ⚠ Board'un yatay dolgusu değişirse hiza sessizce bozulur.

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
        children: [
          TapTarget(
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
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TapTarget(
              onTap: onLogoTap,
              minHeight: 24,
              // Sol kenar tahtanınkiyle (12 px) hizalı KALMALI — kutu 48 px
              // geniş ama metin dar, ortalansa 4 px sağa kayardı.
              alignment: Alignment.centerLeft,
              child: const Padding(
                // Alttaki pay, header ile tahta arasında ZATEN var olan
                // boşluğun tıklanabilir hâle gelmiş kısmı.
                padding: EdgeInsets.only(bottom: kBackBottomPad),
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
          ),
        ),
      ],
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
      // 30 Ağustos 2026 — pasif kalınlık 0.5 → 1, web ikiziyle birlikte.
      // Sebep webde ölçüldü (kullanıcının iPhone ekran görüntüsü, DPR 3):
      // 0.5 px'lik çerçeve 1,5 CİHAZ pikseli demek ve kutu genişliği kesirli
      // olduğundan iki kenar farklı alt-piksel fazına düşüyor — biri çiziliyor,
      // öteki açık zeminde kayboluyor (ölçülen kontrast farkı 272 ↔ 14).
      // Flutter da 0.5'i yuvarlamaz, yani aynı kırılganlık burada da vardı;
      // uygulamada henüz görülmemiş olması fazın şanslı düşmesiydi.
      // Aktif/pasif ayrımı 2 ↔ 1 olarak korunuyor. Bkz. GameHeader.tsx.
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: col.base, width: active ? 2 : 1),
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
                    // Skor SAYISI siyah (token `text`), 28 Ağustos 2026
                    // kullanıcı isteği: oyuncu renginde okunması zordu.
                    // Kutunun geri kalanı — etiket, çerçeve, zemin —
                    // oyuncu renginde KALIYOR; istek birebir "sadece sayı"
                    // diyordu. 'TESLİM' bir sayı değil, o da renkte kalır.
                    color: player.surrendered ? col.base : kText,
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
    // Kutu ~26 px yüksekliğinde ama header satırı zaten 48 (logo/avatar
    // hedefleri belirliyor) — dokunma kutusunu 48'e çıkarmak BEDAVA, düzen
    // değişmiyor. `minWidth: 0`: genişlik akıcı sistemden geliyor
    // (`playerBoxWidth`/`yzBoxWidth`), 48 dayatmak web paritesini bozardı.
    return onTap == null
        ? dimmed
        : TapTarget(
            onTap: onTap, minWidth: 0, minHeight: kMinTapTarget, child: dimmed);
  }
}
