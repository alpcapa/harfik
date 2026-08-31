// Push token'ının UYGULAMA YAŞAM DÖNGÜSÜNE bağlanması.
//
// NEDEN VAR (28 Ağustos 2026, gerçek cihaz testinde bulundu): token durumunu
// sistem izniyle hizalayan çağrı YALNIZCA Canlı sekmesinin `_reload()`'undaydı.
// Sonuç, dokümanda "değişmez" diye yazılmış olanın tam tersi: bildirimi SİSTEM
// AYARLARINDAN kapatan ve Canlı sekmesine girmeyen kullanıcının token'ı tabloda
// KALIYORDU — sunucu göndermeye devam ediyor, işletim sistemi sessizce
// yutuyordu.
//
// Cihazda ÖLÇÜLDÜ: bildirim kapatıldı, uygulama tamamen kapatılıp açıldı →
// satır durdu (`updated_at` bile değişmedi); Canlı sekmesi açılınca AYNI
// SANİYE silindi. Yani `PushRepo`'nun kendisi doğruydu, tetikleyici yanlış
// yerdeydi.
//
// Aynı denetimde İKİNCİ boşluk çıktı: `temizle()` hiçbir yerden
// çağrılmıyordu, yani ÇIKIŞ da satırı bırakıyordu — sunucu, o hesabın
// oturumu kapalı bir cihaza göndermeye devam ederdi.
//
// Kritik nokta ve bu testin dayandığı şey: **sistem ayarı uygulamanın DIŞINDA
// değişiyor.** Bunu yakalamanın tek güvenilir anı öne dönüş (`resumed`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/bootstrap.dart';
import 'package:kelimeki/src/config/version_gate.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/data/meaning_store.dart';
import 'package:kelimeki/src/data/push_repo.dart';
import 'package:kelimeki/src/ui/app.dart';
import 'package:kelimeki/src/util/online_status.dart';
import 'package:kelimeki_core/kelimeki_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:kelimeki/src/ui/auth/reset_password_modal.dart';

class FakeMessaging implements PushMessaging {
  PushPermission izin;
  String? tokenDegeri;
  FakeMessaging({this.izin = PushPermission.granted, this.tokenDegeri = 'tok-1'});

  @override
  Future<String?> token() async => tokenDegeri;
  @override
  Stream<String> onTokenRefresh() => const Stream<String>.empty();
  @override
  Future<PushPermission> permission() async => izin;
  @override
  Future<PushPermission> requestPermission() async => izin;
}

class FakeStore implements PushTokenStore {
  final yazilanlar = <String>[];
  final silinenler = <String>[];

  @override
  Future<void> upsert({
    required String token,
    required String userId,
    required String platform,
    String? appVersion,
  }) async =>
      yazilanlar.add('$token/$userId');

  @override
  Future<void> remove(String token) async => silinenler.add(token);
}

/// `AuthService.fake` kullanıcıyı yapıcıda sabitliyor; oturum DEĞİŞİMİNİ
/// (giriş/çıkış) taklit edebilmek için üzerine ince bir kabuk.
class TestAuth extends AuthService {
  TestAuth({User? user})
      : _u = user,
        super.fake();
  User? _u;

  @override
  User? get user => _u;

  void setUser(User? u) {
    _u = u;
    notifyListeners();
  }

  /// `passwordRecovery` kapısını testte açmak için (gerçek akış GoTrue
  /// olayından geliyor, testte taklit edilemiyor).
  bool passwordRecoveryTest = false;
  @override
  bool get passwordRecovery => passwordRecoveryTest;

  /// GERÇEK çıkış adımının anını işaretler (sıra testi).
  ///
  /// ⚠ `signOut`u sarmalamak İŞE YARAMIYOR ve bu ölçülerek bulundu: üst
  /// sınıfın tamamı bitince işaretlenirse, temizlik içeride ister önce
  /// ister sonra koşsun sıra hep aynı görünür — ilk sürüm tam bu yüzden
  /// negatif eşini geçti. İşaretlenecek olan SON ADIM.
  void Function()? onSignOutCalled;

