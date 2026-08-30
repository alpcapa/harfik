// Play In-App Update kararı — "app açıldığında yeni sürüm varsa uyar ve
// yaptır" (30 Ağustos 2026, kullanıcı isteği).
//
// NEDEN BU TESTLER VAR: bu akışın CİHAZDA doğrulanması pahalı — In-App
// Update yalnızca Play'den KURULMUŞ pakette çalışıyor, yani CI'ın debug
// `.apk`'sında hiç görünmüyor (bkz. `lib/src/data/store_update.dart` →
// sınırlar). Cihazda ölçülemeyen her dal buradaki sahte gateway'le
// kilitleniyor; cihazda kalan tek soru "Play gerçekten cevap veriyor mu".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/data/store_update.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/update_required_screen.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki_core/kelimeki_core.dart';

import 'support/test_view.dart';

class FakeStoreUpdate implements StoreUpdateGateway {
  StoreUpdateDurumu durum;
  bool akisBasarili;
  int kontrolSayisi = 0;
  int guncelleSayisi = 0;

  FakeStoreUpdate({
    this.durum = StoreUpdateDurumu.gerekYok,
    this.akisBasarili = true,
  });

  @override
  Future<StoreUpdateDurumu> kontrolEt() async {
    kontrolSayisi++;
    return durum;
  }

  @override
  Future<bool> hemenGuncelle() async {
    guncelleSayisi++;
    return akisBasarili;
  }
}

