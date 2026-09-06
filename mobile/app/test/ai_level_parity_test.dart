// YZ zorluğunun ÜRÜN yüzü — web ↔ port paritesi (ROADMAP #23 Faz 4).
//
// NEDEN VAR: etiketler (`Kolay`/`Normal`/`Zor`), Setup'ta seçilebilir liste
// (Zor Faz 5'e kadar YOK), seviye açıklamaları ve HelpModal'ın zorluk paragrafı
// web'de `src/utils/aiLevel.ts` + `Setup.tsx` + `HelpModal.tsx`te, portta
// `util/ai_level.dart` + `help_modal.dart`ta ELLE senkron duruyor —
// derleyici görmez. Faz 5 Zor'u açtığında iki liste birlikte değişmeli;
// biri unutulursa bir taraf "Zor" sunar öteki sunmaz (ve +4 puanı bir
// platform verir, öteki vermez). Desen `help_text_parity_test.dart` /
// `rank_tiers_parity_test.dart` ile aynı: web kaynağını oku, ayrıştır,
// karşılaştır.
//
// ⚠ Bu test `mobile/` DIŞINDAN dosya okuyor — `web-ci.yml`in `paths`
// listesinde `src/**` zaten var (kök CLAUDE.md, "Web CI mobil testleri de
// koşuyor").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/util/ai_level.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  final web = File('../../src/utils/aiLevel.ts').readAsStringSync();

  test('AI_LEVEL_LABEL ↔ aiLevelLabel: üç etiket birebir', () {
    final block = RegExp(r'AI_LEVEL_LABEL[^{]*\{([^}]*)\}').firstMatch(web);
    expect(block, isNotNull, reason: 'aiLevel.ts yeniden düzenlendiyse regex');
    final labels = <String, String>{
      for (final m in RegExp(r"(\w+):\s*'([^']+)'").allMatches(block!.group(1)!))
        m.group(1)!: m.group(2)!,
    };
    expect(labels.length, 3);
    for (final lv in AiLevel.values) {
      expect(aiLevelLabel[lv], labels[lv.json],
          reason: 'web ${lv.json} etiketi "${labels[lv.json]}", port farklı');
    }
  });

  test('SELECTABLE_AI_LEVELS ↔ selectableAiLevels: aynı küme, aynı sıra '
      '(Zor Faz 5\'e kadar ikisinde de YOK)', () {
    final m = RegExp(r'SELECTABLE_AI_LEVELS[^=]*=\s*\[([^\]]*)\]').firstMatch(web);
    expect(m, isNotNull);
    final webList = RegExp(r"'(\w+)'")
        .allMatches(m!.group(1)!)
        .map((x) => x.group(1)!)
        .toList();
    expect(webList, isNotEmpty);
    expect([for (final lv in selectableAiLevels) lv.json], webList,
        reason: 'Zor açılırken/kapanırken iki liste AYNI PR\'da değişmeli');
  });

  test('AI_LEVEL_PITCH ↔ aiLevelPitch: üç hitap cümlesi birebir', () {
    final block = RegExp(r'AI_LEVEL_PITCH[^{]*\{([\s\S]*?)\n\};').firstMatch(web);
    expect(block, isNotNull, reason: 'aiLevel.ts yeniden düzenlendiyse regex');
    final pitches = <String, String>{
      for (final m in RegExp(r"(\w+):\s*'([^']+)'").allMatches(block!.group(1)!))
        m.group(1)!: m.group(2)!,
    };
    expect(pitches.length, 3);
    for (final lv in AiLevel.values) {
      expect(aiLevelPitch[lv], pitches[lv.json],
          reason: 'web ${lv.json} hitap cümlesi port ile farklı');
    }
  });

  test('aiLevelDescription: altı bileşim tam metin (web smoke testi aynı '
      'metinleri Setup\'ta okuyor; sayılar leaguePoints tablosundan)', () {
    const kolay = 'Çok iyi değilim, daha yeni yeni alışıyorum, karşımda o '
        'kadar zor bir rakip istemiyorum diyorsanız doğru yerdesiniz.';
    const normal = 'Orta-iyi seviye bir oyuncuyum, sıradan oyunculardan biraz '
        'daha iyiyim diyorsanız burası size göre.';
    const zor = 'Çok iyi oyuncuyum, genelde %80+ kazanırım diyorsanız bunu '
        'denemelisiniz.';
    expect(aiLevelDescription(AiLevel.kolay, 2),
        '$kolay Bu seviyede birincilik 1 puan kazandırır.');
    expect(aiLevelDescription(AiLevel.kolay, 4),
        '$kolay Bu seviyede birincilik 1 puan kazandırır, ikincilik puan '
        'kazandırmaz.');
    expect(aiLevelDescription(AiLevel.normal, 2),
        '$normal Bu seviyede birincilik 2 puan kazandırır.');
    expect(aiLevelDescription(AiLevel.normal, 4),
        '$normal Bu seviyede birincilik 2, ikincilik 1 puan kazandırır.');
    expect(aiLevelDescription(AiLevel.zor, 2),
        '$zor Bu seviyede birincilik 4 puan kazandırıyor. Bol şans!');
    expect(aiLevelDescription(AiLevel.zor, 4),
        '$zor Bu seviyede birincilik 4, ikincilik 2 puan kazandırıyor. '
        'Bol şans!');
  });

  test('HelpModal zorluk paragrafı iki tarafta da var (aynı cümle başı ve '
      'aynı sayılar)', () {
    final help = File('../../src/components/HelpModal.tsx').readAsStringSync();
    final port =
        File('lib/src/ui/game/help_modal.dart').readAsStringSync();
    // `<strong>`/`**` işaretleri ve JSX `{' '}` ekleri atılır; Dart'ın satır
    // satır birleşen dize literalleri (`'… '\n'…'`) tek metne dikilir.
    String plain(String s) => _norm(s
        .replaceAll(RegExp(r"</?strong>|\{' '\}|\*\*"), '')
        .replaceAll(RegExp(r"'\s*\n\s*'"), ''));
    final webPara = RegExp(r"Yapay Zeka'ya karşı oynarken[\s\S]*?verilir\.")
        .firstMatch(help);
    final portPara = RegExp(r"Yapay Zeka\\'ya karşı oynarken[\s\S]*?verilir\.")
        .firstMatch(port);
    expect(webPara, isNotNull, reason: 'web HelpModal zorluk paragrafı yok');
    expect(portPara, isNotNull, reason: 'port help_modal zorluk paragrafı yok');
    final w = plain(webPara!.group(0)!);
    final p = plain(portPara!.group(0)!.replaceAll(r"\'", "'"));
    expect(p, w);
  });

  test('rozet seviyesi: YZ oyununda her seviye (null = Normal), Canlı\'da yok', () {
    expect(aiLevelForBadge(null, isAiGame: true), AiLevel.normal);
    expect(aiLevelForBadge(AiLevel.kolay, isAiGame: true), AiLevel.kolay);
    expect(aiLevelForBadge(AiLevel.kolay, isAiGame: false), isNull);
    expect(aiLevelForBadge(null, isAiGame: false), isNull);
    expect(aiLevelBadgeLabel(null), isNull);
    expect(aiLevelBadgeLabel(AiLevel.normal), 'Normal');
    expect(aiLevelBadgeLabel(AiLevel.kolay), 'Kolay');
    expect(aiLevelBadgeLabel(AiLevel.zor), 'Zor');
  });
}
