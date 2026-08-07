// "Görüş Bildir" parçası — FeedbackRepo (kuyruk/flush/rate-limit, gerçek
// SQLite ffi + enjekte saat) ve FeedbackModal/GameOver/Terms bağlamaları.
// Gerçek `feedback` insert'i (RLS: feedback_insert_any, anonim serbest)
// cihazda doğrulanacak (mobile/TESTING.md, "Görüş Bildir").
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/feedback_api.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/storage/pending_queue_store.dart';
import 'package:kelimeki/src/ui/auth/auth_modal.dart';
import 'package:kelimeki/src/ui/feedback/feedback_modal.dart';
import 'package:kelimeki/src/ui/game/game_over_modal.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

late int clock;

int _dbSeq = 0;

/// Test başına BENZERSİZ dosya yolu — `inMemoryDatabasePath` burada bilerek
/// kullanılmıyor: sqflite factory'si aynı yolu açık kaldıkça paylaşır
/// (diğer test dosyaları her testin sonunda `storage.close()` çağırarak
/// çözüyor; burada kuyruk/rate-limit durumu testler arasında sızınca iki
/// test bundan gerçekten kırıldı — benzersiz yol kapatma sırasına bağımlı
/// olmayan izolasyon veriyor).
Future<AppStorage> openTestStorage() async {
  SharedPreferences.setMockInitialValues({});
  final dir = Directory.systemTemp.createTempSync('kelimeki-fb-test');
  return AppStorage.open(
    factory: databaseFactoryFfi,
    path: '${dir.path}/t${_dbSeq++}.db',
    prefs: await SharedPreferences.getInstance(),
    nowMs: () => clock,
  );
}

class MemFeedbackGateway implements FeedbackGateway {
  final inserted = <Map<String, Object?>>[];
  Object? failWith;

  @override
  Future<void> insert(
      {required String message, String? email, required String source}) async {
    final f = failWith;
    if (f != null) throw f;
    inserted.add({'message': message, 'email': email, 'source': source});
  }
}

int _idSeq = 0;

FeedbackRepo newRepo(FeedbackGateway? gw, Future<AppStorage> storage) {
  // Sayaç GLOBAL — repo başına sıfırlansaydı aynı kuyruğa yazan iki repo
  // aynı id'yi üretir, enqueue'nun dedup'ı ikinci kaydı sessizce yutardı
  // (yaşandı: "Supabase yokken de kuyruk" testi bundan kırıldı).
  return FeedbackRepo(gw, storage,
      nowMs: () => clock, newId: () => 'fb-${_idSeq++}');
}

