// GameController'ın motor + GERÇEK sözlük asset'iyle uçtan uca doğrulaması.
// Golden senaryo reducer_ai2 (tohum 12345) burada uygulama katmanından
// yeniden oynatılır ve final skorlar fixture'la karşılaştırılır — core'un
// kendi replay testinin üstüne, "uygulamanın kullandığı kablolama da aynı
// sonucu veriyor" katmanını ekler.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/game/game_controller.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

SetWordSource loadWordsFromFile() {
  final f = File('assets/dictionary/words_tr.txt');
  return SetWordSource(
    const LineSplitter().convert(f.readAsStringSync()).where((w) => w.isNotEmpty),
  );
}

void main() {
  late SetWordSource words;

  setUpAll(() {
    words = loadWordsFromFile();
    expect(words.length, greaterThan(60000));
  });

  test('reducer_ai2 golden senaryosu controller üzerinden aynı sonucu verir',
      () {
    final golden = jsonDecode(
      File('../kelimeki_core/test/goldens/reducer_ai2.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final seed = golden['seed'] as int;
    final steps = golden['steps'] as List;
    final lastState = (steps.last as Map)['state'] as Map<String, dynamic>;

    final controller = GameController(
      words: words,
      rng: Mulberry32(seed),
      nowIso: () => '',
      autoPlayAi: false, // deterministik sürüş: adımları elle dispatch
    );
    controller.dispatch(StartAction(const [
      PlayerSetup(name: '', isAI: true),
      PlayerSetup(name: '', isAI: true),
    ]));
    var guard = 0;
    while (!controller.state.isGameOver && guard < 500) {
      controller.dispatch(const AiPlayAction());
      guard++;
    }

    expect(controller.state.isGameOver, isTrue);
    expect(controller.state.turnCount, lastState['turnCount']);
    final expectedScores = [
      for (final p in lastState['players'] as List) (p as Map)['score'] as int
    ];
    expect([for (final p in controller.state.players) p.score], expectedScores);
  });

  test('autoPlayAi sırayı kendiliğinden sürer', () async {
    final controller = GameController(words: words, rng: Mulberry32(7));
    final sawProgress = Completer<void>();
    controller.addListener(() {
      if (!sawProgress.isCompleted && controller.state.turnCount >= 2) {
        sawProgress.complete();
      }
    });
    controller.dispatch(StartAction(const [
      PlayerSetup(name: '', isAI: true),
      PlayerSetup(name: '', isAI: true),
    ]));
    // İnsan müdahalesi olmadan en az iki YZ hamlesi kendiliğinden oynanmalı.
    await sawProgress.future.timeout(const Duration(seconds: 60));
    controller.dispose();
  });
}
