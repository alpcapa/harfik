// Canlı oyun tahtası — Oyun İçi Mesajlaşma entegrasyonu. Board footer'ının
// "Mesajlaşma" butonu, sohbet penceresi/ayarlar paneli açılışı, Realtime ile
// gelen mesajın okunmamış rozeti + popup'ı, sohbet AÇIKKEN gelen mesajın
// canlı güncellenmesi, ve (gerçek depoyla) ilk-ziyaret tanıtım akışı +
// kalıcılık. Gerçek RPC'ler/Realtime cihazda doğrulanacak
// (mobile/TESTING.md, bölüm 11).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/data/chat_api.dart';
import 'package:kelimeki/src/data/online_games_api.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/live/online_game_screen.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_online_gateway.dart';
import 'support/real_io.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

late SetWordSource words;

Player _player(String name,
        {required bool isAI, required int index, required List<Tile> rack}) =>
    Player(
      name: name,
      corners: cornersFor(2)[index],
      colorIndex: index,
      isAI: isAI,
      surrendered: false,
      rack: rack,
      score: 0,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState _baseState() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: List<Tile>.filled(60, const Tile(letter: 'A', pts: 1)),
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [
        _player('Ironman',
            isAI: false,
            index: 0,
            rack: List<Tile>.filled(7, const Tile(letter: 'A', pts: 1))),
        _player('Esiner',
            isAI: false,
            index: 1,
            rack: List<Tile>.filled(7, const Tile(letter: 'A', pts: 1))),
      ],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 0,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

Map<String, Object?> stateJson(GameState s) => {
      'board': [
        for (final row in s.board) [for (final tile in row) tile?.toJson()]
      ],
      'bonuses': {for (final e in s.bonuses.entries) e.key: 'TW'},
      'players': [
        for (final p in s.players)
          {
            'name': p.name,
            'corners': p.corners,
            'colorIndex': p.colorIndex,
            'isAI': p.isAI,
            'surrendered': p.surrendered,
            'rackCount': p.rack.length,
            'score': p.score,
            'bestMoveScore': p.bestMoveScore,
            'bestWordScore': p.bestWordScore,
            'longestWord': p.longestWord,
            'moveCount': p.moveCount,
            'moveScoreSum': p.moveScoreSum,
          }
      ],
      'current': s.current,
      'turn_count': s.turnCount,
      'consecutive_passes': s.consecutivePasses,
      'is_game_over': false,
      'end_reason': null,
      'last_move_cells': const <List<int>>[],
      'bag_count': s.bag.length,
      'started_at': s.startedAt,
    };

int _dbSeq = 0;

/// Gerçek SQLite ffi + gerçek SharedPreferences — sqflite'ın açılışı
/// (`AppStorage.open`) gerçek I/O olduğundan `runAsync` köprüsü şart
/// (feedback/friends testlerindeki aynı ders).
Future<AppStorage> newStorageForWidget(WidgetTester tester) async {
  late AppStorage storage;
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('kelimeki-chat-test');
    storage = await AppStorage.open(
      factory: databaseFactoryFfi,
      path: '${dir.path}/t${_dbSeq++}.db',
      prefs: await SharedPreferences.getInstance(),
      nowMs: () => DateTime.now().millisecondsSinceEpoch,
    );
  });
  return storage;
}

