// SİSTEM YAZI BOYUTU büyütüldüğünde düzen ayakta kalıyor mu?
//
// NEDEN VAR (28 Ağustos 2026, kullanıcı cihazda bildirdi: *"Görmediği için
// telefon fontlarını büyütenlerde ciddi sorunlar çıkıyor. Mesela, arkadaşlık
// davetinde davetin kimden geldiği görünmüyor. Bunun dışında başka yerler de
// patlıyor."*).
//
// **Bu sınıfı hiçbir test göremiyordu**, çünkü tüm widget testleri ölçek
// 1,0'da koşuyor. Envanter, takımın TAMAMI ölçek enjekte edilerek yeniden
// koşturularak çıkarıldı (`platformDispatcher.textScaleFactorTestValue`):
// taşma sayısı 1,0 → **0** · 1,3 → **10** · 1,6 → **27** · 2,0 → **73**.
//
// ⚠ **Takımın tamamını 1,3'te koşturmak bir CI KAPISI OLARAK KULLANILAMAZ**
// (denendi ve ölçüldü): 31 test düşüyor ve büyük çoğunluğu GERÇEK bir hata
// değil — bu projede birçok test web paritesini piksel piksel ölçüyor
// (golden dikdörtgenler, kutu yükseklikleri), ölçek değişince o ölçümler
// tanım gereği kayıyor. Bu yüzden kalıcı kapı BURASI: geometriyi değil
// "taşma var mı / bilgi kayboluyor mu" sorusunu ölçen dar bir test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/friends_api.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/ui/friends/friends_modal.dart';
import 'package:kelimeki/src/ui/game/board_widget.dart';
import 'package:kelimeki/src/ui/text_scale.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

Player _player(String name, int index) => Player(
      name: name,
      corners: cornersFor(2)[index],
      colorIndex: index,
      isAI: false,
      surrendered: false,
      rack: const [],
      score: 0,
      bestMoveScore: 0,
      bestWordScore: 0,
      longestWord: '',
      moveCount: 0,
      moveScoreSum: 0,
    );

GameState _state() => GameState(
      phase: GamePhase.play,
      startedAt: '',
      multiSession: false,
      endReason: EndReason.normal,
      board: createEmptyBoard(),
      bag: const [],
      bonuses: buildInitialBonuses(),
      placed: const {},
      players: [_player('Ben', 0), _player('Rakip', 1)],
      current: 0,
      selectedTile: null,
      swapMode: false,
      swapSelection: const [],
      turnCount: 5,
      consecutivePasses: 0,
      isGameOver: false,
      message: '',
      messageType: MessageKind.none,
      lastMoveCells: const [],
      moveHistory: const [],
    );

class _IstekGw implements FriendsGateway {
  @override
  Future<List<Map<String, Object?>>> listIncomingRequests() async => [
        {'requester_id': 'r1', 'name': 'Esiner Yıldırım', 'avatar_url': null},
      ];
  @override
  noSuchMethod(Invocation i) => Future.value(const <Map<String, Object?>>[]);
}

Widget _olcekli(double olcek, Widget child) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
      child: MaterialApp(theme: kelimekiTheme(), home: Scaffold(body: child)),
    );

