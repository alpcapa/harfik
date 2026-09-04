// "Uygulamadan uzakta kalma" izleyicisi — web `src/utils/awayReturn.ts` portu.
//
// NEDEN (21 Ağustos 2026, kullanıcı bildirdi): arka planda açık kalan uygulama
// öne getirildiğinde, sıra kendisinde olmasına rağmen "Arkadaşınla" sekmesi
// açık gelmiyordu. Sebep bir hata değil, "bir kez" kuralının kapsamıydı:
// `_appliedLoginDefault` (web `appliedLoginDefaultRef`) hesap başına bir kez
// uygulanıyor ve ekran hiç dispose OLMADIĞINDAN (SetupScreen `MaterialApp.home`)
// o bir kez ilk girişte tükeniyordu. Kuralın kendisi ("kullanıcı bir sekmede
// otururken yeni davet/hamle onu oradan koparmaz") DEĞİŞMEDİ; değişen
// "ekrana giriş" tanımı — uygulamadan gerçekten uzaklaşıp dönmek de bir
// giriştir, kısa bir kesinti (bildirim bandı, Kontrol Merkezi) değildir.
//
// **EŞİK İKİ PLATFORMDA AYNI OLMAK ZORUNDA** — biri değişirse öteki de
// (`test/away_return_test.dart` bunu web dosyasını okuyarak zorluyor).
const Duration kLongAway = Duration(minutes: 5);

/// Uzaklaşma/dönüş anlarını sayan, saat enjekte edilebilir küçük bir izleyici.
class AwayTracker {
  AwayTracker({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  // Uzaklaşma anı: İLK işaret kazanır. iOS'ta `inactive` ve `paused` art arda
  // geliyor; ikincisi damgayı tazeleseydi uzakta geçen süre olduğundan kısa
  // ölçülürdü.
  DateTime? _awayAt;

  /// Uygulama arka plana alındığında (resumed DIŞINDAKİ her durum) çağrılır.
  void markAway() => _awayAt ??= _now();

  /// Öne dönüşte çağrılır. Uzakta geçen süre eşiği aştıysa `true` döner ve
  /// sayacı sıfırlar — hiç uzaklaşma görülmediyse (ör. uygulama az önce
  /// açıldı) karar VERİLMEZ, kullanıcı bulunduğu sekmede kalır.
  bool takeLongAway([Duration threshold = kLongAway]) {
    final at = _awayAt;
    _awayAt = null;
    return at != null && _now().difference(at) >= threshold;
  }
}
