// Oyun İçi Mesajlaşma — Faz 1 (sohbet) + Faz 2 (sessize alma/raporlama).
// ChatRepo (sahte gateway) + ChatModal/ChatSettingsModal widget akışları.
// OnlineGameScreen entegrasyonu (Board footer, Realtime, popup, ilk-ziyaret
// damgalama) `online_game_chat_test.dart`'ta. Gerçek RPC'ler/Realtime
// cihazda doğrulanacak (mobile/TESTING.md, bölüm 11).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/chat_api.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/chat/chat_modal.dart';
import 'package:kelimeki/src/ui/chat/chat_settings_modal.dart';

import 'support/fake_online_gateway.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  group('ChatRepo', () {
    test('messages: ağ hatasında null', () async {
      final gw = FakeChatGateway()..messagesFailWith = Exception('ağ');
      expect(await ChatRepo(gw).messages('g1'), isNull);
    });

    test('messages: başarılı çözümleme', () async {
      final gw = FakeChatGateway()
        ..rows = [chatRow(id: 'm1', senderUserId: 'u1', message: 'Selam')];
      final rows = await ChatRepo(gw).messages('g1');
      expect(rows, hasLength(1));
      expect(rows!.single.message, 'Selam');
    });

    test('send: boş/200 karakter üstü istemci tarafında reddedilir', () async {
      final gw = FakeChatGateway();
      final repo = ChatRepo(gw);
      await expectLater(repo.send('g1', '   '), throwsException);
      await expectLater(
          repo.send('g1', 'x' * 201), throwsException);
      expect(gw.sent, isEmpty); // gateway'e hiç gitmedi

      await repo.send('g1', '  Merhaba  ');
      expect(gw.sent.single, ('g1', 'Merhaba')); // trim edilmiş
    });

    test('myMutes/myActiveReports: ağ hatasında boş set', () async {
      final gw = FakeChatGateway()
        ..mutesFailWith = Exception('ağ')
        ..reportsFailWith = Exception('ağ');
      final repo = ChatRepo(gw);
      expect(await repo.myMutes(), isEmpty);
      expect(await repo.myActiveReports(), isEmpty);
    });

    test('myMutes/myActiveReports: başarılı', () async {
      final gw = FakeChatGateway()
        ..mutes = ['u1', 'u2']
        ..activeReports = ['u2'];
      final repo = ChatRepo(gw);
      expect(await repo.myMutes(), {'u1', 'u2'});
      expect(await repo.myActiveReports(), {'u2'});
    });

    test('report: 500 karakter üstü reddedilir', () async {
      final gw = FakeChatGateway();
      final repo = ChatRepo(gw);
      await expectLater(
          repo.report('g1', 'u1', 'x' * 501), throwsException);
      await expectLater(repo.report('g1', 'u1', '  '), throwsException);
      expect(gw.reportedCalls, isEmpty);

      await repo.report('g1', 'u1', '  spam  ');
      expect(gw.reportedCalls.single, ('g1', 'u1', 'spam'));
    });

    test('setMute/withdrawReports gateway\'e delege eder', () async {
      final gw = FakeChatGateway();
      final repo = ChatRepo(gw);
      await repo.setMute('g1', 'u1', true);
      expect(gw.mutedCalls.single, ('g1', 'u1', true));
      await repo.withdrawReports('u1');
      expect(gw.withdrawnCalls, ['u1']);
    });

    test('subscribe: satırı OnlineGameMessageRow\'a çevirip iletir', () async {
      final gw = FakeChatGateway();
      final repo = ChatRepo(gw);
      OnlineGameMessageRow? received;
      repo.subscribe('g1', (row) => received = row);
      gw.insertListener!(
          chatRow(id: 'm1', senderUserId: 'u1', message: 'Merhaba'));
      expect(received?.message, 'Merhaba');
      expect(received?.senderUserId, 'u1');
    });
  });

  group('ChatModal', () {
    const p1 = ChatParticipant(userId: 'me', name: 'Ironman', colorIndex: 0);
    const p2 = ChatParticipant(userId: 'u2', name: 'Esiner', colorIndex: 1);

    Future<List<String>> pumpModal(
      WidgetTester tester, {
      required List<ChatMessage> messages,
      Set<String> mutedUserIds = const {},
      Set<String> reportedUserIds = const {},
      Future<void> Function(String)? onSend,
      void Function(String)? onOpenParticipantSettings,
      GlobalKey? boundaryKey,
    }) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final sent = <String>[];
      Widget dialog = ChatModal(
        messages: messages,
        participants: const [p1, p2],
        myUserId: 'me',
        onSend: onSend ?? (t) async => sent.add(t),
        onOpenSettings: () {},
        mutedUserIds: mutedUserIds,
        reportedUserIds: reportedUserIds,
        onOpenParticipantSettings: onOpenParticipantSettings ?? (_) {},
      );
      if (boundaryKey != null) {
        dialog = RepaintBoundary(
            key: boundaryKey, child: ColoredBox(color: Colors.white, child: dialog));
      }
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(body: Center(child: dialog)),
      ));
      await tester.pump();
      return sent;
    }

    // Kullanıcı isteği (2 Eylül 2026): "mesaj kutusunun hemen üstüne
    // 'Oyunculara buradan mesaj gönder' yaz". Hint'e EK — hint yazmaya
    // başlayınca kayboluyor. İddia metni DE konumu DA tutuyor: sadece
    // metni aramak, etiket yanlışlıkla listenin altına düşse bile geçerdi.
    testWidgets('mesaj kutusunun ÜSTÜNDE yönlendirme etiketi var',
        (tester) async {
      await pumpModal(tester, messages: const []);
      final etiket = find.text('Oyunculara buradan mesaj gönder');
      expect(etiket, findsOneWidget);
      expect(tester.getBottomLeft(etiket).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy));
      // Hint HÂLÂ duruyor — etiket onun yerine geçmedi.
      expect(find.text('Mesajınızı girin'), findsOneWidget);
    });

    testWidgets(
        'mesajlar en yeni üstte + rozetler + 200 sayaç + boşken Gönder pasif',
        (tester) async {
      final key = GlobalKey();
      await pumpModal(
        tester,
        boundaryKey: key,
        messages: [
          const ChatMessage(
              id: '1',
              senderUserId: 'u2',
              message: 'İlk mesaj',
              createdAt: '2026-08-07T10:00:00Z'),
          const ChatMessage(
              id: '2',
              senderUserId: 'me',
              message: 'İkinci mesaj',
              createdAt: '2026-08-07T10:01:00Z'),
        ],
        mutedUserIds: {'u2'},
      );

      // En yeni ("İkinci mesaj", benim) üstte render edilmeli.
      final positions = tester
          .getTopLeft(find.text('İkinci mesaj'))
          .dy
          .compareTo(tester.getTopLeft(find.text('İlk mesaj')).dy);
      expect(positions, lessThan(0));
      expect(find.text('0/200'), findsOneWidget);
      expect(find.text('🚫'), findsOneWidget); // u2 sessize alınmış

      final sendButton =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Gönder'));
      expect(sendButton.onPressed, isNull);

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/chat_modal.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });

    testWidgets('mesaj yazıp Gönder → onSend çağrılır, alan temizlenir',
        (tester) async {
      final sent = await pumpModal(tester, messages: const []);
      await tester.enterText(find.byType(TextField), 'Merhaba dünya');
      await tester.pump();
      expect(find.text('13/200'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Gönder'));
      await tester.pump();
      await tester.pump();
      expect(sent, ['Merhaba dünya']);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('onSend hata fırlatırsa mesaj satırında gösterilir',
        (tester) async {
      await pumpModal(
        tester,
        messages: const [],
        onSend: (_) async => throw Exception('Mesaj gönderilemedi.'),
      );
      await tester.enterText(find.byType(TextField), 'Deneme');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Gönder'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Mesaj gönderilemedi.'), findsOneWidget);
    });

    testWidgets('başkasının mesajına dokunmak onOpenParticipantSettings çağırır',
        (tester) async {
      String? opened;
      await pumpModal(
        tester,
        messages: const [
          ChatMessage(
              id: '1',
              senderUserId: 'u2',
              message: 'Selam',
              createdAt: '2026-08-07T10:00:00Z'),
        ],
        onOpenParticipantSettings: (id) => opened = id,
      );
      await tester.tap(find.text('Selam'));
      await tester.pump();
      expect(opened, 'u2');
    });

    testWidgets('kendi mesajına dokunmak hiçbir şey yapmaz', (tester) async {
      String? opened;
      await pumpModal(
        tester,
        messages: const [
          ChatMessage(
              id: '1',
              senderUserId: 'me',
              message: 'Kendi mesajım',
              createdAt: '2026-08-07T10:00:00Z'),
        ],
        onOpenParticipantSettings: (id) => opened = id,
      );
      await tester.tap(find.text('Kendi mesajım'));
      await tester.pump();
      expect(opened, isNull);
    });
  });

  group('ChatSettingsModal', () {
    const p1 = ChatParticipant(userId: 'u2', name: 'Esiner', colorIndex: 1);
    const p2 = ChatParticipant(userId: 'u3', name: 'Bobola', colorIndex: 2);

    Future<
        ({
          FakeChatGateway gw,
          List<(String, bool)> muteChanges,
          List<String> reported,
          List<String> withdrawn,
        })> pumpSettings(
      WidgetTester tester, {
      Set<String> mutedUserIds = const {},
      Set<String> reportedUserIds = const {},
      String? initialParticipantId,
    }) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final gw = FakeChatGateway();
      final muteChanges = <(String, bool)>[];
      final reported = <String>[];
      final withdrawn = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: Scaffold(
          body: ChatSettingsModal(
            gameId: 'g1',
            chat: ChatRepo(gw),
            participants: const [p1, p2],
            mutedUserIds: mutedUserIds,
            reportedUserIds: reportedUserIds,
            onMuteChange: (id, m) => muteChanges.add((id, m)),
            onReported: (id) => reported.add(id),
            onWithdrawn: (id) => withdrawn.add(id),
            initialParticipantId: initialParticipantId,
          ),
        ),
      ));
      await tester.pump();
      return (
        gw: gw,
        muteChanges: muteChanges,
        reported: reported,
        withdrawn: withdrawn
      );
    }

    testWidgets('liste: rozetler görünür, satıra dokunmak detay açar',
        (tester) async {
      await pumpSettings(tester,
          mutedUserIds: {'u2'}, reportedUserIds: {'u3'});
      expect(find.text('Esiner'), findsOneWidget);
      expect(find.text('Bobola'), findsOneWidget);
      expect(find.text('🚫'), findsOneWidget); // u2 sessize
      expect(find.text('🚩'), findsOneWidget); // u3 rapor edilmiş (öncelikli)

      await tester.tap(find.text('Esiner'));
      await tester.pump();
      expect(find.text('Kişiyi Sessize Al'), findsOneWidget);
      expect(find.text('KİŞİYİ ŞİKAYET ET'), findsOneWidget);
    });

    testWidgets('initialParticipantId doğrudan detay görünümüyle açar',
        (tester) async {
      await pumpSettings(tester, initialParticipantId: 'u2');
      expect(find.text('Kişiyi Sessize Al'), findsOneWidget);
      expect(find.text('← Geri'), findsOneWidget);
    });

    testWidgets('sessize alma: onay adımı + RPC + callback', (tester) async {
      final h = await pumpSettings(tester, initialParticipantId: 'u2');
      await tester.tap(find.text('Kişiyi Sessize Al'));
      await tester.pump();
      expect(find.text('Emin misiniz?'), findsOneWidget);
      expect(find.text('SESSİZE AL'), findsOneWidget);

      await tester.tap(find.text('SESSİZE AL'));
      await tester.pump();
      await tester.pump();
      expect(h.gw.mutedCalls.single, ('g1', 'u2', true));
      expect(h.muteChanges.single, ('u2', true));
      // Onaydan sonra detaya döner, checkbox işaretli görünür.
      expect(find.text('Kişiyi Sessize Al'), findsOneWidget);
    });

    testWidgets('sessize alma onayında VAZGEÇ RPC çağırmaz', (tester) async {
      final h = await pumpSettings(tester, initialParticipantId: 'u2');
      await tester.tap(find.text('Kişiyi Sessize Al'));
      await tester.pump();
      await tester.tap(find.text('VAZGEÇ'));
      await tester.pump();
      expect(h.gw.mutedCalls, isEmpty);
      expect(find.text('Kişiyi Sessize Al'), findsOneWidget);
    });

    testWidgets(
        'rapor: neden → onay → gönderim → RPC + otomatik sessize alma callback\'i',
        (tester) async {
      final h = await pumpSettings(tester, initialParticipantId: 'u2');
      await tester.tap(find.text('KİŞİYİ ŞİKAYET ET'));
      await tester.pump();
      expect(find.textContaining('neden şikayet ediyorsunuz'), findsOneWidget);

      // Boşken Devam Et pasif.
      final devam =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'DEVAM ET'));
      expect(devam.onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Uygunsuz dil');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'DEVAM ET'));
      await tester.pump();

      expect(find.text('Emin misiniz?'), findsOneWidget);
      expect(find.text('Uygunsuz dil'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ŞİKAYET ET'));
      await tester.pump();
      await tester.pump();

      expect(h.gw.reportedCalls.single, ('g1', 'u2', 'Uygunsuz dil'));
      // Web kararı: rapor otomatik sessize de alır (ChatSettingsModal RPC'si
      // içinde) — istemci tarafı yalnızca `onReported` çağırır, mute'u
      // ÇAĞIRAN (OnlineGameScreen) kendi tarafında ayrıca işaretler; burada
      // yalnızca onReported'ın tetiklendiği doğrulanır.
      expect(h.reported, ['u2']);
      expect(find.text('Şikayetiniz iletildi.'), findsOneWidget);

      await tester.tap(find.text('TAMAM'));
      await tester.pump();
      expect(find.text('Esiner'), findsOneWidget); // listeye döndü
    });

    testWidgets('geri çekme: onay + RPC + callback', (tester) async {
      final h = await pumpSettings(tester,
          initialParticipantId: 'u2', reportedUserIds: {'u2'});
      expect(find.text('Bu kişiyi şikayet ettiniz.'), findsOneWidget);
      await tester.tap(find.text('ŞİKAYETİ GERİ ÇEK'));
      await tester.pump();
      expect(find.text('Emin misiniz?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'ŞİKAYETİ GERİ ÇEK'));
      await tester.pump();
      await tester.pump();
      expect(h.gw.withdrawnCalls, ['u2']);
      expect(h.withdrawn, ['u2']);
      expect(find.text('Esiner'), findsOneWidget); // listeye döndü
    });

    testWidgets('RPC hatası mesaj satırında gösterilir, view değişmez',
        (tester) async {
      final h = await pumpSettings(tester, initialParticipantId: 'u2');
      h.gw.muteFailWith = Exception('ağ hatası');
      await tester.tap(find.text('Kişiyi Sessize Al'));
      await tester.pump();
      await tester.tap(find.text('SESSİZE AL'));
      await tester.pump();
      await tester.pump();
      expect(find.text('İşlem başarısız oldu.'), findsOneWidget);
      expect(h.muteChanges, isEmpty);
    });
  });
}
