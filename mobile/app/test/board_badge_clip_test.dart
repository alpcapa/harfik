// Hamle rozeti tahtanın DIŞINA boyanmamalı — PİKSEL ölçümü.
//
// 2 Eylül 2026, kullanıcı cihazda: *"Web'deki aynı taşma mobilde de var.
// Onu da web ile birebir hâle getir."* Rozet katmanı zoom matrisini
// izliyor ama HİÇ kırpılmıyordu (`_zoomWrap`in `unclipped` parametresi),
// yani hücresi görünür kareden çıkınca rozet kartın üstüne — başlığın
// içine — çiziliyordu.
//
// ⚠ YAPISAL İDDİA YETMEZ, bu ölçülerek öğrenildi: daha önce rozetin
// atalarında `Stack clipBehavior=Clip.hardEdge` görülüp "port zaten
// kırpıyor" sonucuna varılmıştı. Yanlıştı — `Transform` boyama zamanı
// çalıştığından Stack layout'ta taşma GÖRMÜYOR ve kırpmıyor. Tek güvenilir
// kanıt boyanan piksel.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/player_colors.dart';
import 'package:kelimeki/src/ui/tokens.dart';

import 'board_zoom_test.dart' show pumpZoomGame, doubleTapAt;
import 'game_screen_test.dart' show rackTile, boardCell;

/// [r,g,b] rozetin renklerinden birine yakın mı (dar tolerans: başlıktaki
/// oyuncu kutucuklarının kenarlığı geniş toleransta karışıyor).
bool _rozetRengi(int r, int g, int b) {
  bool yakin(Color c) =>
      ((c.r * 255).round() - r).abs() < 12 &&
      ((c.g * 255).round() - g).abs() < 12 &&
      ((c.b * 255).round() - b).abs() < 12;
  return yakin(kMoveValid) || yakin(kMoveInvalid);
}

void main() {
  testWidgets('zoom: hamle rozeti tahtanın DIŞINA boyanmaz', (tester) async {
    final kok = GlobalKey();
    await pumpZoomGame(tester, boundaryKey: kok);

    // Taş tahtanın ORTASINDA: kenara dayamak yetmiyor (ızgaranın 10 px
    // dolgusu taşmayı yutuyor) ve ilk sütun da yetmiyor (rozet yatayda da
    // kareden çıkıp tamamen kırpılıyor) — web ikizinde ikisi de ölçüldü.
    await tester.tap(rackTile(0));
    await tester.pump();
    await tester.tap(boardCell(6, 6));
    await tester.pump();

    final tahta = tester.getRect(find.byType(BoardWidget));

    Future<int> disaridakiPiksel() async {
      var n = 0;
      await tester.runAsync(() async {
        final b = kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final d = bd!.buffer.asUint8List();
        for (var y = 0; y < img.height; y++) {
          for (var x = 0; x < img.width; x++) {
            final icerde = x >= tahta.left &&
                x <= tahta.right &&
                y >= tahta.top &&
                y <= tahta.bottom;
            if (icerde) continue;
            final i = (y * img.width + x) * 4;
            if (_rozetRengi(d[i], d[i + 1], d[i + 2])) n++;
          }
        }
      });
      return n;
    }

    Future<int> tasDisaridaPiksel() async {
      var n = 0;
      await tester.runAsync(() async {
        final b =
            kok.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        final d = bd!.buffer.asUint8List();
        final tint = playerColors[0].tint;
        for (var y = 0; y < img.height; y++) {
          for (var x = 0; x < img.width; x++) {
            final icerde = x >= tahta.left &&
                x <= tahta.right &&
                y >= tahta.top &&
                y <= tahta.bottom;
            if (icerde) continue;
            final i = (y * img.width + x) * 4;
            if (((tint.r * 255).round() - d[i]).abs() < 12 &&
                ((tint.g * 255).round() - d[i + 1]).abs() < 12 &&
                ((tint.b * 255).round() - d[i + 2]).abs() < 12) {
              n++;
            }
          }
        }
      });
      return n;
    }

    // ⚠ İKİSİ de FARK ölçümü: başlıktaki skor kutucuklarının zemini oyuncu
    // TINT'i, rozet renkleri de kutucuk kenarlıklarına yakın. Mutlak sayım
    // yanlış pozitif veriyor (ölçüldü: "613 piksel taşma" aslında
    // kutucuklardı). Zoom öncesi ↔ sonrası sabit olan her şeyi eliyor.
    final once = await disaridakiPiksel();
    final tasOnce = await tasDisaridaPiksel();

    // Zoom aç (taşın KENDİSİNE değil, komşu boş kareye) ve yukarı kaydır:
    // 6. satır görünür karenin üst kenarına gelir, rozet 14 px yukarı taşar.
    await doubleTapAt(tester, tester.getCenter(boardCell(9, 6)));
    await tester.pumpAndSettle();
    final merkez = tahta.center;
    for (var i = 0; i < 4; i++) {
      await tester.dragFrom(merkez, Offset(0, -tahta.height));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final sonra = await disaridakiPiksel();
    expect(sonra - once, lessThanOrEqualTo(0),
        reason: 'rozet tahtanın dışına ${sonra - once} piksel boyadı');

    // IZGARA da taşmamalı. Portun ızgara kırpması web'inkinden FARKLI
    // (dolgunun içinde, 3,5 px paylı) — bu ölçüm onun görünür bir taşma
    // üretmediğini KANITLIYOR, yani dokunulmasına gerek yok. Ölçmeden
    // "web'de değişti, burada da değiştireyim" demek bugün bir kez daha
    // çalışan kodu bozdu (bkz. `docs/decisions/touch-ux-bugs.md`).
    final tasSonra = await tasDisaridaPiksel();
    expect(tasSonra - tasOnce, lessThanOrEqualTo(0),
        reason: 'ızgara tahtanın dışına ${tasSonra - tasOnce} piksel boyamış');
  });
}
