// Hesap Ayarları — web AccountSettingsModal.tsx portu: hidrasyon
// (profil/e-posta), doğrulama sırası (Ad → Soyad → Takma isim → doğum
// tarihi), takma isim debounce (sahte denetleyiciyle — AuthModal'daki
// aynı desen), pazarlama onayı tarihi. Gerçek `updateProfile`/`updateEmail`
// (Supabase RLS/trigger) bu ortamdan test EDİLEMEZ — `AuthService.fake`
// gerçek bir Supabase client taşımadığından, doğrulamayı geçen bir
// gönderim "Supabase yapılandırılmadı." ile sonuçlanır; bu, akışın ağ
// çağrısına GERÇEKTEN ulaştığının kanıtı olarak kullanılıyor (signup_test
// ile aynı sınır/desen).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:kelimeki/src/ui/theme.dart';
import 'package:kelimeki/src/ui/auth/account_button.dart';
import 'package:kelimeki/src/ui/auth/account_settings_modal.dart';
import 'package:kelimeki/src/ui/game/neo_button.dart';
import 'package:kelimeki/src/util/avatar_image.dart';
import 'package:kelimeki/src/util/avatar_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'support/test_fonts.dart';
import 'support/test_view.dart';

User fakeUser(String id, {String email = 'me@ornek.com'}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
      email: email,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> pumpSettings(
    WidgetTester tester,
    AuthService auth, {
    Future<bool> Function(String)? checker,
    PickAvatarFn? pickAvatar,
    ShrinkAvatarFn? shrinkAvatar,
  }) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(
        body: AccountSettingsModal(
            auth: auth,
            nicknameChecker: checker,
            pickAvatar: pickAvatar,
            shrinkAvatar: shrinkAvatar),
      ),
    ));
    await tester.pump();
  }

  Finder field(String key) => find.byKey(ValueKey('field-$key'));

  testWidgets('hidrasyon: profil + e-posta alanları doldurulmuş gelir',
      (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me', email: 'ironman@ornek.com'),
      profile: const KProfile(
        id: 'me',
        firstName: 'Deniz',
        lastName: 'Can',
        displayName: 'ironman',
        gender: 'male',
        birthDate: '1990-05-20',
        marketingConsent: true,
        marketingConsentAt: '2026-08-01T14:32:00Z',
        emailNotificationsEnabled: false,
      ),
    );
    await pumpSettings(tester, auth);

    expect(tester.widget<TextField>(field('first-name')).controller!.text,
        'Deniz');
    expect(tester.widget<TextField>(field('last-name')).controller!.text,
        'Can');
    expect(
        tester.widget<TextField>(field('nickname')).controller!.text,
        'ironman');
    expect(tester.widget<TextField>(field('email')).controller!.text,
        'ironman@ornek.com');
    expect(
        tester
            .widget<TextField>(field('birth-date'))
            .controller!
            .text,
        '20/05/1990');
    // Pazarlama onayı işaretli + kabul tarihi (yerel saate çevrilmiş).
    expect(find.byType(Checkbox).at(0), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).at(0)).value, isTrue);
    expect(find.textContaining('Kabul tarihi:'), findsOneWidget);
    // E-posta bildirimi tercihi kapalı gelmiş.
    expect(
        tester.widget<Checkbox>(find.byType(Checkbox).at(1)).value, isFalse);
  });

  testWidgets('doğrulama sırası: Ad → Soyad → Takma isim → doğum tarihi',
      (tester) async {
    final auth = AuthService.fake(user: fakeUser('me'));
    await pumpSettings(tester, auth, checker: (_) async => true);

    Future<void> submitExpect(String msg) async {
      await tester.tap(find.text('KAYDET'));
      await tester.pump();
      expect(find.text(msg), findsOneWidget);
    }

    await submitExpect('Ad zorunludur.');
    await tester.enterText(field('first-name'), 'Deniz');
    await tester.pump();
    await submitExpect('Soyad zorunludur.');
    await tester.enterText(field('last-name'), 'Can');
    await tester.pump();
    await submitExpect('Takma isim zorunludur.');

    await tester.enterText(field('nickname'), 'denizcan');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('Kullanılabilir'), findsOneWidget);

    await tester.enterText(
        field('birth-date'), '31/13/1990');
    await tester.pump();
    await submitExpect('Doğum ayı geçersiz.');

    // Doğum tarihi de geçerliyken artık ağ çağrısına ulaşır — fake client
    // "Supabase yapılandırılmadı." ile döner (akışın ucu buraya kadar geldi).
    await tester.enterText(field('birth-date'), '');
    await tester.pump();
    await submitExpect('Supabase yapılandırılmadı.');
  });

  testWidgets(
      'takma isim: mevcut isimle AYNIYSA kontrol atlanır (sunucuya sorulmaz)',
      (tester) async {
    final asked = <String>[];
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    await pumpSettings(tester, auth, checker: (n) async {
      asked.add(n);
      return true;
    });

    // Aynı ismi yeniden yaz — "checking" hiç görünmemeli.
    await tester.enterText(field('nickname'), 'ironman');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(asked, isEmpty);
    expect(find.text('Kontrol ediliyor…'), findsNothing);
  });

  testWidgets('takma isim dolu → KAYDET engellenir (submit hiç çalışmaz)',
      (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(
          id: 'me', firstName: 'D', lastName: 'C', displayName: 'eskiisim'),
    );
    await pumpSettings(tester, auth, checker: (_) async => false);

    await tester.enterText(field('nickname'), 'ironman');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    expect(find.text('Bu takma isim kullanımda.'), findsOneWidget);

    await tester.tap(find.text('KAYDET'), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Bu takma isim zaten kullanılıyor.'), findsNothing);
    expect(find.text('Supabase yapılandırılmadı.'), findsNothing);
  });

  testWidgets(
      'profil fotoğrafı: seçim → yükleme → ağ çağrısına ulaşır (fake client "Supabase yapılandırılmadı." döner)',
      (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    await pumpSettings(tester, auth,
        pickAvatar: () async => PickedImage(
            bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/png'));

    expect(find.text('FOTOĞRAF DEĞİŞTİR'), findsOneWidget);
    await tester.tap(find.text('FOTOĞRAF DEĞİŞTİR'));
    await tester.pumpAndSettle();
    // AuthService.fake gerçek bir Supabase client taşımıyor —
    // uploadAvatar'ın `_client == null` kontrolüne takılıp
    // 'Supabase yapılandırılmadı.' fırlatması, akışın GERÇEKTEN
    // AuthService.uploadAvatar'a ulaştığının kanıtı (signup_test/_save
    // testleriyle aynı sınır/desen).
    expect(find.text('Supabase yapılandırılmadı.'), findsOneWidget);
    expect(find.text('YÜKLENİYOR…'), findsNothing);
    expect(find.text('FOTOĞRAF DEĞİŞTİR'), findsOneWidget);
  });

  testWidgets(
      'profil fotoğrafı: seçilen görsel YÜKLEMEDEN ÖNCE küçültme katmanından '
      'geçer (10 MB yalnızca giriş sınırı — saklanan küçük hâli)',
      (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    final buyuk = PickedImage(
        bytes: Uint8List(3 * 1024 * 1024), mimeType: 'image/jpeg');
    PickedImage? shrinkGirdisi;
    await pumpSettings(
      tester,
      auth,
      pickAvatar: () async => buyuk,
      shrinkAvatar: (p) async {
        shrinkGirdisi = p;
        return PickedImage(
            bytes: Uint8List(40 * 1024), mimeType: 'image/png');
      },
    );

    await tester.tap(find.text('FOTOĞRAF DEĞİŞTİR'));
    await tester.pumpAndSettle();

    expect(shrinkGirdisi, isNotNull,
        reason: 'Küçültme katmanı hiç çağrılmadı — 3 MB’lık orijinal olduğu '
            'gibi yüklenirdi');
    expect(identical(shrinkGirdisi, buyuk), isTrue);
    // Akış küçültmeden SONRA da yüklemeye devam etmeli (fake client'ta
    // beklenen hata mesajı, diğer avatar testleriyle aynı sınır).
    expect(find.text('Supabase yapılandırılmadı.'), findsOneWidget);
  });

  testWidgets('profil fotoğrafı: galeri iptal edilirse (null) hiçbir şey olmaz',
      (tester) async {
    var calls = 0;
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    await pumpSettings(tester, auth, pickAvatar: () async {
      calls++;
      return null;
    });

    await tester.tap(find.text('FOTOĞRAF DEĞİŞTİR'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('YÜKLENİYOR…'), findsNothing);
    expect(find.text('Supabase yapılandırılmadı.'), findsNothing);
    expect(find.text('FOTOĞRAF DEĞİŞTİR'), findsOneWidget);
  });

  testWidgets('AccountButton menüsünde "Hesap Ayarları" satırı modalı açar',
      (tester) async {
    await setPhoneViewSize(tester, const Size(420, 900));
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    await tester.pumpWidget(MaterialApp(
      theme: kelimekiTheme(),
      home: Scaffold(body: Align(child: AccountButton(auth: auth))),
    ));
    await tester.pump();

    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();
    expect(find.text('⚙️  Hesap Ayarları'), findsOneWidget);

    await tester.tap(find.text('⚙️  Hesap Ayarları'));
    await tester.pumpAndSettle();
    expect(find.text('HESAP AYARLARI'), findsOneWidget);
    expect(find.byType(AccountSettingsModal), findsOneWidget);
  });

  // --- Parça 87 -------------------------------------------------------
  // Android'in `image_picker`ı, `maxWidth/maxHeight/imageQuality` verilince
  // görseli yeniden kodluyor (JPEG) ama çıktıyı `scaled_<orijinal ad>`
  // olarak yazıyor — yani HEIC seçen kullanıcıda dosya `.heic` uzantılı
  // ama İÇİ JPEG oluyor (`ImageResizer.java`). Eski kod uzantıya baktığı
  // için geçerli bir JPEG'i `application/octet-stream` sanıp yüklemeyi
  // reddediyordu.
  test('MIME baytlardan çözülür — uzantı yalan söylese bile', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
    expect(
      resolveAvatarMime(bytes: jpeg, declaredMime: null, path: '/t/scaled_IMG_1.heic'),
      'image/jpeg',
    );
  });

  test('gerçek HEIC baytları image/heic olarak tanınır (ftyp markası)', () {
    // Flutter web dalı: picker parametreleri yok sayıldığından baytlar
    // GERÇEKTEN orijinal formatta geliyor.
    final heic = Uint8List.fromList([
      0x00, 0x00, 0x00, 0x18, // kutu boyu
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      0x68, 0x65, 0x69, 0x63, // 'heic'
    ]);
    expect(resolveAvatarMime(bytes: heic), 'image/heic');
    // İlk baytı 0x00 olduğundan hiçbir düz imzayla yakalanamaz; markaya
    // bakmayan bir uygulama burada null döner.
    expect(sniffImageMime(heic), isNotNull);
  });

  test('tanınmayan baytta bildirilen tip, o da yoksa uzantı kullanılır', () {
    final junk = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    expect(resolveAvatarMime(bytes: junk, declaredMime: 'image/png'), 'image/png');
    expect(resolveAvatarMime(bytes: junk, path: 'a/b.WebP'), 'image/webp');
    expect(resolveAvatarMime(bytes: junk, path: 'a/b'), 'application/octet-stream');
  });

  testWidgets('galeri patlarsa kullanıcıya görünür hata verilir', (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    // Gerçek uçta bu, izin reddinde gelen `PlatformException`.
    await pumpSettings(tester, auth,
        pickAvatar: () async => throw Exception('izin yok'));

    await tester.tap(find.text('FOTOĞRAF DEĞİŞTİR'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Fotoğraf seçilemedi'), findsOneWidget);
    // Buton kilitli kalmamalı — kullanıcı yeniden deneyebilmeli.
    expect(find.text('YÜKLENİYOR…'), findsNothing);
    expect(find.text('FOTOĞRAF DEĞİŞTİR'), findsOneWidget);
  });

  testWidgets('küçültme patlarsa da aynı hata gösterilir', (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    await pumpSettings(
      tester,
      auth,
      pickAvatar: () async => PickedImage(
          bytes: Uint8List.fromList(const [1, 2, 3]), mimeType: 'image/png'),
      shrinkAvatar: (_) async => throw Exception('kodek yok'),
    );

    await tester.tap(find.text('FOTOĞRAF DEĞİŞTİR'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Fotoğraf seçilemedi'), findsOneWidget);
  });

  // ── Hesap silme (ROADMAP madde 2, MAĞAZA BLOKERİ) ────────────────────────
  //
  // Gerçek silme bu ortamdan test EDİLEMEZ (`AuthService.fake` bir Supabase
  // client taşımıyor, Edge Function çağrısı "Supabase yapılandırılmadı." ile
  // düşüyor) — tam da bu, penceredeki ASIL sözleşmeyi sınamak için
  // kullanılıyor: kuru çalıştırma başarısızsa silme butonu ETKİNLEŞMEZ.
  // Cihazdaki uçtan uca kontrol `mobile/TESTING.md`de.
  testWidgets('Hesap Ayarları uygulama içi silme yolunu açar', (tester) async {
    final auth = AuthService.fake(
      user: fakeUser('me'),
      profile: const KProfile(id: 'me', displayName: 'ironman'),
    );
    await pumpSettings(tester, auth);

    // Girişi bul ve dokun — Play, hesap açtıran uygulamalarda uygulama
    // İÇİNDEN başlatılabilen bir silme yolu şart koşuyor.
    final giris = find.text('HESABIMI SİL');
    expect(giris, findsOneWidget);
    await tester.ensureVisible(giris);
    await tester.tap(giris);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('HESABI SİL'), findsOneWidget);
    // Kuru çalıştırma düştü → sebep GÖRÜNÜR olmalı, sessizce yutulmamalı.
    expect(find.textContaining('Supabase yapılandırılmadı'), findsOneWidget);
    // ...ve onay alanı hiç açılmadığından silme butonu devre dışı kalmalı.
    expect(find.byKey(const ValueKey('field-delete-confirm')), findsNothing);
    final buton = tester.widget<NeoButton>(
      find.ancestor(
        of: find.text('KALICI OLARAK SİL'),
        matching: find.byType(NeoButton),
      ),
    );
    expect(buton.onPressed, isNull);
  });
}