User fakeUser() => User(
      id: 'u-test',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: 'alp.capa@hotmail.com',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(loadAppFonts);
  setUp(() => clock = DateTime.parse('2026-08-07T12:00:00Z')
      .millisecondsSinceEpoch);

  group('FeedbackRepo', () {
    test('başarılı gönderim: kuyruk boş kalır, pencereye sayılır', () async {
      final storage = openTestStorage();
      final gw = MemFeedbackGateway();
      final repo = newRepo(gw, storage);

      final r = await repo.submitDurable(
          message: ' merhaba ', email: '', source: FeedbackSource.general);
      expect(r, FeedbackSubmitResult.accepted);
      expect(gw.inserted, hasLength(1));
      expect(gw.inserted.single['source'], 'general');
      final s = await storage;
      expect(await s.queue.count(feedbackKind), 0);
      expect(s.flags.feedbackSubmissionTimes, hasLength(1));
    });

    test('ağ hatası → kuyruğa düşer; Supabase yokken (gateway null) de',
        () async {
      final storage = openTestStorage();
      final gw = MemFeedbackGateway()..failWith = Exception('ağ');
      final repo = newRepo(gw, storage);
      await repo.submitDurable(
          message: 'kayboldu mu?',
          email: 'a@b.c',
          source: FeedbackSource.gameEnd);

      final offline = newRepo(null, storage); // web: configured değilken de kuyruk
      await offline.submitDurable(
          message: 'offline mesaj', email: null, source: FeedbackSource.general);

      final s = await storage;
      final q = await s.queue.readAll(feedbackKind);
      expect(q, hasLength(2));
      expect(q.first.payload['message'], 'kayboldu mu?');
      expect(q.first.payload['email'], 'a@b.c');
      expect(q.first.payload['source'], 'game_end');
    });

    test('rate limit: 10 dakikada 3 — dördüncüsü reddedilir, pencere geçince açılır',
        () async {
      final storage = openTestStorage();
      final gw = MemFeedbackGateway();
      final repo = newRepo(gw, storage);
      for (var i = 0; i < 3; i++) {
        expect(
            await repo.submitDurable(
                message: 'm$i', email: null, source: FeedbackSource.general),
            FeedbackSubmitResult.accepted);
        clock += 60 * 1000;
      }
      expect(
          await repo.submitDurable(
              message: 'm3', email: null, source: FeedbackSource.general),
          FeedbackSubmitResult.rateLimited);
      expect(gw.inserted, hasLength(3)); // reddedilen hiç gönderilmedi

      clock += 8 * 60 * 1000; // ilk mesaj penceresi (10dk) artık geride
      expect(
          await repo.submitDurable(
              message: 'm4', email: null, source: FeedbackSource.general),
          FeedbackSubmitResult.accepted);
    });

    test('flushPending: oturum ŞARTSIZ gönderir, başarısız kuyrukta kalır, bozuk düşer',
        () async {
      final storage = openTestStorage();
      final gw = MemFeedbackGateway()..failWith = Exception('ağ');
      final repo = newRepo(gw, storage);
      await repo.submitDurable(
          message: 'bir', email: null, source: FeedbackSource.general);
      await repo.submitDurable(
          message: 'iki', email: 'x@y.z', source: FeedbackSource.gameEnd);
      final s = await storage;
      // Bozuk kayıt (message yok) — flush kuyruğu tıkamadan düşürmeli.
      await s.queue.enqueue(kind: feedbackKind, id: 'bozuk', payload: {'x': 1});
      expect(await s.queue.count(feedbackKind), 3);

      gw.failWith = null;
      expect(await repo.flushPending(), 2);
      expect(await s.queue.count(feedbackKind), 0);
      expect(gw.inserted.map((m) => m['message']), ['bir', 'iki']);
      expect(gw.inserted.last['email'], 'x@y.z');

      // Gateway yoksa flush ağa hiç dokunmaz (0 döner, kuyruk olduğu gibi).
      final offline = newRepo(null, storage);
      await offline.submitDurable(
          message: 'bekleyen', email: null, source: FeedbackSource.general);
      expect(await offline.flushPending(), 0);
      expect(await s.queue.count(feedbackKind), 1);
    });
  });

  group('FeedbackModal', () {
    Future<(FeedbackRepo, AppStorage)> pumpForm(
      WidgetTester tester, {
      required MemFeedbackGateway gw,
      AuthService? auth,
      int minSubmitOffsetMs = kFeedbackMinSubmitMs + 1,
    }) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final storage = await tester.runAsync(openTestStorage);
      final repo = newRepo(gw, Future.value(storage));
      final openedAt = clock;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
        home: Scaffold(
          body: FeedbackModal(
            auth: auth ?? AuthService.fake(),
            feedback: repo,
            source: FeedbackSource.gameEnd,
            // MIN_SUBMIT_MS: modal açılışı openedAt'te; gönderim anında saat
            // ileride olsun ki gerçek gönderim bot sanılmasın.
            nowMs: () => clock == openedAt ? openedAt : clock,
          ),
        ),
      ));
      await tester.pump();
      clock += minSubmitOffsetMs;
      return (repo, storage!);
    }

    testWidgets('misafir: boş mesaj hatası → gönderim → üyelik teklifi → KAYIT',
        (tester) async {
      final gw = MemFeedbackGateway();
      await pumpForm(tester, gw: gw);

      expect(find.text('GÖRÜŞLERİNİZ BİZİM İÇİN ÖNEMLİ'), findsOneWidget);
      // Misafirde e-posta alanı VAR, "Yanıt e-postan" satırı YOK.
      final emailField = find.widgetWithText(
          TextField, 'E-posta (yanıt alabilmen için, isteğe bağlı)');
      expect(emailField, findsOneWidget);
      expect(find.textContaining('Yanıt e-postan'), findsNothing);

      await tester.tap(find.text('GÖNDER'));
      await tester.pump();
      expect(find.text('Mesaj boş olamaz.'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, 'Mesajın'), 'Harika oyun!');
      await tester.enterText(emailField, 'misafir@ornek.com');
      await tester.tap(find.text('GÖNDER'));
      await tester.pumpAndSettle();

      expect(gw.inserted.single['message'], 'Harika oyun!');
      expect(gw.inserted.single['source'], 'game_end');
      expect(find.text('Teşekkürler, mesajın bize ulaştı.'), findsOneWidget);
      expect(
          find.text('misafir@ornek.com ile üyeliğine devam etmek ister misin?'),
          findsOneWidget);

      // EVET → AuthModal doğrudan KAYIT modunda, e-posta önceden dolu,
      // signup_channel='form' (web FeedbackModal→AuthModal zinciri).
      await tester.tap(find.text('EVET'));
      await tester.pumpAndSettle();
      expect(find.text('KAYIT'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'misafir@ornek.com'),
          findsOneWidget);
    });

    testWidgets('girişli: e-posta alanı yerine "Yanıt e-postan", teklif yok',
        (tester) async {
      final gw = MemFeedbackGateway();
      final key = GlobalKey();
      await setPhoneViewSize(tester, const Size(420, 900));
      final storage = await tester.runAsync(openTestStorage);
      final repo = newRepo(gw, Future.value(storage));
      final openedAt = clock;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            body: FeedbackModal(
              auth: AuthService.fake(user: fakeUser()),
              feedback: repo,
              source: FeedbackSource.general,
              nowMs: () => clock == openedAt ? openedAt : clock,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('Yanıt e-postan', findRichText: true),
          findsOneWidget);
      expect(
          find.widgetWithText(
              TextField, 'E-posta (yanıt alabilmen için, isteğe bağlı)'),
          findsNothing);

      await tester.enterText(
          find.widgetWithText(TextField, 'Mesajın'), 'Bir önerim var.');

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File('build/screenshots/feedback_form.png');
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes!.buffer.asUint8List());
      });

      clock += kFeedbackMinSubmitMs + 1;
      await tester.tap(find.text('GÖNDER'));
      await tester.pumpAndSettle();
      // Girişlide teklif yok — yalnızca teşekkür + KAPAT (e-posta hesaptan
      // gateway'de tamamlanır, formda alan yoktu).
      expect(find.text('Teşekkürler, mesajın bize ulaştı.'), findsOneWidget);
      expect(find.textContaining('üyeliğine devam'), findsNothing);
      expect(find.text('KAPAT'), findsOneWidget);
    });

    testWidgets('1.5sn altı gönderim: hiçbir şey kaydetmeden sahte "gönderildi"',
        (tester) async {
      final gw = MemFeedbackGateway();
      final (_, storage) = await pumpForm(tester, gw: gw, minSubmitOffsetMs: 0);
      await tester.enterText(
          find.widgetWithText(TextField, 'Mesajın'), 'bot');
      await tester.tap(find.text('GÖNDER'));
      await tester.pumpAndSettle();
      expect(find.text('Teşekkürler, mesajın bize ulaştı.'), findsOneWidget);
      // Web bot dalı: ne gönderilir ne kuyruklanır ("botu bilgilendirme").
      expect(gw.inserted, isEmpty);
      expect(await tester.runAsync(() => storage.queue.count(feedbackKind)), 0);
    });

    testWidgets('rate limit hatası formda gösterilir', (tester) async {
      final gw = MemFeedbackGateway();
      final (repo, _) = await pumpForm(tester, gw: gw);
      // Pencereyi doldur (repo üzerinden — form değil, aynı FlagsStore).
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => repo.submitDurable(
            message: 'x$i', email: null, source: FeedbackSource.general));
      }
      await tester.enterText(
          find.widgetWithText(TextField, 'Mesajın'), 'dördüncü');
      await tester.tap(find.text('GÖNDER'));
      await tester.pumpAndSettle();
      expect(
          find.text('Çok fazla mesaj gönderdin, birkaç dakika sonra tekrar dene.'),
          findsOneWidget);
      expect(gw.inserted, hasLength(3));
    });
  });

  group('Bağlamalar', () {
    testWidgets('GameOver: onFeedback verilirse GÖRÜŞ BİLDİR çizilir ve çağrılır',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      final golden = jsonDecode(File(
              '../kelimeki_core/test/goldens/reducer_ai4.json')
          .readAsStringSync()) as Map<String, dynamic>;
      final steps = golden['steps'] as List;
      final state = gameStateFromJson(
          ((steps.last as Map)['state'] as Map).cast<String, Object?>());
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'SpaceGrotesk'),
        home: Scaffold(
            body: GameOverModal(state: state, onFeedback: () => opened++)),
      ));
      await tester.pump();
      await tester.tap(find.text('GÖRÜŞ BİLDİR'));
      expect(opened, 1);

      // Verilmezse hiç çizilmez (testler/önizlemeler).
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'SpaceGrotesk'),
        home: Scaffold(body: GameOverModal(state: state)),
      ));
      await tester.pump();
      expect(find.text('GÖRÜŞ BİLDİR'), findsNothing);
    });

    testWidgets('Kayıt formu → Kullanım Koşulları → "Görüş Bildir formu" formu açar',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 1000));
      final storage = await tester.runAsync(openTestStorage);
      final repo = newRepo(MemFeedbackGateway(), Future.value(storage));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: 'SpaceGrotesk', scaffoldBackgroundColor: Colors.white),
        home: Scaffold(
          body: AuthModal(
              auth: AuthService.fake(),
              feedback: repo,
              nicknameChecker: (_) async => true),
        ),
      ));
      await tester.pump();
      await tester.tap(find.textContaining('Kayıt ol', findRichText: true));
      await tester.pump();
      await tester.tapOnText(find.textRange.ofSubstring('Kullanım Koşulları'));
      await tester.pumpAndSettle();
      expect(find.text('KULLANIM KOŞULLARI'), findsOneWidget);

      // Link 7. bölümde, kaydırmak gerekir — en üstteki dialog'un scroll'u.
      await tester.scrollUntilVisible(find.text('Görüş Bildir formu'), 300,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Görüş Bildir formu'));
      await tester.pumpAndSettle();
      expect(find.text('GÖRÜŞLERİNİZ BİZİM İÇİN ÖNEMLİ'), findsOneWidget);
      // source='general' — form gönderilebilir durumda (Mesajın alanı açık).
      expect(find.widgetWithText(TextField, 'Mesajın'), findsOneWidget);
    });
  });
}
