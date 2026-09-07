// Kart altı PUAN SATIRININ GEOMETRİSİ — web `src/utils/scoreLine.ts` ikizi
// (6 Eylül 2026, kullanıcı isteği). Her puan KENDİ AVATARININ TAM ALTINDA.
//
// ⚠ İLK HÂLİ TEK BİR DİZEYDİ (`45 - 38`) ve kullanıcı aynı gün bildirdi:
// *"Puanlar avatarların tam altına gelmiyor. Özellikle 4 kişilik oyunda."*
// Sebep yapısal: avatarlar ÜST ÜSTE BİNİYOR (26 px çap, 6 px binişme →
// adım 20 px), akan bir metin kendi harf genişliğine göre ilerler; iki ritim
// 4 koltukta tamamen ayrışır. Sayılar avatar adımına oturtulunca ayırıcı
// tireye de gerek kalmadı — ayrımı HİZA yapıyor (kullanıcı: "C hizalı").
//
// Sıra AVATAR SIRASIDIR (koltuk / snapshot sırası), sıralama DEĞİL.

/// Bir puan hücresinin eni = avatar ADIMI (bindirme yüzünden çaptan küçük).
double scoreCellWidth(double avatarSize, double overlap) => avatarSize - overlap;

/// Satırın sola kaydırması: `(çap - adım)/2 = binişme/2` (26/6 için 3 px).
/// Çap parametre DEĞİL, çünkü sadeleşince düşüyor — iki taraf da öyle.
double scoreRowOffset(double overlap) => overlap / 2;
