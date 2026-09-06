// Kart altı PUAN SATIRI — web `src/utils/scoreLine.ts` ikizi (6 Eylül 2026,
// kullanıcı isteği: *"avatarların altına kişilerin o anki puanlarını
// yazalım … Böylece oyuna girmeden puan durumunu görebilsinler"*).
//
// Sıra AVATAR SIRASIDIR (koltuk / snapshot sırası), sıralama (rank) DEĞİL:
// satırın hemen üstündeki `PlayerAvatarRow` aynı diziyi çiziyor, yani N'inci
// puan N'inci yüzün altına düşer. Ayırıcı her zaman " - ": sayılar yan yana
// tek satırda durduğundan boşluk yetmiyor ("45 38" bir sayı gibi okunuyor).
// Metin web ile BİREBİR — `score_line_test.dart` üç kartta da okuyor.
String scoreLine(Iterable<int> scores) => scores.join(' - ');
