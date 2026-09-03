// Kafa kafaya oran çubuğunun SAF kuralı — web ikizi
// `src/utils/headToHead.ts` ile BİREBİR aynı. Biri değişirse öteki de.
//
// Kullanıcı isteği (3 Eylül 2026): barın SOLUNDA bakılan kişinin avatarı,
// SAĞINDA bakana ait avatar, üstünde oyun sayısı, isim YOK.
//
// Veri `head_to_head_stats` RPC'sinden ve ÇAĞIRANIN bakış açısından geliyor:
// `wins` = çağıran kazandı, `losses` = bakılan kişi kazandı. Bar bu yüzden
// TERS okunuyor — sol uç `losses`, sağ uç `wins`.

class HeadToHead {
  final int games;
  final int wins; // çağıran (bakan kişi)
  final int losses; // bakılan kişi
  final int draws;
  const HeadToHead({
    required this.games,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  factory HeadToHead.fromJson(Map<String, Object?> m) => HeadToHead(
        games: (m['games'] as num?)?.toInt() ?? 0,
        wins: (m['wins'] as num?)?.toInt() ?? 0,
        losses: (m['losses'] as num?)?.toInt() ?? 0,
        draws: (m['draws'] as num?)?.toInt() ?? 0,
      );
}

class HeadToHeadBar {
  /// Bakılan kişinin payı — barın SOL ucu, yüzde.
  final int left;

  /// Beraberlikler — ortada nötr bant, yüzde.
  final int middle;

  /// Bakanın payı — barın SAĞ ucu, yüzde.
  final int right;
  const HeadToHeadBar(this.left, this.middle, this.right);
}

/// Üç dilimi yüzdeye çevirir ve **toplamlarının tam 100 olmasını GARANTİ
/// eder** (oyun varsa).
///
/// ⚠ Yuvarlama üçünü de bağımsız yuvarlamakla yapılmıyor: 1/3-1/3-1/3 gibi
/// bir dağılımda üç ayrı `round` 33+33+33 = 99 verir ve barın ucunda
/// görünür bir boşluk kalır. Bunun yerine soldan kümülatif yuvarlama
/// kullanılıyor — son dilim artanı alır.
///
/// `games <= 0` → üçü de 0; çağıran bloğu HİÇ çizmemeli ([hasHeadToHead]).
HeadToHeadBar headToHeadBar(HeadToHead h) {
  if (h.games <= 0) return const HeadToHeadBar(0, 0, 0);
  double pay(int n) => (n * 100) / h.games;
  final left = pay(h.losses).round();
  final middle = pay(h.losses + h.draws).round() - left;
  return HeadToHeadBar(left, middle, 100 - left - middle);
}

/// Blok çizilsin mi — hiç oynanmamışsa yer kaplamasın.
bool hasHeadToHead(HeadToHead? h) => h != null && h.games > 0;
