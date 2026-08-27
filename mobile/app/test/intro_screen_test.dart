// İlk açılış tanıtımı (`IntroScreen`) + kapısı (`app.dart`'taki _HomeGate).
//
// Ölçülen sözleşme üç parça:
//  1) ekranın kendisi — beş sayfa, hem PARMAKLA hem ara sayfalardaki
//     "DEVAM ›" düğmesiyle ilerlenir (düğme 26 Ağustos 2026'da GERİ
//     KONDU: gerçek kullanıcılar kaydırmayı anlamayıp tanıtımda takıldı),
//     son sayfada HEMEN OYNA çıkar, logo her sayfada tek kopya görünür
//     (ve HİÇBİR yerde atlama yok: tanıtımın TEK çıkışı o düğme);
//  2) kapı — bayrak YOKKEN tanıtım, VARKEN doğrudan Setup;
//  3) bayrak GERÇEKTEN yazılıyor (yoksa tanıtım her açılışta çıkardı).
//
// Kapı testleri GERÇEK `AppStorage` kullanıyor (sqflite ffi): bayrağın
// yazıldığını sahte bir depo üzerinden "kanıtlamak" hiçbir şey kanıtlamaz.
// Gerçek I/O testWidgets'ın sahte zaman bölgesinde ilerlemediğinden her
// testin sonunda `drainRealIo` şart (Parça 11/13/64/74'ün dersi).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/storage/app_storage.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/game/logo_mark.dart';
import 'package:kelimeki/src/ui/game/neo_button.dart';
import 'package:kelimeki/src/ui/intro/intro_screen.dart';
import 'package:kelimeki/src/ui/rank/league_rank.dart';
import 'package:kelimeki/src/ui/rank/rank_seal.dart';
import 'package:kelimeki/src/ui/setup/setup_screen.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'support/test_fonts.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_view.dart';

Future<void> drainRealIo(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
}

/// Ekrandaki tahtayı taşıyan slaydın DİKEY kaydırma payı (0 = slayt tek
/// ekrana sığıyor). `find.ancestor` en yakından uzağa yürüdüğünden ilk
/// DİKEY eşleşme slaydın kendi `SingleChildScrollView`ı olur; `PageView`in
/// kendi Scrollable'ı yatay olduğundan eksene bakmak onu eliyor (sırayı
/// varsaymak yerine ölçüt koymak, PageView bir gün araya başka bir
/// kaydırma görünümü girerse testin sessizce yanlış şeyi ölçmesini
/// engelliyor).
double dikeyKayma(Finder icerik) {
  // `.first` KULLANILMIYOR: `PageView` bir gün komşu sayfayı da canlı
  // tutarsa iki tahta birden bulunur ve ölçüm sessizce YANLIŞ slayda
  // kayar. Ölçmeden önce tek eşleşme şart koşuluyor — bugün doğru olduğu
  // aynı dosyadaki içerik testinin `findsOneWidget`leriyle de sabit.
  expect(icerik, findsOneWidget,
      reason: 'kaydırma ölçümü tek bir slayda ait olmalı');
  for (final el
      in find.ancestor(of: icerik, matching: find.byType(Scrollable)).evaluate()) {
    final st = (el as StatefulElement).state as ScrollableState;
    if (st.position.axis == Axis.vertical) return st.position.maxScrollExtent;
  }
  fail('slaydın dikey kaydırma görünümü bulunamadı');
}

/// Sonraki slayta parmakla geç — 19 Ağustos 2026'dan beri ara sayfalarda
/// düğme YOK, ilerlemenin TEK yolu `PageView` kaydırması.
Future<void> kaydir(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-400, 0));
  await tester.pumpAndSettle();
}

/// Gerçek depo — `AppStorage.open` gerçek I/O olduğundan `runAsync` köprüsü
/// şart (pump'tan ÖNCE açılıyor ki kapının beklediği Future zaten çözülmüş
/// olsun; aksi halde sahte zamanda hiç tamamlanmaz).
Future<AppStorage> newStorage(WidgetTester tester,
    {bool seenIntro = false}) async {
  late AppStorage storage;
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(
        seenIntro ? {'seen_intro': true} : {});
    storage = await AppStorage.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      prefs: await SharedPreferences.getInstance(),
      nowMs: () => DateTime.now().millisecondsSinceEpoch,
    );
  });
  return storage;
}

