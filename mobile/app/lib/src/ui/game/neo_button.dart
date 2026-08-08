// Web'in btn-raised / btn-raised-neutral / btn-raised-gold butonları —
// index.css'teki gölge değerleriyle, CSS semantiğinde
// (ShapeDecorationWithCssShadows; tahta/raf ile aynı ders). Disabled durum
// web'le aynı: gölge YOK + tüm buton %35 opaklık (accent'te bu, açık mavi
// zemin üstünde BEYAZ yazı görünümü verir — kullanıcı ekran görüntüsüyle
// istedi, Material'ın gri disabled görünümü DEĞİL).
import 'package:flutter/material.dart';

import 'neo_box.dart';

enum NeoButtonVariant { accent, neutral, gold, orange }

class NeoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final NeoButtonVariant variant;
  final double fontSize;
  final double letterSpacing;
  final EdgeInsets padding;

  /// Zengin (çok stilli) etiket — web'in tek bir `<span>`i (`text-[13px]
  /// text-accent`) üzerine bindirip geri kalanı butondan MİRAS ALAN
  /// deseninin (App.tsx TORBA butonu) Flutter karşılığı. Verilirse [label]
  /// yerine bu render edilir (yine de [label] geçilmeli — a11y/semantics
  /// yedeği); null ise davranış tamamen değişmeden [label] tek biçimde
  /// basılır.
  final List<InlineSpan>? richLabel;

  const NeoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NeoButtonVariant.neutral,
    this.fontSize = 11,
    this.letterSpacing = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    this.richLabel,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    final Color bg;
    final Color fg;
    final Color? borderColor;
    final List<CssShadow> shadows;
    switch (variant) {
      case NeoButtonVariant.accent:
        bg = const Color(0xFF2563EB);
        fg = Colors.white;
        borderColor = null;
        // web .btn-raised
        shadows = const [
          CssShadow(color: Color(0x8CA3B1C6), offset: Offset(3, 3), blur: 8),
          CssShadow(color: Color(0xB3FFFFFF), offset: Offset(-2, -2), blur: 6),
          CssShadow(color: Color(0x59647489), offset: Offset(0, 6), blur: 14),
        ];
      case NeoButtonVariant.gold:
        bg = const Color(0xFFB7791F);
        fg = Colors.white;
        borderColor = null;
        shadows = const [
          CssShadow(color: Color(0x8CA3B1C6), offset: Offset(3, 3), blur: 8),
          CssShadow(color: Color(0xB3FFFFFF), offset: Offset(-2, -2), blur: 6),
          CssShadow(color: Color(0x59647489), offset: Offset(0, 6), blur: 14),
        ];
      case NeoButtonVariant.orange:
        bg = const Color(0xFFF2650F); // tailwind orange (Setup "+ Yeni" butonu)
        fg = Colors.white;
        borderColor = null;
        // web .btn-raised-orange — gölge değerleri .btn-raised ile birebir
        // aynı (ölçüldü, index.css:78), yalnızca zemin rengi farklı.
        shadows = const [
          CssShadow(color: Color(0x8CA3B1C6), offset: Offset(3, 3), blur: 8),
          CssShadow(color: Color(0xB3FFFFFF), offset: Offset(-2, -2), blur: 6),
          CssShadow(color: Color(0x59647489), offset: Offset(0, 6), blur: 14),
        ];
      case NeoButtonVariant.neutral:
        bg = const Color(0xFFF5F7FA); // web bg-panel
        fg = const Color(0xFF1B2430); // web text-text
        borderColor = const Color(0xFFDCE2EA); // web border-border
        // web .btn-raised-neutral
        shadows = const [
          CssShadow(color: Color(0x80A3B1C6), offset: Offset(2, 2), blur: 6),
          CssShadow(color: Color(0xD9FFFFFF), offset: Offset(-2, -2), blur: 5),
        ];
    }

    Widget box = Container(
      padding: padding,
      alignment: Alignment.center,
      // web disabled: box-shadow none — gölge yalnızca aktifken.
      decoration: enabled
          ? ShapeDecorationWithCssShadows(
              color: bg, radius: 6, shadows: shadows)
          : BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      foregroundDecoration: borderColor == null
          ? null
          : BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: () {
          final baseStyle = TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: letterSpacing,
            color: fg,
            height: 1.2,
          );
          if (richLabel != null) {
            return Text.rich(
              TextSpan(style: baseStyle, children: richLabel),
              textAlign: TextAlign.center,
            );
          }
          return Text(
            label,
            textAlign: TextAlign.center,
            style: baseStyle,
          );
        }(),
      ),
    );
    if (!enabled) box = Opacity(opacity: 0.35, child: box); // web opacity-35
    return GestureDetector(onTap: onPressed, child: box);
  }
}
