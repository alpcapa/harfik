// Kart altı PUAN SATIRI (6 Eylül 2026, kullanıcı isteği): "Devam Eden"
// (Canlı + YZ) ve "Son Oynananlar" kartlarında avatarların altında koltuk
// sırasıyla puanlar, " - " ile; "Son Oynananlar"da tarih avatarların
// ÜSTÜNE çıktı. Canlı kartının ve Setup'ın YZ kartının düzeni kendi
// testlerinde (`live_games_test` "Devam Edenler kartı", `setup_screen_test`
// "DEVAM EDEN OYUN"); burada metin sözleşmesi + "Son Oynananlar" düzeni.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/ui/game/player_avatar_row.dart';
import 'package:kelimeki/src/ui/setup/recent_games_section.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/util/score_line.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(loadAppFonts);
  setUp(clearRecentGamesCache);

  test('scoreLine: koltuk sırasıyla, " - " ile (web scoreLine.ts ile birebir)',
      () {
    expect(scoreLine([45, 38]), '45 - 38');
    expect(scoreLine([0, 12, 7, 103]), '0 - 12 - 7 - 103');
    expect(scoreLine(const []), '');
  });

  test('scoresFromPlayersJson: `players` jsonb → puan listesi; bozuk eleman 0',
      () {
    expect(
        scoresFromPlayersJson([
          {'score': 45, 'name': 'A'},
          {'score': 38.0},
          {'name': 'eksik'},
          'çöp',
        ]),
        [45, 38, 0, 0]);
    expect(scoresFromPlayersJson(null), isEmpty);
    expect(scoresFromPlayersJson('x'), isEmpty);
  });

  testWidgets(
      'RecentGamesSection: tarih avatarların ÜSTÜNDE, bitiş puanları '
      'avatarların ALTINDA ve snapshot (avatar) sırasıyla', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-1',
          createdAt: '2026-09-06T12:00:00.000Z',
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

    final tarih = tester.getRect(find.text('06.09.2026'));
    final avatar = tester.getRect(find.byType(PlayerAvatarRow));
    final puan = tester.getRect(find.text('238 - 179'));
    expect(tarih.bottom, lessThanOrEqualTo(avatar.top),
        reason: 'tarih avatarların ÜSTÜNDE olmalı (kullanıcı isteği)');
    expect(puan.top, greaterThanOrEqualTo(avatar.bottom),
        reason: 'bitiş puanları avatarların ALTINDA olmalı');
    // Sağdaki sütunlar (kendi puanım + k-lig) yerinde — puan satırı sol
    // sütuna girdi, sağ blok ETKİLENMEDİ.
    expect(find.text('238'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });
}
