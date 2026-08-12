// Hesap değişimi kapsayıcısı — PORT_BRIEF §7 değişmezi (6 Ağustos 2026):
//
//   "Oturuma bağlı UI state'i hesap değişiminde sıfırlanmalı ve karar auth
//    NESNESİNE değil user.id'ye bakmalı."
//
// Tuzak Dart'ta da birebir var: supabase_flutter'ın onAuthStateChange'i
// `tokenRefreshed` olayını kabaca saatte bir, HER SEFERİNDE taze bir User
// nesnesiyle yayınlar — nesne kimliğine (ya da "user değişti mi" referans
// karşılaştırmasına) bağlanan bir sıfırlama, oturum-başına-bir-kez'i
// saatte-bir'e çevirir (web'de yaşandı: CLAUDE.md, "user REFERANSI hesap
// değişimi DEĞİLDİR"). Bu sınıf o kararı TEK yerde, id üzerinden verir.
//
// KURAL (auth fazı bunun üzerine kurulur): oturumu aşan ömürlü her
// controller/notifier (seçili sekme, tek-seferlik bayraklar, kullanıcıya
// özel önbellek listeleri) sıfırlamasını buraya kaydeder; onAuthStateChange
// dinleyicisi HER olayda yalnızca `onAuthEvent(user?.id)` çağırır.
class AccountScope {
  String? _lastUserId;
  bool _initialized = false;
  final List<void Function()> _resets = [];

  /// Hesap değişince (yalnızca GERÇEK id değişiminde) çağrılacak sıfırlama.
  void registerReset(void Function() reset) => _resets.add(reset);

  String? get currentUserId => _lastUserId;

  /// Her auth olayında çağrılır. Yalnızca user.id GERÇEKTEN değiştiyse
  /// kayıtlı sıfırlamaları koşar ve true döner. İlk olay (uygulama açılışı)
  /// sıfırlama SAYILMAZ — web'deki "ref'i user?.id ile başlat, mount yolunu
  /// dokunulmamış bırak" inceliğinin eşleniği: açılışta önbellekten anında
  /// çizme davranışı bozulmaz.
  bool onAuthEvent(String? userId) {
    if (!_initialized) {
      _initialized = true;
      _lastUserId = userId;
      return false;
    }
    if (userId == _lastUserId) return false; // tokenRefreshed vb. → no-op
    _lastUserId = userId;
    for (final reset in _resets) {
      reset();
    }
    return true;
  }
}
