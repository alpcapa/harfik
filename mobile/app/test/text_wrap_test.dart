// SINIF 3 — SABİT GENİŞLİKLİ KUTUDA SARMA (1 Eylül 2026).
//
// NEDEN VAR: bir kullanıcı cihazda bildirdi — *"fontlarını büyüten kişilerde
// bitirme modalı puanları bölüyor"*. Ekran görüntüsünde skor `241` ekranda
// `24` / `1` diye okunuyordu. Kök sebep: skor sütunları SABİT piksel
// genişlikli kutular; yazı ölçeği büyürken kutu sabit kaldığından metin
// sarıyor.
//
// **Bu sınıfı mevcut hiçbir test göremiyordu:** taşma (sarı-siyah şerit)
// ÜRETMİYOR — ölçüldü, ölçek 1,3'te takımın tamamında taşma sayısı SIFIR —
// ve sıkışma da değil, çünkü bilgi kaybolmuyor, yalnızca okunamaz hâle
// geliyor. Tavan (`kMaxTextScale`) çözmüyor: 1,3'te de sarıyor, üstelik dört
// vaka ölçek 1,0'da BİLE sarıyordu (4 haneli skor `1000`, `+12`, `12.`,
// `10.`).
//
// KAPI: aşağıdaki envanterdeki her sütun, hem 1,0 hem tavan ölçeğinde TEK
// SATIR kalmalı. Yeni bir sabit genişlikli sütun eklendiğinde buraya bir
// satır eklenir; eklenmezse bu test onu görmez, ama `ScaledCell` kullanmak
// zaten sarmayı yapısal olarak imkânsız kılar (bkz. `ui/text_scale.dart`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// (yer, kutu genişliği, font ailesi, punto, en KÖTÜ durum metinleri)
/// (yer, kutu genişliği, font ailesi, punto, GERÇEKÇİ en kötü metinler)
///
/// ⚠ "En kötü" değerler ÖLÇÜLDÜ, uydurulmadı:
///   • k-lig katkısı: `leaguePoints` yalnızca -2/0/1/2 döndürür
///     (`league_points.dart`) → en uzun çıktı "-2". "+12" İMKÂNSIZ.
///   • Anlam madde numarası: sözlükteki en çok anlamlı kelime `çıkmak`,
///     **54 anlam** (`meanings.json` üzerinde sayıldı) → "54." gerçek.
///   • Oyun skoru: 100 taşlık torbayla üç hane; dört hane oluşamıyor.
///     Lider tablosundaki skor ise k-lig TOPLAMI, beş haneye çıkabilir.
const _sutunlar = <(String, double, String, double, List<String>)>[
  ('GameOver · KALAN başlığı', 29, 'SpaceGrotesk', 9, ['KALAN']),
  ('GameOver · TOPLAM başlığı', 37, 'SpaceGrotesk', 9, ['TOPLAM']),
  ('GameOver · k-lig başlığı', 20, 'SpaceGrotesk', 9, ['k-lig']),
  ('GameOver · kalan taş', 29, 'SpaceMono', 13, ['-12']),
  ('GameOver · toplam skor', 37, 'SpaceMono', 20, ['499']),
  ('GameOver · k-lig katkısı', 20, 'SpaceMono', 13, ['-2', '+2']),
  ('Leaderboard · sıra', 28, 'SpaceMono', 14, ['100']),
  ('Leaderboard · skor', 44, 'SpaceMono', 14, ['12500']),
  ('GameHistory · PUAN başlığı', 40, 'SpaceMono', 9, ['PUAN']),
  ('GameHistory · k-lig başlığı', 32, 'SpaceMono', 9, ['k-lig']),
  ('GameHistory · sıra', 18, 'SpaceMono', 12, ['4.']),
  ('GameHistory · skor', 40, 'SpaceMono', 12, ['499']),
  ('GameHistory · k-lig katkısı', 32, 'SpaceMono', 12, ['-2']),
  ('MeaningModal · madde no', 20, 'SpaceMono', 13, ['54.']),
  ('HelpModal · kademe harfi', 26, 'SpaceMono', 12, ['K']),
];

/// Metnin TEK SATIR doğal genişliği (sarma yok — `ScaledCell` içinde
/// `maxLines: 1` + `softWrap: false` var, yani gerçek widget da sarmaz).
double _dogalGenislik(String metin, String aile, double punto, double olcek) {
  final tp = TextPainter(
    text: TextSpan(
        text: metin, style: TextStyle(fontFamily: aile, fontSize: punto)),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(olcek),
  )..layout();
  return tp.width;
}

