// YZ zorluğunun kartlardaki yüzü (ROADMAP #23 Faz 4): rozet + seviyeli
// k-lig puanı üç kartta — GameOverModal · GameHistoryModal ·
// RecentGamesSection. Kural (6 Eylül 2026, kullanıcı kararı): YZ oyununda
// rozet HER seviyede — Kolay yeşil · Normal turuncu · Zor kırmızı; Canlı
// oyunda rozet YOK. Puan: Kolay birinci +1, Normal +2.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/ui/ai_level_badge.dart';
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki/src/ui/score/game_history_modal.dart';
import 'package:kelimeki/src/ui/setup/recent_games_section.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/tokens.dart';
import 'package:kelimeki/src/util/ai_level.dart';
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
    testWidgets('Kolay golden: başlık altında yeşil "Kolay" rozeti, birinci +1',
        (tester) async {
      final finished = _lastState('reducer_ai2_kolay');
      expect(finished.aiLevel, AiLevel.kolay,
          reason: 'golden bayat — reducer_ai2_kolay aiLevel taşımalı');
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
            body: Center(
                child: GameOverModal(
                    state: finished,
                    onOpenHistory: () {},
                    aiLevel: aiLevelForBadge(finished.aiLevel, isAiGame: true)))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AiLevelBadge), findsOneWidget);
      expect(find.text('Kolay'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Kolay')).style?.color, kGreen);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('+2'), findsNothing);
    });

    testWidgets('Normal golden (YZ ekranı): turuncu "Normal" rozeti, birinci +2',
        (tester) async {
      final finished = _lastState('reducer_ai2');
      expect(finished.aiLevel, isNull);
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
            body: Center(
                child: GameOverModal(
                    state: finished,
                    onOpenHistory: () {},
                    aiLevel: aiLevelForBadge(finished.aiLevel, isAiGame: true)))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AiLevelBadge), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Normal')).style?.color, kOrange);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('Canlı ekran (aiLevel geçirilmez): rozet YOK, puan Normal +2',
        (tester) async {
      final finished = _lastState('reducer_ai2');
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
            body: Center(
                child: GameOverModal(state: finished, onOpenHistory: () {}))),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AiLevelBadge), findsNothing);
      expect(find.text('Normal'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });
  });

  testWidgets(
      'GameHistoryModal: `ai_level: kolay` satırında "Yapay Zeka"nın yanında '
      '"Kolay" rozeti ve +1; Normal satırda "Normal" rozeti, +2; Canlı satırda '
      'rozet YOK', (tester) async {
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
        // Canlı oyun: seviye kavramı yok → rozet HİÇ çizilmez.
        gameRow(
          id: 'g-online',
          createdAt: '2026-09-04T12:00:00.000Z',
          playerScore: 100,
          aiScore: 90,
          rank: 1,
          onlineGameId: 'og-1',
          players: [
            snap('Ironman', 100, colorIndex: 0),
            snap('Esiner', 90, colorIndex: 1),
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
    // İki YZ kartında rozet var, Canlı kartında YOK.
    expect(find.byType(AiLevelBadge), findsNWidgets(2));
    expect(find.text('Kolay'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    // Kolay kartta birinci +1; Normal ve Canlı kartlarında +2.
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2'), findsNWidgets(2));
    // Rozet "Yapay Zeka" rozetinin SAĞINDA, aynı satırda (web sırası).
    final yz = tester.getTopLeft(find.text('Yapay Zeka').first);
    final kolay = tester.getTopLeft(find.text('Kolay'));
    expect(kolay.dx, greaterThan(yz.dx));
    expect((kolay.dy - yz.dy).abs(), lessThan(4));
  });

  testWidgets(
      'RecentGamesSection: Kolay satırında tarihin yanında yeşil rozet ve +1, '
      'Normal satırında turuncu rozet ve +2',
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

    expect(find.byType(AiLevelBadge), findsNWidgets(2));
    expect(find.text('Kolay'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Kolay')).style?.color, kGreen);
    expect(tester.widget<Text>(find.text('Normal')).style?.color, kOrange);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    final tarih = tester.getTopLeft(find.text('06.09.2026'));
    final kolay = tester.getTopLeft(find.text('Kolay'));
    expect(kolay.dx, greaterThan(tarih.dx));
  });
}
