// Bölge vergisi onay diyaloğu — web `App.tsx` ve `OnlineGameScreen.tsx`'in
// `invasionConfirm` bloğunun portu.
//
// **Neden PAYLAŞILAN bir dosya (11 Ağustos 2026, Parça 55):** `game_screen`
// ↔ `online_game_screen` çifti sürükleme/joker/mesaj desenini bilinçli
// olarak ayrı ayrı taşıyor (web'in iki dosyasını birebir yansıtsın diye),
// ama bu diyalog o desenlerden biri değil — iki ekranda BİREBİR aynı metin
// ve aynı vurgu kuralı. `invasionShare` formülünün core'da tek kopya
// tutulmasıyla aynı gerekçe: üçüncü bir kopya açma.
import 'package:flutter/material.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import '../tokens.dart';
import 'dialog_shell.dart';
import 'neo_button.dart';

/// "Sınır İhlali!" onayı. `true` → oyuncu OYNA dedi.
///
/// Metin web ile birebir; vurgular da öyle: kazanılacak puan YEŞİL, her
/// bölge sahibine giden pay KIRMIZI, sahibin adı yalnızca kalın
/// (`<strong>` — rengi yok, gövde rengini miras alır).
Future<bool> showInvasionConfirm(
  BuildContext context, {
  required int score,
  required List<InvasionShare> shares,
  required List<Player> players,
}) async {
  const bold = TextStyle(fontWeight: FontWeight.bold);
  final spans = <InlineSpan>[
    const TextSpan(text: 'Bu hamleden kazanacağın '),
    TextSpan(
        text: '$score',
        style: const TextStyle(fontWeight: FontWeight.bold, color: kGreen)),
    const TextSpan(text: ' puanın '),
  ];
  for (var i = 0; i < shares.length; i++) {
    final s = shares[i];
    spans
      ..add(TextSpan(
          text: '${s.amount}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: kRed)))
      ..add(const TextSpan(text: ' puanı '))
      ..add(TextSpan(text: players[s.index].name, style: bold))
      // Web: son öğeden sonra ', ' değil ' ' — cümle "… kullanıcısına vergi
      // olarak gidecek." diye akıyor.
      ..add(TextSpan(
          text: ' kullanıcısına${i < shares.length - 1 ? ', ' : ' '}'));
  }
  spans.add(const TextSpan(text: 'vergi olarak gidecek.'));

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => KDialogCard(
      title: const Text('Sınır İhlali!', style: kDialogTitleStyle),
      content: Text.rich(TextSpan(
          style: kDialogBodyStyle.copyWith(fontFamily: 'SpaceGrotesk'),
          children: spans)),
      actions: [
        // Kabul butonu SOLDA — web'in düz flex sırası (bkz. Parça 25).
        kDialogButton(
          label: 'OYNA',
          variant: NeoButtonVariant.accent,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        kDialogButton(
          label: 'VAZGEÇ',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );
  return ok == true;
}
