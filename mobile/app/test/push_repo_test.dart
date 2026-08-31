// `PushRepo` — token yaşam döngüsü.
//
// Buradaki iddiaların çoğu SESSİZ arızaları koruyor: hepsinin ortak özelliği
// "kimse şikayet etmez, yalnızca bildirim gelmez" olması. Bu yüzden sahte
// uçlar yazılan HER çağrıyı kaydediyor ve testler yalnızca "hata olmadı"
// demiyor, ne yazıldığını da doğruluyor.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/push_repo.dart';

class FakeMessaging implements PushMessaging {
  String? tokenDegeri;
  final refreshCtl = StreamController<String>.broadcast();
  PushPermission izin = PushPermission.notDetermined;
  int tokenCagrisi = 0;
  bool tokenFirlatsin = false;

  FakeMessaging({this.tokenDegeri = 'tok-1'});

  @override
  Future<String?> token() async {
    tokenCagrisi += 1;
    if (tokenFirlatsin) throw StateError('FCM patladı');
    return tokenDegeri;
  }

  /// ⚠ Gerçek FCM'de yenilemeden SONRA `getToken()` YENİ token'ı döndürür.
  /// Sahte uç bunu taklit etmezse `temizle`nin canlı token'ı okuyan yolu
  /// gerçekte olmayan bir durumu test eder (eski token'ı silmeye çalışmak).
  @override
  Stream<String> onTokenRefresh() =>
      refreshCtl.stream.map((t) => tokenDegeri = t);

  @override
  Future<PushPermission> permission() async => izin;

  @override
  Future<PushPermission> requestPermission() async => izin;
}

class FakeStore implements PushTokenStore {
  final yazilanlar = <Map<String, String?>>[];
  final silinenler = <String>[];
  bool upsertFirlatsin = false;

  @override
  Future<void> upsert({
    required String token,
    required String userId,
    required String platform,
    String? appVersion,
  }) async {
    if (upsertFirlatsin) throw StateError('ağ yok');
    yazilanlar.add({
      'token': token,
      'userId': userId,
      'platform': platform,
      if (appVersion != null) 'appVersion': appVersion,
    });
  }

  @override
  Future<void> remove(String token) async => silinenler.add(token);
}

PushRepo repo(FakeMessaging m, FakeStore s,
        {String? platform = 'android', String? appVersion}) =>
    PushRepo(
        messaging: m,
        store: s,
        platformKaynagi: () => platform,
        appVersion: appVersion);

