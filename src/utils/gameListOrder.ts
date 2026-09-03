// Oyun listelerinin SIRALAMA kuralı — saf, çağrı yerinden bağımsız.
// Port ikizi: `mobile/app/lib/src/util/game_list_order.dart`.
//
// NEDEN AYRI DOSYA (3 Eylül 2026): aynı kural bugüne kadar İKİ AYRI YERDE
// elle yazılıydı — web'de `LiveGamesTab`ın içinde inline `.sort`, portta
// `activeBucket`. İkisinin yorumu "birebir aynı ölçütler" diyordu ama
// hiçbir şey bunu ZORLAMIYORDU. Kural buraya çıkarıldı ve iki taraf da
// aynı vakalarla test ediliyor.
//
// Kullanıcı isteği (3 Eylül 2026): *"YZ ve canlı sıra sende bekleyen
// oyunlarda sıralama bitmeye en yakın üstte şeklinde olmalı. Oyun
// davetlerinde de süresi bitmeye en yakın üstte olacak."*

/**
 * Aktif Canlı oyunlar: **sırası bende olanlar üstte**, sonra iki grup
 * KENDİ İÇİNDE farklı yönde sıralanır. Bu asimetri bilinçli:
 *
 * - **Sıra BENDE** → `turn_deadline`a göre ARTAN (en yakın bitiş üstte).
 *   Yapılacak bir iş var ve en acili en üstte olmalı; süre dolarsa oyun
 *   teslim sayılıyor ve k-lig puanı düşüyor.
 * - **Sıra RAKİPTE** → `turn_deadline`a göre AZALAN (son oynanan üstte).
 *   Burada yapabileceğim bir şey yok; anlamlı sıra "en son hareket eden".
 *
 * ⚠ **AZALAN yön 31 Ağustos 2026'da bir kullanıcı şikayetiyle KONDU**
 * (*"son oynanan her zaman en üstte olacak"* — öncesinde oyunun KURULMA
 * sırası kullanılıyordu). 3 Eylül'deki "en yakın bitiş üstte" isteği onu
 * geçersiz KILMIYOR: o istek sırası ÇAĞIRANDA olan gruba ait. Listenin
 * tamamını artana çevirmek, iki gün önce düzeltilen davranışı geri
 * getirirdi.
 *
 * ⚠ **`deadlineMs == null` HER İKİ grupta da EN SONA düşer.** Bu, artan
 * sıralamada sessiz bir tuzak: null'ı 0 saymak (portun ve web'in eski
 * ortak numarası) onu "en yakın bitiş" sanıp EN ÜSTE taşırdı. Null =
 * "state henüz kurulmamış", yani bilinmeyen — bilinmeyeni acil saymak
 * yanlış.
 */
export function orderActiveGames<T>(
  items: readonly T[],
  opts: { myTurn: (t: T) => boolean; deadlineMs: (t: T) => number | null },
): T[] {
  return stableSort(items, (a, b) => {
    const grup = Number(opts.myTurn(b)) - Number(opts.myTurn(a));
    if (grup !== 0) return grup;
    const da = opts.deadlineMs(a);
    const db = opts.deadlineMs(b);
    // Bilinmeyen her zaman sona — grubun yönünden BAĞIMSIZ.
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return opts.myTurn(a) ? da - db : db - da;
  });
}

/**
 * Süresi olan bekleyen kayıtlar (oyun davetleri, yerel YZ kayıtları):
 * **bitmeye en yakın üstte**, yani ARTAN.
 *
 * İki yerde de "bitiş" gerçek bir kayıp: davet süresi dolunca oyun iptal
 * oluyor, yerel kaydın 7 günü dolunca oyun siliniyor (girişli kullanıcıda
 * -2 puanla teslim sayılıyor). Yani en yakın olan en üstte durmalı.
 *
 * ⚠ Null yine EN SONA — bkz. [orderActiveGames].
 */
export function orderByExpiry<T>(
  items: readonly T[],
  expiryMs: (t: T) => number | null,
): T[] {
  return stableSort(items, (a, b) => {
    const ea = expiryMs(a);
    const eb = expiryMs(b);
    if (ea == null && eb == null) return 0;
    if (ea == null) return 1;
    if (eb == null) return -1;
    return ea - eb;
  });
}

/**
 * İndeks tie-break'li sıralama.
 *
 * ⚠ Gerekli, çünkü **Dart'ın `List.sort`u kararlı DEĞİL** (core sözleşmesi)
 * ve bu dosyanın port ikizi aynı sonucu vermek zorunda. JS `Array.sort`
 * ES2019'dan beri kararlı olsa da iki taraf aynı algoritmayı okusun diye
 * burada da açıkça yazılıyor — "platform zaten yapıyor" bir parite
 * garantisi değil.
 */
function stableSort<T>(items: readonly T[], cmp: (a: T, b: T) => number): T[] {
  return items
    .map((value, index) => ({ value, index }))
    .sort((a, b) => cmp(a.value, b.value) || a.index - b.index)
    .map((e) => e.value);
}