/// Board alt şeridindeki okunmamış-mesaj rozetinin gösterdiği sayı.
/// 16 Ağustos 2026'ya kadar burada sayısız bir kırmızı nokta vardı; rozet
/// sayaca çevrilince testin de sayıyı görmesi gerekti (yalnızca "var/yok"
/// kontrolü, sayacın hiç artmadığı bir regresyonu yakalayamazdı).
String _badgeText() => (find
        .descendant(
          of: find.byKey(const ValueKey('chat-unread-badge')),
          matching: find.byType(Text),
        )
        .evaluate()
        .single
        .widget as Text)
    .data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() async {
    await loadAppFonts();
    final f = File('assets/dictionary/words_tr.txt');
    words = SetWordSource(const LineSplitter()
        .convert(f.readAsStringSync())
        .where((w) => w.isNotEmpty));
  });

  Future<
      ({
        FakeOnlineGamesGateway onlineGw,
        FakeChatGateway chatGw,
      })> pumpScreen(
    WidgetTester tester, {
    Future<AppStorage>? storage,
    bool withChat = true,
  }) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final s = _baseState();
    final onlineGw = FakeOnlineGamesGateway()..stateRow = stateJson(s);
    final chatGw = FakeChatGateway();
    final row = gameRow(
      id: 'g1',
      myId: 'me',
      status: 'active',
      slots: [
        slotHuman('me', name: 'Ironman', relation: 'self'),
        slotHuman('esiner', name: 'Esiner'),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: OnlineGameScreen(
        game: game(row),
        myUserId: 'me',
        onlineGames: OnlineGamesRepo(onlineGw),
        words: words,
        auth: AuthService.fake(user: fakeUser('me')),
        chat: withChat ? ChatRepo(chatGw) : null,
        storage: storage,
      ),
    ));
    await tester.pump();
    await tester.pump();
    return (onlineGw: onlineGw, chatGw: chatGw);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  group('Board footer', () {
    testWidgets('chat verilmezse Mesajlaşma butonu hiç çizilmez',
        (tester) async {
      await pumpScreen(tester, withChat: false);
      expect(find.text('Mesajlaşma'), findsNothing);
      expect(find.text('Hamleler'), findsOneWidget); // öteki link etkilenmedi
      await unmount(tester);
    });

    testWidgets('chat verilmişse buton görünür', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Mesajlaşma'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Sohbet penceresi (storage yok)', () {
    testWidgets(
        'storage null: tanıtım atlanır, doğrudan sohbet açılır, mesaj gönderilir',
        (tester) async {
      final h = await pumpScreen(tester);
      await tester.tap(find.text('Mesajlaşma'));
      await tester.pumpAndSettle();
      // Storage yok → FlagsStore de yok → tanıtım diyaloğu ATLANIR (bilinçli
      // derece bozulma) — doğrudan boş-sohbet metni görünür.
      expect(find.textContaining('hoşgeldiniz'), findsNothing);
      expect(find.text('Henüz mesaj yok. İlk mesajı sen gönder!'),
          findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Selam!');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gönder'));
      await tester.pumpAndSettle();
      expect(h.chatGw.sent.single, ('g1', 'Selam!'));
      await unmount(tester);
    });

    testWidgets('gerçekten katılımcı olan biri Ayarlar\'da görünür, ben hariç',
        (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Mesajlaşma'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      // "Ironman" arkadaki GameHeader'da da geçiyor — Ayarlar diyaloğuna
      // (en üstteki Dialog) daraltılmış finder kullanılmalı.
      final settingsDialog = find.byType(Dialog).last;
      expect(
          find.descendant(of: settingsDialog, matching: find.text('Esiner')),
          findsOneWidget);
      expect(
          find.descendant(of: settingsDialog, matching: find.text('Ironman')),
          findsNothing); // kendisi hariç
      await unmount(tester);
    });

    // Realtime kanalı arka planda askıya alınırsa o sırada gelen mesaj
    // KALICI olarak kaybolur (postgres_changes canlı bir akış, kaçırılan
    // olayı tekrar oynatmaz) — oyun state'i bunu resume tazelemesiyle
    // kurtarıyordu, sohbet kurtarmıyordu: tek çare ekrandan çıkıp girmekti
    // (14 Ağustos 2026, iki cihazla yazışırken bildirildi).
    // Negatif eş: `didChangeAppLifecycleState`ten `_fetchChat()` çağrısı
    // kaldırılırsa bu test düşer.
    testWidgets('ön plana dönüşte sohbet tazelenir (kaçırılan mesaj gelir)',
        (tester) async {
      final h = await pumpScreen(tester);
      expect(h.chatGw.messagesCalls, 1);

      // Arka plandayken bir mesaj geldi: sunucuda var ama Realtime olayı
      // bu istemciye HİÇ ulaşmadı (insertListener bilerek çağrılmıyor).
      h.chatGw.rows = [
        chatRow(id: 'm1', senderUserId: 'esiner', message: 'Kaçırılan mesaj')
      ];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(h.chatGw.messagesCalls, greaterThan(1));
      // Popup AÇILMAMALI (yalnızca Realtime dalı açar) ama mesaj sohbette
      // olmalı — okunmamış rozeti kullanıcıyı zaten oraya çağırıyor.
      expect(find.text('CEVAP VER'), findsNothing);
      await tester.tap(find.text('Mesajlaşma').last);
      await tester.pumpAndSettle();
      expect(find.text('Kaçırılan mesaj'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
        'Realtime: sessize alınmamış mesaj → sayaç rozeti + popup; '
        'CEVAP VER sohbeti açar', (tester) async {
      final h = await pumpScreen(tester);
      // Board rozeti başta yok (unreadMessageCount 0).
      expect(find.byKey(const ValueKey('chat-unread-badge')), findsNothing);
      h.chatGw.insertListener!(
          chatRow(id: 'm1', senderUserId: 'esiner', message: 'Merhaba!'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chat-unread-badge')), findsOneWidget);

      // Popup: gönderen adı + mesaj + iki buton.
      expect(find.text('Esiner'), findsOneWidget);
      expect(find.text('Merhaba!'), findsOneWidget);
      expect(find.text('CEVAP VER'), findsOneWidget);
      expect(find.text('KAPAT'), findsOneWidget);

      // Zemine dokunmak popup'ı KAPATMAZ — web'de de kapatmıyor (kabın
      // hiç onClick'i yok). Flutter'ın varsayılanı bunun tersi olduğundan
      // kullanıcıya mesaj "kendiliğinden kayboluyor" gibi görünüyordu.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Merhaba!'), findsOneWidget);
      expect(find.text('CEVAP VER'), findsOneWidget);

      await tester.tap(find.text('CEVAP VER'));
      await tester.pumpAndSettle();
      // Sohbet açıldı, mesaj thread'de.
      expect(find.text('Mesajlaşma'), findsWidgets); // başlık + footer linki
      expect(find.text('Merhaba!'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
        'sessize alınmış gönderenin mesajı popup AÇMAZ ama sayaç rozeti '
        'ÇIKAR ve thread\'e girer', (tester) async {
      final onlineGw = FakeOnlineGamesGateway()
        ..stateRow = stateJson(_baseState());
      final chatGw = FakeChatGateway()..mutes = ['esiner'];
      await setPhoneViewSize(tester, const Size(420, 900));
      final row = gameRow(
        id: 'g1',
        myId: 'me',
        status: 'active',
        slots: [
          slotHuman('me', name: 'Ironman', relation: 'self'),
          slotHuman('esiner', name: 'Esiner'),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: OnlineGameScreen(
          game: game(row),
          myUserId: 'me',
          onlineGames: OnlineGamesRepo(onlineGw),
          words: words,
          auth: AuthService.fake(user: fakeUser('me')),
          chat: ChatRepo(chatGw),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-unread-badge')), findsNothing);

      chatGw.insertListener!(
          chatRow(id: 'm1', senderUserId: 'esiner', message: 'Gizli mesaj'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('CEVAP VER'), findsNothing); // popup açılmadı
      // Ama rozet ÇIKAR — mute yalnızca popup'ı bastırır
      // (15 Ağustos 2026, kullanıcı kararı).
      expect(find.byKey(const ValueKey('chat-unread-badge')), findsOneWidget);
      expect(_badgeText(), '1');

      // Rozet SAYAR — 16 Ağustos 2026'da sayısız kırmızı nokta yerine
      // `CountBadge` geldi (kullanıcı: "insanlar noktayı farketmiyor").
      chatGw.insertListener!(
          chatRow(id: 'm2', senderUserId: 'esiner', message: 'Gizli mesaj 2'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_badgeText(), '2');

      await tester.tap(find.text('Mesajlaşma'));
      await tester.pumpAndSettle();
      expect(find.text('Gizli mesaj'), findsOneWidget); // ama thread'de var
      // Rozet her balonda çizilir; yukarıda sayacı 2'ye çıkarmak için AYNI
      // susturulmuş gönderenden ikinci bir mesaj eklendiğinden 🚫 de iki tane.
      expect(find.text('Gizli mesaj 2'), findsOneWidget);
      expect(find.text('🚫'), findsNWidgets(2)); // rozet, mesaj başına bir
      await unmount(tester);
    });

    testWidgets('sohbet AÇIKKEN gelen mesaj popup açmadan thread\'i günceller',
        (tester) async {
      final h = await pumpScreen(tester);
      await tester.tap(find.text('Mesajlaşma'));
      await tester.pumpAndSettle();

      h.chatGw.insertListener!(
          chatRow(id: 'm1', senderUserId: 'esiner', message: 'Canlı mesaj'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Canlı mesaj'), findsOneWidget);
      expect(find.text('CEVAP VER'), findsNothing); // popup açık DEĞİL
      await unmount(tester);
    });
  });

  group('Sohbet — gerçek depo (ilk-ziyaret tanıtımı + kalıcılık)', () {
    testWidgets(
        'ilk açılışta tanıtım gösterilir; Devam → sohbet açılır + bayrak kalıcı',
        (tester) async {
      final storage = await newStorageForWidget(tester);
      await pumpScreen(tester, storage: Future.value(storage));
      await drainRealIo(tester);

      await tester.tap(find.text('Mesajlaşma'));
      await tester.pumpAndSettle();
      expect(find.text('Oyun içi mesajlaşmaya hoşgeldiniz!'), findsOneWidget);

      await tester.tap(find.text('DEVAM'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz mesaj yok. İlk mesajı sen gönder!'),
          findsOneWidget);

      await tester.runAsync(() async {
        expect(storage.flags.seenChatIntro, isTrue);
      });
      // `_openChatModal` içindeki `unawaited(_markChatReadTo(...))` gerçek
      // bir sqflite yazması başlatır — sqflite'ın dahili ~10sn'lik yazma
      // kilidi uyarı Timer'ı bu yazma GERÇEK zamanda tamamlanıp iptal
      // olana kadar bekler. Sahte zamanda `unmount` çağrılırsa bu timer
      // hâlâ bekliyor sayılır ve "Timer is still pending" ile test düşer —
      // kısa bir gerçek-zaman uykusu yazmanın bitmesine yetiyor.
      await drainRealIo(tester);
      await unmount(tester);
    });

    testWidgets('tanıtımı görmüş kullanıcı bir daha görmez', (tester) async {
      final storage = await newStorageForWidget(tester);
      await tester.runAsync(() => storage.flags.markChatIntroSeen());

      await pumpScreen(tester, storage: Future.value(storage));
      await drainRealIo(tester);
      await tester.tap(find.text('Mesajlaşma'));
      await tester.pumpAndSettle();
      expect(find.text('Oyun içi mesajlaşmaya hoşgeldiniz!'), findsNothing);
      expect(find.text('Henüz mesaj yok. İlk mesajı sen gönder!'),
          findsOneWidget);
      // Aynı gerçek-zaman bekleyişi — bkz. yukarıdaki yorum.
      await drainRealIo(tester);
      await unmount(tester);
    });
  });
}