void main() {
  setUpAll(loadAppFonts);

  // ——— 1. TAVAN GERÇEKTEN BAĞLI MI? ———
  //
  // Tek bir satırın (MaterialApp.builder'daki `withClampedTextScaling`)
  // sessizce düşmesi, aşağıdaki her şeyi anlamsız kılar: kısıt yoksa
  // uygulama yine 2,0'a çıkar ve o ölçekte 59 taşma noktası duruyor
  // (ölçüldü — hepsi bugün ERİŞİLEMEZ, çünkü tavan var).
  testWidgets('yazı ölçeği $kMaxTextScale ile SINIRLI — kısıt bağlı',
      (tester) async {
    await setPhoneViewSize(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    late double icerdekiOlcek;
    await tester.pumpWidget(KelimekiApp(
      services: AppServices(
        onlineStatus: OnlineStatus.fake(),
        dictionary: Future.value(SetWordSource(const ['ab'])),
        meanings: MeaningStore(bundle: rootBundle),
        auth: AuthService.fake(user: null),
        supabase: null,
        versionGate: VersionGateStatus.ok,
      ),
    ));
    await tester.pumpAndSettle();

    // Ağacın İÇİNDEN oku — `MaterialApp.builder` Navigator'ı sardığından
    // her ekran bu değeri görür.
    final ctx = tester.element(find.byType(Scaffold).first);
    icerdekiOlcek = MediaQuery.textScalerOf(ctx).scale(100) / 100;

    expect(icerdekiOlcek, lessThanOrEqualTo(kMaxTextScale + 0.001),
        reason: 'Sistem 3,0 istedi, ağaç ${icerdekiOlcek.toStringAsFixed(2)} '
            'gördü. `MediaQuery.withClampedTextScaling` düşmüş olabilir — '
            'onsuz uygulama 2,0\'a çıkar ve orada 59 taşma noktası var.');
    expect(icerdekiOlcek, greaterThan(1.0),
        reason: 'Kısıt ölçeği 1,0\'a KİLİTLEMEMELİ — fontu göremediği için '
            'büyüten kullanıcıya hiçbir şey vermemek olurdu; karar 1,3 tavan '
            '(28 Ağustos 2026).');
  });

  // ——— 2. TAŞMA: tahtanın alt şeridi ———
  //
  // `kMaxTextScale` tavanından SONRA kalan TEK taşma noktasıydı (8,3-14 px);
  // `Row` → `Wrap` ile kapatıldı. Burada tavanın kendisinde ölçülüyor.
  testWidgets('tahta alt şeridi $kMaxTextScale ölçeğinde TAŞMIYOR',
      (tester) async {
    await setPhoneViewSize(tester, const Size(360, 800));
    await tester.pumpWidget(_olcekli(
      kMaxTextScale,
      BoardWidget(
        state: _state(),
        onOpenHistory: () {},
        onOpenMessaging: () {},
        onOpenHelp: () {},
        // "Çevrimdışı" rozeti de şeritte — en dolu hâli bu.
        onlineStatus: OnlineStatus.fake(online: false),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Alt şerit taştı. İki grup da `shrink-0` olduğundan düz bir '
            '`Row` sığmadığı anda taşar — bu yüzden `Wrap` kullanılıyor.');
    // Şeridin üç kontrolü de GÖRÜNÜR kalmalı (taşmayı gizlemek çözüm değil).
    for (final t in const ['Hamleler', 'Mesajlaşma', 'Nasıl Oynanır?']) {
      expect(find.text(t), findsOneWidget, reason: '$t şeritten düştü');
    }
  });

  // ——— 2b. Şerit TAŞMIYOR ama KÜMELENİYOR mu? ———
  //
  // 30 Ağustos 2026, bir kullanıcı cihazda bildirdi (iki ekran görüntüsü):
  // *"Hamleler, Mesajlaşma satırı Android'de ortaya kümelenmiş, iPhone'da
  // (web) kenarlara yaslı."* Yukarıdaki `Row` → `Wrap` düzeltmesinin yan
  // etkisiydi: `Row` (mainAxisSize.max) gelen genişliği DOLDURUR, `Wrap`
  // ise gevşek kısıt altında içeriğine KÜÇÜLÜR. Küçülen kutuda
  // dağıtılacak boşluk kalmadığından `spaceBetween` no-op olur; üstteki
  // `Column`un varsayılan `center` hizası da kümeyi ortaya alır.
  //
  // ⚠ Yukarıdaki 2. test bunu GÖREMEZ ve görmesi de beklenmez: kümelenme
  // taşma ÜRETMEZ, üç metin de bulunur. `tap_target_test` de göremez —
  // orası yalnızca kutu BOYUTLARINI (48×48) ölçüyor, KONUM ölçmüyor.
  //
  // ⚠ **İlk yazılan iddia YANLIŞTI ve ölçüm düzeltti:** "kümelenince iki
  // grup birbirine yapışır" sanılmıştı, oysa gruplar arası boşluk
  // kümelenmiş hâlde de 124,7 px. Kümelenmenin gerçek imzası boşluğun
  // KÜÇÜK olması değil, **genişlikten BAĞIMSIZ** olması: `Wrap` doğal
  // genişliğinde (313,3 px) donduğu için 360/390/430 px'te boşluk hep
  // 124,7 px çıkıyordu. Düzeltmeden sonra 151,4 / 181,4 / 221,4 —
  // yani şerit büyüdükçe boşluk da büyüyor. Test bu yüzden TEK bir
  // genişlikte değil İKİ genişlikte ölçüyor.
  testWidgets('tahta alt şeridi ŞERİDİ DOLDURUR (kümelenmez)',
      (tester) async {
    // Şeridin yatay dolgusu (`_footer`ın `EdgeInsets.symmetric(horizontal:
    // 10)`) — sağ/sol uçtaki linkler bu kadar içeride durmalı.
    const dolgu = 10.0;

    Future<({double solBosluk, double sagBosluk, double aradakiBosluk})> olc(
        double genislik) async {
      await setPhoneViewSize(tester, Size(genislik, 844));
      await tester.pumpWidget(_olcekli(
        1.0,
        BoardWidget(
          state: _state(),
          onOpenHistory: () {},
          onOpenMessaging: () {},
          onOpenHelp: () {},
        ),
      ));
      await tester.pump();
      final tahta = tester.getRect(find.byType(BoardWidget));
      final sol = tester.getRect(find.text('Hamleler'));
      final sag = tester.getRect(find.text('Nasıl Oynanır?'));
      return (
        solBosluk: sol.left - tahta.left,
        sagBosluk: tahta.right - sag.right,
        aradakiBosluk: sag.left - sol.right,
      );
    }

    final dar = await olc(360);
    final genis = await olc(430);

    // 1) Sağ uçtaki link şeridin SAĞ kenarına yaslı (yalnızca dolgu kadar
    //    içeride). Kümelenmiş hâlde bu 38,4 / 58,4 px çıkıyordu.
    for (final (ad, m) in [('360', dar), ('430', genis)]) {
      expect(m.sagBosluk, lessThan(dolgu + 1),
          reason: '$ad px: "Nasıl Oynanır?" sağ kenara yaslı değil '
              '(${m.sagBosluk.toStringAsFixed(1)} px içeride). `Wrap` gelen '
              'genişliği DOLDURMUYOR demektir — `SizedBox(width: '
              'double.infinity)` düşmüş olabilir (board_widget.dart '
              '`_footer`).');
    }

    // 2) ASIL İMZA: şerit genişledikçe iki grup arasındaki boşluk da
    //    büyümeli. Şerit 70 px genişledi; `spaceBetween` çalışıyorsa
    //    boşluk da ~70 px büyür, `Wrap` doğal genişliğinde donmuşsa HİÇ
    //    değişmez.
    final buyume = genis.aradakiBosluk - dar.aradakiBosluk;
    expect(buyume, greaterThan(60),
        reason: 'Şerit 360→430 px büyüdü ama gruplar arası boşluk yalnızca '
            '${buyume.toStringAsFixed(1)} px arttı. Boşluğun genişlikten '
            'BAĞIMSIZ olması kümelenmenin imzasıdır.');
  });

  // ——— 3. SIFIRA SIKIŞMA: arkadaşlık isteği satırı ———
  //
  // Kullanıcının BİLDİRDİĞİ hata. Taşma üretmediğinden yukarıdaki envantere
  // hiç girmiyordu; tavan da çözmüyor (360 px ekranda isim ölçek 1,0'da
  // 77,6 px, 1,3'te 53,2 px, 2,0'da **0,0 px** — ölçüldü). Çözüm satırı
  // ikiye bölmek: üstte isim, altta butonlar.
  //
  // ⚠ Ölçüt MUTLAK bir genişlik DEĞİL, 1,0'daki kendi genişliği. Sebebi
  // ölçülerek bulundu: 360 px'lik dar bir ekranda "Esiner Yıldırım" ölçek
  // 1,0'da BİLE tam sığmıyor (77,6 px'te üç noktaya iniyor) — yani mutlak
  // bir eşik ya bugünü hatalı sayardı ya da hiçbir şeyi yakalamazdı. Kural
  // şu: yazı büyüdüğünde isim için ayrılan yer KÜÇÜLMESİN.
  testWidgets('istek satırında ADIN yeri yazı büyüdükçe DARALMAZ',
      (tester) async {
    Future<double> adGenisligi(double olcek) async {
      await setPhoneViewSize(tester, const Size(360, 800));
      await tester.pumpWidget(_olcekli(
        olcek,
        FriendsModal(
          friends: FriendsRepo(_IstekGw()),
          auth: AuthService.fake(user: null),
          initialTab: FriendsTab.requests,
        ),
      ));
      await tester.pump();
      await tester.pump();

      final ad = find.text('Esiner Yıldırım');
      expect(ad, findsOneWidget, reason: 'ölçek $olcek: isim hiç çizilmemiş');
      // Bölme, aksiyonu GİZLEMEK değil — butonlar da yerinde kalmalı.
      expect(find.text('KABUL ET'), findsOneWidget,
          reason: 'ölçek $olcek: Kabul Et düştü');
      expect(find.text('REDDET'), findsOneWidget,
          reason: 'ölçek $olcek: Reddet düştü');
      expect(tester.takeException(), isNull, reason: 'ölçek $olcek: taşma');
      return tester.getSize(ad).width;
    }

    final taban = await adGenisligi(1.0);
    // ignore: avoid_print
    print('[ÖLÇÜM] istek satırı — isim genişliği @1.0 = '
        '${taban.toStringAsFixed(1)} px');

    for (final olcek in const [kMaxTextScale, 2.0]) {
      final w = await adGenisligi(olcek);
      // ignore: avoid_print
      print('[ÖLÇÜM] istek satırı — isim genişliği @$olcek = '
          '${w.toStringAsFixed(1)} px');
      expect(w, greaterThanOrEqualTo(taban),
          reason: 'Ölçek $olcek\'te isim ${w.toStringAsFixed(1)} px — '
              '1,0\'daki ${taban.toStringAsFixed(1)} px\'ten DAR. Satırdaki '
              'tek esnek öğe isim, "KABUL ET"/"REDDET" ise metin butonu: '
              'büyüdükçe ismi eziyorlar. Eşik aşılınca satır ikiye '
              'bölünmeli (bkz. `buyukOlcek`).');
    }
  });
}
