// Bağlantısızken hesap adı E-POSTAYA düşmemeli.
//
// NEDEN VAR (29 Ağustos 2026, cihaz testi 6.3 — kullanıcı uçak modunda
// bildirdi: *"T2 yerine KE yazıyor"*): profilin yerel kopyası YOKTU, her
// açılışta sunucudan çekiliyordu. Bağlantı olmayınca çekim düşüyor,
// `menuName` zinciri en sona (e-posta) iniyor ve avatar
// `kelimekitest2@…`'dan "KE" türetiyor — kullanıcı GİRİŞLİ ama kim olduğu
// yanlış görünüyor. Web'de de aynı zincir var (`UserMenu.tsx`).
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/storage/profile_cache_store.dart';
import 'package:kelimeki/src/data/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

User _user(String id, String email) => User(
      id: id,
      email: email,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProfileCacheStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = ProfileCacheStore(await SharedPreferences.getInstance());
  });

  test('yazılan profil aynı kullanıcı için geri okunur', () async {
    await store.write('u1', {'id': 'u1', 'display_name': 'T2'});
    expect(store.read('u1')?['display_name'], 'T2');
  });

  test('BAŞKA kullanıcının kopyası OKUNAMAZ', () async {
    // ⚠ Bu testin asıl konusu: tek bir "son profil" kaydı tutulsaydı, hesap
    // değiştiren kullanıcı bağlantısız açılışta ÖNCEKİ kişinin adını
    // görürdü. Bu projede aynı sınıftan hatalar tekrar tekrar çıktı
    // (`AccountScope`; 29 Ağustos'ta push token'ında iki kez daha).
    await store.write('u1', {'id': 'u1', 'display_name': 'T2'});
    expect(store.read('u2'), isNull,
        reason: 'Önbellek user_id ile anahtarlanmalı — yanlış hesabın adı '
            'hiçbir koşulda okunamamalı.');
  });

  test('çıkışta temizlenen kayıt geri okunamaz', () async {
    await store.write('u1', {'id': 'u1', 'display_name': 'T2'});
    await store.clear('u1');
    expect(store.read('u1'), isNull);
  });

  test('BOZUK kayıt uygulamayı düşürmez, yok sayılır', () async {
    // Depolama katmanının disiplini: güvenme, ama patlatma da.
    SharedPreferences.setMockInitialValues(
        {'profile_cache_u1': '{bozuk json'});
    final s2 = ProfileCacheStore(await SharedPreferences.getInstance());
    expect(s2.read('u1'), isNull);
  });

  // ─── ASIL DÜZELTME: çekim düşünce önbellekten devam ─────────────────────

  test('çekim DÜŞERSE hesap adı e-postaya değil YEREL KOPYAYA düşer',
      () async {
    await store.write('u1', {'id': 'u1', 'display_name': 'T2'});
    final auth = AuthService.fake(
      user: _user('u1', 'kelimekitest2@example.com'),
      profileCache: Future.value(store),
      // Uçak modu: çekim patlıyor.
      profileFetcher: (_) async => throw Exception('offline'),
    );
    // `_fetchProfile` asenkron; bir tur bekle.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(auth.menuName, 'T2',
        reason: 'Bağlantısızken hesap adı e-postadan türetilmiş bir isme '
            'düşüyor (cihazda "KE" görünüyordu). Yerel kopya varken ondan '
            'devam edilmeli.');
  });

  test('önbellek YOKKEN davranış değişmiyor (e-posta yedeği duruyor)',
      () async {
    final auth = AuthService.fake(
      user: _user('u1', 'kelimekitest2@example.com'),
      profileCache: Future.value(store), // boş
      profileFetcher: (_) async => throw Exception('offline'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(auth.menuName, 'kelimekitest2@example.com',
        reason: 'Kopya yoksa eski davranış korunmalı — düzeltme yalnızca '
            'kopya VARKEN devreye girer.');
  });

  test('çekim BAŞARILIYSA satır diske yazılır (sonraki offline açılış için)',
      () async {
    final auth = AuthService.fake(
      user: _user('u1', 'kelimekitest2@example.com'),
      profileCache: Future.value(store),
      profileFetcher: (_) async => {'id': 'u1', 'display_name': 'T2'},
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(auth.menuName, 'T2');
    expect(store.read('u1')?['display_name'], 'T2',
        reason: 'Taze satır yazılmazsa bir sonraki bağlantısız açılışta '
            'okunacak hiçbir şey olmaz — düzeltme yarım kalır.');
  });
}