void main() {
  setUpAll(loadAppFonts);

  // `ScaledCell` kutuyu ölçekle büyütür ve sığmayanı KÜÇÜLTÜR (FittedBox).
  // Kapı iki şeyi birden ölçüyor: metin sarmıyor (yapısal olarak zaten
  // sarmaz) VE küçültme okunurluğu bozacak kadar sert değil.
  const enAzOran = 0.8;

  test('sabit genişlikli sütunlar: metin sığar ya da en çok %20 küçülür', () {
    final bozuk = <String>[];
    for (final (yer, kutu, aile, punto, metinler) in _sutunlar) {
      for (final olcek in const [1.0, kMaxTextScale]) {
        for (final m in metinler) {
          final gerekli = _dogalGenislik(m, aile, punto, olcek);
          // ScaledCell'in kutusu: sabit genişlik × yazı ölçeği.
          final kutuOlcekli = kutu * olcek;
          final oran = kutuOlcekli / gerekli;
          if (oran < enAzOran) {
            bozuk.add('$yer · "$m" · ölçek $olcek → '
                '%${(oran * 100).round()} küçültme gerekiyor '
                '(${gerekli.toStringAsFixed(1)}px metin, '
                '${kutuOlcekli.toStringAsFixed(1)}px kutu)');
          }
        }
      }
    }
    expect(bozuk, isEmpty,
        reason: 'Sütun kutusu gerçekçi en kötü içeriğe göre DAR: metin ya '
            'sarardı (eski hata) ya da okunmayacak kadar küçülür. Çözüm: '
            'kutuyu genişlet — `ScaledCell` yalnızca ölçeği taşır, dar '
            'kutuyu kurtarmaz.');
  });

  // NEGATİF EŞ: kutu yazı ölçeğiyle BÜYÜMESEYDİ (düzeltmeden önceki hâl)
  // tavanda gerçekten sarardı — yani bu kapı boş yere durmuyor.
  test('NEGATİF EŞ: ölçeksiz kutu tavanda yetersiz kalırdı', () {
    final yetersiz = <String>[];
    for (final (yer, kutu, aile, punto, metinler) in _sutunlar) {
      for (final m in metinler) {
        if (kutu / _dogalGenislik(m, aile, punto, kMaxTextScale) < enAzOran) {
          yetersiz.add('$yer · "$m"');
        }
      }
    }
    expect(yetersiz, isNotEmpty,
        reason: 'Ölçeksiz kutuda hiçbir sütun sıkışmıyorsa envanter '
            'bayatlamış — bu kapı artık bir şey ölçmüyor demektir.');
  });

  // GERÇEK RENDER KANITI — yukarıdakiler hesap; bu, modalın kendisini
  // tavan ölçeğinde çizip `ScaledCell` içindeki HER metnin tek satır
  // olduğunu ölçüyor. Kullanıcının cihazda gördüğü ekranın ta kendisi.
  testWidgets('GameOver modalı tavan ölçeğinde: hiçbir sütun bölünmez',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = kMaxTextScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final son = (golden['steps'] as List).last as Map;
    final state =
        gameStateFromJson((son['state'] as Map).cast<String, Object?>());

    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
          body: Center(
              child: GameOverModal(state: state, onOpenHistory: () {}))),
    ));
    await tester.pumpAndSettle();

    // İKİ AYRI İDDİA, iki ayrı mekanizma (karıştırmak testi yanıltır —
    // ilk taslakta karıştı ve negatif eş sessizce geçti):
    //   (a) BÖLÜNME YOK  ← maxLines:1 + softWrap:false + FittedBox
    //   (b) KÜÇÜLME YOK  ← scaledWidth (kutu ölçekle büyüyor)
    // (b) olmadan (a) yine sağlanır ama sayı okunmayacak kadar küçülür —
    // yazı boyutunu BÜYÜTEN kullanıcıda sayının küçülmesi, düzeltilen
    // hatanın yerine geçen ikinci bir kusur olurdu.
    final bolunen = <String>[];
    final kuculen = <String>[];
    for (final e in find
        .descendant(of: find.byType(ScaledCell), matching: find.byType(Text))
        .evaluate()) {
      final ro = e.renderObject;
      if (ro is! RenderParagraph) continue;
      final metin = (e.widget as Text).data ?? '';
      if (metin.trim().isEmpty) continue;

      final tp = TextPainter(
        text: ro.text,
        textDirection: ro.textDirection,
        textScaler: ro.textScaler,
      )..layout(maxWidth: ro.size.width);
      if (tp.computeLineMetrics().length > 1) bolunen.add('"$metin"');

      // Hücrenin GERÇEK kutusu: ScaledCell'in SizedBox'ı.
      final hucre = find
          .ancestor(of: find.byWidget(e.widget), matching: find.byType(SizedBox))
          .evaluate()
          .first
          .renderObject as RenderBox;
      // FittedBox child'a sonsuz genişlik verdiğinden `ro.size.width`
      // metnin DOĞAL (küçültülmemiş) genişliğidir.
      if (ro.size.width > hucre.size.width + 0.5) {
        kuculen.add('"$metin" (${ro.size.width.toStringAsFixed(1)}px metin, '
            '${hucre.size.width.toStringAsFixed(1)}px kutu)');
      }
    }
    expect(bolunen, isEmpty,
        reason: 'Skor sütunu tavan ölçeğinde BÖLÜNÜYOR — kullanıcının '
            'cihazda bildirdiği hata (241 → 24/1) geri gelmiş.');
    expect(kuculen, isEmpty,
        reason: 'Sütun kutusu yazı ölçeğiyle büyümüyor: metin sığmak için '
            'KÜÇÜLTÜLÜYOR. Yazıyı büyüten kullanıcıda sayının küçülmesi '
            'kabul edilemez — `ScaledCell` genişliği `scaledWidth` ile '
            'ölçeklemeli.');
  });
}