void main() {
  test('kaydet: token + kullanıcı + platform doğru yazılır', () async {
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s).kaydet('kisi-1');
    expect(s.yazilanlar, [
      {'token': 'tok-1', 'userId': 'kisi-1', 'platform': 'android'}
    ]);
  });

  // ── Sürüm damgası (ROADMAP #12, 31 Ağustos 2026) ────────────────────────
  // "Kaç KİŞİ hangi sürümde" sorusunu cevaplayan tek alan bu. Sessizce
  // düşmesi mümkün ve fark edilmesi ZOR: bildirimler çalışmaya devam eder,
  // yalnızca tablodaki sürüm sonsuza kadar null kalır — yani bir gün
  // "neden herkes bilinmiyor?" diye bakana kadar hiçbir belirti vermez.
  test('kaydet: appVersion verilmişse damga yazılır', () async {
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s, appVersion: '9.9.9').kaydet('kisi-1');
    expect(s.yazilanlar.single['appVersion'], '9.9.9');
  });

  test('kaydet: appVersion YOKSA alan hiç gönderilmez (null kalır)', () async {
    // Web/test derlemesi sürüm damgası taşımıyor. Boş dizgi ya da 'bilinmiyor'
    // GÖNDERMEK yanlış olurdu: sunucudaki `coalesce(app_version,'bilinmiyor')`
    // zaten null'ı öyle gösteriyor, istemcinin ikinci bir "bilinmiyor" değeri
    // uydurması dökümde iki ayrı satır üretirdi.
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s).kaydet('kisi-1');
    expect(s.yazilanlar.single.containsKey('appVersion'), isFalse);
  });

  test('token YENİLENİNCE de damga taşınır', () async {
    // Yenileme dalı ayrı bir upsert çağrısı — ilkini damgalayıp bunu
    // unutmak, cihazın sürümünün token döndüğü anda null'a düşmesi demekti.
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s, appVersion: '9.9.9').kaydet('kisi-1');
    m.refreshCtl.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(s.yazilanlar.length, 2);
    expect(s.yazilanlar.last['token'], 'tok-2');
    expect(s.yazilanlar.last['appVersion'], '9.9.9');
  });

  test('DESTEKLENMEYEN platformda FCM\'e HİÇ dokunulmaz', () async {
    // `push_tokens.platform` check kısıtı yalnızca android|ios kabul ediyor;
    // 'app-web' yollamak insert'i düşürürdü. Ama asıl iddia şu: bu durumda
    // token bile İSTENMEZ — boş yere platform eklentisi uyandırılmaz.
    for (final p in ['app-web', null, 'macos']) {
      final m = FakeMessaging();
      final s = FakeStore();
      await repo(m, s, platform: p).kaydet('kisi-1');
      expect(s.yazilanlar, isEmpty, reason: '$p için yazılmamalı');
      expect(m.tokenCagrisi, 0, reason: '$p için token bile sorulmamalı');
    }
  });

  test('token null/boşsa yazılmaz', () async {
    for (final t in [null, '']) {
      final m = FakeMessaging(tokenDegeri: t);
      final s = FakeStore();
      await repo(m, s).kaydet('kisi-1');
      expect(s.yazilanlar, isEmpty);
    }
  });

  test('token YENİLENİNCE satır güncellenir', () async {
    // Token dönebiliyor (uygulama verisi temizlenmesi, yedekten geri yükleme).
    // Yakalanmazsa satır eski token'la kalır ve bildirimler SESSİZCE gitmez.
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s).kaydet('kisi-1');
    m.refreshCtl.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(s.yazilanlar.last,
        {'token': 'tok-2', 'userId': 'kisi-1', 'platform': 'android'});
  });

  test('temizle: SON yazılan token silinir ve yenileme dinleyicisi kapanır',
      () async {
    final m = FakeMessaging();
    final s = FakeStore();
    final r = repo(m, s);
    await r.kaydet('kisi-1');
    m.refreshCtl.add('tok-2');
    await Future<void>.delayed(Duration.zero);

    await r.temizle();
    // İKİ silme bekleniyor ve ikisi de doğru: yenileme eski satırı (tok-1),
    // çıkış canlı token'ı (tok-2) siliyor. Önemli olan SONUNCUSU.
    expect(s.silinenler, ['tok-1', 'tok-2']);
    expect(s.silinenler.last, 'tok-2',
        reason: 'çıkışta silinen, cihazın GÜNCEL token\'ı olmalı');

    // Çıkıştan sonra gelen bir yenileme artık YAZILMAMALI — yoksa çıkmış
    // kullanıcının satırı geri gelir ve bildirimleri bu cihaza düşer.
    final oncekiSayi = s.yazilanlar.length;
    m.refreshCtl.add('tok-3');
    await Future<void>.delayed(Duration.zero);
    expect(s.yazilanlar.length, oncekiSayi);
  });

  test('hiç kaydedilmemişken bile CANLI token silinir', () async {
    // Bu davranış bilerek böyle: `_sonToken` yalnızca bu oturumda bir kayıt
    // yapıldıysa dolu. Uygulama yeniden başladıktan sonra çıkış yapan bir
    // kullanıcının satırı, canlı token okunmasaydı tabloda KALIRDI.
    // Olmayan bir satırı silmek zararsız (no-op).
    final s = FakeStore();
    await repo(FakeMessaging(), s).temizle();
    expect(s.silinenler, ['tok-1']);
  });

  test('FCM token veremezse temizle sessizce geçer', () async {
    final s = FakeStore();
    await repo(FakeMessaging(tokenDegeri: null), s).temizle();
    expect(s.silinenler, isEmpty);
  });

  test('token yenilenince ESKİ satır silinir (cihaz iki kez görünmesin)',
      () async {
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s).kaydet('kisi-1');
    m.refreshCtl.add('tok-2');
    await Future<void>.delayed(Duration.zero);
    expect(s.yazilanlar.last['token'], 'tok-2');
    expect(s.silinenler, ['tok-1'],
        reason: 'eski satır kalırsa aynı cihaza iki kez gönderilmeye çalışılır');
  });

  test('FCM ya da tablo patlarsa FIRLATMAZ', () async {
    // Push bir EK kanal: arızası girişi/çıkışı/Canlı sekmesini düşüremez.
    final m1 = FakeMessaging()..tokenFirlatsin = true;
    await repo(m1, FakeStore()).kaydet('kisi-1');

    final s2 = FakeStore()..upsertFirlatsin = true;
    await repo(FakeMessaging(), s2).kaydet('kisi-1');
    // Buraya gelmek testin kendisi — fırlatsaydı test düşerdi.
  });

  group('senkronize: token varlığı İZNİ takip eder', () {
    // DEĞİŞMEZ: `push_tokens`teki satır "bu cihaz bildirimi GERÇEKTEN
    // gösterebilir" demek. İzin yokken gönderilen bildirimi Android sessizce
    // atar ama FCM 200 döner — yani satır kalsaydı sayaçlar yalan söyler ve
    // her turda boşuna kota yakılırdı.
    test('granted → yazar', () async {
      final s = FakeStore();
      await repo(FakeMessaging(), s)
          .senkronize(userId: 'kisi-1', izin: PushPermission.granted);
      expect(s.yazilanlar, hasLength(1));
    });

    test('denied ve permanentlyDenied → var olan satırı SİLER', () async {
      for (final izin in [
        PushPermission.denied,
        PushPermission.permanentlyDenied,
      ]) {
        final m = FakeMessaging();
        final st = FakeStore();
        final r = repo(m, st);
        await r.senkronize(userId: 'kisi-1', izin: PushPermission.granted);
        expect(st.yazilanlar, hasLength(1));
        // Kullanıcı sistem ayarlarından kapattı: bir sonraki açılışta silinir.
        await r.senkronize(userId: 'kisi-1', izin: izin);
        expect(st.silinenler, ['tok-1'], reason: '$izin için silinmeli');
      }
    });

    test('notDetermined → HİÇBİR ŞEY yapmaz', () async {
      final m = FakeMessaging();
      final st = FakeStore();
      await repo(m, st)
          .senkronize(userId: 'kisi-1', izin: PushPermission.notDetermined);
      expect(st.yazilanlar, isEmpty);
      expect(st.silinenler, isEmpty);
      expect(m.tokenCagrisi, 0, reason: 'sorulmamışken token bile istenmez');
    });

    test('izin geri gelirse token YENİDEN yazılır (kendi kendini onarır)',
        () async {
      final m = FakeMessaging();
      final st = FakeStore();
      final r = repo(m, st);
      await r.senkronize(userId: 'kisi-1', izin: PushPermission.granted);
      await r.senkronize(userId: 'kisi-1', izin: PushPermission.denied);
      await r.senkronize(userId: 'kisi-1', izin: PushPermission.granted);
      expect(st.yazilanlar, hasLength(2),
          reason: 'ayarlardan tekrar açılınca dinleyici gerekmeden düzelmeli');
    });
  });
}
