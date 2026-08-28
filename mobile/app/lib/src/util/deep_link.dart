// Gelen derin bağlantıların TEK ayrıştırma noktası.
//
// **Neden ayrı bir dosya (28 Ağustos 2026, ROADMAP madde 1):** uygulamaya
// bugün üç ayrı yerden URI düşüyor ve her biri kendi tanımasını yapıyordu —
// supabase_flutter auth callback'lerini kendi yakalıyor, `FriendInviteInbox`
// davet token'ını `parseInviteToken` ile çözüyor. Sürüm B bir DÖRDÜNCÜSÜNÜ
// ekliyor (bildirime dokununca Canlı tahtayı aç). Üç ayrı `if (scheme == ...)`
// zinciri, dördüncüsü eklendiğinde hangi dalın hangi URI'yi yuttuğunu
// kimsenin göremeyeceği hâle gelirdi.
//
// Saf fonksiyon ve Flutter/Supabase bağımlılığı YOK — bu proje kararlarını
// widget testine değil birim testine bağlıyor (aynı gerekçe:
// `inviteTokensFromEvents`, `friends_api.dart`).
//
// **Kapsam sınırı — bu dosya YALNIZCA sınıflandırır, işlemez.** Auth
// URI'larını supabase_flutter'ın kendi dinleyicisi tüketiyor; buradaki
// `KAuthReturnLink` yalnızca "bu bir davet/oyun linki DEĞİL" demek için var,
// yoksa bilinmeyen sayılıp gelecekte yanlış bir dala düşebilirdi.
library;

/// Ayrıştırılmış bir derin bağlantı. `null` = bizi ilgilendirmiyor.
sealed class KDeepLink {
  const KDeepLink();
}

/// `kelimeki://davet/<token>` · `https://kelimeki.com/davet/<token>`
///
/// İki biçim de tanınıyor çünkü paylaşılan link BİLEREK https
/// (`buildInviteUrl`) — alıcı üye olmayabilir, linkin webde de açılması
/// gerekiyor. Uygulama kuruluysa Android App Links onu uygulamaya düşürür ve
/// aynı token bu kez custom şemadan değil https'ten gelir.
class KFriendInviteLink extends KDeepLink {
  final String token;
  const KFriendInviteLink(this.token);
}

/// `https://kelimeki.com/auth` (kayıt onayı) · `kelimeki://auth` ·
/// `kelimeki://reset` (şifre sıfırlama).
///
/// Bu uygulamanın İŞLEMEDİĞİ tek tür: oturumu supabase_flutter kendi
/// `AppLinks` aboneliğinden kurar (`detectSessionInUri`). Burada var olma
/// sebebi ayırt edilebilmesi.
///
/// **Kayıt onayı 28 Ağustos 2026'da https'e geçti** (`env.dart` →
/// `authRedirectUri`): custom şema, uygulamanın kurulu OLMADIĞI bir
/// tarayıcıda `ERR_UNKNOWN_URL_SCHEME` çıkmazı üretiyordu. Custom şema
/// dalı SİLİNMEDİ — hâlâ Redirect URLs listesinde ve eski derlemelerden
/// gelen linkler bu biçimde. Şifre sıfırlama (`resetRedirectUri`) bilerek
/// custom şemada kaldı: o linke basan kişi tanım gereği uygulamadan
/// "şifremi unuttum" demiş, yani uygulama O CİHAZDA kurulu.
class KAuthReturnLink extends KDeepLink {
  /// `auth` | `reset` — custom şemada host, https'te ilk yol parçası.
  final String kind;
  const KAuthReturnLink(this.kind);
}

/// `kelimeki://oyun/<online_game_id>` — Canlı tahtayı doğrudan açar.
///
/// **BİLEREK yalnızca custom şema, https karşılığı YOK.** Bu linki üreten tek
/// şey bir push bildirimi, o da yalnızca uygulamanın KURULU olduğu cihazda
/// var; `https://kelimeki.com/oyun/<id>` diye bir sayfa web'de bulunmadığından
/// böyle bir linki üretmek, uygulaması olmayan birine 404 göstermek olurdu.
/// (`/game/<id>` ile karıştırma — o BİTMİŞ oyunun paylaşım sayfası,
/// `webOrigin` üzerinden ve bambaşka bir kayıt.)
class KOnlineGameLink extends KDeepLink {
  final String gameId;
  const KOnlineGameLink(this.gameId);
}

const String _kScheme = 'kelimeki';
const String _kWebHost = 'kelimeki.com';

/// Gelen URI'yi sınıflandırır; tanımadıysa `null`.
KDeepLink? parseDeepLink(Uri uri) {
  if (uri.scheme == _kScheme) {
    final seg = uri.pathSegments;
    final one = seg.length == 1 && seg.first.isNotEmpty ? seg.first : null;
    return switch (uri.host) {
      'davet' => one == null ? null : KFriendInviteLink(one),
      'oyun' => one == null ? null : KOnlineGameLink(one),
      // Auth dönüşleri sorgu dizesi taşır (`?code=...`) ve yol taşımaz;
      // `pathSegments` boş olduğundan yukarıdaki `one` burada kullanılmıyor.
      'auth' || 'reset' => KAuthReturnLink(uri.host),
      _ => null,
    };
  }
  // Web linki App Links ile uygulamaya düştüyse — YALNIZCA davet ve kayıt
  // onayı. Manifest `https://kelimeki.com`'un TAMAMINI talep ediyor (yol
  // kısıtı yok), yani buraya `/gizlilik/` gibi sayfalar da düşebilir;
  // onları tanımıyoruz ve tanımamalıyız.
  if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.host == _kWebHost) {
    final seg = uri.pathSegments;
    if (seg.length == 2 && seg.first == 'davet' && seg[1].isNotEmpty) {
      return KFriendInviteLink(seg[1]);
    }
    // `env.dart` → `authRedirectUri`. Sınıflandırma yine İŞLEM DEĞİL:
    // oturumu supabase_flutter kuruyor. Burada tanınmasının sebebi, aynı
    // URI'nin "bilinmeyen" sayılıp ileride yanlış bir dala düşmemesi.
    if (seg.length == 1 && seg.first == 'auth') {
      return const KAuthReturnLink('auth');
    }
  }
  return null;
}

/// `kelimeki://oyun/<id>` — push yükünün taşıyacağı bağlantı.
/// Sunucu tarafı (Edge Function) aynı biçimi ELLE kuruyor; biçim değişirse
/// iki tarafı birden güncelle.
String buildOnlineGameLink(String gameId) => '$_kScheme://oyun/$gameId';