AppServices services({Future<AppStorage>? storage}) => AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab', 'aba', 'kelime'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: AuthService(null),
      supabase: null,
      versionGate: VersionGateStatus.ok,
      storage: storage,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  // GERÇEK FONTLAR ŞART — bu dosya artık GEOMETRİ ölçüyor (slayt kaydırma
  // payı, legend'in yan yana olup olmadığı). `flutter_test` pubspec'teki
  // fontları OTOMATİK YÜKLEMEZ: varsayılan Ahem'de her glyph
  // fontSize×fontSize bir bloktur, yani 27 karakterlik legend metni 11px'te
  // 297px yer kaplar (gerçek Space Grotesk'te 144px — web'de ölçüldü).
  // Ahem'le ölçmek iki testi de UYDURMA bir düzende sınardı: metinler daha
  // çok satıra sarıp slaydı şişirir, legend hiçbir genişlikte yan yana
  // sığmaz. Nitekim ilk sürümde tam bu oldu (CI: 1. slayt 29px taşıyor,
  // legend üstleri 730 ve 750). Ölçüm yapan kardeş testlerin hepsi
  // (`board_render_test`, `game_header_test`, `account_button_test`…)
  // baştan beri bu satırı taşıyor.
  setUpAll(loadAppFonts);

  group('IntroScreen', () {
    testWidgets('beş sayfa: ara sayfalarda DEVAM, son sayfada HEMEN OYNA; '
        'parmakla da düğmeyle de ilerler; atlama YOK', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      var done = 0;
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () => done++),
      ));

      // İlk sayfa: kahraman cümlesi. Cümlenin TAMAMI
      // aranıyor (`textContaining` DEĞİL): 2. sayfadaki "Bölgeni büyüt"
      // adımı da aynı alt dizeyi taşıyor, PageView komşu sayfayı da inşa
      // ederse eşleşme ikiye çıkardı.
      expect(find.text('Kelime bul, bölgeni büyüt, tahtayı ele geçir.'),
          findsOneWidget);
      // ARA SAYFALARDA "DEVAM ›" VAR (26 Ağustos 2026). 19 Ağustos'ta
      // kullanıcı isteğiyle kaldırılmıştı ("altta sadece ince bir nokta
      // alanı bıraksak herkes parmakla ilerleyeceğini bilir"); kapalı
      // testin ilk gerçek kullanıcıları o varsayımı ÇÜRÜTTÜ — tanıtımda
      // takılıp Setup'a hiç ulaşamadılar. Atlama da olmadığı için çıkmazdı.
      expect(find.text('DEVAM ›'), findsOneWidget);
      expect(find.text('HEMEN OYNA'), findsNothing);
      // Logo ekranın (PageView'ın DEĞİL) parçası: dört sayfada da tek
      // kopya görünür — sayfa başına kopyalansaydı bu sayı 1'de kalmazdı.
      expect(find.byType(LogoMark), findsOneWidget);
      // Atlama YOK — 19 Ağustos 2026 kullanıcı kararı. Bu iddia her
      // sayfada tekrarlanıyor (aşağı bkz.), çünkü tek bir sayfada
      // yokluğunu görmek başka bir sayfada durduğunu ekarte etmez.
      expect(find.text('Atla'), findsNothing);

      // 1 → 2: DÜĞMEYLE ilerle. Düğmenin var olma sebebi bu — kaydırmayı
      // anlamayan kullanıcı buradan geçebilmeli.
      // Negatif eş: `_ileri`/`onPressed` kaldırılırsa bu expect düşer.
      await tester.tap(find.text('DEVAM ›'));
      await tester.pumpAndSettle();
      expect(find.text('Kelime bul, bölgeni büyüt, tahtayı ele geçir.'),
          findsNothing,
          reason: 'düğme gerçekten bir sonraki slayta geçirmeli');

      // Kalan sayfalar PARMAKLA — kaydırma düğmeyle birlikte çalışmaya
      // devam etmeli, düğme onun YERİNE geçmiyor.
      for (var i = 1; i < kIntroPageCount - 1; i++) {
        await kaydir(tester);
        expect(find.text('Atla'), findsNothing);
        expect(find.byType(LogoMark), findsOneWidget);
        final sonSayfa = i == kIntroPageCount - 2;
        expect(find.text('DEVAM ›'), sonSayfa ? findsNothing : findsOneWidget);
      }

      // Son sayfa: tanıtımın TEK çıkışı; DEVAM burada yerini bırakıyor.
      expect(find.text('HEMEN OYNA'), findsOneWidget);
      expect(find.text('DEVAM ›'), findsNothing);
      expect(done, 0);

      await tester.tap(find.text('HEMEN OYNA'));
      await tester.pumpAndSettle();
      expect(done, 1);
    });

    // 19 Ağustos 2026, kullanıcı spesifikasyonu: dört slaytın İÇERİĞİ
    // (yalnızca sayısı değil) web'in karşılama katmanıyla aynı olmalı —
    // "Bu tanıtım değil kaçırım olmuş… webdeki gibi tahtaya bir bak
    // bölümünü koy… 3. slayt: neler var (6 kutu), 4. slayt: k-lig
    // (9 kutu)". Her slaytta o slayta ÖZGÜ bir işaret aranıyor; PageView
    // komşu sayfayı da inşa edebildiğinden başlıklar bilerek benzersiz.
    testWidgets('beş slaydın içeriği: 2 kişilik tahta · 4 kişilik tahta · '
        'dört adım · altı özellik · dokuz rütbe', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () {}),
      ));

      // 1. slayt: kahraman + GERÇEK tahta. Rakam kutuları 19 Ağustos
      // 2026'da 2. slayda TAŞINDI — `13×13` burada ARANMIYOR, yokluğu
      // aşağıda ölçülüyor (taşımanın negatif eşi).
      // Tahta bölümünün başlığı YALNIZCA üst başlık — 19 Ağustos 2026'da
      // "Oyun tam olarak böyle görünüyor" kaldırıldı (slayt tek ekrana
      // sığsın diye); kalktığının kanıtı ikinci satır.
      expect(find.text('TAHTAYA BİR BAK'), findsOneWidget);
      expect(find.text('Oyun tam olarak böyle görünüyor'), findsNothing);
      expect(find.byType(BoardWidget), findsOneWidget);
      expect(find.text('13×13'), findsNothing);
      expect(find.text('X2 — Kelime puanının 2 katı'), findsOneWidget);

      await kaydir(tester);

      // 2. slayt: dört rakam kutusu + 4 kişilik tahta + KENDİ açıklaması
      // (19 Ağustos 2026, kullanıcı isteği). Web'in aynı bölümünün ikinci
      // görseli; metin oradan birebir. Legend (X2/X3) burada
      // TEKRARLANMIYOR — web de tekrarlamıyor, yani bu satır aynı zamanda
      // o kararın negatif eşi.
      expect(find.byType(BoardWidget), findsOneWidget);
      expect(find.text('13×13'), findsOneWidget);
      expect(find.text('$kKelimeSayisi+'), findsOneWidget);
      expect(find.text('Ücretsiz'), findsOneWidget);
      expect(find.textContaining('3 yapay zekaya veya 3 arkadaşına karşı'),
          findsOneWidget);
      expect(find.text('X2 — Kelime puanının 2 katı'), findsNothing);

      await kaydir(tester);

      // 2. slayt: dört adımın DÖRDÜ de tek sayfada (eski sürümde ikişer
      // ikişer iki sayfaya bölünmüştü).
      expect(find.text('Nasıl oynanır?'), findsOneWidget);
      // "Köşenden başla" BİLEREK aranmıyor: 1. slayttaki tahta açıklaması da
      // aynı cümleyle başlıyor ve PageView komşu sayfayı önbellekte tutabilir.
      expect(find.textContaining('İlk kelimen köşendeki ev karesine'),
          findsOneWidget);
      expect(find.textContaining('Bölgeni büyüt'), findsOneWidget);
      expect(find.textContaining('Merkeze oyna'), findsOneWidget);
      expect(find.textContaining('Bölge vergisine dikkat!'), findsOneWidget);

      await kaydir(tester);

      // 3. slayt: altı özellik kutusu.
      expect(find.text("Kelimeki'de neler yapabilirsin?"), findsOneWidget);
      expect(find.text('Yapay zekaya karşı oyna'), findsOneWidget);
      expect(find.text('k-lig ve rütbeler'), findsOneWidget);

      await kaydir(tester);

      // 4. slayt: dokuz rütbe — liste `kRankTiers`ten çiziliyor, elle
      // yazılmıyor (eşik/ad değişirse ekran kendiliğinden takip eder).
      expect(find.text("Çaylak'tan Kozmik'e dokuz rütbe"), findsOneWidget);
      expect(find.byType(RankSeal), findsNWidgets(kRankTiers.length));
      expect(find.text(kRankTiers.first.name), findsOneWidget);
      expect(find.text(kRankTiers.last.name), findsOneWidget);
    });

    // 19 Ağustos 2026, kullanıcının ASIL şikâyeti: *"1. slayt hâlâ aşağıya
    // kayıyor ve bu app mantığına aykırı."* Rakam kutularının 2. slayda
    // taşınması tam olarak bunu çözmek için yapıldı — yani düzeltmenin
    // ölçüsü "kutular nerede" DEĞİL, "slayt kayıyor mu".
    //
    // İÇERİK TESTİ BUNU GÖREMEZ: hangi metnin hangi slaytta olduğunu
    // ölçen assertion'lar, iki slayt da ekrandan taşarken de yeşil kalır.
    // Bu yüzden ayrı bir test ve ölçülen şey doğrudan kaydırma payı.
    //
    // Kaydırma FALLBACK'İ bilerek duruyor (`SingleChildScrollView`
    // kalktı sanılmasın): bundan daha küçük/daha dar bir ekranda içerik
    // yine taşabilir ve o zaman kaydırmak kırpmaktan iyidir. Test bunu
    // yaygın bir telefon boyunda güvence altına alıyor, "her cihazda"
    // değil — dürüst sınır.
    // BOYUT LİSTESİ (19 Ağustos 2026'da genişletildi): 420×900 tek başına
    // YETMİYORDU — kullanıcı GitHub Pages web derlemesini iOS Safari'de
    // açtığında 1. slayt hâlâ bir satır taşıyordu, çünkü Safari'nin durum
    // çubuğu + alt adres çubuğu görünür yüksekliği ~150px kısaltıyor ve
    // test o yüzeyi hiç temsil etmiyordu. İkinci boy tam olarak onu
    // temsil ediyor: geniş bir telefon (430) ama KISA görünür alan (740).
    //
    // 19 Ağustos 2026, üçüncü tur: boşluklar kırpılıp metinlerin son satır
    // leading'i kaldırıldıktan sonra (~23px) eşik düştü, o yüzden boylar da
    // sıkılaştırıldı. **414 EN KÖTÜ DURUM, en dar ekran DEĞİL:** orada
    // kahraman başlığı iki satıra sarıyor AMA tahta zaten geniş (390-24);
    // 430'da başlık tek satıra sığdığından slayt daha kısa. Yani "daha dar
    // ekran = daha zor" sezgisi burada YANLIŞ, ölçümle bulundu.
    // 27 Ağustos 2026 — kullanıcı bildirdi: *"Tanıtımdaki devam butonu
    // ekranın altına yapışıyor ve ortalı değil. Bu kadar uzun olmasına da
    // gerek yok, normal buton gibi olsun."* Üçü de ÖLÇÜLDÜ (390×844):
    // buton x **0 → 378** (tam genişlik), alt kenarı **844** (ekranın tam
    // dibi), etiketi sağdaki 12 px dolgu yüzünden merkezin 6 px solunda.
    //
    // Kök sebep düzende değil `NeoButton`da: kökü `alignment` taşıyan bir
    // `Container` ve o, verilen kısıtların TAMAMINI kaplar. Çare
    // `IntrinsicWidth`.
    //
    // Bu test ÜÇ İDDİANIN ÜÇÜNÜ de ayrı ayrı kilitliyor — biri düzelip
    // öteki bozulursa görünsün diye.
    for (final boy in const [Size(390, 844), Size(844, 390)]) {
      testWidgets(
          '"DEVAM ›" normal boyda, YATAYDA ORTALI ve alt kenara yapışmıyor '
          '— ${boy.width.toInt()}×${boy.height.toInt()}', (tester) async {
        await setPhoneViewSize(tester, boy);
        await tester.pumpWidget(MaterialApp(
          theme: kelimekiTheme(),
          home: IntroScreen(onDone: () {}),
        ));
        await tester.pump();

        final kutu =
            tester.getRect(find.widgetWithText(NeoButton, 'DEVAM ›'));

        // 1) NORMAL BOY — ekranı kaplamıyor. Eskiden genişlik ekranın
        //    %97'siydi (390'da 378).
        expect(kutu.width, lessThan(boy.width * 0.4),
            reason: 'buton yine ekranı kaplıyor — `IntrinsicWidth` düşmüş '
                'olabilir (`NeoButton` kısıtların tamamını kaplar)');

        // 2) YATAYDA ORTALI.
        expect(kutu.center.dx, closeTo(boy.width / 2, 0.5),
            reason: 'buton yatayda ortalı değil');

        // 3) ALT KENARA YAPIŞMIYOR — nefes payı var. (Gerçek cihazda
        //    `SafeArea` bunun ÜSTÜNE sistem çubuğu payını ekler.)
        expect(boy.height - kutu.bottom, greaterThanOrEqualTo(8.0),
            reason: 'buton ekranın dibine yapışmış');
      });
    }

    const boylar = [Size(420, 900), Size(430, 710), Size(414, 720)];
    for (final boy in boylar) {
      testWidgets(
          'tahtalı iki slayt tek ekrana sığar — ${boy.width.toInt()}×'
          '${boy.height.toInt()} (aşağı kaymaz)', (tester) async {
        await setPhoneViewSize(tester, boy);
        await tester.pumpWidget(MaterialApp(
          theme: kelimekiTheme(),
          home: IntroScreen(onDone: () {}),
        ));

        final ilk = dikeyKayma(find.byType(BoardWidget));
        expect(ilk, 0,
            reason: '$boy: 1. slayt $ilk px taşıyor — kroma (üst boşluk, '
                'nokta şeridi, sayfa dolgusu) ve içeriğe bak; taşan piksel '
                'sayısı ne kadar kısaltmak gerektiğini doğrudan söylüyor.');

        await kaydir(tester);

        final ikinci = dikeyKayma(find.byType(BoardWidget));
        expect(ikinci, 0,
            reason: '$boy: 2. slayt $ikinci px taşıyor — rakam kutuları '
                'buraya eklenince sığmaz olduysa denge yanlış kurulmuş.');
      });
    }

    // 19 Ağustos 2026, kullanıcı bildirdi: *"X2, X3 legendlar alt alta
    // gelmiş. Webde yan yana."* Port bunu baştan DİKEY kodlamıştı (iki
    // rozet arasında `SizedBox(height: 6)`), yani sığsa bile alt alta
    // duruyordu; artık web'in `flex-wrap`ının karşılığı olan `Wrap`.
    //
    // METİN VARLIĞI YETMEZ: iki rozetin de EKRANDA olduğunu ölçen mevcut
    // assertion, ikisi alt alta dururken de yeşildi — bu yüzden ölçülen
    // şey KONUM. Web'de eşik ~349px (ölçüldü: 320'de sarıyor, 360'ta yan
    // yana); portta metin sütunu 16+16 dolgu yediğinden eşik ~380px, yani
    // çok dar telefonlarda ALT ALTA düşmesi doğru davranış — bu test
    // yaygın bir boyda (420) yan yana durduğunu güvence altına alıyor.
    testWidgets('1. slayt: X2/X3 legend\'i YAN YANA (web gibi)',
        (tester) async {
      await setPhoneViewSize(tester, const Size(420, 900));
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: IntroScreen(onDone: () {}),
      ));

      final x2 = tester.getRect(find.text('X2 — Kelime puanının 2 katı'));
      final x3 = tester.getRect(find.text('X3 — Kelime puanının 3 katı'));
      expect(x2.top, x3.top,
          reason: 'aynı satırda olmalı; üstleri ${x2.top} ve ${x3.top}');
      expect(x3.left, greaterThan(x2.right),
          reason: 'X3, X2\'nin SAĞINDA olmalı (üst üste binmemeli)');
    });
  });

  group('kapı (_HomeGate)', () {
    testWidgets('ilk açılış: tanıtım çıkar, bitince Setup açılır ve bayrak '
        'GERÇEKTEN yazılır', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 950));
      final storage = await newStorage(tester);
      expect(storage.flags.seenIntro, isFalse);

      await tester.pumpWidget(
          KelimekiApp(services: services(storage: Future.value(storage))));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsOneWidget);
      expect(find.byType(SetupScreen), findsNothing);

      // Tanıtımın TEK çıkışı son sayfadaki düğme — kapı testinin de o
      // yoldan geçmesi gerekiyor (atlama kaldırıldı).
      for (var i = 0; i < kIntroPageCount - 1; i++) {
        await kaydir(tester);
      }
      await tester.tap(find.text('HEMEN OYNA'));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(SetupScreen), findsOneWidget);

      await drainRealIo(tester);
      expect(storage.flags.seenIntro, isTrue,
          reason: 'bayrak yazılmazsa tanıtım HER açılışta tekrar çıkar');
    });

    testWidgets('ikinci açılış: tanıtım HİÇ çıkmaz', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 950));
      final storage = await newStorage(tester, seenIntro: true);

      await tester.pumpWidget(
          KelimekiApp(services: services(storage: Future.value(storage))));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(SetupScreen), findsOneWidget);
      await drainRealIo(tester);
    });

    testWidgets('depo YOKKEN (widget testleri/önizlemeler) kapı devreye '
        'girmez — doğrudan Setup', (tester) async {
      await setPhoneViewSize(tester, const Size(420, 950));
      await tester.pumpWidget(KelimekiApp(services: services()));
      await tester.pump();
      expect(find.byType(IntroScreen), findsNothing);
      expect(find.byType(SetupScreen), findsOneWidget);
    });
  });
}
