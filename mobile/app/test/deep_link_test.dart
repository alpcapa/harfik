// Derin bağlantı ayrıştırması — `util/deep_link.dart`.
//
// NEDEN VAR: bu fonksiyon işletim sisteminden gelen bir URI'yi bir EYLEME
// çeviriyor ve üç ayrı üretici besliyor (e-posta linki, paylaşılan davet
// linki, push bildirimi). Yanlış sınıflandırma sessiz: link "işe yaramıyor"
// olarak görünür, hiçbir hata düşmez. Cihazda doğrulaması pahalı (gerçek
// kurulum + gerçek e-posta) olduğundan biçim sözleşmesi burada kilitleniyor.
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimeki/src/data/friends_api.dart' show buildInviteUrl;
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
}