  @override
  Future<void> oturumuKapat() async => onSignOutCalled?.call();
}

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMessaging messaging;
  late FakeStore store;
  late TestAuth auth;

  AppServices kur() {
    messaging = FakeMessaging();
    store = FakeStore();
    auth = TestAuth(user: _user('u1'));
    return AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: auth,
      supabase: null,
      versionGate: VersionGateStatus.ok,
      push: PushRepo(
        messaging: messaging,
        store: store,
        platformKaynagi: () => 'android',
      ),
      pushMessaging: messaging,
    );
  }

  Future<void> ac(WidgetTester tester, AppServices s) async {
    await tester.pumpWidget(KelimekiApp(services: s));
    await tester.pump();
  }

  testWidgets('AÇILIŞTA token izinle hizalanır (Canlı sekmesi GEREKMEZ)',
      (tester) async {
    final s = kur();
    await ac(tester, s);
    await tester.pumpAndSettle();

    expect(store.yazilanlar, ['tok-1/u1'],
        reason: 'açılışta hizalama koşmadı — hata yeniden doğdu: kullanıcı '
            'Canlı sekmesine girmeden token durumu güncellenmiyor');
  });

  testWidgets('ÖNE DÖNÜŞTE sistem ayarındaki kapatma yakalanır', (tester) async {
    final s = kur();
    await ac(tester, s);
    await tester.pumpAndSettle();
    store.silinenler.clear();

    // Kullanıcı uygulamadan ÇIKMADAN sistem ayarlarına gidip bildirimi
    // kapattı — uygulamanın bundan haberi olmasının tek yolu öne dönüş.
    messaging.izin = PushPermission.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(store.silinenler, ['tok-1'],
        reason: 'öne dönüşte token silinmedi — sistem ayarından kapatan '
            'kullanıcıya sunucu göndermeye devam eder');
  });

  test('ÇIKIŞ temizliği oturum KAPANMADAN ÖNCE koşar', () async {
    // ⚠ SIRA TESTİ, varlık testi değil (29 Ağustos 2026, cihazda bulundu):
    // temizlik `onAuthStateChange` dinleyicisine bağlıydı, yani oturum ZATEN
    // kapandıktan sonra koşuyordu. O anda `auth.uid()` null olduğundan
    // `push_tokens` DELETE'i RLS'e takılıp HİÇBİR SATIRA dokunmuyor ve hata
    // da vermiyor — çıkmış hesabın bildirimleri o telefona düşmeye devam
    // ediyor. Aşağıdaki `sira` listesi tam olarak bunu kilitliyor.
    final sira = <String>[];
    final auth = TestAuth(user: _user('u1'));
    auth.registerBeforeSignOut(() async => sira.add('temizlik'));
    auth.onSignOutCalled = () => sira.add('signOut');

    await auth.signOut();

    expect(sira, ['temizlik', 'signOut'],
        reason: 'Temizlik çıkıştan SONRA koşarsa kimlik kaybedilmiş olur ve '
            'RLS silmeyi sessizce reddeder — satır tabloda kalır.');
  });

  testWidgets('ÇIKIŞTA token silinir', (tester) async {
    final s = kur();
    await ac(tester, s);
    await tester.pumpAndSettle();
    store.silinenler.clear();

    auth.setUser(null);
    await tester.pumpAndSettle();

    expect(store.silinenler, ['tok-1'],
        reason: 'çıkışta token silinmedi — sunucu, oturumu kapalı bir cihaza '
            'göndermeye devam eder (temizle hiçbir yerden çağrılmıyordu)');
  });

  testWidgets('HESAP DEĞİŞİMİNDE token yeni kullanıcıya devrolur',
      (tester) async {
    // 28 Ağustos 2026, cihazda ÖLÇÜLDÜ: T2 ile giriş yapılıp satır T2'ye
    // yazıldıktan sonra Ironman'a geçildi — satır T2'DE KALDI (`updated_at`
    // bile değişmedi), uygulama ise Ironman gösteriyordu.
    //
    // Bunun bedeli boşa gönderim DEĞİL, YANLIŞ KİŞİYE gönderim: T2'ye
    // gidecek bildirim, Ironman'ın girişli olduğu telefona düşer.
    //
    // Eski kodda hizalama Canlı sekmesinin `_reload()`'una bağlıydı ve o da
    // liste yüklemesi düşerse erken dönüyordu; yani devir üç ayrı yoldan
    // atlanabiliyordu. Artık oturum değişimi TEK BAŞINA yeterli.
    final s = kur();
    await ac(tester, s);
    await tester.pumpAndSettle();
    store.yazilanlar.clear();

    auth.setUser(_user('u2'));
    await tester.pumpAndSettle();

    expect(store.yazilanlar, ['tok-1/u2'],
        reason: 'hesap değişiminde token devrolmadı — eski hesabın '
            'bildirimleri yeni kullanıcının telefonuna düşer');
  });

  testWidgets('şifre kurtarma ekranının ARKASINDA logo var (boş beyaz DEĞİL)',
      (tester) async {
    // 29 Ağustos 2026, kullanıcı cihazda bildirdi: *"Şifre değiştirme
    // modalının arkası boş ekran. En azından kelimeki logosu görünmeli."*
    // Bu ekrana kullanıcı bir E-POSTA LİNKİNDEN düşüyor; beyaz bir sayfada
    // şifre isteyen bir kutu kimlik avından ayırt edilemez. Web'de de aynı
    // eksikti ve aynı PR'da düzeltildi (`App.tsx`, passwordRecovery dalı).
    final s = kur();
    (s.auth as TestAuth).passwordRecoveryTest = true;
    await ac(tester, s);
    await tester.pumpAndSettle();

    // ⚠ `find.byType(LogoMark)` KULLANMA: arkadaki Setup ekranı da bir logo
    // çiziyor, yani bu logo hiç olmasa bile eşleşir — ilk sürüm tam bu
    // yüzden negatif eşini geçti (29 Ağustos 2026, ölçüldü).
    expect(find.byKey(const ValueKey('recovery-logo')), findsOneWidget,
        reason: 'Kurtarma ekranının arkasında logo yok — kullanıcı, linke '
            'bastığı yerin Kelimeki olduğunu doğrulayacak hiçbir şey '
            'göremiyor.');
    // Logo modalın ÜSTÜNDE durmalı, altında değil.
    final logoY = tester.getCenter(find.byKey(const ValueKey('recovery-logo'))).dy;
    final modalY = tester.getCenter(find.byType(ResetPasswordModal)).dy;
    expect(logoY, lessThan(modalY),
        reason: 'Logo modalın altına düşmüş — ekranın üst yarısında olmalı');
  });

  testWidgets('push YOKKEN (web/Firebase yok) kapı sorunsuz açılır',
      (tester) async {
    final s = AppServices(
      onlineStatus: OnlineStatus.fake(),
      dictionary: Future.value(SetWordSource(const ['ab'])),
      meanings: MeaningStore(bundle: rootBundle),
      auth: TestAuth(user: _user('u1')),
      supabase: null,
      versionGate: VersionGateStatus.ok,
    );
    await ac(tester, s);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
