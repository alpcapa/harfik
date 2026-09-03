// Oyun listelerinin SIRALAMA kuralı — saf, çağrı yerinden bağımsız.
// Web ikizi: `src/utils/gameListOrder.ts`. Biri değişirse öteki de.
//
// NEDEN AYRI DOSYA (3 Eylül 2026): aynı kural bugüne kadar İKİ AYRI YERDE
// elle yazılıydı — web'de `LiveGamesTab`ın içinde inline sort, burada
// `activeBucket`. İkisinin yorumu "birebir aynı ölçütler" diyordu ama
// hiçbir şey bunu ZORLAMIYORDU.
//
// Kullanıcı isteği (3 Eylül 2026): "YZ ve canlı sıra sende bekleyen
// oyunlarda sıralama bitmeye en yakın üstte şeklinde olmalı. Oyun
// davetlerinde de süresi bitmeye en yakın üstte olacak."

/// Aktif Canlı oyunlar: **sırası bende olanlar üstte**, sonra iki grup
/// KENDİ İÇİNDE farklı yönde sıralanır. Asimetri bilinçli:
///
/// - **Sıra BENDE** → `turn_deadline`a göre ARTAN (en yakın bitiş üstte).
///   Yapılacak iş var, en acili en üstte olmalı; süre dolarsa oyun teslim
///   sayılıyor ve k-lig puanı düşüyor.
/// - **Sıra RAKİPTE** → AZALAN (son oynanan üstte). Yapabileceğim bir şey
///   yok; anlamlı sıra "en son hareket eden".
///
/// ⚠ **AZALAN yön 31 Ağustos 2026'da bir kullanıcı şikayetiyle KONDU**
/// ("son oynanan her zaman en üstte olacak"). 3 Eylül'deki "en yakın bitiş
/// üstte" isteği onu geçersiz KILMIYOR: o istek sırası ÇAĞIRANDA olan
/// gruba ait. Listenin tamamını artana çevirmek iki gün önce düzeltilen
/// davranışı geri getirirdi.
///
/// ⚠ **`deadlineMs == null` HER İKİ grupta da EN SONA düşer.** Artan
/// sıralamada bu sessiz bir tuzak: null'ı 0 saymak (eski ortak numara) onu
/// "en yakın bitiş" sanıp EN ÜSTE taşırdı. Null = state henüz kurulmamış,
/// yani bilinmeyen — bilinmeyeni acil saymak yanlış.
List<T> orderActiveGames<T>(
  List<T> items, {
  required bool Function(T) myTurn,
  required int? Function(T) deadlineMs,
}) =>
    _stableSort(items, (a, b) {
      final grup = (myTurn(b) ? 1 : 0) - (myTurn(a) ? 1 : 0);
      if (grup != 0) return grup;
      final da = deadlineMs(a);
      final db = deadlineMs(b);
      // Bilinmeyen her zaman sona — grubun yönünden BAĞIMSIZ.
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return myTurn(a) ? da.compareTo(db) : db.compareTo(da);
    });

/// Süresi olan bekleyen kayıtlar (oyun davetleri, yerel YZ kayıtları):
/// **bitmeye en yakın üstte**, yani ARTAN.
///
/// İki yerde de "bitiş" gerçek bir kayıp: davet süresi dolunca oyun iptal
/// oluyor, yerel kaydın 7 günü dolunca oyun siliniyor (girişli kullanıcıda
/// -2 puanla teslim sayılıyor).
///
/// ⚠ Null yine EN SONA — bkz. [orderActiveGames].
List<T> orderByExpiry<T>(List<T> items, int? Function(T) expiryMs) =>
    _stableSort(items, (a, b) {
      final ea = expiryMs(a);
      final eb = expiryMs(b);
      if (ea == null && eb == null) return 0;
      if (ea == null) return 1;
      if (eb == null) return -1;
      return ea.compareTo(eb);
    });

/// İndeks tie-break'li sıralama — **Dart'ın `List.sort`u kararlı DEĞİL**
/// (core sözleşmesi), yani eşit ölçütte giriş sırası ancak böyle korunur.
List<T> _stableSort<T>(List<T> items, int Function(T, T) cmp) {
  final indexed = items.asMap().entries.toList()
    ..sort((a, b) {
      final c = cmp(a.value, b.value);
      return c != 0 ? c : a.key - b.key;
    });
  return [for (final e in indexed) e.value];
}
