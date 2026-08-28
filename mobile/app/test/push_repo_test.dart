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

  @override
  Stream<String> onTokenRefresh() => refreshCtl.stream;

  @override
  Future<PushPermission> permission() async => izin;

  @override
  Future<PushPermission> requestPermission() async => izin;
}

class FakeStore implements PushTokenStore {
  final yazilanlar = <Map<String, String>>[];
  final silinenler = <String>[];
  bool upsertFirlatsin = false;

  @override
  Future<void> upsert({
    required String token,
    required String userId,
    required String platform,
  }) async {
    if (upsertFirlatsin) throw StateError('ağ yok');
    yazilanlar.add({'token': token, 'userId': userId, 'platform': platform});
  }

  @override
  Future<void> remove(String token) async => silinenler.add(token);
}

PushRepo repo(FakeMessaging m, FakeStore s, {String? platform = 'android'}) =>
    PushRepo(messaging: m, store: s, platformKaynagi: () => platform);

void main() {
  test('kaydet: token + kullanıcı + platform doğru yazılır', () async {
    final m = FakeMessaging();
    final s = FakeStore();
    await repo(m, s).kaydet('kisi-1');
    expect(s.yazilanlar, [
      {'token': 'tok-1', 'userId': 'kisi-1', 'platform': 'android'}
    ]);
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
    expect(s.silinenler, ['tok-2'],
        reason: 'silinen, en son YAZILAN token olmalı');

    // Çıkıştan sonra gelen bir yenileme artık YAZILMAMALI — yoksa çıkmış
    // kullanıcının satırı geri gelir ve bildirimleri bu cihaza düşer.
    final oncekiSayi = s.yazilanlar.length;
    m.refreshCtl.add('tok-3');
    await Future<void>.delayed(Duration.zero);
    expect(s.yazilanlar.length, oncekiSayi);
  });

  test('hiç kaydedilmemişken temizle sessizce geçer', () async {
    final s = FakeStore();
    await repo(FakeMessaging(), s).temizle();
    expect(s.silinenler, isEmpty);
  });

  test('FCM ya da tablo patlarsa FIRLATMAZ', () async {
    // Push bir EK kanal: arızası girişi/çıkışı/Canlı sekmesini düşüremez.
    final m1 = FakeMessaging()..tokenFirlatsin = true;
    await repo(m1, FakeStore()).kaydet('kisi-1');

    final s2 = FakeStore()..upsertFirlatsin = true;
    await repo(FakeMessaging(), s2).kaydet('kisi-1');
    // Buraya gelmek testin kendisi — fırlatsaydı test düşerdi.
  });
}
