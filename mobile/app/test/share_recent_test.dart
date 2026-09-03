// Paylaşma + "Son Oynadıklarım" (parça 5c).
//
// Paylaşım gerçek platform kanalına (share_plus/path_provider) GİTMEZ:
// `GameHistoryModal` paylaşımı `ShareBoardFn` olarak alıyor, test sahte bir
// fonksiyonla AKIŞI doğruluyor (markShared → görsel yakala → paylaş).
// Gerçek paylaş sayfası cihazda doğrulanır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/games_api.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/score/game_history_modal.dart';
import 'package:kelimeki/src/util/share_board.dart';
import 'package:kelimeki/src/ui/score/score_box_row.dart';
import 'package:kelimeki/src/ui/setup/recent_games_section.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_games_gateway.dart';
import 'support/game_rows.dart';
import 'support/test_fonts.dart';
import 'support/test_view.dart';

/// Paylaş çağrısının kaydı.
class _ShareCall {
  final Uint8List? png;
  final String text;
  final String? url;
  final Rect? origin;
  _ShareCall(this.png, this.text, this.url, this.origin);
}

List<Map<String, Object?>> _tiles() => [
      {'r': 0, 'c': 0, 'l': 'K', 'o': 0},
      {'r': 0, 'c': 1, 'l': 'E', 'o': 0},
      {'r': 0, 'c': 2, 'l': 'L', 'o': 0},
      {'r': 6, 'c': 6, 'l': 'A', 'o': 1},
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(loadAppFonts);
  setUp(clearRecentGamesCache);

  Future<List<_ShareCall>> pumpHistoryWithShare(
    WidgetTester tester,
    GamesRepo repo, {
    String? initialExpandedId,
    Key? boundaryKey,
  }) async {
    final calls = <_ShareCall>[];
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          body: GameHistoryModal(
            games: repo,
            userId: 'u-me',
            playerCount: null,
            currentName: 'Ironman',
            initialExpandedId: initialExpandedId,
            share: ({
              required png,
              required text,
              required url,
              required origin,
            }) async {
              calls.add(_ShareCall(png, text, url, origin));
            },
            // Gerçek `toImage` sahte zamanda tamamlanmıyor (bkz.
            // CaptureBoardFn notu) — akış testinde sahte bayt, gerçek
            // yakalama ayrı bir testte `runAsync` ile doğrulanıyor.
            capture: (_) async => Uint8List.fromList(List.filled(2048, 7)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return calls;
  }

  testWidgets('paylaş: önce set_game_shared, sonra görsel + link',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g1', players: [
          snap('Ironman', 150, colorIndex: 0),
          snap('Yapay Zeka 2', 120, ai: true, colorIndex: 1),
        ])
      ]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    final calls = await pumpHistoryWithShare(tester, repo);

    // Kartı aç → tahta gelir.
    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreBoxRow), findsOneWidget);

    // Tahtaya dokun → aksiyon menüsü.
    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    expect(find.text('Paylaş'), findsOneWidget);
    expect(find.text('Kapat'), findsOneWidget);
    // 13 Ağustos 2026 — ayrı "Vazgeç" paneli iki platformdan da kaldırıldı
    // (kullanıcı kararı: aksiyonlardan biri zaten "Kapat", ikisi aynı işi
    // yapıyormuş gibi okunuyordu). Bkz. Parça 85.
    expect(find.text('Vazgeç'), findsNothing);

    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    expect(gw.sharedGames, ['g1']); // link ancak bu bayrakla çalışır
    expect(calls, hasLength(1));
    expect(calls.single.text, "Kelimeki'deki şu oyunu görmeni istedim.");
    expect(calls.single.url, 'https://kelimeki.com/game/g1');
    // Görsel paylaşıma iletildi (yakalayıcı çağrıldı).
    expect(calls.single.png, isNotNull);
    expect(calls.single.png!.length, greaterThan(1000));

    // iPad ankrajı (Parça 86): share_plus'ın iOS eklentisi, iPad'de origin
    // BOŞ ya da kök view'ın DIŞINDA ise paylaşmak yerine FlutterError
    // döndürüyor — yani ankraj vermemek paylaşımı sessizce öldürüyor.
    // Web derlemesinde bu hiç görünmez (orada `navigator.share` kullanılıyor),
    // o yüzden sözleşme burada pinleniyor.
    final origin = calls.single.origin;
    expect(origin, isNotNull);
    expect(origin!.isEmpty, isFalse, reason: 'CGRectIsEmpty olmamalı');
    final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.contains(origin.topLeft), isTrue);
    expect(screen.contains(origin.bottomRight - const Offset(0.01, 0.01)), isTrue,
        reason: 'ankraj kök view koordinat uzayının İÇİNDE kalmalı');
    // ⚠ ÜÇÜNCÜ İDDİA — 2 Eylül 2026'da EKLENDİ, çünkü yukarıdaki ikisi
    // GERÇEK BİR HATAYI KAÇIRDI. Ekranın tamamını kaplayan bir ankraj hem
    // "boş değil" hem "içeride"dir, yani ikisinden de geçer; ama iPad'de
    // popover görünmüyor ve `SharePlus.share` HİÇ DÖNMÜYOR (Appetize,
    // iPad Air / iOS 16.2). İki çağrı yeri tam bu yüzden kırıktı ve testler
    // yeşildi. İddia "küçük olsun" DEĞİL — tahtanın ankrajı meşru biçimde
    // büyük; ankraj kök view'ın KENDİSİ olmasın.
    expect(origin.width < screen.width * 0.95 ||
        origin.height < screen.height * 0.95,
        isTrue,
        reason: 'ankraj ekranın tamamı OLMAMALI — öyleyse `State.context` '
            'geçilmiş demektir ve iPad\'de popover görünmez');

    // Paylaşılacak GÖRSELİN kendisi: aynı düğümü gerçek yakalayıcıyla
    // çekip diske yazıyoruz — ekran görüntüsü, paylaşılan PNG'nin birebir
    // aynısı (skor şeridi + tahta).
    await tester.runAsync(() async {
      final boundary = tester
          .renderObject<RenderRepaintBoundary>(find.ancestor(
              of: find.byType(ScoreBoxRow),
              matching: find.byType(RepaintBoundary))
            .first);
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/share_image.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });

  testWidgets('paylaş: işaretleme düşerse LİNKSİZ paylaşılır', (tester) async {
    final gw = _NoShareMarkGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g1')]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    final calls = await pumpHistoryWithShare(tester, repo);

    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();

    expect(calls.single.url, isNull);
    expect(calls.single.text, isNotEmpty);
  });

  testWidgets('menüdeki "Kapat" tahtayı kapatır', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g1')]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistoryWithShare(tester, repo);

    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    expect(find.byType(ScoreBoxRow), findsOneWidget);

    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.byType(ScoreBoxRow), findsNothing);
  });

  // "Vazgeç" paneli kalkınca aksiyonsuz çıkış yolu KAYBOLMAMALI —
  // `showModalBottomSheet`'in zemin dokunuşu hâlâ menüyü kapatmalı ve
  // hiçbir `onSelect` çalışmamalı (tahta AÇIK kalır, paylaşım gitmez).
  // Bu, Vazgeç'in kaldırılmasının kullanıcıyı kapana kıstırMADIĞININ kanıtı.
  testWidgets('zemine dokunmak menüyü aksiyonsuz kapatır (Vazgeç yerine)',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g1')]
      ..snapshots = {'g1': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    final calls = await pumpHistoryWithShare(tester, repo);

    await tester.tap(find.text('01.08.2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ScoreBoxRow));
    await tester.pumpAndSettle();
    expect(find.text('Paylaş'), findsOneWidget);

    // Menünün DIŞINA (ekranın üst kenarına) dokun.
    await tester.tapAt(const Offset(210, 30));
    await tester.pumpAndSettle();

    expect(find.text('Paylaş'), findsNothing, reason: 'menü kapanmalı');
    expect(find.byType(ScoreBoxRow), findsOneWidget,
        reason: 'tahta AÇIK kalmalı — "Kapat" seçilmedi');
    expect(calls, isEmpty, reason: 'paylaşım tetiklenmemeli');
    expect(gw.sharedGames, isEmpty);
  });

  testWidgets('initialExpandedId: hedef ilk sayfada YOKSA sayfalanır ve açılır',
      (tester) async {
    // 30 kayıt, hedef 25. sırada → ilk sayfa (20) yetmiyor; web'in aynı
    // düzeltmesi: hedef bulunana kadar sayfa sayfa çekilir.
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        for (var i = 0; i < 30; i++)
          gameRow(
            id: 'g$i',
            createdAt: '2026-07-${(i % 28 + 1).toString().padLeft(2, '0')}'
                'T12:00:00.000Z',
            players: [
              snap('Ironman', 150 - i, colorIndex: 0),
              snap('Yapay Zeka 2', 100, ai: true, colorIndex: 1),
            ],
          )
      ]
      ..snapshots = {'g25': _tiles()};
    final repo = await newRepoForWidget(tester, gw);
    await pumpHistoryWithShare(tester, repo, initialExpandedId: 'g25');

    // İki sayfa çekildi (20 + kalan) ve hedefin tahtası AÇIK.
    expect(gw.listCalls.length, greaterThanOrEqualTo(2));
    expect(find.byType(ScoreBoxRow), findsOneWidget);

    // Kart görünür alanda ve makul biçimde ortalanmış olmalı.
    final box = tester.getRect(find.byType(ScoreBoxRow));
    final screen = tester.getRect(find.byType(MaterialApp));
    expect(box.top, greaterThanOrEqualTo(screen.top));
    expect(box.bottom, lessThanOrEqualTo(screen.bottom));
  });

  testWidgets('Son Oynadıklarım: satır + ekran görüntüsü', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
          id: 'g-ai',
          createdAt: '2026-08-03T09:30:00.000Z',
          playerScore: 238,
          aiScore: 179,
          rank: 1,
          players: [
            snap('Ironman', 238, colorIndex: 0),
            snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
          ],
        ),
        gameRow(
          id: 'g-ai2',
          createdAt: '2026-08-01T12:00:00.000Z',
          playerCount: 4,
          playerScore: 120,
          aiScore: 190,
          rank: 3,
          players: [
            snap('Yapay Zeka 2', 190, ai: true, colorIndex: 1),
            snap('Yapay Zeka 3', 150, ai: true, colorIndex: 2),
            snap('Ironman', 120, colorIndex: 0),
            snap('Yapay Zeka 4', 90, ai: true, colorIndex: 3),
          ],
        ),
        // Canlı oyun: onlineOnly=false filtresiyle GÖRÜNMEMELİ.
        gameRow(id: 'g-online', onlineGameId: 'og-1'),
      ]
      ..snapshots = {'g-ai': _tiles()};
    final repo = await newRepoForWidget(tester, gw);

    final key = GlobalKey();
    await setPhoneViewSize(tester, const Size(420, 520));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RecentGamesSection(
                games: repo,
                userId: 'u-me',
                onlineOnly: false,
                currentName: 'Ironman',
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('SON OYNADIKLARIM'), findsOneWidget);
    expect(find.text('TÜM OYUNLARIM'), findsOneWidget);
    expect(find.text('03.08.2026'), findsOneWidget);
    expect(find.text('01.08.2026'), findsOneWidget);
    expect(find.text('238'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget); // 2 kişilik birincilik
    expect(find.text('-'), findsOneWidget); // 4 kişilik 3.lük puan getirmez
    // Canlı oyun bu sekmede yok (onlineOnly filtresi sunucuda uygulanıyor).
    expect(gw.listCalls, isNotEmpty);

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots')..createSync(recursive: true);
      File('${dir.path}/recent_games.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });

  testWidgets('captureBoundaryAsPng gerçek PNG üretir', (tester) async {
    // Paylaşılan görselin GERÇEK yolu: RepaintBoundary → toImage → PNG.
    // `runAsync` şart — sahte zamanda toImage hiç tamamlanmıyor.
    final key = GlobalKey();
    await setPhoneViewSize(tester, const Size(200, 200));
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: const ColoredBox(color: Colors.red, child: SizedBox(width: 100, height: 100)),
      ),
    ));
    await tester.pumpAndSettle();

    Uint8List? png;
    await tester.runAsync(() async {
      png = await captureBoundaryAsPng(key);
    });
    expect(png, isNotNull);
    // PNG imzası: 89 50 4E 47
    expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  // 9 Ağustos 2026 — cihaz testinde "Paylaş çalışmıyor, tepki yok" bildirildi.
  // Kök sebep: `shareBoard`ın TEK `catch`i her şeyi yutuyordu; geçici dosya
  // yazımı (path_provider) başarısız olursa kullanıcıya hiçbir şey
  // gösterilmiyordu. Web `handleShare` ise dosyalı paylaşım mümkün değilse
  // (`navigator.canShare({files})` false) DOSYASIZ metin+link paylaşımına
  // düşüyor — port bu ikinci basamağı hiç taşımamıştı. Bu test tam o
  // basamağı doğruluyor: path_provider mock'lanMADIĞINDAN
  // `getTemporaryDirectory()` MissingPluginException fırlatır, akış metin
  // paylaşımına düşmeli ve share kanalına metin+link GİTMELİ.
  testWidgets('görselli paylaşım olmazsa metin+link paylaşımına düşer',
      (tester) async {
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        calls.add(call);
        return '';
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null));

    await tester.runAsync(() async {
      await shareBoard(
        png: Uint8List.fromList([1, 2, 3]), // geçerli bayt: dosya yolu denenir
        text: shareMessage,
        url: 'https://kelimeki.com/game/a',
        origin: const Rect.fromLTWH(10, 20, 30, 40),
      );
    });

    expect(calls, hasLength(1), reason: 'yedek metin paylaşımı çağrılmalı');
    final args = calls.single.arguments as Map;
    expect(args['text'],
        '$shareMessage\nhttps://kelimeki.com/game/a');
    // Dosya yolu YOK — görselli dal başarısız olduğu için metne düşüldü.
    expect(args['uri'], isNull);
  });

  // 13 Ağustos 2026 — cihaz testinde "app tahta yerine jenerik Kelimeki
  // görselini gönderiyor, web gerçek tahtayı gönderiyor" bildirildi. Kök
  // sebep: görselli dal `dart:io` `File` + `path_provider` ile geçici dosya
  // yazıyordu, ikisi de Flutter web'de çalışmadığından dal HER SEFERİNDE
  // patlayıp metin+link yedeğine düşüyordu (WhatsApp da linkten sitenin
  // GENEL og:image kartını üretiyordu). Bu test görselli dalın GERÇEKTEN
  // alındığını ve kanala doğru adlı/tipli PNG'nin gittiğini sabitliyor.
  //
  // DOĞRULAMA SINIRI (dürüst kayıt): hatanın KENDİSİ bu testte
  // ÜRETİLEMEZ — native VM'de `dart:io` çalışır, yani eski kod da bu testi
  // geçerdi. Web tarafı ayrıca gerçek CanvasKit derlemesinde ölçüldü
  // (bkz. Parça 84 notu). Buradaki değer, sözleşmenin (veri destekli
  // XFile + fileNameOverrides → doğru ad/tip/bayt) kalıcı olarak
  // pinlenmesi.
  testWidgets('görselli paylaşım: kanala kelimeki.png + PNG baytları gider',
      (tester) async {
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final calls = <MethodCall>[];
    final tempRoot = Directory.systemTemp.createTempSync('kelimeki_share_');

    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
      calls.add(call);
      return '';
    });
    // share_plus, path'i BOŞ olan bir XFile'ı kendisi geçici dizine yazar
    // (`method_channel_share.dart`, `_getFile`) — yani dosya yazma işi
    // bizden kütüphaneye geçti; bu mock o yolu açıyor.
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
      return call.method == 'getTemporaryDirectory' ? tempRoot.path : null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null);
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      tempRoot.deleteSync(recursive: true);
    });

    // Gerçek bir PNG imzası — mimeType tahminine değil bize bağlı olmalı.
    final png = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
    await tester.runAsync(() async {
      await shareBoard(
        png: png,
        text: shareMessage,
        url: 'https://kelimeki.com/game/a',
        origin: const Rect.fromLTWH(10, 20, 30, 40),
      );
    });

    expect(calls, hasLength(1), reason: 'görselli dal metne DÜŞMEMELİ');
    final args = calls.single.arguments as Map;
    expect(args['text'], '$shareMessage\nhttps://kelimeki.com/game/a');
    expect(args['mimeTypes'], ['image/png']);
    // iPad ankrajı KANALA ulaşmalı (Parça 86) — iOS eklentisi bu dört alanı
    // okuyup popover sourceRect'ini kuruyor; boş gelirse iPad'de paylaşmak
    // yerine FlutterError döndürüyor.
    expect(args['originX'], 10.0);
    expect(args['originY'], 20.0);
    expect(args['originWidth'], 30.0);
    expect(args['originHeight'], 40.0);

    final paths = (args['paths'] as List).cast<String>();
    expect(paths, hasLength(1));
    // `fileNameOverrides` olmadan native'de ad kaybolur (`cross_file`ın io
    // uygulaması `name`i yok sayıyor — paket belgesinde yazılı).
    expect(paths.single, endsWith('/kelimeki.png'));
    expect(File(paths.single).readAsBytesSync(), png);
  });

  testWidgets('Son Oynadıklarım: hiç bitmiş oyun yoksa bölüm GİZLİ',
      (tester) async {
    final repo =
        await newRepoForWidget(tester, FakeGamesGateway(userId: 'u-me'));
    await setPhoneViewSize(tester, const Size(420, 520));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: false),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SON OYNADIKLARIM'), findsNothing);
  });

  testWidgets('Son Oynadıklarım: satıra dokunmak geçmişi O OYUNLA açar',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g-ai', players: [
          snap('Ironman', 238, colorIndex: 0),
          snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
        ])
      ]
      ..snapshots = {'g-ai': _tiles()};
    final repo = await newRepoForWidget(tester, gw);

    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: false),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('238'));
    await tester.pumpAndSettle();

    expect(find.text('TÜM OYUNLAR'), findsOneWidget);
    // Hedef oyunun tahtası ayrıca dokunmaya gerek kalmadan AÇIK geldi.
    expect(find.byType(ScoreBoxRow), findsOneWidget);
  });

  // 3 Eylül 2026, kullanıcı: *"YZ'de oyun bitti yazmasına gerek yok. Bu
  // sadece canlı oyunlar için geçerli."* Gerekçe: YZ oyunu SENİN cihazında
  // bitiyor, bitişini zaten gözünle görüyorsun — orada etiket bilgi taşımaz.
  // Canlı'da ise oyun sen yokken bitiyor, asıl mesele o.
  // ⚠⚠ 3 Eylül 2026, kullanıcı CİHAZDA bildirdi: *"Son oynananlar … puan ve
  // k-lig bozulmuş, sağda hizalı olmaları lazım."* İKİ ayrı sebep vardı ve
  // ikisi de bu testin YOKLUĞUNDA gizlenmişti:
  //   (1) skor/k-lig düz `Text`ti → genişlikleri İÇERİĞE göre değişiyordu
  //       ("0" bir karakter, "253" üç) → satırın sonu kayıyordu.
  //   (2) sol sütun Canlı'da `Flexible`di (loose fit) → avatar SAYISI
  //       genişliği değiştiriyordu (2 kişilik 46 px, 4 kişilik 86 px) ve
  //       artan boşluk `MainAxisAlignment.start` gereği en sağda kalıyordu.
  // ÖLÇÜLDÜ (düzeltme öncesi, 412 px): k-lig sağ kenarı 289,9 / 289,9 /
  // **320,8** / **283,2** / 289,9 — dört farklı yerde.
  //
  // Bu test SAĞ KENARLARIN eşitliğini ölçüyor; ikisinden biri geri alınırsa
  // GERÇEKTEN düşer.
  testWidgets(
      'Son Oynadıklarım: puan ve k-lig sütunları SAĞDA hizalı — satır '
      'içeriği (avatar sayısı, skor basamağı) değişse bile', (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        // 2 kişilik, üç basamaklı skor
        gameRow(id: 'g1', onlineGameId: 'o1', playerScore: 253, aiScore: 100,
            rank: 1, createdAt: '2026-09-03T10:00:00.000Z',
            players: [snap('Ben', 253, colorIndex: 0), snap('Be', 100, colorIndex: 1)]),
        // 4 KİŞİLİK (sol sütun daha geniş) + tek basamaklı k-lig farkı
        gameRow(id: 'g2', onlineGameId: 'o2', playerScore: 123, aiScore: 200,
            rank: 2, playerCount: 4, createdAt: '2026-09-02T10:00:00.000Z',
            players: [snap('Ben', 123, colorIndex: 0), snap('Fb', 200, colorIndex: 1),
                      snap('X', 90, colorIndex: 2), snap('Y', 80, colorIndex: 3)]),
        // TEK BASAMAKLI skor
        gameRow(id: 'g3', onlineGameId: 'o3', playerScore: 0, aiScore: 100,
            rank: 1, createdAt: '2026-09-02T09:00:00.000Z',
            players: [snap('Ben', 0, colorIndex: 0), snap('Vi', 100, colorIndex: 1)]),
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(412, 900));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo,
            userId: 'u-me',
            onlineOnly: true,
            // Bir satırda "YENİ" rozeti VAR — ortadaki blok genişliği
            // değişse de sağ sütunlar kıpırdamamalı.
            newlyFinishedIds: const {'g1'}),
      ),
    ));
    await tester.pumpAndSettle();

    // ⚠ Aynı metin BİRDEN FAZLA satırda olabilir ("+2" iki kez) — finder
    // tekil değil, hepsini topla.
    List<double> sagKenarlar(String metin) => [
          for (final e in find.text(metin).evaluate())
            tester.getRect(find.byWidget(e.widget)).right
        ];

    // Skorlar: 253 (2 kişi) · 123 (4 KİŞİ) · 0 (tek basamak)
    final skorlar = [
      ...sagKenarlar('253'),
      ...sagKenarlar('123'),
      ...sagKenarlar('0'),
    ];
    expect(skorlar, hasLength(3));
    for (final x in skorlar) {
      expect(x, closeTo(skorlar.first, 0.5),
          reason: 'skor sütunu sağda hizalı DEĞİL: $skorlar');
    }
    // k-lig: +2 (iki satır) · +1
    final kligler = [...sagKenarlar('+2'), ...sagKenarlar('+1')];
    expect(kligler, hasLength(3));
    for (final x in kligler) {
      expect(x, closeTo(kligler.first, 0.5),
          reason: 'k-lig sütunu sağda hizalı DEĞİL: $kligler');
    }
    // ignore: avoid_print
    print('[ÖLÇÜM] skor sağ=${skorlar.first.toStringAsFixed(1)} '
        'k-lig sağ=${kligler.first.toStringAsFixed(1)} (üç satır AYNI)');
  });

  testWidgets('Son Oynadıklarım: "OYUN BİTTİ" YZ tarafında ÇİZİLMEZ',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g-ai', players: [
          snap('Ironman', 238, colorIndex: 0),
          snap('Yapay Zeka 2', 179, ai: true, colorIndex: 1),
        ])
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: false),
      ),
    ));
    await tester.pumpAndSettle();

    // Satır GERÇEKTEN çizilmiş olmalı — yoksa test hiçbir şey kanıtlamaz.
    expect(find.text('238'), findsOneWidget);
    expect(find.text('OYUN BİTTİ'), findsNothing);
  });

  testWidgets('Son Oynadıklarım: "OYUN BİTTİ" CANLI tarafta çizilir',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g-live', onlineGameId: 'og-1', players: [
          snap('Ironman', 238, colorIndex: 0),
          snap('Esiner', 179, colorIndex: 1),
        ])
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('OYUN BİTTİ'), findsOneWidget);
    // "YENİ" yalnızca bitişini görmediklerinde — burada verilmedi.
    expect(find.text('YENİ'), findsNothing);
  });

  // 3 Eylül 2026, kullanıcı sordu: süre yüzünden teslim senaryosunda satırda
  // teslim göstergesi yoktu. Ayrı bir sütun yer sorunu çıkarırdı (kullanıcı
  // da bunu söyledi), o yüzden AYNI kutunun metni değişiyor.
  testWidgets('Son Oynadıklarım: teslimle biten oyunda etiket "TESLİM OLDUN"',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
            id: 'g-live',
            onlineGameId: 'og-1',
            surrendered: true,
            rank: 2,
            playerScore: 0,
            aiScore: 147,
            players: [
              snap('Ironman', 0, colorIndex: 0),
              snap('Esiner', 147, colorIndex: 1),
            ])
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('TESLİM OLDUN'), findsOneWidget);
    expect(find.text('OYUN BİTTİ'), findsNothing);
    // Sağdaki -2 k-lig puanı DURUYOR — teslimin asıl sayısal işareti o.
    expect(find.text('-2'), findsOneWidget);
  });

  // ⚠ Bayrak SATIR SAHİBİNE ait: rakibin süresi dolduysa BENİM satırım
  // "OYUN BİTTİ" kalmalı (ben kazandım). `games.surrendered` kişi başına.
  testWidgets('Son Oynadıklarım: RAKİBİN teslimi benim satırımı DEĞİŞTİRMEZ',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
            id: 'g-live',
            onlineGameId: 'og-1',
            surrendered: false,
            rank: 1,
            playerScore: 147,
            aiScore: 0,
            players: [
              snap('Ironman', 147, colorIndex: 0),
              snap('Esiner', 0, colorIndex: 1),
            ])
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo, userId: 'u-me', onlineOnly: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('OYUN BİTTİ'), findsOneWidget);
    expect(find.text('TESLİM OLDUN'), findsNothing);
  });

  // ⚠ 3 Eylül 2026, kullanıcı sordu: *"Bir de ekran büyütenler için en büyük
  // font nasıl davranıyor?"* Web'de bu soru YOK (px metin sistem yazı
  // boyutuyla ölçeklenmiyor, sayfanın tamamı zoom'lanıyor) ama PORTTA var:
  // ölçek tavana (kMaxTextScale = 1,3) kadar metni büyütür, kutular sabit
  // kalır. Bu satır tam o riskin sınıfı: dar bir şeritte yan yana iki metin.
  //
  // İlk yazımda burası `Row`du ve ÖLÇÜM KIRPILMA BULDU: 320 px / ölçek 1,3'te
  // etiket 111 px istiyor, 74,9 px alıyordu → `TESLİ…`. Çözüm `Wrap`:
  // sığdığı sürece rozet YANDA, sığmadığında ALTA iner (satır uzar, harf
  // kaybolmaz).
  //
  // 32 bileşim ölçüldü (320/360/390/430 px × 2-4 kişi × iki etiket × iki
  // ölçek). Oyuncu SAYISI hiç fark etmiyor (avatar şeridi zaten sabit-ish);
  // belirleyen genişlik + etiket uzunluğu + ölçek:
  //   ölçek 1,0 → 360 px ve üstünde HEPSİ yanda; 320 px'te yalnızca
  //               "TESLİM OLDUN" alta iniyor
  //   ölçek 1,3 → 430 px'te hepsi yanda, 390 px'te "OYUN BİTTİ" yanda,
  //               daha darda alta iniyor
  // Yani "yanda" iddiası gerçekçi tabanda (360 px, yaygın Android alt
  // sınırı) tutuluyor; alta inme yalnızca gerçekten sığmadığında oluyor.

  /// Etiket kırpıldı mı (`ellipsis` sessizce kısaltır, HATA BASMAZ — yani
  /// "taşma yok" tek başına hiçbir şey kanıtlamaz).
  ({bool kirpildi, bool yanda, double isteyen, double alan}) olcRozet(
      WidgetTester tester, String etiket) {
    final rp = tester.renderObject<RenderParagraph>(find.descendant(
        of: find.text(etiket), matching: find.byType(RichText)));
    final isteyen = rp.getMaxIntrinsicWidth(double.infinity);
    return (
      kirpildi: rp.size.width + 0.5 < isteyen || rp.didExceedMaxLines,
      yanda: (tester.getCenter(find.text(etiket)).dy -
                  tester.getCenter(find.text('YENİ')).dy)
              .abs() <=
          1.0,
      isteyen: isteyen,
      alan: rp.size.width,
    );
  }

  Future<void> pumpTeslimSatiri(WidgetTester tester,
      {required double genislik, required double olcek}) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(
            id: 'g-live',
            onlineGameId: 'og-1',
            surrendered: true,
            rank: 2,
            playerScore: 0,
            aiScore: 147,
            playerCount: 4,
            players: [
              snap('Ironman', 0, colorIndex: 0),
              snap('Esiner', 147, colorIndex: 1),
              snap('Ayla', 90, colorIndex: 2),
              snap('Murat', 70, colorIndex: 3),
            ])
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, Size(genislik, 700));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      // ⚠ `Builder` ŞART: `MediaQuery.of` context istiyor ve
      // `tester.element(...)` burada henüz YOK (pumpWidget'in argümanı
      // eagerly değerlendiriliyor). Repo'nun kendi deseni bu.
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(olcek)),
          child: Scaffold(
            body: RecentGamesSection(
                games: repo,
                userId: 'u-me',
                onlineOnly: true,
                newlyFinishedIds: const {'g-live'}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // SÖZLEŞME: yaygın taban (360 px) + normal ölçekte rozet etiketin
  // YANINDA (kullanıcı isteği) ve etiket kırpılmamış.
  testWidgets('Son Oynadıklarım: 360 px normal ölçek — rozet YANDA, kırpma yok',
      (tester) async {
    await pumpTeslimSatiri(tester, genislik: 360, olcek: 1.0);
    final m = olcRozet(tester, 'TESLİM OLDUN');
    expect(m.kirpildi, isFalse,
        reason: 'etiket kırpıldı (isteyen ${m.isteyen.toStringAsFixed(1)}, '
            'alan ${m.alan.toStringAsFixed(1)})');
    expect(m.yanda, isTrue, reason: 'rozet alta inmiş — yanda kalmalı');
  });

  // EN KÖTÜ DURUM: en dar ekran + tavandaki yazı boyutu. Burada rozetin
  // alta inmesi KABUL EDİLEN davranış; kabul edilmeyen şey KIRPILMA.
  testWidgets(
      'Son Oynadıklarım: 320 px + ölçek 1.3 (tavan) — etiket KIRPILMAZ '
      '(rozet alta inebilir)', (tester) async {
    await pumpTeslimSatiri(tester, genislik: 320, olcek: 1.3);
    final m = olcRozet(tester, 'TESLİM OLDUN');
    // ignore: avoid_print
    print('[ÖLÇÜM] 320px ölçek 1.3: etiket isteyen '
        '${m.isteyen.toStringAsFixed(1)} px, alan '
        '${m.alan.toStringAsFixed(1)} px · '
        '${m.yanda ? "rozet YANDA" : "rozet ALTA indi"}');
    expect(m.kirpildi, isFalse,
        reason: 'tavandaki ölçekte etiket kırpıldı — `Wrap` yerine `Row` '
            'kullanılırsa bu GERÇEKTEN düşer (ilk yazımda düşmüştü)');
    expect(find.text('YENİ'), findsOneWidget);
  });

  testWidgets('Son Oynadıklarım: görülmemiş oyunda "YENİ" rozeti çıkar',
      (tester) async {
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [
        gameRow(id: 'g-live', onlineGameId: 'og-1', players: [
          snap('Ironman', 238, colorIndex: 0),
          snap('Esiner', 179, colorIndex: 1),
        ])
      ];
    final repo = await newRepoForWidget(tester, gw);
    await setPhoneViewSize(tester, const Size(420, 780));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
            games: repo,
            userId: 'u-me',
            onlineOnly: true,
            newlyFinishedIds: const {'g-live'}),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('OYUN BİTTİ'), findsOneWidget);
    expect(find.text('YENİ'), findsOneWidget);
  });

  testWidgets('Son Oynadıklarım: ağ hatası "oyunun yok" DEĞİL "yüklenemedi"',
      (tester) async {
    // Çevrimdışıyken "Henüz bitmiş bir Yapay Zeka oyunun yok." demek
    // YANLIŞ bilgi — oyunlar sunucuda duruyor. Sunucu boş liste döndüğü
    // durumla ayrışması için `history` bir `failed` bayrağı taşıyor.
    final gw = FakeGamesGateway(userId: 'u-me')
      ..history = [gameRow(id: 'g-ai')]
      ..failList = true;
    final repo = await newRepoForWidget(tester, gw);

    await setPhoneViewSize(tester, const Size(420, 520));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: RecentGamesSection(
          games: repo,
          userId: 'u-me',
          onlineOnly: false,
          emptyMessage: 'Henüz bitmiş bir Yapay Zeka oyunun yok.',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('yüklenemedi'), findsOneWidget);
    expect(find.text('Henüz bitmiş bir Yapay Zeka oyunun yok.'), findsNothing);
  });

  // ── shareOriginFrom sözleşmesi (Parça 86 + 2 Eylül 2026 düzeltmesi) ─────
  //
  // NEDEN AYRI BİR TEST: yukarıdaki akış testi ankrajın ekrana ULAŞTIĞINI
  // kanıtlıyor ama ankrajın KENDİSİNİN geçerli olduğunu kanıtlamıyordu.
  // Gerçek hata tam o boşluktan geçti: iki çağrı yeri `State.context`
  // veriyordu, yani ankraj EKRANIN TAMAMIYDI — "boş değil" ve "içeride"
  // olduğundan iddialardan geçiyor, ama iPad'de popover görünmüyor ve
  // `SharePlus.share` hiç dönmüyordu (Appetize, iPad Air / iOS 16.2;
  // belirtiler: Setup'ta "tepki yok", Arkadaşlar'da buton `…`ta kilitli).
  group('shareOriginFrom', () {
    // ⚠ Ankraj ancak DÜZEN KURULDUKTAN sonra okunabilir: `build` sırasında
    // `findRenderObject()` henüz null döner ve fonksiyon yedeğe düşerdi —
    // yani test iki dalı da 1x1 görüp SESSİZCE geçerdi. Bu yüzden ölçüm
    // `pump`tan SONRA, `GlobalKey.currentContext` üzerinden yapılıyor.
    Future<Rect> olc(WidgetTester tester,
        {required bool ekranBoyutunda}) async {
      await setPhoneViewSize(tester, const Size(400, 800));
      final anahtar = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: ekranBoyutunda
            // `State.context`in yaptığının aynısı: kutu = tüm ekran.
            ? SizedBox.expand(key: anahtar)
            : Center(
                child: SizedBox(key: anahtar, width: 40, height: 20),
              ),
      ));
      await tester.pump();
      return shareOriginFrom(anahtar.currentContext!);
    }

    testWidgets('gerçek bir düğmenin kutusu OLDUĞU GİBİ ankraj olur',
        (tester) async {
      final r = await olc(tester, ekranBoyutunda: false);
      expect(r.isEmpty, isFalse);
      expect(r.width, 40);
      expect(r.height, 20);
    });

    testWidgets('EKRAN BOYUTUNDA kutu ankraj SAYILMAZ — 1x1 yedeğe düşer',
        (tester) async {
      final r = await olc(tester, ekranBoyutunda: true);
      // Negatif eş: `_kFullScreenOriginRatio` kontrolü kaldırılırsa bu iddia
      // düşer (o zaman 400x800 dönerdi) — düzeltmenin gerçekten bu satıra
      // bağlı olduğu böyle kanıtlanıyor.
      expect(r.width, 1);
      expect(r.height, 1);
      expect(r.center, const Offset(200, 400));
      expect(r.isEmpty, isFalse, reason: 'CGRectIsEmpty olmamalı');
    });
  });
}

/// `set_game_shared` düşen uç — link olmadan paylaşılmalı.
class _NoShareMarkGateway extends FakeGamesGateway {
  _NoShareMarkGateway({super.userId});

  @override
  Future<void> markShared(String gameId) async => throw Exception('ağ hatası');
}
