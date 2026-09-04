// Kurallar ekranı — web HelpModal.tsx paritesi: iki adım (Hızlı Başlangıç /
// Detaylı Kurallar), başlıktaki link ile geçiş, kural metinlerinin birebir
// aktarıldığı örnek cümleler ve puan tablosu.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/help_modal.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/rank/league_rank.dart';
import 'package:kelimeki_core/kelimeki_core.dart' show bingoBonus, letterPoints;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// Verilen düz metin ekranda (Text.rich parçalarına bölünmüş olsa bile)
/// bulunuyor mu — `find.textContaining` RichText'in düz metnini tarar.
void expectText(String s) =>
    expect(find.textContaining(s, findRichText: true), findsWidgets,
        reason: 'metin bulunamadı: $s');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  Future<void> pumpHelp(WidgetTester tester, GlobalKey key) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: RepaintBoundary(key: key, child: const HelpModal()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/$name.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });

  testWidgets('Hızlı Başlangıç: 9 madde + Bingo bonusu motordan',
      (tester) async {
    final key = GlobalKey();
    await pumpHelp(tester, key);

    expect(find.text('HIZLI BAŞLANGIÇ'), findsOneWidget); // KModal başlığı
    // Web'deki dokuz maddenin her birinden ayırt edici bir parça.
    expectText('2 ya da 4 oyuncuyla');
    expectText('Kendi bölgenden başlar');
    expectText('Yeni kelimeler tahtadaki mevcut harflere');
    expectText('bölge vergisi');
    expectText('Ortadaki 5×5 bonus bölgesi');
    expectText('+$bingoBonus Bingo bonus'); // sabit motordan geliyor
    expectText('istediğin harfe dönüşür');
    expectText('TDK sözlüğündeki');
    expectText('Yüksek puanı olan kazanır');

    await shoot(tester, key, 'help_quick');
  });

  testWidgets('link ile Detaylı Kurallar ↔ Hızlı Başlangıç geçişi',
      (tester) async {
    final key = GlobalKey();
    await pumpHelp(tester, key);

    await tester.tap(find.text('Detaylı Kurallar →').first);
    await tester.pumpAndSettle();
    expect(find.text('DETAYLI KURALLAR'), findsOneWidget);
    expect(find.text('HIZLI BAŞLANGIÇ'), findsNothing);

    // Bölüm başlıkları (web Section title'ları). Web `uppercase` CSS'i
    // taşıdığından port `trUpper`dan geçiriyor — beklenti de büyük harfli
    // olmalı, ve native `toUpperCase` DEĞİL `trUpper` ile üretilmiş
    // (İ/I ayrımı: "Nasıl" → "NASIL", "Bingo" → "BİNGO" değil "BINGO";
    // "İhlal"deki İ korunur). Metinler burada ELLE büyük yazılıyor ki
    // `trUpper`ı kendisiyle karşılaştıran bir totoloji kurulmasın.
    for (final t in [
      'NASIL OYNANIR?',
      'TEMEL KURALLAR',
      'BÖLGE VERGİSİ',
      'BONUS BÖLGESİ',
      'HAMLE SEÇENEKLERİ',
      'BİNGO BONUSU',
      'SÖZLÜK',
      'OYUNUN SONU',
      'SKOR KARTI VE PUANLAMA',
      'RÜTBELER VE ÖDÜLLER',
      'PUAN TABLOSU',
    ]) {
      expect(find.text(t), findsOneWidget, reason: 'bölüm yok: $t');
    }
    expectText('Joker ('); // ★ ikonlu başlık (glyph değil, WidgetSpan)

    // Kural metninden birkaç ayırt edici cümle — özetlenmediğinin kanıtı.
    expectText('puanın 1/3\'ü bölge sahibine gider, 2/3\'ü sende kalır');
    expectText('X3 hücresi kullanıldığında ayrıca X2 eklenmez');
    expectText('Beraberlikte aynı sırayı paylaşan oyuncuların hepsi');

    await shoot(tester, key, 'help_detailed');

    await tester.tap(find.text('Hızlı Başlangıç →').first);
    await tester.pumpAndSettle();
    expect(find.text('HIZLI BAŞLANGIÇ'), findsOneWidget);
  });

  testWidgets('Puan tablosu motordaki harf puanlarıyla tutarlı',
      (tester) async {
    await pumpHelp(tester, GlobalKey());
    await tester.tap(find.text('Detaylı Kurallar →').first);
    await tester.pumpAndSettle();

    // Tablodaki her satır gerçekten o puan grubunu listelemeli — örnek
    // harfleri motorun letterPoints'iyle karşılaştır (web tablosu elle
    // yazılmış, sapmayı burada yakalarız).
    const samples = {
      'A': 1, 'E': 1, 'İ': 1, 'K': 1, 'L': 1, 'R': 1, 'N': 1, 'T': 1, //
      'I': 2, 'M': 2, 'O': 2, 'S': 2, 'U': 2, //
      'B': 3, 'Ç': 3, 'D': 3, 'Ü': 3, 'Y': 3, //
      'C': 4, 'Ş': 4, 'Z': 4, //
      'G': 5, 'H': 5, 'P': 5, //
      'F': 7, 'Ö': 7, 'V': 7, //
      'Ğ': 8, 'J': 10,
    };
    samples.forEach((letter, pts) {
      expect(letterPoints(letter), pts,
          reason: '$letter için tablo $pts diyor, motor '
              '${letterPoints(letter)} diyor');
    });
    expectText('sabit toplam 100 taş');
    expectText('Joker');
  });

  // Rütbe tablosu ELLE YAZILMIYOR (`kRankTiers`ten geliyor) — bu test onu
  // sabitliyor: dokuz kademenin HEPSİ, kendi eşiği ve ödülüyle ekranda
  // olmalı. Eşik/ödül tablosu SQL ↔ TS ↔ Dart arasında ELLE senkron
  // olduğundan (bkz. league_rank.dart), ekranın kaynağı kaçırması sessiz
  // bir yalan üretirdi.
  testWidgets('Rütbeler bölümü dokuz kademeyi kaynaktan çiziyor',
      (tester) async {
    await pumpHelp(tester, GlobalKey());
    await tester.tap(find.text('Detaylı Kurallar →').first);
    await tester.pumpAndSettle();

    expect(kRankTiers.length, 9); // kaynak gerçekten dokuz kademe mi
    for (final t in kRankTiers) {
      expect(find.text(t.letter), findsWidgets, reason: 'harf yok: ${t.letter}');
      // Ad + eşik tek bir TextSpan zincirinde; düz metin araması yeterli.
      expectText(t.name);
      expectText('${t.threshold} puan');
      if (t.reward > 0) expectText('(ödül +${t.reward})');
    }
    // Çaylak'ın ödülü 0 — "(ödül +0)" HİÇ yazılmamalı.
    expectText('Çaylak');
    expect(find.textContaining('(ödül +0)'), findsNothing);

    // −2 cezası: kullanıcı bunu bugüne kadar yalnızca cezayı YEDİKTEN sonra
    // gelen e-postadan öğreniyordu.
    expectText('2 puan');
    expectText('48');
    expectText('7 gün');
  });
}
