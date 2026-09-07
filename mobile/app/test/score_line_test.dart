// Kart altı PUAN SATIRI (6 Eylül 2026, kullanıcı isteği) ve HİZASI.
//
// Kullanıcı ilk sürümü cihazda gördü: *"Puanlar avatarların tam altına
// gelmiyor. Özellikle 4 kişilik oyunda."* Sebep yapısaldı (avatarlar 6 px
// biniyor, akan metin kendi ritmiyle ilerliyor) — bu dosya düzeltmenin
// DEĞİŞMEZİNİ kilitliyor: i'inci puanın merkezi i'inci avatarın merkezi.
// Üç kart da aynı bileşeni (`AvatarScoreRow`) kullanıyor; burada bileşenin
// kendisi + "Son Oynadıklarım"ın dikey sırası ölçülüyor (Canlı kartı
// `live_games_test`, Setup kartı `setup_screen_test`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/ui/game/player_avatar_row.dart';
import 'package:kelimeki/src/ui/setup/recent_games_section.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/util/score_line.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// i'inci avatarın merkezi — şeridin kendi geometrisinden (özel `_Avatar`
/// widget'ına bağlanmadan): sol kenar + `i*adım` + yarıçap.
double _avatarCenter(Rect row, int i, {double size = kAvatarRowSize}) =>
    row.left + i * scoreCellWidth(size, kAvatarRowOverlap) + size / 2;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  setUpAll(loadAppFonts);
  setUp(clearRecentGamesCache);

  test('geometri: hücre eni avatar ADIMI, kaydırma binişmenin yarısı', () {
    // 26 px çap, 6 px binişme → adım 20, kaydırma 3. Web ikizindeki
    // `scoreCellWidth`/`scoreRowOffset` ile aynı formül.
    expect(scoreCellWidth(kAvatarRowSize, kAvatarRowOverlap), 20);
    expect(scoreRowOffset(kAvatarRowOverlap), 3);
    // Hizanın cebiri: hücre merkezi == avatar merkezi, her i için.
    for (var i = 0; i < 4; i++) {
      final hucre = scoreRowOffset(kAvatarRowOverlap) +
          i * scoreCellWidth(kAvatarRowSize, kAvatarRowOverlap) +
          scoreCellWidth(kAvatarRowSize, kAvatarRowOverlap) / 2;
      final avatar = i * scoreCellWidth(kAvatarRowSize, kAvatarRowOverlap) +
          kAvatarRowSize / 2;
      expect(hucre, avatar, reason: '$i. hücre ile $i. avatar merkezi ayrıştı');
    }
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

  // Asıl iddia: 4 kişilik + ÜÇ HANELİ puanlar (kullanıcının bildirdiği en
  // kötü hâl) ve yazı ölçeği tavanı. Tavan bilerek burada: hücre `ScaledCell`
  // DEĞİL (avatarlar ölçekle büyümüyor), yani ölçek hizayı kaydırmamalı.
  for (final olcek in [1.0, kMaxTextScale]) {
    testWidgets('AvatarScoreRow: her puan kendi avatarının merkezinde '
        '(4 kişilik, üç haneli, ölçek $olcek)', (tester) async {
      const puanlar = [238, 179, 103, 87];
      await setPhoneViewSize(tester, const Size(320, 600));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(olcek)),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlayerAvatarRow(players: [
                      AvatarRowPlayer(name: 'Ironman'),
                      AvatarRowPlayer(name: 'Yapay Zeka 2', isAi: true),
                      AvatarRowPlayer(name: 'Yapay Zeka 3', isAi: true),
                      AvatarRowPlayer(name: 'Yapay Zeka 4', isAi: true),
                    ]),
                    AvatarScoreRow(scores: puanlar),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final serit = tester.getRect(find.byType(PlayerAvatarRow));
      for (var i = 0; i < puanlar.length; i++) {
        final puan = tester.getRect(find.text('${puanlar[i]}'));
        expect((puan.center.dx - _avatarCenter(serit, i)).abs(),
            lessThan(0.5),
            reason: '${puanlar[i]} puanı $i. avatarın altında değil '
                '(${puan.center.dx.toStringAsFixed(1)} ↔ '
                '${_avatarCenter(serit, i).toStringAsFixed(1)})');
        // Komşuya değmemeli: hücreler 20 px, üç hane ~15 px.
        if (i > 0) {
          final onceki = tester.getRect(find.text('${puanlar[i - 1]}'));
          expect(puan.left, greaterThan(onceki.right),
              reason: 'puanlar birbirine giriyor');
        }
      }
      // Şerit ile puan satırı aynı eni paylaşır (satır taşmaz).
      final satir = tester.getRect(find.byType(AvatarScoreRow));
      expect(satir.right, lessThanOrEqualTo(serit.right + 0.5));
    });
  }

  testWidgets(
      'RecentGamesSection: tarih avatarların ÜSTÜNDE, bitiş puanları '
      'avatarların ALTINDA ve hizalı', (tester) async {
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
    final serit = tester.getRect(find.byType(PlayerAvatarRow));
    final puanSatiri = tester.getRect(find.byType(AvatarScoreRow));
    expect(tarih.bottom, lessThanOrEqualTo(serit.top),
        reason: 'tarih avatarların ÜSTÜNDE olmalı (kullanıcı isteği)');
    expect(puanSatiri.top, greaterThanOrEqualTo(serit.bottom),
        reason: 'bitiş puanları avatarların ALTINDA olmalı');
    // 238 hem sol sütunda (hizalı puan) hem sağda (kendi skorun) geçiyor:
    // hizayı ölçerken sol sütundakini seç.
    final solPuan = tester.getRect(find.descendant(
        of: find.byType(AvatarScoreRow), matching: find.text('238')));
    expect((solPuan.center.dx - _avatarCenter(serit, 0)).abs(), lessThan(0.5));
    final ikinci = tester.getRect(find.text('179'));
    expect((ikinci.center.dx - _avatarCenter(serit, 1)).abs(), lessThan(0.5));
    // Sağdaki sütunlar (kendi puanım + k-lig) yerinde.
    expect(find.text('+2'), findsOneWidget);
  });
}
