// Kelimeki core — Türkçe büyük/küçük harf ve sıralama (src/utils/turkish.ts
// portu).
//
// Dart'ın toLowerCase/toUpperCase'i JS gibi kök-locale çalışır: 'I'→'i'
// (yanlış, 'ı' olmalı) ve 'İ'.toLowerCase() Unicode varsayılanında 'i'+U+0307
// (İKİ code unit, görünmez birleşen nokta) üretir — replaceAll'ların
// toLowerCase'ten ÖNCE koşması bu yüzden yük taşır, sırayı değiştirme.

String trLower(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

// TS'teki trCompare `localeCompare(..., 'tr')` (ICU) kullanır; Dart çekirdeğinde
// collator yok. Alfabe kapalı olduğundan (a-z + çğıöşü) tablo tabanlı bir
// karşılık yeterli: birincil karşılaştırma trLower'lanmış harf sıralarıyla,
// eşitlikte üçüncül olarak küçük harf büyükten önce gelir (ICU davranışı).
// Golden vector'lardaki işaret karşılaştırmaları bu eşleşmeyi doğrular.
const String _turkishOrder = 'abcçdefgğhıijklmnoöprsştuüvyz';
final Map<String, int> _rank = {
  for (var i = 0; i < _turkishOrder.length; i++) _turkishOrder[i]: i,
};

int trCompare(String a, String b) {
  final la = trLower(a), lb = trLower(b);
  final n = la.length < lb.length ? la.length : lb.length;
  for (var i = 0; i < n; i++) {
    final ca = la[i], cb = lb[i];
    if (ca == cb) continue;
    final ra = _rank[ca], rb = _rank[cb];
    if (ra != null && rb != null) return ra < rb ? -1 : 1;
    // Alfabe dışı karakter (rakam, boşluk, noktalama…): kod birimi sırası.
    final d = ca.codeUnitAt(0) - cb.codeUnitAt(0);
    if (d != 0) return d < 0 ? -1 : 1;
  }
  if (la.length != lb.length) return la.length < lb.length ? -1 : 1;
  // Birincil eşit: üçüncül — ilk farklı orijinal pozisyonda küçük harf önce.
  final m = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < m; i++) {
    if (a[i] == b[i]) continue;
    final aLower = a[i] == trLower(a[i]);
    final bLower = b[i] == trLower(b[i]);
    if (aLower != bLower) return aLower ? -1 : 1;
    return a.codeUnitAt(i) < b.codeUnitAt(i) ? -1 : 1;
  }
  if (a.length != b.length) return a.length < b.length ? -1 : 1;
  return 0;
}
