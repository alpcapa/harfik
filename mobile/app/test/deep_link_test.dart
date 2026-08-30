// Derin bağlantı ayrıştırması — `util/deep_link.dart`.
//
// NEDEN VAR: bu fonksiyon işletim sisteminden gelen bir URI'yi bir EYLEME
// çeviriyor ve üç ayrı üretici besliyor (e-posta linki, paylaşılan davet
// linki, push bildirimi). Yanlış sınıflandırma sessiz: link "işe yaramıyor"
// olarak görünür, hiçbir hata düşmez. Cihazda doğrulaması pahalı (gerçek
// kurulum + gerçek e-posta) olduğundan biçim sözleşmesi burada kilitleniyor.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/friends_api.dart' show buildInviteUrl;
import 'package:kelimeki/src/data/game_link_inbox.dart';
import 'package:kelimeki/src/data/push_taps.dart' show pushMessageLink;
import 'package:kelimeki/src/config/env.dart' show authRedirectUri;
import 'package:kelimeki/src/util/deep_link.dart';

void main() {
  group('parseDeepLink — arkadaş daveti', () {
    test('custom şema ve web linki AYNI token\'ı verir', () {
      // İki biçim de tanınmak zorunda: paylaşılan link BİLEREK https
      // (alıcı üye olmayabilir), ama App Links kuruluysa onu uygulamaya
      // düşürüyor ve token bu kez https'ten geliyor.
      expect(
          (parseDeepLink(Uri.parse('kelimeki://davet/abc123'))
                  as KFriendInviteLink)
              .token,
          'abc123');
      expect(
          (parseDeepLink(Uri.parse('https://kelimeki.com/davet/abc123'))
                  as KFriendInviteLink)
              .token,
          'abc123');
      expect(
          (parseDeepLink(Uri.parse('http://kelimeki.com/davet/t'))
                  as KFriendInviteLink)
              .token,
          't');
    });

    test('`?ref=arkadas` etiketi token\'ı bozmaz', () {
      // buildInviteUrl etiketi ZORUNLU olarak ekliyor (ROADMAP #7); sorgu
      // dizesi pathSegments'e girmediğinden ayrıştırma etkilenmemeli.
      expect((parseDeepLink(Uri.parse(buildInviteUrl('tok'))) as KFriendInviteLink)
          .token, 'tok');
    });
  });

  group('parseDeepLink — Canlı oyun (push bildirimi)', () {
    test('kelimeki://oyun/<id> çözülür ve buildOnlineGameLink ile gidip gelir',
        () {
      const id = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
      expect((parseDeepLink(Uri.parse('kelimeki://oyun/$id')) as KOnlineGameLink)
          .gameId, id);
      // Gidiş-dönüş: sunucu (Edge Function) bu biçimi ELLE kuruyor. İki
      // taraftan biri değişirse bildirime dokunmak hiçbir şey açmaz.
      expect((parseDeepLink(Uri.parse(buildOnlineGameLink(id))) as KOnlineGameLink)
          .gameId, id);
    });

    test('https karşılığı BİLEREK YOK', () {
      // `https://kelimeki.com/oyun/<id>` diye bir sayfa web'de bulunmuyor;
      // böyle bir link üretmek uygulaması olmayan birine 404 göstermek
      // olurdu. Bu satır o kararı kilitliyor.
      expect(parseDeepLink(Uri.parse('https://kelimeki.com/oyun/abc')), isNull);
    });
  });

  group('parseDeepLink — auth dönüşleri', () {
    test('auth ve reset ayırt edilir (işlenmez, yalnızca sınıflandırılır)', () {
      // Oturumu supabase_flutter kendi dinleyicisinden kuruyor; buradaki
      // amaç bunların "bilinmeyen" sayılıp yanlış bir dala düşmemesi.
      expect((parseDeepLink(Uri.parse('kelimeki://auth?code=xyz'))
          as KAuthReturnLink).kind, 'auth');
      expect((parseDeepLink(Uri.parse('kelimeki://reset?code=xyz'))
          as KAuthReturnLink).kind, 'reset');
    });

    test('kayıt onayı https App Link biçiminde de tanınır', () {
      // 28 Ağustos 2026: `authRedirectUri` custom şemadan https'e geçti
      // (uygulama kurulu değilken ERR_UNKNOWN_URL_SCHEME çıkmazı). Aynı
      // URI'nin İKİ biçimi de aynı sınıfa düşmeli.
      expect(
          (parseDeepLink(Uri.parse('$authRedirectUri?code=xyz'))
              as KAuthReturnLink).kind,
          'auth');
      expect(
          (parseDeepLink(Uri.parse('https://kelimeki.com/auth?error=access_denied'))
              as KAuthReturnLink).kind,
          'auth');
    });

    test('authRedirectUri App Link filtresinin KAPSAMINDA', () {
      // Manifest yalnızca `https://kelimeki.com`ı talep ediyor; değer başka
      // bir origin'e kayarsa işletim sistemi URI'yi uygulamaya HİÇ
      // düşürmez ve akış sessizce tarayıcıda kalır.
      final u = Uri.parse(authRedirectUri);
      expect(u.scheme, 'https');
      expect(u.host, 'kelimeki.com');
    });
  });

  group('parseDeepLink — negatifler', () {
    test('eksik/fazla yol parçası tanınmaz', () {
      expect(parseDeepLink(Uri.parse('kelimeki://davet/')), isNull);
      expect(parseDeepLink(Uri.parse('kelimeki://davet/a/b')), isNull);
      expect(parseDeepLink(Uri.parse('kelimeki://oyun/')), isNull);
      expect(parseDeepLink(Uri.parse('kelimeki://oyun/a/b')), isNull);
    });

    test('başka host/şema tanınmaz', () {
      expect(parseDeepLink(Uri.parse('https://ornek.com/davet/abc')), isNull);
      expect(parseDeepLink(Uri.parse('kelimeki://bilinmeyen/abc')), isNull);
    });

    test('kelimeki.com\'un davet DIŞINDAKİ sayfaları tanınmaz', () {
      // Manifest `https://kelimeki.com`un TAMAMINI talep ediyor (yol kısıtı
      // yok), yani App Links kuruluyken bu sayfalar da uygulamaya düşebilir.
      // `/game/` özellikle önemli: o BİTMİŞ oyunun paylaşım sayfası ve
      // Canlı oyunla karıştırılmamalı.
      expect(parseDeepLink(Uri.parse('https://kelimeki.com/game/abc')), isNull);
      expect(parseDeepLink(Uri.parse('https://kelimeki.com/gizlilik/')), isNull);
      expect(parseDeepLink(Uri.parse('https://kelimeki.com/')), isNull);
    });
  });

  group('pushMessageLink — FCM data yükü (Faz 3)', () {
    test('sunucunun gönderdiği biçim çözülür', () {
      final uri = pushMessageLink({'link': 'kelimeki://oyun/g1'});
      expect(uri, isNotNull);
      // Uçtan uca: FCM yükü → parseDeepLink → oyun id'si. Sunucu tarafı
      // (`_shared/push.ts` → data.link) biçimi ELLE kuruyor; bu test
      // istemci yarısını kilitliyor.
      expect(parseDeepLink(uri!), isA<KOnlineGameLink>());
      expect((parseDeepLink(uri)! as KOnlineGameLink).gameId, 'g1');
    });

    test('link yok / boş / yanlış tip → sessizce null (teslim uyarısı '
        'bildirimi link TAŞIMIYOR, bu beklenen yol)', () {
      expect(pushMessageLink(const {}), isNull);
      expect(pushMessageLink(const {'link': ''}), isNull);
      expect(pushMessageLink(const {'link': 42}), isNull);
      expect(pushMessageLink(const {'baska': 'alan'}), isNull);
    });
  });

  group('GameLinkInbox (Faz 3)', () {
    test('oyun URI\'sı pending olur, davet/auth URI\'larına dokunmaz',
        () async {
      final inbox = GameLinkInbox();
      var bildirim = 0;
      inbox.addListener(() => bildirim++);
      final ctrl = StreamController<Uri>();
      inbox.attach(ctrl.stream);

      ctrl.add(Uri.parse('kelimeki://davet/tok1')); // FriendInviteInbox'un işi
      ctrl.add(Uri.parse('kelimeki://auth?code=x')); // supabase_flutter'ın işi
      await Future<void>.delayed(Duration.zero);
      expect(inbox.pendingGameId, isNull);
      expect(bildirim, 0);

      ctrl.add(Uri.parse('kelimeki://oyun/g1'));
      await Future<void>.delayed(Duration.zero);
      expect(inbox.pendingGameId, 'g1');
      expect(bildirim, 1);
      await ctrl.close();
    });

    test('take oku-ve-temizle; üst üste dokunuşta SONUNCUSU kazanır',
        () async {
      final inbox = GameLinkInbox();
      final ctrl = StreamController<Uri>();
      inbox.attach(ctrl.stream);
      ctrl.add(Uri.parse('kelimeki://oyun/g1'));
      ctrl.add(Uri.parse('kelimeki://oyun/g2'));
      await Future<void>.delayed(Duration.zero);
      expect(inbox.take(), 'g2');
      expect(inbox.take(), isNull); // ikinci kez işlenmez
      await ctrl.close();
    });

    test('iki kaynak bağlanabilir (URI akışı + bildirim dokunuşları)',
        () async {
      final inbox = GameLinkInbox();
      final a = StreamController<Uri>();
      final b = StreamController<Uri>();
      inbox.attach(a.stream);
      inbox.attach(b.stream);
      a.add(Uri.parse('kelimeki://oyun/g1'));
      await Future<void>.delayed(Duration.zero);
      expect(inbox.take(), 'g1');
      b.add(Uri.parse('kelimeki://oyun/g2'));
      await Future<void>.delayed(Duration.zero);
      expect(inbox.take(), 'g2');
      await a.close();
      await b.close();
    });
  });
}
