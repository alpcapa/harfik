// Dokunma hedefi ÖLÇÜMÜ — kaynak deseni değil, EKRANDAKİ kutu.
//
// NEDEN VAR (24 Ağustos 2026): kullanıcı cihazda arka arkaya beş kontrol
// bildirdi ve hepsi aynı cümleyle: *"biraz üstüne basınca çalışıyor"* —
// alt şerit linkleri, "Detaylı Kurallar", "← Geri", avatar. Alt şerit için
// o gün bir düzeltme çıkıldı ama **portta ekrandaki kutu hiç ölçülmedi**:
// `layout_parity_test.dart` yalnızca KAYNAKTA dolgunun durduğunu doğruluyor,
// render edilen boyutu değil. Kullanıcı düzeltmeden sonra da aynı şikayeti
// bildirince bu boşluk görünür oldu.
//
// KÜRESEL BİR KAYMA DEĞİL: eğer dokunuş koordinatları topluca kaysaydı taş
// sürükleme de bozulurdu (tahta hücreleri 390px'te ~24px) — kullanıcı taş
// koyup OYNA'ya basabiliyor. Yani sorun tek tek hedeflerin KÜÇÜKLÜĞÜ.
//
// Bu dosya her hedefin gerçek kutusunu ölçer, CI log'una BASAR (sayılar
// düzeltme turlarında elde kalsın diye) ve Material'ın 48dp asgarisine
// göre iddia eder. Bir hedef bilinçli olarak küçük kalacaksa buraya
// GEREKÇESİYLE bir istisna yazılır — sessizce küçülmesi engellenir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/game_header.dart';
import 'package:kelimeki/src/ui/game/help_modal.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// Material'ın dokunma hedefi asgarisi (`kMinInteractiveDimension`).
const double kMin = 48.0;

Player _player(String name, {required bool isAI, required int index}) => Player(
      name: name,
      corners: cornersFor(2)[index],
      colorIndex: index,
      isAI: isAI,
      surrendered: false,
      rack: const [],
      score: 0,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState _state() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: const [],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        _player('Ben', isAI: false, index: 0),
        _player('Rakip', isAI: false, index: 1),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 5,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

/// Bir metnin/ikonun İÇİNDE bulunduğu dokunulabilirin gerçek kutusu.
/// `GestureDetector` bulunamazsa `InkWell`e düşer; ikisi de yoksa test
/// SESSİZCE geçmesin diye düşer.
Size _tapBox(WidgetTester t, Finder inner, String label) {
  for (final type in [GestureDetector, InkWell]) {
    final f = find.ancestor(of: inner, matching: find.byType(type));
    if (f.evaluate().isNotEmpty) return t.getSize(f.first);
  }
  fail('$label: çevresinde GestureDetector/InkWell YOK — '
      'ayrıştırıcı bayatlamış olabilir, sessizce geçmesin diye düşürüldü');
}

final List<String> _rapor = [];

void _olc(WidgetTester t, Finder inner, String label) {
  final s = _tapBox(t, inner, label);
  _rapor.add('  ${label.padRight(28)} ${s.width.toStringAsFixed(1)} × '
      '${s.height.toStringAsFixed(1)}  (alan ${(s.width * s.height).round()} px²)'
      '${s.height >= kMin ? '' : '   ← 48dp ALTINDA'}');
}

void main() {
  setUpAll(() async {
    await loadRobotoIfAvailable();
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== DOKUNMA HEDEFİ ÖLÇÜMLERİ (390×844) ===\n${_rapor.join('\n')}\n');
  });

  testWidgets('alt şerit linkleri', (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: BoardWidget(
          state: _state(),
          onOpenHistory: () {},
          onOpenMessaging: () {},
          onOpenHelp: () {},
        ),
      ),
    ));
    await tester.pump();

    _olc(tester, find.text('Hamleler'), 'alt şerit: Hamleler');
    _olc(tester, find.text('Mesajlaşma'), 'alt şerit: Mesajlaşma');
    _olc(tester, find.text('Nasıl Oynanır?'), 'alt şerit: Nasıl Oynanır?');
  });

  testWidgets('oyun başlığı: ← Geri ve hesap düğmesi', (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: GameHeader(
            state: _state(), onLogoTap: () {}, auth: AuthService.fake()),
      ),
    ));
    await tester.pump();

    _olc(tester, find.text('← Geri'), 'başlık: ← Geri');
  });

  testWidgets('Nasıl Oynanır? penceresi: Detaylı Kurallar linki',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: const HelpModal(),
    ));
    await tester.pumpAndSettle();

    _olc(tester, find.text('Detaylı Kurallar →'), 'yardım: Detaylı Kurallar');
  });
}
