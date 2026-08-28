// İzin akışının SIRASI — asıl korunan şey "sistem diyaloğu ne zaman açılır".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/push_repo.dart';
import 'package:kelimeki/src/storage/flags_store.dart';
import 'package:kelimeki/src/ui/push/push_permission_flow.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_repo_test.dart' show FakeMessaging, FakeStore;

class SayanMessaging extends FakeMessaging {
  int istekSayisi = 0;
  PushPermission istekSonucu = PushPermission.granted;

  SayanMessaging({required PushPermission durum}) {
    izin = durum;
  }

  @override
  Future<PushPermission> permission() async => izin;

  @override
  Future<PushPermission> requestPermission() async {
    istekSayisi += 1;
    return istekSonucu;
  }
}

Future<FlagsStore> yeniFlags([Map<String, Object> baslangic = const {}]) async {
  SharedPreferences.setMockInitialValues(baslangic);
  return FlagsStore(await SharedPreferences.getInstance());
}

Future<void> akisiCalistir(
  WidgetTester tester, {
  required SayanMessaging m,
  required FakeStore s,
  required FlagsStore flags,
  bool aktifOyunVar = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: kelimekiTheme(),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => pushIzniAkisi(
          context,
          messaging: m,
          repo: PushRepo(
              messaging: m, store: s, platformKaynagi: () => 'android'),
          flags: flags,
          userId: 'kisi-1',
          aktifOyunVar: aktifOyunVar,
        ),
        child: const Text('baslat'),
      ),
    ),
  ));
  await tester.tap(find.text('baslat'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"ŞİMDİ DEĞİL" sistem diyaloğunu AÇMAZ', (tester) async {
    // Akışın var oluş sebebi bu iddia: Android 13+'ta ikinci sistem reddi
    // kalıcı. Kullanıcı bizim kartımızda hayır derse sistem denemesi
    // HARCANMAMALI, yoksa geri dönüşü olmayan bir hak yakılır.
    final m = SayanMessaging(durum: PushPermission.notDetermined);
    final s = FakeStore();
    final flags = await yeniFlags();
    await akisiCalistir(tester, m: m, s: s, flags: flags);

    expect(find.text('Bildirimleri açalım mı?'), findsOneWidget);
    await tester.tap(find.text('ŞİMDİ DEĞİL'));
    await tester.pumpAndSettle();

    expect(m.istekSayisi, 0, reason: 'sistem diyaloğu açılmamalı');
    expect(flags.pushSorulmaSayisi, 1, reason: 'yine de sorulmuş sayılır');
  });

  testWidgets('"BİLDİRİMLERİ AÇ" sistem diyaloğunu açar ve token yazılır',
      (tester) async {
    final m = SayanMessaging(durum: PushPermission.notDetermined)
      ..istekSonucu = PushPermission.granted;
    final s = FakeStore();
    await akisiCalistir(tester, m: m, s: s, flags: await yeniFlags());

    await tester.tap(find.text('BİLDİRİMLERİ AÇ'));
    await tester.pumpAndSettle();
    expect(m.istekSayisi, 1);
    expect(s.yazilanlar, hasLength(1), reason: 'izin verilince token yazılmalı');
  });

  testWidgets('KALICI reddedilmişse kart HİÇ gösterilmez', (tester) async {
    // Gösterseydik kullanıcı "Aç"a basar ve HİÇBİR ŞEY olmazdı — gözünde
    // bozuk bir buton.
    final m = SayanMessaging(durum: PushPermission.permanentlyDenied);
    final flags = await yeniFlags();
    await akisiCalistir(tester, m: m, s: FakeStore(), flags: flags);
    expect(find.text('Bildirimleri açalım mı?'), findsNothing);
    expect(flags.pushSorulmaSayisi, 0, reason: 'sorulmuş da sayılmamalı');
  });

  testWidgets('aktif oyun yoksa sorulmaz ama token yine de senkronlanır',
      (tester) async {
    final m = SayanMessaging(durum: PushPermission.granted);
    final s = FakeStore();
    await akisiCalistir(tester,
        m: m, s: s, flags: await yeniFlags(), aktifOyunVar: false);
    expect(find.text('Bildirimleri açalım mı?'), findsNothing);
    // Senkron sormaktan BAĞIMSIZ: izin zaten varsa token yazılmalı.
    expect(s.yazilanlar, hasLength(1));
  });

  testWidgets('sistem ayarlarından KAPATILMIŞSA token silinir', (tester) async {
    final m = SayanMessaging(durum: PushPermission.granted);
    final s = FakeStore();
    final flags = await yeniFlags();
    // Önce izinliyken bir kayıt oluşsun.
    await akisiCalistir(tester, m: m, s: s, flags: flags);
    expect(s.yazilanlar, hasLength(1));

    // Kullanıcı ayarlardan kapattı; bir sonraki açılış.
    m.izin = PushPermission.denied;
    await akisiCalistir(tester, m: m, s: s, flags: flags);
    expect(s.silinenler, ['tok-1'],
        reason: 'token varlığı izni takip etmeli (dinleyici gerekmeden)');
  });
}
