// Oyun başlığı — src/components/GameHeader.tsx portu: solda logo (dokunuş =
// oyundan çık), sağda oyuncu skor kutuları. Web'in akıcı clamp() sistemi
// (375px'te min → 465px'te max) burada _fluid() ile birebir hesaplanır;
// UserMenu (hesap menüsü) BİLİNÇLİ eksik — auth sonraki fazın işi.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'logo_mark.dart';
import 'neo_box.dart';
import 'player_colors.dart';

/// Web'deki `clamp(min, calc(a + b·vw), max)` eşleniği — vw = ekran
/// genişliği / 100. Uç noktalar web'le aynı (375 → min, 465 → max).
double _fluid(double screenWidth, double min, double a, double b, double max) {
  final v = a + b * (screenWidth / 100);
  return v.clamp(min, max);
}

class GameHeader extends StatelessWidget {
  final GameState state;
  final VoidCallback? onLogoTap;

  /// Verilirse insan koltuklarının kutuları tıklanabilir olur (Canlı oyunda
  /// skor kartı — web onPlayerClick'in eşleniği; yerel oyunda verilmez).
  final void Function(int index)? onPlayerTap;

  const GameHeader({
    super.key,
    required this.state,
    this.onLogoTap,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    // Web sabitleri (GameHeader.tsx) — aynı katsayılar.
    final playerBoxWidth = _fluid(w, 43, -52.83, 25.56, 66);
    final yzBoxWidth = _fluid(w, 28, -34.5, 16.67, 43);
    final labelFontSize = _fluid(w, 6, -2.33, 2.22, 8);
    final scoreFontSize = _fluid(w, 13, -7.83, 5.56, 18);
    final boxPaddingX = _fluid(w, 1.5, -6.83, 2.22, 3.5);
    final boxGap = _fluid(w, 4, -4.33, 2.22, 6);
    final boxPaddingY = _fluid(w, 2.7, -0.63, 0.89, 3.5);
    final logoHeight = _fluid(w, 28, -5.33, 8.89, 36);
    // UserMenu.tsx'in GIRIS_* sabitleri — Giriş butonu skor kutularıyla aynı
    // satırda/aynı akıcı sistemde büyür.
    final girisFontSize = _fluid(w, 8, -4.5, 3.33, 11);
    final girisPaddingX = _fluid(w, 6, -2.33, 2.22, 8);
    final girisPaddingY = _fluid(w, 8.7, -5.05, 3.67, 12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                const SizedBox(width: 8),
                _GirisButton(
                  fontSize: girisFontSize,
                  paddingX: girisPaddingX,
                  paddingY: girisPaddingY,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Web UserMenu'nün misafir durumu: accent zeminli "GİRİŞ" düğmesi (oturum
/// açıksa web avatar+dropdown gösterir — o durum auth fazıyla gelecek).
/// Şimdilik dokununca dürüst bir "yakında" açıklaması gösterilir; sahte bir
/// giriş formu bilinçli olarak YOK.
class _GirisButton extends StatelessWidget {
  final double fontSize;
  final double paddingX;
  final double paddingY;
  const _GirisButton({
    required this.fontSize,
    required this.paddingX,
    required this.paddingY,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Giriş'),
          content: const Text(
              'Hesapla giriş ve Canlı oyun özellikleri uygulamanın sonraki '
              'sürümünde gelecek. Şimdilik Yapay Zeka\'ya karşı '
              'oynayabilirsin.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('TAMAM'),
            ),
          ],
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: paddingX, vertical: paddingY),
        // Web: `btn-raised bg-accent` — index.css'teki gölge üçlüsü, CSS
        // semantiğiyle (bkz. neo_box.dart).
        decoration: const ShapeDecorationWithCssShadows(
          color: Color(0xFF2563EB), // web bg-accent
          radius: 6,
          shadows: [
            CssShadow(color: Color(0x8CA3B1C6), offset: Offset(3, 3), blur: 8),
            CssShadow(
                color: Color(0xB3FFFFFF), offset: Offset(-2, -2), blur: 6),
            CssShadow(color: Color(0x59647489), offset: Offset(0, 6), blur: 14),
          ],
        ),
        child: Text(
          'GİRİŞ',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontWeight: FontWeight.bold,
            fontSize: fontSize,
            letterSpacing: 0.5,
            height: 1,
            color: Colors.white,
          ),
        ),
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
