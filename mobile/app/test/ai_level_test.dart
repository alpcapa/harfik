// YZ zorluğunun kartlardaki yüzü (ROADMAP #23 Faz 4): rozet + seviyeli
// k-lig puanı üç kartta — GameOverModal · GameHistoryModal ·
// RecentGamesSection. Web eşleri Faz 3'te aynı kuralla çizildi:
// Normal/null'da rozet YOK ve puan bugünkü tablo (kartlar bayt bayt aynı);
// Kolay'da altın "Kolay" rozeti ve birinci +1 (Normal +2).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/ai_level_badge.dart';
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki/src/ui/score/game_history_modal.dart';
import 'package:kelimeki/src/ui/setup/recent_games_section.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

GameState _lastState(String golden) {
  final g = jsonDecode(
    File('../kelimeki_core/test/goldens/$golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final steps = g['steps'] as List;
  return gameStateFromJson(
      ((steps.last as Map)['state'] as Map).cast<String, Object?>());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(loadAppFonts);
  setUp(clearRecentGamesCache);

  group('GameOverModal', () {
    testWidgets('Kolay golden: başlık altında "Kolay" rozeti, birinci +1',
        (tester) async {
      final finished = _lastState('reducer_ai2_kolay');
      expect(finished.aiLevel, AiLevel.kolay,
          reason: 'golden bayat — reducer_ai2_kolay aiLevel taşımalı');
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
            body: Center(
                child: GameOverModal(state: finished, onOpenHistory: () {}))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AiLevelBadge), findsOneWidget);
      expect(find.text('Kolay'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+2'), findsNothing);
    });

    testWidgets('Normal golden: rozet YOK, birinci +2 (bugünkü kart)',
        (tester) async {
      final finished = _lastState('reducer_ai2');
      expect(finished.aiLevel, isNull);
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
            body: Center(
                child: GameOverModal(state: finished, onOpenHistory: () {}))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AiLevelBadge), findsNothing);
      expect(find.text('Kolay'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });
  });

  testWidgets(
      'GameHistoryModal: `ai_level: kolay` satırında "Yapay Zeka"nın yanında '
      '"Kolay" rozeti ve +1; Normal satırda rozet yok, +2', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-kolay',
          createdAt: '2026-09-06T12:00:00.000Z',
          playerScore: 238,
          aiScore: 179,
          rank: 1,
          aiLevel: 'kolay',
          players: [
            snap('Ironman', 238, colorIndex: 0),
            snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
          ],
        ),
        gameRow(
          id: 'g-normal',
          createdAt: '2026-09-05T12:00:00.000Z',
          playerScore: 238,
          aiScore: 179,
          rank: 1,
          players: [
            snap('Ironman', 238, colorIndex: 0),
            snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
          ],
        ),
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: GameHistoryModal(
          games: repo,
          userId: 'u-me',
          playerCount: null,
          currentName: 'Ironman',
          isMe: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Yapay Zeka'), findsNWidgets(2));
    expect(find.byType(AiLevelBadge), findsOneWidget);
    expect(find.text('Kolay'), findsOneWidget);
    // Kolay kartta birinci +1, Normal kartta +2.
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    // Rozet "Yapay Zeka" rozetinin SAĞINDA, aynı satırda (web sırası).
    final yz = tester.getTopLeft(find.text('Yapay Zeka').first);
    final kolay = tester.getTopLeft(find.text('Kolay'));
    expect(kolay.dx, greaterThan(yz.dx));
    expect((kolay.dy - yz.dy).abs(), lessThan(4));
  });

  testWidgets(
      'RecentGamesSection: Kolay satırında tarihin yanında rozet ve +1',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-kolay',
          createdAt: '2026-09-06T12:00:00.000Z',
          rank: 1,
          aiLevel: 'kolay',
          players: [
            snap('Ironman', 238, colorIndex: 0),
            snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
          ],
        ),
        gameRow(
          id: 'g-normal',
          createdAt: '2026-09-05T12:00:00.000Z',
          rank: 1,
          players: [
            snap('Ironman', 238, colorIndex: 0),
            snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
          ],
        ),
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 600));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
          games: repo,
          userId: 'u-me',
          onlineOnly: false,
          currentName: 'Ironman',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AiLevelBadge), findsOneWidget);
    expect(find.text('Kolay'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    final tarih = tester.getTopLeft(find.text('06.09.2026'));
    final kolay = tester.getTopLeft(find.text('Kolay'));
    expect(kolay.dx, greaterThan(tarih.dx));
  });
}
