// Rafın dokunma kutusu ile rafın KENDİSİ arasındaki yarış (31 Ağustos 2026).
//
// SAHA KAYDI (`client_errors`, 26 Ağustos 2026, route=game):
//   RangeError (length): Invalid value: Not in inclusive range 0..5: 6
//   #1 _GameScreenState.build.<anonymous closure>.<anonymous closure>
//   #2 RackWidget._tileTouchArea.<anonymous closure>
//
// MEKANİZMA: `RackWidget` dokunma kutularını ÇİZİLDİĞİ ANDAKİ raf uzunluğuna
// göre kuruyor (`for (var i = 0; i < tiles.length; i++)`). Parmak indiğinde
// raf kısalmışsa — taş tahtaya geçmiş, ya da Canlı oyunda sunucudan bir
// durum güncellemesi gelmiş — `rack[i]` sınır dışına düşüyor ve uygulama
// ErrorBoundary'ye çöküyor.
//
// ⚠ TESTİN YAKLAŞIMI: yarışı zamanlamayla üretmeye ÇALIŞMIYOR (widget
// testinde raf kısaldıktan sonra 7. kutu zaten çizilmez, yani `tap` ile o
// indekse ulaşılamaz — yarışı taklit etmek testi kırılgan ve yalancı
// yapardı). Bunun yerine sahada çöken GERÇEK closure'ı ağaçtan alıp
// doğrudan sınır dışı bir indeksle çağırıyor. Kanıtladığı tam olarak şu:
// "bu geri çağırım, rafta olmayan bir indeksle çağrılırsa çökmez".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki/src/ui/game/game_screen.dart';
import 'package:kelimeki/src/ui/game/rack_widget.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

// Oyun ekranını RAFLI bir durumda açan mevcut yardımcılar — bu testin konusu
// düzenin kendisi değil, tek bir geri çağırım. `game_screen_test.dart`taki
// hazır durumu tekrar yazmak, aynı fikstürün iki kopyasını üretirdi.
import 'game_screen_test.dart' show craftedState;

void main() {
  testWidgets('rafta OLMAYAN indekse dokunuş çökertmez', (tester) async {
    final words = SetWordSource(const ['ab', 'aba']);
    final controller =
        GameController(words: words, autoPlayAi: false, nowIso: () => '');
    controller.dispatch(ResumeSavedAction(craftedState()));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: GameScreen(
          controller: controller, words: words, auth: AuthService.fake()),
    ));
    await tester.pump();

    final rack = tester.widget<RackWidget>(find.byType(RackWidget));
    // Önce testin gerçekten bir şey ölçtüğünü doğrula: sürükleme geri
    // çağırımı bağlı olmasaydı aşağıdaki çağrı hiçbir şey kanıtlamazdı.
    expect(rack.onTilePointerDown, isNotNull,
        reason: 'sürükleme geri çağırımı bağlı değil — test anlamsız olurdu');
    expect(rack.tiles, isNotEmpty);

    // Sahadaki çökmenin birebir şekli: rafın uzunluğunun DIŞINDA bir indeks.
    rack.onTilePointerDown!(
      rack.tiles.length,
      const PointerDownEvent(position: Offset(10, 10)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'raf kısaldıktan sonra gelen dokunuş uygulamayı çökertti');
  });
}
