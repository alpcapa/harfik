// Kart altı PUAN SATIRI — "Devam Eden" (Canlı + YZ) ve "Son Oynananlar"
// kartlarında avatarların altına, koltuk sırasıyla (6 Eylül 2026, kullanıcı
// isteği: *"avatarların altına kişilerin o anki puanlarını yazalım … Böylece
// oyuna girmeden puan durumunu görebilsinler"*).
//
// Sıra AVATAR SIRASIDIR (koltuk / snapshot sırası), sıralama (rank) DEĞİL:
// satırın hemen üstündeki `PlayerAvatarRow` aynı diziyi çiziyor, yani N'inci
// puan N'inci yüzün altına düşer. Ayırıcı her zaman " - ": sayılar yan yana
// tek satırda durduğundan boşluk yetmiyor ("45 38" bir sayı gibi okunuyor).
// Port ikizi: `mobile/app/lib/src/util/score_line.dart` — metin BİREBİR.
export function scoreLine(scores: readonly number[]): string {
  return scores.join(' - ');
}