void main() {
  group('magazaGuncellemesiniCalistir', () {
    test('güncelleme varsa Immediate akışı BAŞLATILIR ve soru kapanır',
        () async {
      final gw = FakeStoreUpdate(
          durum: StoreUpdateDurumu.hemenGuncellenebilir);
      expect(await magazaGuncellemesiniCalistir(gw), isTrue);
      expect(gw.guncelleSayisi, 1);
    });

    test('güncelleme yoksa akış HİÇ başlatılmaz', () async {
      final gw = FakeStoreUpdate(durum: StoreUpdateDurumu.gerekYok);
      expect(await magazaGuncellemesiniCalistir(gw), isTrue);
      expect(gw.guncelleSayisi, 0);
    });

    // ⚠ Bu dal, özelliğin var oluş sebebinin kendisi: "soramadım"ı
    // "güncel" saymak, açılışta ağı olmayan kullanıcıyı sonsuza dek eski
    // sürümde bırakırdı — 1.0.0'da 93 kişiyle yaşanan tam olarak buydu.
    test('sorulamadıysa soru KAPANMAZ (öne dönüşte tekrar denenir)',
        () async {
      final gw = FakeStoreUpdate(durum: StoreUpdateDurumu.bilinmiyor);
      expect(await magazaGuncellemesiniCalistir(gw), isFalse);
      expect(gw.guncelleSayisi, 0);
    });

    // Kullanıcı Play'in penceresinde vazgeçerse soru yine KAPANIR: her öne
    // dönüşte tam ekran bir güncelleme penceresi açmak düşmanca olurdu.
    // Bir sonraki AÇILIŞTA yeniden sorulur.
    test('kullanıcı vazgeçerse soru kapanır (öne dönüşte tekrar AÇILMAZ)',
        () async {
      final gw = FakeStoreUpdate(
          durum: StoreUpdateDurumu.hemenGuncellenebilir,
          akisBasarili: false);
      expect(await magazaGuncellemesiniCalistir(gw), isTrue);
      expect(gw.guncelleSayisi, 1);
    });
  });

  group('UpdateRequiredScreen (acil fren)', () {
    testWidgets('buton önce uygulama İÇİNDEKİ akışı dener', (tester) async {
      final gw = FakeStoreUpdate(
          durum: StoreUpdateDurumu.hemenGuncellenebilir);
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: UpdateRequiredScreen(storeUpdate: gw),
      ));
      await tester.tap(find.byKey(const ValueKey('update-store-button')));
      await tester.pump();
      expect(gw.guncelleSayisi, 1);
    });

    // Yedek yol: Play In-App Update yan yüklenmiş pakette HİÇ çalışmaz ve
    // bu ekranı görenler tanım gereği eski sürümde. Yedek olmadan yine
    // çıkışsız bir ekran olurdu — 1.0.0'ın hatasının aynısı.
    testWidgets('Play cevap vermezse ÇÖKMEZ (mağaza yedeğine düşer)',
        (tester) async {
      final gw = FakeStoreUpdate(durum: StoreUpdateDurumu.bilinmiyor);
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: UpdateRequiredScreen(storeUpdate: gw),
      ));
      await tester.tap(find.byKey(const ValueKey('update-store-button')));
      await tester.pump();
      expect(gw.guncelleSayisi, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gateway yokken buton eski davranışını sürdürür (ÇÖKMEZ)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: kelimekiTheme(),
        home: const UpdateRequiredScreen(),
      ));
      await tester.tap(find.byKey(const ValueKey('update-store-button')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
  // ——— KABLOLAMA: kanca gerçekten AÇILIŞTA koşuyor mu? ———
  //
  // Yukarıdaki kararlar doğru olsa bile `_HomeGate` onu çağırmıyorsa özellik
  // ölü olur ve hiçbir test bunu söylemez. Bu projede tam bu sınıf bir hata
  // yaşandı: push token hizalaması "her açılışta koşuyor" sanılıyordu, oysa
  // çağrı yalnızca Canlı sekmesindeydi (Parça 159).
  group('kablolama — _HomeGate', () {
    Future<FakeStoreUpdate> pumpApp(
      WidgetTester tester, {
      StoreUpdateDurumu durum = StoreUpdateDurumu.gerekYok,
    }) async {
      final gw = FakeStoreUpdate(durum: durum);
      await setPhoneViewSize(tester, const Size(390, 844));
      await tester.pumpWidget(KelimekiApp(
        services: AppServices(
          onlineStatus: OnlineStatus.fake(),
          dictionary: Future.value(SetWordSource(const ['ab'])),
          meanings: MeaningStore(bundle: rootBundle),
          auth: AuthService.fake(user: null),
          supabase: null,
          versionGate: VersionGateStatus.ok,
          storeUpdate: gw,
        ),
      ));
      await tester.pumpAndSettle();
      return gw;
    }

    testWidgets('açılışta Play\'e SORULUR', (tester) async {
      final gw = await pumpApp(tester);
      expect(gw.kontrolSayisi, 1, reason: 'Açılış kancası koşmadı');
    });

    testWidgets('güncelleme varsa açılışta akış BAŞLAR', (tester) async {
      final gw =
          await pumpApp(tester, durum: StoreUpdateDurumu.hemenGuncellenebilir);
      expect(gw.guncelleSayisi, 1);
    });

    // Soru bir kez KAPANDIYSA öne dönüş onu tekrar açmamalı.
    testWidgets('soru kapandıysa öne dönüşte TEKRAR sorulmaz', (tester) async {
      final gw = await pumpApp(tester);
      expect(gw.kontrolSayisi, 1);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gw.kontrolSayisi, 1, reason: 'Kapanmış soru yeniden soruldu');
    });

    // ⚠ Ama SORULAMADIYSA öne dönüş yeniden denemeli — açılışta ağı olmayan
    // kullanıcı yoksa sonsuza dek eski sürümde kalır.
    testWidgets('sorulamadıysa öne dönüşte TEKRAR sorulur', (tester) async {
      final gw = await pumpApp(tester, durum: StoreUpdateDurumu.bilinmiyor);
      expect(gw.kontrolSayisi, 1);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(gw.kontrolSayisi, 2,
          reason: 'Ağsız açılıştan sonra bir daha hiç sorulmadı');
    });
  });
}
